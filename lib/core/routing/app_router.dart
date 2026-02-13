import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_state_listenable.dart';

// Suas telas
import '../../features/auth/tela_login.dart';
import '../../features/home/tela_home.dart';
import '../../features/trilha/tela_trilha.dart';
import '../../features/canteiros/tela_canteiros.dart';
import '../../features/solo/tela_diagnostico.dart';
import '../../features/calculadoras/tela_calagem.dart';
import '../../features/planejamento/tela_planejamento_consumo.dart';
import '../../features/adubacao/tela_adubacao_organo15.dart';

CustomTransitionPage<T> _fadeSlide<T>({
  required Widget child,
  required GoRouterState state,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      final offset = Tween<Offset>(
        begin: const Offset(0.02, 0.02),
        end: Offset.zero,
      ).animate(fade);

      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: offset, child: child),
      );
    },
  );
}

GoRouter buildRouter(AuthStateListenable auth) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      final loggedIn = auth.isLoggedIn;
      final goingLogin = state.matchedLocation == '/login';

      if (!loggedIn && !goingLogin) return '/login';
      if (loggedIn && goingLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _fadeSlide(child: const TelaLogin(), state: state),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            _fadeSlide(child: const TelaHome(), state: state),
      ),

      // Rotas utilitárias (pra navegar sem depender de "abas internas")
      GoRoute(
        path: '/trilha',
        pageBuilder: (context, state) =>
            _fadeSlide(child: const TelaTrilha(), state: state),
      ),
      GoRoute(
        path: '/planejamento',
        pageBuilder: (context, state) =>
            _fadeSlide(child: const TelaPlanejamentoConsumo(), state: state),
      ),
      GoRoute(
        path: '/canteiros',
        pageBuilder: (context, state) =>
            _fadeSlide(child: const TelaCanteiros(), state: state),
      ),
      GoRoute(
        path: '/adubacao',
        pageBuilder: (context, state) =>
            _fadeSlide(child: const TelaAdubacaoOrgano15(), state: state),
      ),
      GoRoute(
        path: '/diagnostico/:canteiroId',
        pageBuilder: (context, state) {
          final id = state.pathParameters['canteiroId']!;
          return _fadeSlide(
            child: TelaDiagnostico(canteiroIdOrigem: id),
            state: state,
          );
        },
      ),
      GoRoute(
        path: '/calagem/:canteiroId',
        pageBuilder: (context, state) {
          final id = state.pathParameters['canteiroId']!;
          return _fadeSlide(
            child: TelaCalagem(canteiroIdOrigem: id),
            state: state,
          );
        },
      ),
    ],
  );
}
