import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../core/session/session_scope.dart';
import '../../core/ui/app_ui.dart';
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
    if (session != null && _repo == null) {
      _repo = DiarioRepository(session.tenantId);
    }
  }

  void _abrirSheetRegistro(Map<String, String> canteiros) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
    final tenantId = SessionScope.of(context).session?.tenantId;

    if (_repo == null || tenantId == null) {
      return const PageContainer(
        scroll: false,
        body: Center(child: Text("Carregando sessão...")),
      );
    }

    return PageContainer(
      title: 'Diário de Campo',
      subtitle: 'Registre e acompanhe as atividades do seu espaço',
      scroll: false, // 🛡️ Important for screens with Expanded/ListView
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. FILTRO INTELIGENTE E AÇÕES
          _FiltroCanteiros(
            tenantId: tenantId,
            selectedId: _canteiroFiltro,
            onChanged: (id, map) {
              setState(() => _canteiroFiltro = id);
            },
            onAddPressed: (map) => _abrirSheetRegistro(map),
          ),

          const SizedBox(height: AppTokens.md),

          // 2. LISTA DE HISTÓRICO
          Expanded(
            child: SectionCard(
              title: 'Histórico de Atividades',
              child: StreamBuilder<QuerySnapshot>(
                stream: _repo!.watchHistorico(canteiroId: _canteiroFiltro),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                        child: Text('Erro: ${snap.error}',
                            style: TextStyle(color: cs.error)));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data!.docs;

                  if (docs.isEmpty) {
                    return const _EmptyState();
                  }

                  // Calculate some quick stats for a mini dashboard
                  int concluidos = 0;
                  int pendentes = 0;
                  for (var doc in docs) {
                    final d = doc.data() as Map<String, dynamic>;
                    if (d['concluido'] == true) {
                      concluidos++;
                    } else {
                      pendentes++;
                    }
                  }

                  return Column(
                    children: [
                      // Mini Dashboard KPI
                      Row(
                        children: [
                          Expanded(
                              child: _MiniKpi(
                                  label: 'Total',
                                  value: '${docs.length}',
                                  color: cs.primary)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _MiniKpi(
                                  label: 'Pendentes',
                                  value: '$pendentes',
                                  color: Colors.orange.shade700)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _MiniKpi(
                                  label: 'Concluídos',
                                  value: '$concluidos',
                                  color: Colors.green.shade700)),
                        ],
                      ),
                      const Divider(height: 32),

                      // The actual list
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final data = docs[i].data() as Map<String, dynamic>;
                            return _ManejoCard(
                              data: data,
                              docId: docs[i].id,
                              onToggle: () => _repo!.toggleConcluido(
                                  docs[i].id, data['concluido'] == true),
                              onDelete: () => _confirmarExclusao(docs[i].id),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmarExclusao(String id) {
    AppDialogs.confirm(
      context,
      title: 'Excluir registro?',
      message: 'Tem certeza que deseja apagar esta atividade do diário?',
      confirmText: 'EXCLUIR',
      isDanger: true,
      onConfirm: () async {
        try {
          await _repo!.excluirManejo(id);
          if (mounted) AppMessenger.success('Registro excluído.');
        } catch (e) {
          if (mounted) AppMessenger.error('Erro ao excluir.');
        }
      },
    );
  }
}

// ============================================================================
// WIDGETS AUXILIARES (UI LIMPA E PADRONIZADA)
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

        return SectionCard(
          title: 'Filtrar por Lote',
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: map.containsKey(selectedId) ? selectedId : null,
                  decoration: const InputDecoration(
                    labelText: 'Selecione um lote...',
                    prefixIcon: Icon(Icons.filter_list),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Todos os lotes')),
                    ...map.entries.map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value))),
                  ],
                  onChanged: (v) => onChanged(v, map),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 50,
                child: AppButtons.elevatedIcon(
                  onPressed: map.isEmpty ? null : () => onAddPressed(map),
                  icon: const Icon(Icons.add),
                  label: const Text('NOVO'),
                ),
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
  final VoidCallback onDelete;

  const _ManejoCard({
    required this.data,
    required this.docId,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final concluido = data['concluido'] == true;
    final date = (data['data'] as Timestamp?)?.toDate();
    final tipo = (data['tipo_manejo'] ?? 'Manejo').toString();
    final produto = (data['produto'] ?? '').toString();
    final detalhes = (data['detalhes'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        color: concluido
            ? cs.surfaceContainerHighest.withOpacity(0.3)
            : cs.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(
          color: concluido
              ? cs.outlineVariant.withOpacity(0.5)
              : _getColorForType(tipo).withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            leading: CircleAvatar(
              backgroundColor: concluido
                  ? cs.surfaceContainerHighest
                  : _getColorForType(tipo).withOpacity(0.2),
              child: Icon(
                _getIconForType(tipo),
                color: concluido ? cs.outline : _getColorForType(tipo),
              ),
            ),
            title: Text(
              tipo,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                decoration: concluido ? TextDecoration.lineThrough : null,
                color: concluido ? cs.outline : cs.onSurface,
              ),
            ),
            subtitle: Text(
              data['canteiro_nome'] ?? 'Lote Desconhecido',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cs.onSurfaceVariant,
              ),
            ),
            trailing: Checkbox(
              value: concluido,
              onChanged: (_) => onToggle(),
              activeColor: Colors.green,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (produto.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Produto/Ação: $produto',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
                if (detalhes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(detalhes,
                      style:
                          TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: cs.outline),
                        const SizedBox(width: 4),
                        Text(
                          date != null
                              ? DateFormat('dd/MM/yyyy HH:mm').format(date)
                              : 'Data não registrada',
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.outline,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: onDelete,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(Icons.delete_outline,
                            size: 18, color: cs.error),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'irrigação':
        return Icons.water_drop;
      case 'adubação':
        return Icons
            .compost; // Using the new material icon if available, or just eco
      case 'plantio':
        return Icons.spa;
      case 'colheita':
        return Icons.shopping_basket;
      case 'controle de pragas':
        return Icons.bug_report;
      default:
        return Icons.handyman;
    }
  }

  Color _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'irrigação':
        return Colors.blue;
      case 'adubação':
        return Colors.brown.shade600;
      case 'plantio':
        return Colors.green.shade700;
      case 'colheita':
        return Colors.orange.shade700;
      case 'controle de pragas':
        return Colors.red.shade700;
      default:
        return Colors.blueGrey;
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_edu, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Diário em branco',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Nenhuma atividade registrada para este filtro. Use o botão "NOVO" acima para adicionar um manejo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _MiniKpi extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniKpi(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

// ============================================================================
// SHEET DE REGISTRO (Inteligente e Padronizado)
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

  final List<String> _tiposManejo = [
    'Irrigação',
    'Adubação',
    'Controle de Pragas',
    'Plantio',
    'Poda/Limpeza',
    'Colheita',
    'Outro'
  ];

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_canteiroId == null) {
      AppMessenger.warn('Selecione o local da atividade.');
      return;
    }

    setState(() => _salvando = true);
    try {
      await widget.repo.adicionarManejo({
        'canteiro_id': _canteiroId,
        'canteiro_nome': widget.canteiros[_canteiroId],
        'tipo_manejo': _tipo,
        'produto': _produtoCtrl.text.trim(),
        'detalhes': _detalhesCtrl.text.trim(),
        'data': FieldValue.serverTimestamp(),
        'concluido': true, // Assume done when logged
        'uid_usuario': FirebaseAuth.instance.currentUser?.uid,
      });

      if (mounted) Navigator.pop(context);
      AppMessenger.success('Atividade registrada no diário!');
    } catch (e) {
      AppMessenger.error('Erro ao salvar registro.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  void dispose() {
    _produtoCtrl.dispose();
    _detalhesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Registrar Manejo',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900)),
                      IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: widget.canteiros.containsKey(_canteiroId)
                        ? _canteiroId
                        : null,
                    decoration: const InputDecoration(
                        labelText: 'Localização (Lote/Vaso)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.place_outlined)),
                    items: widget.canteiros.entries
                        .map((e) => DropdownMenuItem(
                            value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setState(() => _canteiroId = v),
                    validator: (v) => v == null ? 'Obrigatório' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _tipo,
                    decoration: const InputDecoration(
                        labelText: 'Tipo de Atividade',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category_outlined)),
                    items: _tiposManejo
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _tipo = v!),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _produtoCtrl,
                    labelText: 'Produto/Ação Principal',
                    hintText: _tipo == 'Adubação'
                        ? 'Ex: Yoorin, Esterco Bovino...'
                        : (_tipo == 'Controle de Pragas'
                            ? 'Ex: Óleo de Nim, Calda Bordalesa...'
                            : 'Ex: 10 min gotejamento...'),
                    prefixIcon: Icons.shopping_bag_outlined,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _detalhesCtrl,
                    labelText: 'Detalhes/Observações (Opcional)',
                    hintText:
                        'Ex: Aplicado no fim da tarde. Presença de joaninhas.',
                    prefixIcon: Icons.notes,
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 24),
                  AppButtons.elevatedIcon(
                    onPressed: _salvando ? null : _salvar,
                    icon: _salvando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: Text(_salvando ? 'SALVANDO...' : 'SALVAR NO DIÁRIO'),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
