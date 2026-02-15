import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
      final tenantId = await session.createTenant(name: name);
      AppMessenger.show('✅ Espaço criado: $name');
      await session.selectTenant(tenantId);
      if (mounted) context.go('/home');
    } catch (e) {
      AppMessenger.show('❌ Falha ao criar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selecionar(String tenantId) async {
    final session = SessionScope.of(context);
    setState(() => _busy = true);
    try {
      await session.selectTenant(tenantId);
      if (mounted) context.go('/home');
    } catch (e) {
      AppMessenger.show('❌ Falha ao selecionar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final uid = session.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Faça login para continuar.')),
      );
    }

    final userRef = FirebasePaths.userRef(uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolha o espaço'),
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
                        const Icon(Icons.apartment, size: 48),
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
                      final tdata = tsnap.data?.data() ?? {};
                      final name = (tdata['name'] ?? 'Espaço').toString();
                      final status = (tdata['status'] ?? 'active').toString();
                      final sub =
                          (tdata['subscriptionStatus'] ?? 'trial').toString();

                      return Card(
                        child: ListTile(
                          leading:
                              const CircleAvatar(child: Icon(Icons.apartment)),
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
              color: Colors.black.withOpacity(0.08),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
