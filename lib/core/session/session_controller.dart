import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../firebase/firebase_paths.dart';
import 'app_session.dart';

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
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _tenantSub;

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

    // estado inicial
    _onAuth(_auth.currentUser);

    // e depois escuta mudanças
    _authSub = _auth.authStateChanges().listen(_onAuth);
  }

  void _resetAll({bool notify = true}) {
    _userSub?.cancel();
    _memberSub?.cancel();
    _tenantSub?.cancel();

    _userSub = null;
    _memberSub = null;
    _tenantSub = null;

    _session = null;
    _error = null;
    _ready = false;

    if (notify) notifyListeners();
  }

  void _onAuth(User? user) {
    _resetAll(notify: true);

    if (user == null) {
      _ready = true;
      notifyListeners();
      return;
    }

    final uref = FirebasePaths.userRef(user.uid);

    _userSub = uref.snapshots().listen((snap) async {
      try {
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
          _error = null;
          notifyListeners();
          return;
        }

        _listenMembership(user.uid, tenantId);
      } catch (e) {
        _error = e;
        _session = null;
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

        // ✅ aqui é o pulo do gato: além do member, carrega o tenant doc
        _listenTenantDoc(uid: uid, tenantId: tenantId, scopes: scopes);
      } catch (e) {
        _error = e;
        _session = null;
        _ready = true;
        notifyListeners();
      }
    });
  }

  void _listenTenantDoc({
    required String uid,
    required String tenantId,
    required List<String> scopes,
  }) {
    _tenantSub?.cancel();

    final tRef = FirebasePaths.tenantsCol().doc(tenantId);

    _tenantSub = tRef.snapshots().listen((snap) {
      try {
        if (!snap.exists) {
          _session = null;
          _ready = true;
          _error = Exception('Tenant não encontrado');
          notifyListeners();
          return;
        }

        final t = snap.data() ?? {};
        final name = (t['name'] ?? 'Espaço').toString();
        final subscriptionStatus = (t['subscriptionStatus'] ?? 'trial').toString();

        DateTime? trialEndsAt;
        final te = t['trialEndsAt'];
        if (te is Timestamp) trialEndsAt = te.toDate();

        final modulesEnabled = (t['modulesEnabled'] is Map)
            ? Map<String, dynamic>.from(t['modulesEnabled'] as Map)
            : null;

        _session = AppSession(
          uid: uid,
          tenantId: tenantId,
          scopes: scopes,
          tenantName: name,
          subscriptionStatus: subscriptionStatus,
          trialEndsAt: trialEndsAt,
          modulesEnabled: modulesEnabled,
        );

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
        SetOptions(merge: true),
      );
    });

    return tenantRef.id;
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } finally {
      _resetAll(notify: false);
      _ready = true;
      notifyListeners();

      // garante que volta a escutar auth após logout
      init();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    _memberSub?.cancel();
    _tenantSub?.cancel();
    super.dispose();
  }
}
