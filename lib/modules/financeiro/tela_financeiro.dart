import 'package:flutter/material.dart';

class TelaFinanceiro extends StatelessWidget {
  const TelaFinanceiro({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Financeiro (em breve 💸)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
