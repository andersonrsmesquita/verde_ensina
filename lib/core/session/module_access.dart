import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../ui/app_messenger.dart';
import 'app_session.dart';
import 'session_scope.dart';

/// Guardião simples de acesso por:
/// 1) Módulo habilitado no tenant (modulesEnabled)
/// 2) Permissões (scopes)
///
/// Padrão "não quebra nada":
/// - Se não existir modulesEnabled no tenant, consideramos ativo (mantém comportamento atual).
/// - Em debug: se módulo estiver desabilitado, permite abrir, mas avisa (pra você desenvolver tranquilo).
/// - Em release: se módulo estiver desabilitado, bloqueia e avisa.
class ModuleAccess {
  const ModuleAccess._();

  static AppSession? _session(BuildContext context) {
    return SessionScope.sessionOf(context);
  }

  static bool isModuleEnabled(BuildContext context, String moduleKey) {
    final s = _session(context);
    if (s == null) return true;
    return s.isModuleActive(moduleKey);
  }

  static bool hasAnyScope(BuildContext context, List<String> anyScopes) {
    final s = _session(context);
    if (s == null) return true;
    if (s.scopes.contains('tenant:admin')) return true;
    for (final scope in anyScopes) {
      if (s.scopes.contains(scope)) return true;
    }
    return false;
  }

  /// Abre um módulo com validação de módulo + escopo.
  /// - [moduleKey]: chave em tenant.modulesEnabled (ex: 'financeiro', 'mercado', 'canteiros')
  /// - [requiredAnyScopes]: lista de scopes aceitáveis (ex: ['financeiro:view','financeiro:edit'])
  /// - [proLabel]: label para mostrar no aviso quando estiver bloqueado (ex: 'PRO')
  static void openOrNotify({
    required BuildContext context,
    required String moduleKey,
    required VoidCallback open,
    List<String>? requiredAnyScopes,
    String proLabel = 'PRO',
  }) {
    // 1) Checa módulo habilitado
    final enabled = isModuleEnabled(context, moduleKey);
    if (!enabled) {
      if (kDebugMode) {
        AppMessenger.warn('Módulo $proLabel (desativado no tenant) — abrindo em modo desenvolvimento.');
        open();
        return;
      }
      AppMessenger.warn('Módulo $proLabel: este recurso não está habilitado no seu plano.');
      return;
    }

    // 2) Checa permissões (se informado)
    if (requiredAnyScopes != null && requiredAnyScopes.isNotEmpty) {
      final ok = hasAnyScope(context, requiredAnyScopes);
      if (!ok) {
        AppMessenger.warn('Você não tem permissão para acessar este recurso.');
        return;
      }
    }

    open();
  }
}
