import 'package:flutter/material.dart';

import 'tela_home.dart';

/// Wrapper para o GoRouter.
/// Mantém compatibilidade sem renomear/excluir telas existentes.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TelaHome();
  }
}
