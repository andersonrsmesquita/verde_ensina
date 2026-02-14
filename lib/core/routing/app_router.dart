import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../session/session_controller.dart';

// Importe suas telas
import '../../modules/auth/login_page.dart';
import '../../modules/home/home_page.dart';
import '../../modules/tenancy/tenant_picker_page.dart';
import '../../modules/shared/app_error_page.dart';
import '../../modules/shared/splash_page.dart'; // ✨ Nova tela (crie um arquivo simples)
import '../../modules/layout/main_layout.dart'; // ✨ Novo layout (estrutura com menu)

class AppRouter {
  static GoRouter buildRouter(SessionController session) {
    return GoRouter(
      initialLocation: '/home', // Tenta ir pra Home, o redirect decide se pode
      
      // O router reage a qualquer notifyListeners() do controller
      refreshListenable: session,

      redirect: (context, state) {
        final String loc = state.matchedLocation; // Use matchedLocation é mais seguro que uri.toString()

        // 1. Loading Inicial (Splash)
        // Se o Firebase ainda não respondeu, manda pra Splash
        if (!session.ready) {
          return '/splash';
        }

        // 2. Tratamento de Erros Globais
        // Se houve erro crítico na sessão (ex: conta banida, erro de rede grave)
        if (session.error != null) {
           return loc == '/error' ? null : '/error';
        }

        final bool indoLogin = loc == '/login';
        final bool indoSplash = loc == '/splash';
        final bool indoTenant = loc == '/tenant';
        final bool indoError = loc == '/error';

        // 3. Usuário NÃO logado
        if (!session.isLoggedIn) {
          // Se não está logado, só pode ir pro Login.
          // (Se vier da Splash, Error ou tentar Home, manda pro Login)
          return indoLogin ? null : '/login';
        }

        // 4. Logado, mas sem Tenant selecionado (SaaS Multi-tenant)
        // O usuário existe, mas não sabemos qual "empresa" ele está acessando.
        if (session.session == null) {
          // Permite logout mesmo nessa fase (se quiser sair e entrar com outra conta)
          if (indoLogin) return null; 
          return indoTenant ? null : '/tenant';
        }

        // 5. Usuário Logado e com Sessão Pronta (Happy Path)
        // Se tentar voltar pra login, splash ou tenant picker, manda pra Home
        if (indoLogin || indoSplash || indoTenant || indoError) {
          return '/home';
        }

        // Deixa passar para a rota solicitada (ex: /canteiros, /financeiro)
        return null;
      },

      routes: [
        // Rota de Carregamento
        GoRoute(
          path: '/splash',
          builder: (_, __) => const SplashPage(),
        ),
        
        // Rota de Login (Pública)
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginPage(),
        ),

        // Rota de Escolha de Tenant (Semi-Privada)
        GoRoute(
          path: '/tenant',
          builder: (_, __) => const TenantPickerPage(),
        ),

        // Rota de Erro
        GoRoute(
          path: '/error',
          builder: (context, state) => AppErrorPage(
            error: session.error,
            onRetry: () => session.init(), // Botão de tentar novamente
            onLogout: () => session.signOut(), // Botão de sair
          ),
        ),

        // ✅ SHELL ROUTE: A "Moldura" do seu App
        // Tudo aqui dentro compartilha o mesmo Menu/AppBar
        ShellRoute(
          builder: (context, state, child) {
            // MainLayout é um Widget que tem o Scaffold com Drawer/AppBar
            // e recebe o 'child' que é a página atual.
            return MainLayout(child: child);
          },
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, __) => const HomePage(),
            ),
            // Aqui você adiciona os módulos futuros:
            // GoRoute(path: '/canteiros', builder: (_, __) => CanteirosPage()),
            // GoRoute(path: '/financeiro', builder: (_, __) => FinanceiroPage()),
          ],
        ),
      ],
    );
  }
}