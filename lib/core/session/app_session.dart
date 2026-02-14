class AppSession {
  final String uid;
  final String tenantId;
  final List<String> scopes;

  // ✅ dados do tenant (pra UI e regras SaaS)
  final String? tenantName;
  final String? subscriptionStatus;
  final DateTime? trialEndsAt;
  final Map<String, dynamic>? modulesEnabled;

  const AppSession({
    required this.uid,
    required this.tenantId,
    required this.scopes,
    this.tenantName,
    this.subscriptionStatus,
    this.trialEndsAt,
    this.modulesEnabled,
  });

  AppSession copyWith({
    String? uid,
    String? tenantId,
    List<String>? scopes,
    String? tenantName,
    String? subscriptionStatus,
    DateTime? trialEndsAt,
    Map<String, dynamic>? modulesEnabled,
  }) {
    return AppSession(
      uid: uid ?? this.uid,
      tenantId: tenantId ?? this.tenantId,
      scopes: scopes ?? this.scopes,
      tenantName: tenantName ?? this.tenantName,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      modulesEnabled: modulesEnabled ?? this.modulesEnabled,
    );
  }
}
