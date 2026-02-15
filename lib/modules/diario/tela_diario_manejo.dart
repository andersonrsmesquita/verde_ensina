import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/firebase/firebase_paths.dart';
import '../../core/repositories/diario_repository.dart';
import '../../core/session/session_scope.dart';
import '../../core/ui/app_ui.dart';

class TelaDiarioManejo extends StatefulWidget {
  const TelaDiarioManejo({super.key});

  @override
  State<TelaDiarioManejo> createState() => _TelaDiarioManejoState();
}

class _TelaDiarioManejoState extends State<TelaDiarioManejo> {
  User? get _user => FirebaseAuth.instance.currentUser;
  DiarioRepository? _repo;

  // filtros (padrão canteiros)
  String? _canteiroFiltro; // null = todos
  String _filtroStatus = 'todos'; // todos | pendentes | concluidos
  String _ordem = 'recentes'; // recentes | antigas
  String _busca = '';

  final TextEditingController _buscaCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _buscaCtrl.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionScope.of(context).session;
    if (_repo == null && session != null) {
      _repo = DiarioRepository(session.tenantId);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _buscaCtrl.dispose();
    super.dispose();
  }

  void _runNextFrame(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      fn();
    });
  }

  void _msg(String text, {bool isError = false}) {
    AppMessenger.show(isError ? '❌ $text' : '✅ $text');
  }

  void _onBuscaChanged(String v) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _busca = v);
    });
  }

  // =======================================================================
  // FILTRO + ORDEM LOCAL (igual TelaCanteiros)
  // =======================================================================
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtrarEOrdenarLocal(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final buscaTerm = _busca.trim().toLowerCase();

    var list = docs.where((doc) {
      final d = doc.data();

      // filtro canteiro
      if (_canteiroFiltro != null &&
          _canteiroFiltro!.trim().isNotEmpty &&
          (d['canteiro_id'] ?? '').toString() != _canteiroFiltro) {
        return false;
      }

      // filtro status
      final concluido = (d['concluido'] ?? false) == true;
      if (_filtroStatus == 'pendentes' && concluido) return false;
      if (_filtroStatus == 'concluidos' && !concluido) return false;

      // busca
      if (buscaTerm.isNotEmpty) {
        final tipo = (d['tipo_manejo'] ?? '').toString().toLowerCase();
        final produto = (d['produto'] ?? '').toString().toLowerCase();
        final detalhes = (d['detalhes'] ?? '').toString().toLowerCase();
        final canteiro = (d['canteiro_nome'] ?? '').toString().toLowerCase();

        final ok = tipo.contains(buscaTerm) ||
            produto.contains(buscaTerm) ||
            detalhes.contains(buscaTerm) ||
            canteiro.contains(buscaTerm);

        if (!ok) return false;
      }

      return true;
    }).toList();

    Timestamp tsOf(Map<String, dynamic> d) => d['data'] is Timestamp
        ? d['data']
        : Timestamp.fromMillisecondsSinceEpoch(0);

    if (_ordem == 'antigas') {
      list.sort((a, b) => tsOf(a.data()).compareTo(tsOf(b.data())));
    } else {
      list.sort((a, b) => tsOf(b.data()).compareTo(tsOf(a.data())));
    }

    return list;
  }

  Widget _chip({
    required ColorScheme cs,
    required String key,
    required String label,
    required String current,
    required void Function(String) onSelect,
  }) {
    final selected = current == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelect(key),
      selectedColor: cs.primaryContainer,
      labelStyle: TextStyle(
        color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
      ),
      side: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
    );
  }

  // filtro premium (mesmo “estilo canteiros”)
  Widget _buildFiltros(String tenantId) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTokens.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // busca
          TextField(
            controller: _buscaCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar no diário...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _buscaCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _buscaCtrl.clear();
                        setState(() => _busca = '');
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              ),
              isDense: true,
            ),
            onChanged: _onBuscaChanged,
          ),

          const SizedBox(height: AppTokens.md),

          // filtro canteiro (dropdown premium)
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebasePaths.canteirosCol(tenantId)
                .where('ativo', isEqualTo: true)
                .snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              final map = {
                for (final d in docs)
                  d.id: ((d.data()['nome'] ?? 'Canteiro') as Object).toString(),
              };

              return DropdownButtonFormField<String>(
                isExpanded: true,
                value:
                    map.containsKey(_canteiroFiltro) ? _canteiroFiltro : null,
                decoration: InputDecoration(
                  labelText: 'Filtrar por lote',
                  prefixIcon: const Icon(Icons.filter_list),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  ),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Todos os lotes'),
                  ),
                  ...map.entries.map(
                    (e) => DropdownMenuItem<String>(
                      value: e.key,
                      child: Text(e.value),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _canteiroFiltro = v),
              );
            },
          ),

          const SizedBox(height: AppTokens.md),

          // chips status + ordem (igual canteiros)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(
                  cs: cs,
                  key: 'todos',
                  label: 'Todos',
                  current: _filtroStatus,
                  onSelect: (v) => setState(() => _filtroStatus = v),
                ),
                const SizedBox(width: 8),
                _chip(
                  cs: cs,
                  key: 'pendentes',
                  label: 'Pendentes',
                  current: _filtroStatus,
                  onSelect: (v) => setState(() => _filtroStatus = v),
                ),
                const SizedBox(width: 8),
                _chip(
                  cs: cs,
                  key: 'concluidos',
                  label: 'Concluídos',
                  current: _filtroStatus,
                  onSelect: (v) => setState(() => _filtroStatus = v),
                ),
                const SizedBox(width: 16),
                _chip(
                  cs: cs,
                  key: 'recentes',
                  label: 'Recentes',
                  current: _ordem,
                  onSelect: (v) => setState(() => _ordem = v),
                ),
                const SizedBox(width: 8),
                _chip(
                  cs: cs,
                  key: 'antigas',
                  label: 'Antigas',
                  current: _ordem,
                  onSelect: (v) => setState(() => _ordem = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumo(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final cs = Theme.of(context).colorScheme;
    int pendentes = 0;
    int concluidos = 0;

    for (final d in docs) {
      final c = (d.data()['concluido'] ?? false) == true;
      if (c)
        concluidos++;
      else
        pendentes++;
    }

    return SectionCard(
      title: 'Resumo do Diário',
      child: Row(
        children: [
          Expanded(
              child: _miniKpi('Total', '${docs.length}', Icons.history, cs)),
          Container(
              width: 1, height: 40, color: cs.outlineVariant.withOpacity(0.5)),
          Expanded(
              child: _miniKpi('Pendentes', '$pendentes', Icons.pending, cs)),
          Container(
              width: 1, height: 40, color: cs.outlineVariant.withOpacity(0.5)),
          Expanded(
              child: _miniKpi(
                  'Concluídos', '$concluidos', Icons.check_circle, cs)),
        ],
      ),
    );
  }

  Widget _miniKpi(String label, String value, IconData icon, ColorScheme cs) {
    return Column(
      children: [
        Icon(icon, color: cs.primary, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _abrirSheetRegistro(String tenantId) async {
    // monta mapa de canteiros ativos (pra picker)
    final qs = await FirebasePaths.canteirosCol(tenantId)
        .where('ativo', isEqualTo: true)
        .get();

    final canteiros = <String, String>{
      for (final d in qs.docs)
        d.id: ((d.data()['nome'] ?? 'Canteiro') as Object).toString(),
    };

    if (canteiros.isEmpty) {
      _msg('Você precisa criar um lote primeiro.', isError: true);
      return;
    }

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

  void _confirmarExclusao(String id) {
    AppDialogs.confirm(
      context,
      title: 'Excluir?',
      message: 'Apagar esta atividade do diário?',
      confirmText: 'EXCLUIR',
      isDanger: true,
      onConfirm: () async {
        try {
          await _repo!.excluirManejo(id);
          _msg('Excluído.');
        } catch (e) {
          _msg('Erro ao excluir.', isError: true);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final session = SessionScope.of(context).session;
    final tenantId = session?.tenantId;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Diário de Campo',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: cs.surface,
        foregroundColor: cs.primary,
        elevation: 0,
      ),
      floatingActionButton: (_user == null || _repo == null || tenantId == null)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _abrirSheetRegistro(tenantId),
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('NOVO REGISTRO',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
      body: (_repo == null || tenantId == null)
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppTokens.md),
                  child: _buildFiltros(tenantId),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _repo!.watchHistorico(limit: 500),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Erro: ${snapshot.error}',
                            style: TextStyle(color: cs.error),
                          ),
                        );
                      }

                      final rawDocs = snapshot.data?.docs ?? [];
                      final docs = _filtrarEOrdenarLocal(rawDocs);

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_edu,
                                  size: 64, color: cs.outlineVariant),
                              const SizedBox(height: AppTokens.md),
                              const Text('Nada no diário com esses filtros.',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            AppTokens.md, 0, AppTokens.md, 110),
                        itemCount: docs.length + 1,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppTokens.sm),
                        itemBuilder: (context, index) {
                          if (index == 0) return _buildResumo(docs);

                          final doc = docs[index - 1];
                          final d = doc.data();
                          final id = doc.id;

                          final tipo =
                              (d['tipo_manejo'] ?? 'Manejo').toString();
                          final canteiro =
                              (d['canteiro_nome'] ?? 'Lote').toString();
                          final produto = (d['produto'] ?? '').toString();
                          final detalhes = (d['detalhes'] ?? '').toString();
                          final concluido = (d['concluido'] ?? false) == true;
                          final date = (d['data'] is Timestamp)
                              ? (d['data'] as Timestamp).toDate()
                              : null;

                          final cor =
                              concluido ? Colors.green : Colors.orange.shade700;

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: cs.outlineVariant),
                              borderRadius:
                                  BorderRadius.circular(AppTokens.radiusMd),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AppTokens.md),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(AppTokens.md),
                                    decoration: BoxDecoration(
                                      color: cor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(
                                          AppTokens.radiusMd),
                                    ),
                                    child: Icon(
                                      concluido
                                          ? Icons.check_circle
                                          : Icons.pending_actions,
                                      color: cor,
                                    ),
                                  ),
                                  const SizedBox(width: AppTokens.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tipo,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            decoration: concluido
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          canteiro,
                                          style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (produto.trim().isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text('Ação: $produto',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                        ],
                                        if (detalhes.trim().isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(detalhes,
                                              style: TextStyle(
                                                  color: cs.onSurfaceVariant)),
                                        ],
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today,
                                                size: 14, color: cs.outline),
                                            const SizedBox(width: 6),
                                            Text(
                                              date != null
                                                  ? DateFormat(
                                                          'dd/MM/yyyy HH:mm')
                                                      .format(date)
                                                  : 'Sem data',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: cs.outline,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: cor,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                concluido
                                                    ? 'CONCLUÍDO'
                                                    : 'PENDENTE',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert,
                                        color: cs.outline),
                                    itemBuilder: (ctx) => [
                                      PopupMenuItem(
                                        value: 'toggle',
                                        onTap: () => _runNextFrame(() async {
                                          try {
                                            await _repo!
                                                .toggleConcluido(id, concluido);
                                            _msg('Status atualizado.');
                                          } catch (e) {
                                            _msg('Erro ao atualizar.',
                                                isError: true);
                                          }
                                        }),
                                        child: Row(
                                          children: [
                                            Icon(
                                              concluido
                                                  ? Icons.undo
                                                  : Icons.check,
                                              size: 18,
                                              color: cs.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(concluido
                                                ? 'Marcar pendente'
                                                : 'Marcar concluído'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        onTap: () => _runNextFrame(
                                            () => _confirmarExclusao(id)),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.delete,
                                                size: 18, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Excluir',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
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
// SHEET REGISTRO (padrão canteiros)
// ============================================================================
class _SheetRegistroManejo extends StatefulWidget {
  final Map<String, String> canteiros;
  final DiarioRepository repo;
  final String? preSelectedCanteiro;

  const _SheetRegistroManejo({
    required this.canteiros,
    required this.repo,
    this.preSelectedCanteiro,
  });

  @override
  State<_SheetRegistroManejo> createState() => _SheetRegistroManejoState();
}

class _SheetRegistroManejoState extends State<_SheetRegistroManejo> {
  final _formKey = GlobalKey<FormState>();

  late String? _canteiroId = widget.preSelectedCanteiro;
  String _tipo = 'Irrigação';
  bool _concluido = false;

  final _produtoCtrl = TextEditingController();
  final _detalhesCtrl = TextEditingController();
  bool _salvando = false;

  final List<String> _tiposManejo = const [
    'Irrigação',
    'Adubação',
    'Controle de Pragas',
    'Plantio',
    'Poda/Limpeza',
    'Colheita',
    'Outro'
  ];

  @override
  void dispose() {
    _produtoCtrl.dispose();
    _detalhesCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();
    if (_salvando) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_canteiroId == null) {
      AppMessenger.show('⚠️ Selecione o lote.');
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
        'concluido': _concluido,
        'uid_usuario': FirebaseAuth.instance.currentUser?.uid,
      });

      if (!mounted) return;
      Navigator.pop(context);
      AppMessenger.show('✅ Atividade registrada!');
    } catch (e) {
      AppMessenger.show('❌ Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppTokens.lg,
        AppTokens.lg,
        AppTokens.lg,
        MediaQuery.of(context).viewInsets.bottom + AppTokens.lg,
      ),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Novo registro',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.lg),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: widget.canteiros.containsKey(_canteiroId)
                      ? _canteiroId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Lote',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                  items: widget.canteiros.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _canteiroId = v),
                  validator: (v) => v == null ? 'Obrigatório' : null,
                ),
                const SizedBox(height: AppTokens.md),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _tipo,
                  decoration: const InputDecoration(
                    labelText: 'Atividade',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _tiposManejo
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _tipo = v ?? _tipo),
                ),
                const SizedBox(height: AppTokens.md),
                AppTextField(
                  controller: _produtoCtrl,
                  labelText: 'Ação / Produto (opcional)',
                  hintText: 'Ex: 10 min gotejamento, esterco curtido...',
                  prefixIcon: Icons.work_outline,
                ),
                const SizedBox(height: AppTokens.md),
                AppTextField(
                  controller: _detalhesCtrl,
                  labelText: 'Observações (opcional)',
                  hintText: 'Ex: solo úmido, presença de joaninhas...',
                  prefixIcon: Icons.notes_outlined,
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: AppTokens.md),
                SwitchListTile.adaptive(
                  value: _concluido,
                  onChanged: (v) => setState(() => _concluido = v),
                  title: const Text('Marcar como concluído'),
                  subtitle: const Text('Se desligado, entra como pendente.'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: AppTokens.xl),
                AppButtons.elevatedIcon(
                  onPressed: _salvando ? null : _salvar,
                  icon: _salvando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_salvando ? 'SALVANDO...' : 'SALVAR'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
