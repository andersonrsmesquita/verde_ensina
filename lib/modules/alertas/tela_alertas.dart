import 'package:flutter/material.dart';
import 'package:verde_ensina/core/ui/app_ui.dart';


class TelaAlertas extends StatelessWidget {
  const TelaAlertas({super.key});

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      title: 'Alertas / Agenda',
      child: Column(
        children: [
          SectionCard(
            title: 'Em breve',
            subtitle: 'Lembretes, agenda e rotina do produtor',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                _LinhaInfo(
                  icon: Icons.notifications_active_outlined,
                  text: 'Alertas de irrigação, adubação, calagem e colheita.',
                ),
                SizedBox(height: 10),
                _LinhaInfo(
                  icon: Icons.calendar_month_outlined,
                  text: 'Agenda por canteiro: o que fazer e quando fazer.',
                ),
                SizedBox(height: 10),
                _LinhaInfo(
                  icon: Icons.cloud_outlined,
                  text: 'Integração com clima/chuva para ajustar tarefas.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppButton.primary(
            label: 'VOLTAR',
            icon: Icons.arrow_back,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

class _LinhaInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _LinhaInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
