// FILE: lib/core/session/session_scope.dart
import 'dart:async';
import 'package:flutter/widgets.dart'; // Necessário para ChangeNotifier e InheritedNotifier
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firebase_paths.dart';
import '../models/app_user_model.dart'; // Certifique-se de ter este arquivo
import 'app_session.dart';

// ✅ Configurações padrão (Mantidas do seu código original)
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
    'canteiros:edit',
    'canteiros:view',
    'manejo:edit',
    'manejo:view',
    'financeiro:view',
    'financeiro:edit',
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

  // Streams para manter a sessão viva e reativa
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

  // Getter útil para evitar erro no TenantPicker
  String? get uid => _auth.currentUser?.uid;
  bool get isLoggedIn => uid != null;

  Future<void> init() async {
    _authSub?.cancel();
    _onAuth(_auth.currentUser);
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
          // Cria doc do usuário se não existir
          await uref.set({
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'currentTenantId': null,
            'defaultTenantId': null,
            'tenantIds': <String>[],
            'displayName': user.displayName, // Salva o nome para o perfil
            'email': user.email,
          }, SetOptions(merge: true));
        }

        final data = snap.data() ?? {};
        final currentTenantId = (data['currentTenantId'] ?? '').toString();
        final defaultTenantId = (data['defaultTenantId'] ?? '').toString();

        final tenantId = currentTenantId.isNotEmpty
            ? currentTenantId
            : (defaultTenantId.isNotEmpty ? defaultTenantId : '');

        if (tenantId.isEmpty) {
          // Usuário sem tenant (estado intermediário ou novo)
          // Cria uma sessão temporária apenas com dados do usuário
          final appUser = AppUser.fromMap(data, user.uid);
          _session = AppSession(
            uid: user.uid,
            tenantId: '',
            scopes: {},
            user: appUser,
          );
          _ready = true;
          notifyListeners();
          return;
        }

        // Passa o data para frente para montar o AppUser depois
        _listenMembership(user.uid, tenantId, data);
      } catch (e) {
        _setError(e);
      }
    }, onError: _setError);
  }

  void _setError(Object e) {
    _error = e;
    _session = null;
    _ready = true;
    notifyListeners();
  }

  void _listenMembership(
      String uid, String tenantId, Map<String, dynamic> userData) {
    _memberSub?.cancel();
    _memberSub =
        FirebasePaths.memberRef(tenantId, uid).snapshots().listen((snap) {
      try {
        if (!snap.exists || snap.data()?['active'] != true) {
          _session = null;
          _ready = true;
          notifyListeners();
          return;
        }

        final m = snap.data()!;
        final scopesRaw = (m['scopes'] is List) ? (m['scopes'] as List) : [];
        final scopes = scopesRaw.map((e) => e.toString()).toSet();

        _listenTenantDoc(
            uid: uid, tenantId: tenantId, scopes: scopes, userData: userData);
      } catch (e) {
        _setError(e);
      }
    }, onError: _setError);
  }

  void _listenTenantDoc({
    required String uid,
    required String tenantId,
    required Set<String> scopes,
    required Map<String, dynamic> userData,
  }) {
    _tenantSub?.cancel();
    _tenantSub =
        FirebasePaths.tenantsCol().doc(tenantId).snapshots().listen((snap) {
      try {
        if (!snap.exists) {
          _setError(Exception('Tenant não encontrado'));
          return;
        }

        final t = snap.data() ?? {};
        final name = (t['name'] ?? 'Espaço').toString();
        final subscriptionStatus =
            (t['subscriptionStatus'] ?? 'trial').toString();

        DateTime? trialEndsAt;
        final te = t['trialEndsAt'];
        if (te is Timestamp) trialEndsAt = te.toDate();

        final modulesEnabled = (t['modulesEnabled'] is Map)
            ? Map<String, dynamic>.from(t['modulesEnabled'] as Map)
            : null;

        // Monta o objeto do usuário para o Perfil
        final appUser = AppUser.fromMap(userData, uid);

        _session = AppSession(
          uid: uid,
          tenantId: tenantId,
          scopes: scopes,
          tenantName: name,
          subscriptionStatus: subscriptionStatus,
          trialEndsAt: trialEndsAt,
          modulesEnabled: modulesEnabled,
          user: appUser, // ✅ Adicionado para Perfil
        );

        _ready = true;
        _error = null;
        notifyListeners();
      } catch (e) {
        _setError(e);
      }
    }, onError: _setError);
  }

  // --- MÉTODOS DE AÇÃO (Resolvendo erros do TenantPicker e Perfil) ---

  // ✅ Atualiza o usuário na memória (usado pela tela de Perfil)
  void updateUser(AppUser newUser) {
    if (_session != null) {
      _session = _session!.copyWith(user: newUser);
      notifyListeners();
    }
  }

  // ✅ Troca de fazenda
  Future<void> selectTenant(String tenantId) async {
    final u = _auth.currentUser;
    if (u == null) return;

    await FirebasePaths.userRef(u.uid).set({
      'currentTenantId': tenantId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ✅ Cria nova fazenda
  Future<String> createTenant(String name) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('Usuário não logado');

    final tenantRef = FirebasePaths.tenantsCol().doc();
    final uid = u.uid;

    await _db.runTransaction((tx) async {
      // 1. Criar Tenant
      tx.set(tenantRef, {
        'name': name,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'ownerUid': uid,
        'subscriptionStatus': 'trial',
        'trialEndsAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: SaasConfig.trialDays))),
        'modulesEnabled': SaasConfig.defaultModules,
      });

      // 2. Criar Membro Admin
      tx.set(tenantRef.collection('members').doc(uid), {
        'uid': uid,
        'role': 'owner',
        'active': true,
        'scopes': SaasConfig.ownerScopes,
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
    await _auth.signOut();
    // Não precisa zerar _session aqui, o listener _onAuth(null) fará isso.
  }

  @override
  void dispose() {
    _resetAll(notify: false);
    _authSub?.cancel();
    super.dispose();
  }
}

// ============================================================================
// 2. SESSION SCOPE (Widgets)
// ============================================================================
class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({
    super.key,
    required SessionController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static SessionController of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(w != null, 'SessionScope não encontrado no contexto.');
    return w!.notifier!;
  }

  static AppSession? sessionOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<SessionScope>()
        ?.notifier
        ?.session;
  }

  static SessionController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SessionScope>()?.notifier;
  }
}
