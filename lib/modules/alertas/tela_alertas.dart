import 'package:flutter/material.dart';

import '../../core/ui/app_ui.dart';

class TelaAlertas extends StatelessWidget {
  const TelaAlertas({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas / Agenda'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 92),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Em breve',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lembretes, agenda e rotina do produtor',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  const _InfoTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Alertas de manejo',
                    subtitle: 'Irrigação, adubação, calagem e colheita.',
                  ),
                  const Divider(height: 24),
                  const _InfoTile(
                    icon: Icons.calendar_month_outlined,
                    title: 'Agenda por canteiro',
                    subtitle: 'O que fazer e quando fazer em cada canteiro.',
                  ),
                  const Divider(height: 24),
                  const _InfoTile(
                    icon: Icons.cloud_outlined,
                    title: 'Clima e chuva',
                    subtitle:
                        'Integração com clima/chuva para ajustar tarefas.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.tips_and_updates_outlined),
              title: const Text(
                'Como vai funcionar',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Você vai poder escolher o canteiro e ativar lembretes automáticos '
                'para irrigar, adubar e colher — com base no seu planejamento.',
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: AppButtons.elevatedIcon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('VOLTAR'),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(subtitle),
    );
  }
}
