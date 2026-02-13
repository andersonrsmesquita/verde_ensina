import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppUserModel {
  final String uid;
  final String? email;
  final String displayName;
  final String plan; // free | pro | ...
  final String role; // produtor | admin
  final bool ativo;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  const AppUserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.plan,
    required this.role,
    required this.ativo,
    this.createdAt,
    this.updatedAt,
  });

  factory AppUserModel.fromAuth(User user) {
    return AppUserModel(
      uid: user.uid,
      email: user.email,
      displayName: (user.displayName ?? '').trim(),
      plan: 'free',
      role: 'produtor',
      ativo: true,
      createdAt: null,
      updatedAt: null,
    );
  }

  factory AppUserModel.fromMap(String uid, Map<String, dynamic> map) {
    return AppUserModel(
      uid: uid,
      email: (map['email'] as String?),
      displayName: (map['displayName'] ?? '').toString(),
      plan: (map['plan'] ?? 'free').toString(),
      role: (map['role'] ?? 'produtor').toString(),
      ativo: (map['ativo'] ?? true) == true,
      createdAt: map['createdAt'] as Timestamp?,
      updatedAt: map['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'email': email,
      'displayName': displayName,
      'plan': plan,
      'role': role,
      'ativo': ativo,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
