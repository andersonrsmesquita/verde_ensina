import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Adicione intl no pubspec.yaml para datas bonitas

import '../../core/session/session_scope.dart';
import '../../core/ui/app_ui.dart'; // AppButtons, AppCard, etc.
import '../../core/repositories/diario_repository.dart';
import '../../core/firebase/firebase_paths.dart';

class TelaDiarioManejo extends StatefulWidget {
  const TelaDiarioManejo({super.key});

  @override
  State<TelaDiarioManejo> createState() => _TelaDiarioManejoState();
}

class _TelaDiarioManejoState extends State<TelaDiarioManejo> {
  String? _canteiroFiltro;
  DiarioRepository? _repo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionScope.of(context).session;
    if (session != null) {
      _repo = DiarioRepository(session.tenantId);
    }
  }

  void _abrirSheetRegistro(Map<String, String> canteiros) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SheetRegistroManejo(
        canteiros: canteiros,
        repo: _repo!,
        preSelectedCanteiro: _canteiroFiltro,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_repo == null) {
      return const Scaffold(body: Center(child: Text("Sessão inválida")));
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Diário de Campo'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filtro de Canteiros
          _FiltroCanteiros(
            tenantId: _repo!.tenantId,
            selectedId: _canteiroFiltro,
            onChanged: (id, map) {
              setState(() => _canteiroFiltro = id);
            },
            onAddPressed: (map) => _abrirSheetRegistro(map),
          ),

          // Lista de Histórico
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _repo!.watchHistorico(canteiroId: _canteiroFiltro),
              builder: (context, snap) {
                if (snap.hasError)
                  return Center(child: Text('Erro: ${snap.error}'));
                if (!snap.hasData)
                  return const Center(child: CircularProgressIndicator());

                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return _EmptyState(onAdd: () {
                    // Precisa carregar o mapa de canteiros para abrir o sheet
                    // Simplificação: forçar o usuário a usar o botão + lá em cima
                    AppMessenger.info('Use o botão + acima para registrar.');
                  });
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    return _ManejoCard(
                      data: data,
                      docId: docs[i].id,
                      onToggle: () => _repo!.toggleConcluido(
                          docs[i].id, data['concluido'] == true),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGETS AUXILIARES (UI LIMPA)
// ============================================================================

class _FiltroCanteiros extends StatelessWidget {
  final String tenantId;
  final String? selectedId;
  final Function(String?, Map<String, String>) onChanged;
  final Function(Map<String, String>) onAddPressed;

  const _FiltroCanteiros({
    required this.tenantId,
    required this.selectedId,
    required this.onChanged,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebasePaths.canteirosCol(tenantId)
          .where('ativo', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final map = {
          for (var d in docs) d.id: (d['nome'] ?? 'Canteiro').toString()
        };

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedId,
                  decoration: const InputDecoration(
                    labelText: 'Filtrar Canteiro',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    ...map.entries.map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value))),
                  ],
                  onChanged: (v) => onChanged(v, map),
                ),
              ),
              const SizedBox(width: 12),
              FloatingActionButton.small(
                heroTag: 'add_manejo',
                onPressed: map.isEmpty ? null : () => onAddPressed(map),
                child: const Icon(Icons.add),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ManejoCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final VoidCallback onToggle;

  const _ManejoCard(
      {required this.data, required this.docId, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final concluido = data['concluido'] == true;
    final date = (data['data'] as Timestamp?)?.toDate();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor:
              concluido ? cs.primaryContainer : cs.surfaceContainerHighest,
          child: Icon(
            _getIconForType(data['tipo_manejo']),
            color: concluido ? cs.primary : cs.onSurfaceVariant,
            size: 20,
          ),
        ),
        title: Text(
          data['tipo_manejo'] ?? 'Manejo',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: concluido ? TextDecoration.lineThrough : null,
            color: concluido ? cs.onSurface.withOpacity(0.6) : cs.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${data['produto'] ?? ''} • ${data['canteiro_nome'] ?? ''}'),
            if (date != null)
              Text(
                DateFormat('dd/MM HH:mm').format(date),
                style: TextStyle(fontSize: 11, color: cs.primary),
              ),
          ],
        ),
        trailing: Checkbox(
          value: concluido,
          onChanged: (_) => onToggle(),
          shape: const CircleBorder(),
        ),
      ),
    );
  }

  IconData _getIconForType(String? type) {
    switch (type?.toLowerCase()) {
      case 'irrigação':
        return Icons.water_drop;
      case 'adubação':
        return Icons.eco;
      case 'plantio':
        return Icons.grass;
      case 'colheita':
        return Icons.shopping_basket;
      default:
        return Icons.edit_note;
    }
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_edu, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Nenhum registro encontrado.'),
          const SizedBox(height: 16),
          // Se quiser, pode colocar um botão aqui, mas o FAB já existe na tela
        ],
      ),
    );
  }
}

// ============================================================================
// SHEET DE REGISTRO (Separado para organizar)
// ============================================================================
class _SheetRegistroManejo extends StatefulWidget {
  final Map<String, String> canteiros;
  final DiarioRepository repo;
  final String? preSelectedCanteiro;

  const _SheetRegistroManejo(
      {required this.canteiros, required this.repo, this.preSelectedCanteiro});

  @override
  State<_SheetRegistroManejo> createState() => _SheetRegistroManejoState();
}

class _SheetRegistroManejoState extends State<_SheetRegistroManejo> {
  final _formKey = GlobalKey<FormState>();
  late String? _canteiroId = widget.preSelectedCanteiro;
  String _tipo = 'Irrigação';
  final _produtoCtrl = TextEditingController();
  final _detalhesCtrl = TextEditingController();
  bool _salvando = false;

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_canteiroId == null) {
      AppMessenger.warn('Selecione um canteiro');
      return;
    }

    setState(() => _salvando = true);
    try {
      await widget.repo.adicionarManejo({
        'canteiro_id': _canteiroId,
        'canteiro_nome': widget.canteiros[_canteiroId],
        'tipo_manejo': _tipo,
        'produto': _produtoCtrl.text,
        'detalhes': _detalhesCtrl.text,
        'data': FieldValue.serverTimestamp(),
        'concluido': true, // Assume feito na hora
        'uid_usuario': FirebaseAuth.instance.currentUser?.uid,
      });
      if (mounted) Navigator.pop(context);
      AppMessenger.success('Registro salvo!');
    } catch (e) {
      AppMessenger.error('Erro: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Novo Registro',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _canteiroId,
                decoration: const InputDecoration(labelText: 'Canteiro'),
                items: widget.canteiros.entries
                    .map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _canteiroId = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _tipo,
                decoration: const InputDecoration(labelText: 'Atividade'),
                items: ['Irrigação', 'Adubação', 'Poda', 'Colheita', 'Outro']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _tipo = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _produtoCtrl,
                decoration: const InputDecoration(
                    labelText: 'Produto/Obs (Ex: Água, NPK...)'),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 24),
              AppButtons.elevatedIcon(
                onPressed: _salvando ? null : _salvar,
                icon: _salvando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: Text(_salvando ? 'Salvando...' : 'Confirmar'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
