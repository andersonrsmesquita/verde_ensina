import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../solo/tela_diagnostico.dart';

class TelaHome extends StatelessWidget {
  const TelaHome({super.key});

  @override
  Widget build(BuildContext context) {
    // Pega o usuário atual para mostrar o email dele
    final usuario = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verde Ensina Pro', style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          // Botão de Sair (Logout)
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.eco, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            Text('Olá, ${usuario?.email ?? "Produtor"}!'),
            const SizedBox(height: 40),
            
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TelaDiagnostico()),
                );
              },
              child: const Text('FAZER TESTE DE SOLO'),
            ),
          ],
        ),
      ),
    );
  }
}