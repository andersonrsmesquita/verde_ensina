// FILE: lib/core/models/app_user_model.dart

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? currentTenantId;
  final Map<String, String> tenants; // Map<TenantId, Role>

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.currentTenantId,
    this.tenants = const {},
  });

  // ✅ BLINDAGEM: Converte tipos dinâmicos do Firebase com segurança
  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    return AppUser(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['displayName'] ??
          map['nome'] ??
          'Usuário', // Tenta 'nome' se 'displayName' falhar
      photoUrl: map['photoUrl'],
      currentTenantId: map['currentTenantId'],
      // Converte Map<dynamic, dynamic> para Map<String, String> seguramente
      tenants: (map['tenants'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value.toString()),
          ) ??
          {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'currentTenantId': currentTenantId,
      'tenants': tenants,
    };
  }

  AppUser copyWith({
    String? displayName,
    String? photoUrl,
    String? currentTenantId,
    Map<String, String>? tenants,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      currentTenantId: currentTenantId ?? this.currentTenantId,
      tenants: tenants ?? this.tenants,
    );
  }
}
