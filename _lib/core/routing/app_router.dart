import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_state_listenable.dart';
import 'app_routes.dart';

// Telas
import '../../modules/auth/tela_login.dart';
import '../../modules/home/tela_home.dart';
import '../../modules/conteudo/tela_conteudo.dart';
import '../../modules/diario/tela_diario_manejo.dart';
import '../../modules/alertas/tela_alertas.dart';
import '../../modules/pragas/tela_pragas.dart';
import '../../modules/irrigacao/tela_irrigacao.dart';
import '../../modules/financeiro/tela_financeiro.dart';
import '../../modules/mercado/tela_mercado.dart';
import '../../modules/configuracoes/tela_configuracoes.dart';

class AppRouter {
  static final AuthStateListenable _authListen = AuthStateListenable();

  static CustomTransitionPage<void> _fade(Widget child, GoRouterState state) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: _authListen,
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final indoProLogin = state.matchedLocation == AppRoutes.login;

      if (user == null) {
        return indoProLogin ? null : AppRoutes.login;
      }

      if (user != null && indoProLogin) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _fade(const TelaLogin(), state),
      ),
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (context, state) => _fade(const TelaHome(), state),
      ),

      // Conteúdo & Diário (retenção + essencial)
      GoRoute(
        path: AppRoutes.conteudo,
        pageBuilder: (context, state) => _fade(const TelaConteudo(), state),
      ),
      GoRoute(
        path: AppRoutes.diario,
        pageBuilder: (context, state) => _fade(const TelaDiarioManejo(), state),
      ),

      // Módulos “base” (já deixa reservado)
      GoRoute(
        path: AppRoutes.alertas,
        pageBuilder: (context, state) => _fade(const TelaAlertas(), state),
      ),
      GoRoute(
        path: AppRoutes.pragas,
        pageBuilder: (context, state) => _fade(const TelaPragas(), state),
      ),
      GoRoute(
        path: AppRoutes.irrigacao,
        pageBuilder: (context, state) => _fade(const TelaIrrigacao(), state),
      ),

      // Futuro / admin
      GoRoute(
        path: AppRoutes.financeiro,
        pageBuilder: (context, state) => _fade(const TelaFinanceiro(), state),
      ),
      GoRoute(
        path: AppRoutes.mercado,
        pageBuilder: (context, state) => _fade(const TelaMercado(), state),
      ),
      GoRoute(
        path: AppRoutes.configuracoes,
        pageBuilder: (context, state) =>
            _fade(const TelaConfiguracoes(), state),
      ),
    ],
  );
}
