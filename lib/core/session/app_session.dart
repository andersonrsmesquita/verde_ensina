import 'package:flutter/foundation.dart'; // Necessário para listEquals e mapEquals se não usares o pacote Equatable

class AppSession {
  final String uid;
  final String tenantId;
  // ✅ Mudei para Set. A busca em Set é O(1) (instantânea), em List é O(n).
  final Set<String> scopes;

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

  // ✅ Método auxiliar para verificar permissões facilmente
  bool hasPermission(String permission) {
    return scopes.contains(permission) || scopes.contains('tenant:admin');
  }

  // ✅ Método auxiliar para verificar se um módulo está ativo.
  // Regra de ouro para não quebrar ambientes antigos:
  // - Se o tenant ainda não tem 'modulesEnabled', consideramos TUDO ativo (comportamento atual).
  // - Se o módulo não existe no mapa, consideramos ativo (default permissivo).
  // - Se existir e for 'false', aí sim bloqueia.
  bool isModuleActive(String moduleKey) {
    final m = modulesEnabled;
    if (m == null) return true;
    final v = m[moduleKey];
    if (v == null) return true;
    return v == true;
  }

  AppSession copyWith({
    String? uid,
    String? tenantId,
    Set<String>? scopes,
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

  // ✅ Implementação de igualdade.
  // Sem isso, o Flutter pensa que dois objetos com os mesmos dados são diferentes.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AppSession &&
        other.uid == uid &&
        other.tenantId == tenantId &&
        setEquals(other.scopes, scopes) && // Requer importar flutter/foundation
        other.tenantName == tenantName &&
        other.subscriptionStatus == subscriptionStatus &&
        other.trialEndsAt == trialEndsAt &&
        mapEquals(other.modulesEnabled,
            modulesEnabled); // Requer importar flutter/foundation
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        tenantId.hashCode ^
        scopes.hashCode ^
        tenantName.hashCode ^
        subscriptionStatus.hashCode ^
        trialEndsAt.hashCode ^
        modulesEnabled.hashCode;
  }
}
