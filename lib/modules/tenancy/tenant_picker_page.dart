// FILE: lib/modules/tenancy/tenant_picker_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/session/session_scope.dart';
import '../../core/ui/app_ui.dart';
import '../../core/firebase/firebase_paths.dart';

class TenantPickerPage extends StatefulWidget {
  const TenantPickerPage({super.key});

  @override
  State<TenantPickerPage> createState() => _TenantPickerPageState();
}

class _TenantPickerPageState extends State<TenantPickerPage> {
  bool _busy = false;

  // Helper para mostrar mensagens (substitui AppMessenger se não houver)
  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  Future<void> _criarTenant() async {
    final session = SessionScope.of(context);

    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Criar espaço'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Nome do espaço',
            hintText: 'Ex: Horta da casa / Sítio 01 / Estufa',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Criar'),
          ),
        ],
      ),
    );

    ctrl.dispose();
    if (name == null || name.isEmpty) return;

    setState(() => _busy = true);
    try {
      // ✅ CORREÇÃO AQUI: Passamos 'name' diretamente, sem 'name:'
      final tenantId = await session.createTenant(name);

      _showSnack('✅ Espaço criado: $name');

      // Seleciona e navega
      await session.selectTenant(tenantId);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      _showSnack('❌ Falha ao criar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selecionar(String tenantId) async {
    final session = SessionScope.of(context);
    setState(() => _busy = true);
    try {
      await session.selectTenant(tenantId);
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      _showSnack('❌ Falha ao selecionar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    // Usa o uid da sessão ou do auth direto se a sessão ainda não carregou
    final uid = session.session?.uid ?? FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Faça login para continuar.')),
      );
    }

    final userRef = FirebasePaths.userRef(uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolha o espaço'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await session.signOut();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _criarTenant,
        icon: const Icon(Icons.add),
        label: const Text('Criar espaço'),
      ),
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: userRef.snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snap.data!.data() ?? {};
              final tenantIdsRaw = (data['tenantIds'] is List)
                  ? data['tenantIds'] as List
                  : <dynamic>[];

              final tenantIds = tenantIdsRaw
                  .map((e) => e.toString())
                  .where((e) => e.isNotEmpty)
                  .toList();

              if (tenantIds.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.apartment,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 10),
                        const Text(
                          'Você ainda não tem um espaço.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text('Crie um para começar (trial de 14 dias).'),
                        const SizedBox(height: 14),
                        AppButtons.elevatedIcon(
                          onPressed: _busy ? null : _criarTenant,
                          icon: const Icon(Icons.add),
                          label: const Text('Criar agora'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: tenantIds.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final tid = tenantIds[i];
                  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: FirebasePaths.tenantsCol().doc(tid).get(),
                    builder: (context, tsnap) {
                      if (!tsnap.hasData) return const SizedBox.shrink();

                      final tdata = tsnap.data?.data() ?? {};
                      final name = (tdata['name'] ?? 'Espaço').toString();
                      final status = (tdata['status'] ?? 'active').toString();
                      final sub =
                          (tdata['subscriptionStatus'] ?? 'trial').toString();

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            side: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant),
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'T'),
                          ),
                          title: Text(name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('Status: $status • Plano: $sub'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _busy ? null : () => _selecionar(tid),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          if (_busy)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
