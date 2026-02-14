import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../session/session_controller.dart';

// Ajuste para suas telas reais
import '../../modules/auth/login_page.dart';
import '../../modules/home/home_page.dart';
import '../../modules/tenancy/tenant_picker_page.dart';
import '../../modules/shared/app_error_page.dart';

class AppRouter {
  static GoRouter buildRouter(SessionController session) {
    return GoRouter(
      initialLocation: '/',

      // faz o router reavaliar redirect quando session mudar
      refreshListenable: session,

      redirect: (context, state) {
        if (!session.ready) return null;

        // se tiver erro de sessão, manda pra tela de erro
        if (session.error != null) {
          final indoErro = state.uri.toString().startsWith('/error');
          return indoErro ? null : '/error';
        }

        final loc = state.uri.toString();
        final indoLogin = loc.startsWith('/login');
        final indoTenant = loc.startsWith('/tenant');

        // 1) não logado => login
        if (!session.isLoggedIn) {
          return indoLogin ? null : '/login';
        }

        // 2) logado mas sem sessão multi-tenant => escolher/criar tenant
        if (session.session == null) {
          return indoTenant ? null : '/tenant';
        }

        // 3) logado e com tenant => impede ficar preso em login/tenant
        if (indoLogin || indoTenant) return '/home';

        return null;
      },

      routes: [
        GoRoute(
          path: '/',
          redirect: (_, __) => '/home',
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
          path: '/home',
          builder: (_, __) => const HomePage(),
        ),
        GoRoute(
          path: '/error',
          builder: (context, state) => AppErrorPage(
            error: session.error,
          ),
        ),

        // ✅ aqui você pluga canteiros, irrigação, etc.
        // GoRoute(path: '/canteiros', builder: ...),
      ],
    );
  }
}
