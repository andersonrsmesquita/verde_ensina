import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../firebase/firebase_paths.dart';
import 'app_session.dart';


/// Estado interno simples para telas e logs.
///
/// Não é obrigatório para o app, mas ajuda a manter compatibilidade
/// com chamadas que esperam um 'status' de sessão.
enum SessionStatus {
  booting,
  signedIn,
  signedOut,
}

class SessionController extends ChangeNotifier {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  SessionController({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _memberSub;

  DocumentSnapshot<Map<String, dynamic>>? _userDoc;

  SessionStatus _status = SessionStatus.booting;
  SessionStatus get status => _status;

  bool _ready = false;
  bool get ready => _ready;

  Object? _error;
  Object? get error => _error;

  AppSession? _session;
  AppSession? get session => _session;

  String? get uid => _auth.currentUser?.uid;
  bool get isLoggedIn => uid != null;

  Future<void> init() async {
    _authSub?.cancel();

    // primeiro estado (boot)
    _onAuth(_auth.currentUser);

    // depois continua ouvindo mudanças
    _authSub = _auth.authStateChanges().listen(_onAuth);
  }

  void _onAuth(User? user) {
    _userSub?.cancel();
    _memberSub?.cancel();

    _session = null;
    _error = null;
    _ready = false;
    _status = SessionStatus.booting;
    notifyListeners();

    if (user == null) {
      _status = SessionStatus.signedOut;
      _ready = true;
      notifyListeners();
      return;
    }

    // garante user doc
    final uref = FirebasePaths.userRef(user.uid);
    _userSub = uref.snapshots().listen((snap) async {
      try {
        _userDoc = snap;
        if (!snap.exists) {
          await uref.set({
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'currentTenantId': null,
            'defaultTenantId': null,
            'tenantIds': <String>[],
          }, SetOptions(merge: true));
        }

        final data = snap.data() ?? {};
        final currentTenantId = (data['currentTenantId'] ?? '').toString();
        final defaultTenantId = (data['defaultTenantId'] ?? '').toString();

        final tenantId = currentTenantId.isNotEmpty
            ? currentTenantId
            : (defaultTenantId.isNotEmpty ? defaultTenantId : '');

        if (tenantId.isEmpty) {
          // logou, mas ainda não escolheu/criou tenant
          _session = null;
          _ready = true;
          notifyListeners();
          return;
        }

        _listenMembership(user.uid, tenantId);
      } catch (e) {
        _error = e;
        _ready = true;
        notifyListeners();
      }
    });
  }

  void _listenMembership(String uid, String tenantId) {
    _memberSub?.cancel();
    _memberSub =
        FirebasePaths.memberRef(tenantId, uid).snapshots().listen((snap) {
      try {
        if (!snap.exists) {
          // usuário tá apontando pra um tenant que ele não participa
          _session = null;
          _ready = true;
          notifyListeners();
          return;
        }

        final m = snap.data() ?? {};
        final active = (m['active'] ?? true) == true;
        if (!active) {
          _session = null;
          _ready = true;
          notifyListeners();
          return;
        }

        final scopesRaw =
            (m['scopes'] is List) ? (m['scopes'] as List) : <dynamic>[];
        final scopes = scopesRaw.map((e) => e.toString()).toList();

        _session = AppSession(uid: uid, tenantId: tenantId, scopes: scopes);
        _status = SessionStatus.signedIn;
        _ready = true;
        _error = null;
        notifyListeners();
      } catch (e) {
        _error = e;
        _session = null;
        _ready = true;
        notifyListeners();
      }
    });
  }

  Future<void> selectTenant(String tenantId) async {
    final u = _auth.currentUser;
    if (u == null) return;

    await FirebasePaths.userRef(u.uid).set({
      'currentTenantId': tenantId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> createTenant({
    required String name,
  }) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('Usuário não logado');

    final tenantRef = FirebasePaths.tenantsCol().doc();
    final uid = u.uid;

    await _db.runTransaction((tx) async {
      tx.set(tenantRef, {
        'name': name,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'ownerUid': uid,
        // SaaS baseline
        'subscriptionStatus': 'trial',
        'trialEndsAt':
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
        'modulesEnabled': {
          'canteiros': true,
          'solo': true,
          'irrigacao': true,
          'pragas': true,
          'planejamento': true,
          'mercado': false,
          'financeiro': false,
        },
      });

      tx.set(tenantRef.collection('members').doc(uid), {
        'uid': uid,
        'role': 'owner',
        'active': true,
        'scopes': [
          'tenant:admin',
          'canteiros:edit',
          'canteiros:view',
          'manejo:edit',
          'manejo:view',
          'financeiro:view',
          'financeiro:edit',
        ],
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(
          FirebasePaths.userRef(uid),
          {
            'defaultTenantId': tenantRef.id,
            'currentTenantId': tenantRef.id,
            'tenantIds': FieldValue.arrayUnion([tenantRef.id]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });

    return tenantRef.id;
  }

  /// Sai da conta e reseta o estado local.
  ///
  /// Algumas telas (ex: TenantPickerPage) chamam `session.signOut()`.
  /// Essa API não existia no projeto original, então deixamos aqui
  /// pra ficar estável e previsível.
  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } finally {
      // O authStateChanges vai disparar e `init()` vai limpar,
      // mas garantimos o reset imediatamente.
      _authSub?.cancel();
      _userSub?.cancel();
      _memberSub?.cancel();
      _authSub = null;
      _userSub = null;
      _memberSub = null;
      _userDoc = null;
      _session = null;
      _status = SessionStatus.signedOut;
      notifyListeners();

      // Reescuta o auth para não ficar "morto" após o logout.
      init();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    _memberSub?.cancel();
    super.dispose();
  }
}
