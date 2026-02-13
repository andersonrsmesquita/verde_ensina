class AppUserModel {
  final String uid;
  final String? email;
  final String plan; // free | pro | etc
  final bool active;

  const AppUserModel({
    required this.uid,
    required this.email,
    required this.plan,
    required this.active,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'plan': plan,
    'active': active,
  };

  static AppUserModel fromMap(Map<String, dynamic> map) => AppUserModel(
    uid: (map['uid'] ?? '').toString(),
    email: map['email']?.toString(),
    plan: (map['plan'] ?? 'free').toString(),
    active: (map['active'] ?? true) == true,
  );
}
