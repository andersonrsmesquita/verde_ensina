import 'package:flutter/material.dart';

class TelaAlertas extends StatelessWidget {
  const TelaAlertas({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alertas/Agenda')),
      body: const Center(child: Text('Em breve: lembretes e agenda do produtor.')),
    );
  }
}
