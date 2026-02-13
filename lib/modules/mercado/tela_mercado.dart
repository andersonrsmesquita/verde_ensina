import 'package:flutter/material.dart';

class TelaMercado extends StatelessWidget {
  const TelaMercado({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Mercado (em breve 🛒)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
