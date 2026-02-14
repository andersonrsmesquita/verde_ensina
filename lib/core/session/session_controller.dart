import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../firebase/firebase_paths.dart';
import 'app_session.dart';

enum SessionStatus {
  unknown,
  signedOut,
  signedIn,
  needsTenant,
  ready,
  error,
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

  bool _ready = false;
  bool get ready => _ready;

  Object? _error;
  Object? get error => _error;

  SessionStatus _status = SessionStatus.unknown;
  SessionStatus get status => _status;

  DocumentSnapshot<Map<String, dynamic>>? _userDoc;
  DocumentSnapshot<Map<String, dynamic>>? get userDoc => _userDoc;

  AppSession? _session;
  AppSession? get session => _session;

  String? get uid => _auth.currentUser?.uid;
  bool get isLoggedIn => uid != null;

  // --- helpers de compatibilidade (migração do app antigo p/ multi-tenant) ---
  String? _stringOrNull(dynamic v) {
    if (v is String) {
      final s = v.trim();
      return s.isEmpty ? null : s;
    }
    return null;
  }

  List<String> _asStringList(dynamic v) {
    if (v == null) return <String>[];
    if (v is List) {
      return v
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (v is String) {
      final s = v.trim();
      return s.isEmpty ? <String>[] : <String>[s];
    }
    return <String>[];
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i=0; i<a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _dynamicListEquals(dynamic original, List<String> normalized) {
    if (original == null) return normalized.isEmpty;
    if (original is List) {
      final mapped = original
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
      return _listEquals(mapped, normalized);
    }
    if (original is String) {
      final s = original.trim();
      return _listEquals(s.isEmpty ? <String>[] : <String>[s], normalized);
    }
    return normalized.isEmpty;
  }

  Future<void> init() async {
    await _authSub?.cancel();

    // primeiro estado (boot)
    _onAuth(_auth.currentUser);

    // depois continua ouvindo mudanças
    _authSub = _auth.authStateChanges().listen(_onAuth);
  }

  void _onAuth(User? user) {
    _userSub?.cancel();
    _memberSub?.cancel();

    _session = null;
    _userDoc = null;
    _error = null;
    _ready = false;

    if (user == null) {
      _status = SessionStatus.signedOut;
      _ready = true;
      notifyListeners();
      return;
    }

    _status = SessionStatus.signedIn;
    notifyListeners();

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

        _userDoc = snap;
        final data = snap.data() ?? {};

        final normalizedTenantIds = _asStringList(data['tenantIds']);
        final fix = <String, dynamic>{};

        if (!_dynamicListEquals(data['tenantIds'], normalizedTenantIds)) {
          fix['tenantIds'] = normalizedTenantIds;
        }
        if (data['currentTenantId'] != null && data['currentTenantId'] is! String) {
          fix['currentTenantId'] = null;
        }
        if (data['defaultTenantId'] != null && data['defaultTenantId'] is! String) {
          fix['defaultTenantId'] = null;
        }

        if (fix.isNotEmpty) {
          fix['updatedAt'] = FieldValue.serverTimestamp();
          await uref.set(fix, SetOptions(merge: true));
        }

        final currentTenantId = _stringOrNull(data['currentTenantId']);
        final defaultTenantId = _stringOrNull(data['defaultTenantId']);
        final tenantId = currentTenantId ??
            defaultTenantId ??
            (normalizedTenantIds.isNotEmpty ? normalizedTenantIds.first : null);

        if (tenantId == null || tenantId.trim().isEmpty) {
          _session = null;
          _error = null;
          _ready = true;
          _status = SessionStatus.needsTenant;
          notifyListeners();
          return;
        }

        _listenMembership(user.uid, tenantId);
      } catch (e) {
        _error = e;
        _session = null;
        _ready = true;
        _status = SessionStatus.error;
        notifyListeners();
      }
    });
  }

  void _listenMembership(String uid, String tenantId) {
    _memberSub?.cancel();
    _memberSub = FirebasePaths.memberRef(tenantId, uid).snapshots().listen((snap) {
      try {
        if (!snap.exists) {
          _session = null;
          _ready = true;
          _status = SessionStatus.needsTenant;
          notifyListeners();
          return;
        }

        final m = snap.data() ?? {};
        final active = (m['active'] ?? true) == true;
        if (!active) {
          _session = null;
          _ready = true;
          _status = SessionStatus.needsTenant;
          notifyListeners();
          return;
        }

        final scopesRaw = (m['scopes'] is List) ? (m['scopes'] as List) : <dynamic>[];
        final scopes = scopesRaw.map((e) => e.toString()).toList();

        _session = AppSession(uid: uid, tenantId: tenantId, scopes: scopes);
        _ready = true;
        _error = null;
        _status = SessionStatus.ready;
        notifyListeners();
      } catch (e) {
        _error = e;
        _session = null;
        _ready = true;
        _status = SessionStatus.error;
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

  Future<String> createTenant({required String name}) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('Usuário não logado');

    final tenantRef = FirebasePaths.tenantsCol().doc();
    final uid = u.uid;
    final userRef = FirebasePaths.userRef(uid);

    // IMPORTANTE (Windows): evitamos `runTransaction()` aqui.
    // Em alguns cenários o SDK nativo pode abortar o processo.
    // Batch é atômico (tudo ou nada) e é suficiente para o onboarding.
    final userSnap = await userRef.get();
    final userData = userSnap.data() ?? <String, dynamic>{};

    final defaultTenantId = _stringOrNull(userData['defaultTenantId']);

    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();

    batch.set(tenantRef, {
      'name': name,
      'status': 'active',
      'createdAt': now,
      'updatedAt': now,
      'ownerUid': uid,
      // SaaS baseline
      'subscriptionStatus': 'trial',
      'trialEndsAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
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

    batch.set(FirebasePaths.memberRef(tenantRef.id, uid), {
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
      'createdAt': now,
      'updatedAt': now,
    });

    batch.set(
      userRef,
      {
        if (!userSnap.exists) 'createdAt': now,
        'updatedAt': now,
        if ((defaultTenantId ?? '').isEmpty) 'defaultTenantId': tenantRef.id,
        'currentTenantId': tenantRef.id,
        'tenantIds': FieldValue.arrayUnion([tenantRef.id]),
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    return tenantRef.id;
  }

  /// Sai da conta e reseta o estado local.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } finally {
      await _authSub?.cancel();
      await _userSub?.cancel();
      await _memberSub?.cancel();
      _authSub = null;
      _userSub = null;
      _memberSub = null;

      _userDoc = null;
      _session = null;
      _error = null;
      _ready = true;
      _status = SessionStatus.signedOut;
      notifyListeners();

      // reescuta auth pra não ficar "morto" depois do logout
      await init();
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
