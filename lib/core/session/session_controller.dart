import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase/firebase_paths.dart';
import 'app_session.dart';

// ✅ Configurações padrão separadas (Fica fácil de alterar no futuro)
class SaasConfig {
  static const int trialDays = 14;
  
  static const Map<String, bool> defaultModules = {
    'canteiros': true,
    'solo': true,
    'irrigacao': true,
    'pragas': true,
    'planejamento': true,
    'mercado': false,
    'financeiro': false,
  };

  static const List<String> ownerScopes = [
    'tenant:admin',
    'canteiros:edit', 'canteiros:view',
    'manejo:edit', 'manejo:view',
    'financeiro:view', 'financeiro:edit',
  ];
}

class SessionController extends ChangeNotifier {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  SessionController({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  // ... (As variáveis de StreamSubscription continuam iguais) ...
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
    // Executa a primeira verificação manual
    _onAuth(_auth.currentUser);
    // Escuta alterações
    _authSub = _auth.authStateChanges().listen(_onAuth);
  }

  // ... (O método _resetAll continua igual) ...
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
          // Cria o doc do usuário se não existir
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
          _session = null;
          _ready = true;
          notifyListeners();
          return;
        }

        _listenMembership(user.uid, tenantId);
      } catch (e) {
        _setError(e);
      }
    }, onError: _setError); // ✅ Captura erros do stream
  }

  // ✅ Helper simples para setar erro
  void _setError(Object e) {
    _error = e;
    _session = null;
    _ready = true;
    notifyListeners();
  }

  void _listenMembership(String uid, String tenantId) {
    _memberSub?.cancel();
    _memberSub = FirebasePaths.memberRef(tenantId, uid).snapshots().listen((snap) {
      try {
        if (!snap.exists || snap.data()?['active'] != true) {
          // Se não é membro ou foi desativado
          _session = null;
          _ready = true;
          notifyListeners();
          return;
        }

        final m = snap.data()!;
        final scopesRaw = (m['scopes'] is List) ? (m['scopes'] as List) : [];
        
        // ✅ Conversão para Set
        final scopes = scopesRaw.map((e) => e.toString()).toSet();

        _listenTenantDoc(uid: uid, tenantId: tenantId, scopes: scopes);
      } catch (e) {
        _setError(e);
      }
    }, onError: _setError);
  }

  void _listenTenantDoc({
    required String uid,
    required String tenantId,
    required Set<String> scopes, // Agora recebe Set
  }) {
    _tenantSub?.cancel();
    _tenantSub = FirebasePaths.tenantsCol().doc(tenantId).snapshots().listen((snap) {
      try {
        if (!snap.exists) {
          _setError(Exception('Tenant não encontrado'));
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
        _setError(e);
      }
    }, onError: _setError);
  }

  Future<void> selectTenant(String tenantId) async {
    final u = _auth.currentUser;
    if (u == null) return;

    await FirebasePaths.userRef(u.uid).set({
      'currentTenantId': tenantId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> createTenant({required String name}) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('Usuário não logado');

    final tenantRef = FirebasePaths.tenantsCol().doc();
    final uid = u.uid;

    await _db.runTransaction((tx) async {
      // 1. Criar Tenant com dados da Config
      tx.set(tenantRef, {
        'name': name,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'ownerUid': uid,
        'subscriptionStatus': 'trial',
        'trialEndsAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: SaasConfig.trialDays))),
        'modulesEnabled': SaasConfig.defaultModules, // ✅ Uso da constante
      });

      // 2. Criar Membro Admin
      tx.set(tenantRef.collection('members').doc(uid), {
        'uid': uid,
        'role': 'owner',
        'active': true,
        'scopes': SaasConfig.ownerScopes, // ✅ Uso da constante
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Atualizar Referência no User
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
    // ✅ O signOut dispara o authStateChanges, que chama _onAuth(null).
    // Não precisamos chamar init() de novo nem resetar manualmente aqui, 
    // pois o listener cuidará disso.
    await _auth.signOut();
  }

  @override
  void dispose() {
    _resetAll(notify: false);
    _authSub?.cancel();
    super.dispose();
  }
}