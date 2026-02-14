import 'package:flutter/material.dart';
import '../../core/session/session_scope.dart';
import '../../core/ui/app_ui.dart';

class AppErrorPage extends StatelessWidget {
  final Object? error;
  const AppErrorPage({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Erro')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              'Deu ruim na sessão',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(error?.toString() ?? 'Erro desconhecido'),
            const SizedBox(height: 16),
            AppButtons.elevatedIcon(
              onPressed: () async {
                await session.signOut();
                AppMessenger.show('Saindo para recuperar a sessão...');
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sair'),
            ),
          ],
        ),
      ),
    );
  }
}
