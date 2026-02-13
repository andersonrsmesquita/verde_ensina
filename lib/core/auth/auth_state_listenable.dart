import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthStateListenable extends ChangeNotifier {
  AuthStateListenable() {
    _sub = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  StreamSubscription<User?>? _sub;

  User? get user => FirebaseAuth.instance.currentUser;
  bool get isLoggedIn => user != null;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
