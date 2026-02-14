import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../session/session_controller.dart';

// ✅ CORREÇÃO 1: Importe a TelaHome correta
import '../../modules/home/tela_home.dart';

import '../../modules/auth/login_page.dart';
import '../../modules/tenancy/tenant_picker_page.dart';
import '../../modules/shared/app_error_page.dart';
import '../../modules/shared/splash_page.dart';
// O MainLayout não é mais necessário para a Home, pois a TelaHome já tem layout próprio.
// import '../../modules/layout/main_layout.dart';

class AppRouter {
  static GoRouter buildRouter(SessionController session) {
    return GoRouter(
      initialLocation: '/home',
      refreshListenable: session,
      redirect: (context, state) {
        final String loc = state.matchedLocation;

        // 1. Loading
        if (!session.ready) return '/splash';

        // 2. Erro Global
        if (session.error != null) {
          return loc == '/error' ? null : '/error';
        }

        final bool indoLogin = loc == '/login';
        final bool indoSplash = loc == '/splash';
        final bool indoTenant = loc == '/tenant';
        final bool indoError = loc == '/error';

        // 3. Não logado
        if (!session.isLoggedIn) {
          return indoLogin ? null : '/login';
        }

        // 4. Sem Tenant
        if (session.session == null) {
          if (indoLogin) return null;
          return indoTenant ? null : '/tenant';
        }

        // 5. Logado e Pronto
        if (indoLogin || indoSplash || indoTenant || indoError) {
          return '/home';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, __) => const SplashPage(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginPage(),
        ),
        GoRoute(
          path: '/tenant',
          builder: (_, __) => const TenantPickerPage(),
        ),
        GoRoute(
          path: '/error',
          builder: (context, state) => AppErrorPage(
            error: session.error,
            onRetry: () => session.init(),
            onLogout: () => session.signOut(),
          ),
        ),

        // ✅ CORREÇÃO 2: Home fora do ShellRoute
        // Como a TelaHome já tem Scaffold, AppBar e BottomBar,
        // ela deve ser uma rota "raiz" para não duplicar layouts.
        GoRoute(
          path: '/home',
          builder: (_, __) => const TelaHome(), // Usa a classe correta
        ),

        // Futuramente, se tiver telas internas (ex: Configurações Detalhadas)
        // que precisem de um menu lateral comum, você pode reativar o ShellRoute para elas.
      ],
    );
  }
}
