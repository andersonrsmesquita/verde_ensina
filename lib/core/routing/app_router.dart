import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../session/session_controller.dart';
import '../../modules/home/tela_home.dart';
import '../../modules/auth/tela_login.dart';
import '../../modules/tenancy/tenant_picker_page.dart';
import '../../modules/shared/app_error_page.dart';
import '../../modules/shared/splash_page.dart';

class AppRouter {
  static GoRouter buildRouter(SessionController session) {
    return GoRouter(
      initialLocation: '/home',
      refreshListenable: session,
      redirect: (context, state) {
        final String loc = state.matchedLocation;

        if (!session.ready) return '/splash';

        if (session.error != null) {
          return loc == '/error' ? null : '/error';
        }

        final bool indoLogin = loc == '/login';
        final bool indoSplash = loc == '/splash';
        final bool indoTenant = loc == '/tenant';
        final bool indoError = loc == '/error';

        if (!session.isLoggedIn) {
          return indoLogin ? null : '/login';
        }

        if (session.session == null) {
          if (indoLogin) return null;
          return indoTenant ? null : '/tenant';
        }

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
        GoRoute(
          path: '/home',
          builder: (_, __) => const TelaHome(),
        ),
      ],
      // 🛡️ ESTA É A PROTEÇÃO MESTRA:
      // Se o GoRouter não achar a rota (porque abrimos a tela com Navigator.push),
      // ele não quebra o app, ele deixa o Navigator nativo gerenciar a tela.
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Ops!')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Caminho não encontrado.',
                  style: TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Voltar para o Início'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
