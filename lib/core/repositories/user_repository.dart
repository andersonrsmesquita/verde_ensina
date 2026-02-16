import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_writer.dart';

class UserRepository {
  static final _fs = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> ref(String uid) =>
      _fs.collection('users').doc(uid);

  static Future<void> ensureUserDoc(User user) async {
    final docRef = ref(user.uid);
    final snap = await docRef.get();

    final base = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'plan': 'free',
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    };

    if (!snap.exists) {
      await FirestoreWriter.create(docRef, base);
      return;
    }

    // Já existe: só atualiza login/updatedAt (não destrói dados antigos)
    await FirestoreWriter.update(docRef, {
      'email': user.email,
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }
}
