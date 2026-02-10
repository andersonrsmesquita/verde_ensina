import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../solo/tela_diagnostico.dart';
import '../canteiros/tela_canteiros.dart'; // <--- Importante: Traz a tela de canteiros

class TelaHome extends StatelessWidget {
  const TelaHome({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final nomeUser = user?.email?.split('@')[0] ?? "Produtor";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Fundo cinza clarinho
      appBar: AppBar(
        title: const Text('Verde Ensina Pro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CABEÇALHO
            Text(
              'Olá, $nomeUser! 🌱',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const Text('O que vamos fazer na horta hoje?'),
            const SizedBox(height: 30),

            // GRADE DE MENUS (AQUI ESTÃO OS BOTÕES QUADRADOS)
            Expanded(
              child: GridView.count(
                crossAxisCount: 2, // 2 botões por linha
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: [
                  
                  // --- BOTÃO 1: CANTEIROS ---
                  _BotaoMenu(
                    icon: Icons.grid_on,
                    label: 'Meus Canteiros',
                    color: Colors.brown,
                    onTap: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => const TelaCanteiros())
                      );
                    },
                  ),

                  // --- BOTÃO 2: ANÁLISE DE SOLO ---
                  _BotaoMenu(
                    icon: Icons.science,
                    label: 'Análise de Solo',
                    color: Colors.blueGrey,
                    onTap: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => const TelaDiagnostico())
                      );
                    },
                  ),

                  // --- BOTÃO 3: FUTURO (IRRIGAÇÃO) ---
                  _BotaoMenu(
                    icon: Icons.water_drop,
                    label: 'Irrigação (Breve)',
                    color: Colors.blue,
                    onTap: () {}, 
                  ),

                  // --- BOTÃO 4: FUTURO (LOJA) ---
                  _BotaoMenu(
                    icon: Icons.store,
                    label: 'Marketplace (Breve)',
                    color: Colors.orange,
                    onTap: () {}, 
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// WIDGET DO BOTÃO BONITO (Ajuda a desenhar os quadrados)
class _BotaoMenu extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BotaoMenu({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}