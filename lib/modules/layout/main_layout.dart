import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:verde_ensina/core/session/session_scope.dart';

// ❌ NÃO HÁ IMPORT DO SESSION AQUI DE PROPÓSITO
// VAMOS FAZER O VS CODE ACHAR SOZINHO.

class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // 🔴 A palavra SessionScope abaixo vai ficar VERMELHA. É normal!
    final sessionScope = SessionScope.maybeOf(context);
    
    final session = sessionScope?.session;
    final tenantName = session?.tenantName ?? 'Meu Espaço';
    final status = session?.subscriptionStatus ?? '...';

    return Scaffold(
      appBar: AppBar(
        title: Text(tenantName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () {
              if (sessionScope != null) {
                sessionScope.signOut();
              }
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF2E7D32)),
              accountName: Text(
                tenantName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text('Status: $status'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Color(0xFF2E7D32)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Início'),
              onTap: () {
                context.pop();
                context.go('/home');
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Trocar Espaço'),
              onTap: () {
                context.pop(); 
                if (sessionScope != null) {
                   sessionScope.selectTenant(''); 
                }
              },
            ),
          ],
        ),
      ),
      body: child,
    );
  }
}