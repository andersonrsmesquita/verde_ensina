import 'package:flutter/material.dart';

import '../session/session_scope.dart';

// Troca esses imports pras suas telas reais:
import '../../modules/auth/login_page.dart'; // <- ajuste
import '../../modules/home/home_page.dart';  // <- ajuste
import '../../modules/tenancy/presentation/pages/tenant_picker_page.dart'; // <- vamos criar

class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionCtl = SessionScope.of(context);

    if (!sessionCtl.ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!sessionCtl.isLoggedIn) {
      return const LoginPage(); // <- sua tela de login
    }

    // Logado mas ainda sem tenant selecionado/criado
    if (sessionCtl.session == null) {
      return const TenantPickerPage();
    }

    // Logado + tenant ok
    return const HomePage();
  }
}
