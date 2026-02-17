// FILE: lib/core/repositories/user_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Importe o seu escritor se ele estiver em outro lugar, ajuste o caminho
import 'firestore_writer.dart';

class UserRepository {
  static final _fs = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> ref(String uid) =>
      _fs.collection('users').doc(uid);

  /// Garante que o usuário tenha um documento no banco ao logar
  static Future<void> ensureUserDoc(User user) async {
    final docRef = ref(user.uid);
    final snap = await docRef.get();

    final base = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'displayName':
          user.displayName, // Adicionei para já salvar o nome se houver
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

  // --- NOVO MÉTODO ADICIONADO ---
  // Usado pela TelaPerfil para editar o nome do usuário
  Future<void> updateProfile(
      {required String uid, required String nome}) async {
    final user = FirebaseAuth.instance.currentUser;

    // 1. Atualiza no Auth (Sessão do App)
    if (user != null) {
      await user.updateDisplayName(nome);
    }

    // 2. Atualiza no Firestore (Banco de Dados)
    final docRef = ref(uid);

    await FirestoreWriter.update(docRef, {
      'displayName': nome, // Campo padrão do Firebase Auth
      'nome': nome, // Campo de redundância (caso seu modelo use 'nome')
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
