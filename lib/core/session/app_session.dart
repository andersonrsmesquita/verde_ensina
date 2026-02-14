class AppSession {
  final String uid;
  final String tenantId;
  final List<String> scopes;

  const AppSession({
    required this.uid,
    required this.tenantId,
    required this.scopes,
  });
}
