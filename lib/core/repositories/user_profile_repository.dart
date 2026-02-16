import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user_model.dart';
import 'firestore_writer.dart';

class UserProfileRepository {
  final FirebaseFirestore _fs;
  UserProfileRepository({FirebaseFirestore? fs})
      : _fs = fs ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _fs.collection('usuarios');

  Stream<DocumentSnapshot<Map<String, dynamic>>> watch(String uid) {
    return _col.doc(uid).snapshots();
  }

  Future<void> ensureFromAuthUser(User user) async {
    final ref = _col.doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      final model = AppUserModel.fromAuth(user);
      await FirestoreWriter.create(ref, model.toCreateMap());
      return;
    }

    // já existe -> só garante email/updatedAt
    await FirestoreWriter.update(ref, {
      'email': user.email,
    });
  }
}
