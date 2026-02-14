import 'package:flutter/material.dart';

import 'tela_login.dart';

/// Wrapper para o GoRouter.
/// Mantém compatibilidade sem renomear/excluir telas existentes.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TelaLogin();
  }
}
