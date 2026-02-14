import 'package:flutter/material.dart';

class AppErrorPage extends StatelessWidget {
  final Object? error;
  final VoidCallback? onRetry;
  final VoidCallback? onLogout;

  const AppErrorPage({
    super.key,
    this.error,
    this.onRetry,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Ops! Algo deu errado.',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                error?.toString() ?? 'Erro desconhecido',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),

              // Botões de ação
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 1. Botão de Sair
                  if (onLogout != null)
                    OutlinedButton.icon(
                      onPressed: onLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Sair'),
                    ),

                  // 2. Espaçamento (só aparece se tivermos os DOIS botões)
                  if (onLogout != null && onRetry != null)
                    const SizedBox(width: 16),

                  // 3. Botão de Tentar Novamente
                  if (onRetry != null)
                    ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar Novamente'),
                    ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}