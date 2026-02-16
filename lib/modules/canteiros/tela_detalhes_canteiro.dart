import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../core/ui/app_ui.dart';
import '../../core/session/session_scope.dart';
import '../../core/repositories/detalhes_canteiro_repository.dart';
import '../../core/firebase/firebase_paths.dart';

import '../solo/tela_diagnostico.dart';
import '../calculadoras/tela_calagem.dart';
import 'guia_culturas.dart';

class TelaDetalhesCanteiro extends StatefulWidget {
  final String canteiroId;
  const TelaDetalhesCanteiro({super.key, required this.canteiroId});

  @override
  State<TelaDetalhesCanteiro> createState() => _TelaDetalhesCanteiroState();
}

class _TelaDetalhesCanteiroState extends State<TelaDetalhesCanteiro> {
  DetalhesCanteiroRepository? _repo;

  final ScrollController _scroll = ScrollController();
  FirebaseAuth get _auth => FirebaseAuth.instance;

  final _nomeController = TextEditingController();
  final _compController = TextEditingController();
  final _largController = TextEditingController();

  String? get _uid => _auth.currentUser?.uid;
  bool get _isLogado => _uid != null;
  bool get _enableHardDelete => kDebugMode;

  String? get _tenantIdOrNull => SessionScope.of(context).session?.tenantId;

  static const int _pageSize = 25;
  bool _loadingFirst = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _isFetching = false;

  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];

  bool _aggInitChecked = false;

  // ===========================================================================
  // Helpers
  // ===========================================================================
  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AppMessenger.error(msg);
    } else {
      AppMessenger.success(msg);
    }
  }

  String _money(double v) {
    final sign = v < 0 ? '-' : '';
    final abs = v.abs();
    final s = abs.toStringAsFixed(2).replaceAll('.', ',');
    return '${sign}R\$ $s';
  }

  String _fmtData(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$mi';
  }

  Color _getCorStatus(String status, ColorScheme cs) {
    if (status == 'ocupado') return cs.error;
    if (status == 'manutencao') return Colors.orange.shade800;
    return cs.primary;
  }

  String _getTextoStatus(String status) {
    if (status == 'ocupado') return 'EM PRODUÇÃO';
    if (status == 'manutencao') return 'EM MANUTENÇÃO';
    return 'LIVRE';
  }

  String _labelFinalidade(String f) =>
      (f == 'comercio') ? 'Comércio' : 'Consumo';

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    final s = v.toString().trim().replaceAll(',', '.');
    return double.tryParse(s) ?? 0.0;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Map<String, int> _intMapFromAny(dynamic mp) {
    if (mp is Map) {
      final out = <String, int>{};
      mp.forEach((k, v) => out[k.toString()] = _toInt(v));
      return out;
    }
    return {};
  }

  Widget _buildFirestoreError(Object? error) {
    return Container(
      margin: const EdgeInsets.all(AppTokens.md),
      padding: const EdgeInsets.all(AppTokens.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Text(
        '❌ Erro ao carregar dados.',
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }

  // ===========================================================================
  // Ciclo de Vida e Init
  // ===========================================================================
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_repo == null) {
      final session = SessionScope.of(context).session;
      if (session != null) {
        _repo = DetalhesCanteiroRepository(session.tenantId);
        _refreshHistorico();
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _compController.dispose();
    _largController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _irParaDiagnostico() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => TelaDiagnostico(canteiroIdOrigem: widget.canteiroId)),
    ).then((_) async {
      if (mounted) await _refreshHistorico();
    });
  }

  void _irParaCalagem() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => TelaCalagem(canteiroIdOrigem: widget.canteiroId)),
    ).then((_) async {
      if (mounted) await _refreshHistorico();
    });
  }

  void _alternarStatus(bool ativoAtual) async {
    try {
      await _repo?.editarCanteiro(widget.canteiroId, {'ativo': !ativoAtual});
      _snack(!ativoAtual ? 'Lote reativado.' : 'Lote arquivado.');
    } catch (_) {}
  }

  Future<void> _ensureAggFields(Map<String, dynamic> d) async {
    if (_aggInitChecked || _repo == null) return;
    _aggInitChecked = true;

    final precisa = !(d.containsKey('agg_total_custo') &&
        d.containsKey('agg_total_receita') &&
        d.containsKey('agg_ciclo_custo') &&
        d.containsKey('agg_ciclo_receita') &&
        d.containsKey('agg_ciclo_concluido') &&
        d.containsKey('agg_ciclo_mapa'));

    if (!precisa) return;

    try {
      await _repo!.editarCanteiro(widget.canteiroId, {
        'agg_total_custo': _toDouble(d['agg_total_custo']),
        'agg_total_receita': _toDouble(d['agg_total_receita']),
        'agg_ciclo_custo': _toDouble(d['agg_ciclo_custo']),
        'agg_ciclo_receita': _toDouble(d['agg_ciclo_receita']),
        'agg_ciclo_id': (d['agg_ciclo_id'] ?? '').toString(),
        'agg_ciclo_inicio': d['agg_ciclo_inicio'],
        'agg_ciclo_produtos': (d['agg_ciclo_produtos'] ?? '').toString(),
        'agg_ciclo_mapa': d['agg_ciclo_mapa'] ?? <String, int>{},
        'agg_ciclo_concluido': (d['agg_ciclo_concluido'] ?? false) == true,
      });
    } catch (_) {}
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore) return;
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _refreshHistorico() async {
    if (!_isLogado || _repo == null) return;
    if (_isFetching) return;

    _isFetching = true;
    setState(() {
      _loadingFirst = true;
      _loadingMore = false;
      _hasMore = true;
      _lastDoc = null;
      _docs.clear();
    });

    await _loadMore();

    _isFetching = false;
    if (mounted) setState(() => _loadingFirst = false);
  }

  Future<void> _loadMore() async {
    if (!_isLogado || _repo == null || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    try {
      Query<Map<String, dynamic>> q =
          _repo!.queryHistorico(widget.canteiroId, _uid!).limit(_pageSize);
      if (_lastDoc != null) q = q.startAfterDocument(_lastDoc!);

      final snap = await q.get();
      if (snap.docs.isNotEmpty) {
        _lastDoc = snap.docs.last;
        final existingIds = _docs.map((d) => d.id).toSet();
        final newDocs =
            snap.docs.where((d) => !existingIds.contains(d.id)).toList();
        _docs.addAll(newDocs);
      }
      if (snap.docs.length < _pageSize) _hasMore = false;
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // ===========================================================================
  // Modais de Manejo Premium
  // ===========================================================================

  void _mostrarDialogoIrrigacao(double areaCanteiro) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetIrrigacao(
        canteiroId: widget.canteiroId,
        areaCanteiro: areaCanteiro,
        uid: _uid!,
        tenantId: _tenantIdOrNull!,
        onSaved: _refreshHistorico,
      ),
    );
  }

  void _mostrarDialogoPlantio(double areaCanteiro, String tipoLocal) {
    if (!_isLogado || _repo == null) return;

    double areaEfetiva = areaCanteiro > 0 ? areaCanteiro : 0.5;
    final qtdPorPlanta = <String, int>{};
    final obsController = TextEditingController();
    final custoMudasController = TextEditingController(text: '0,00');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: StatefulBuilder(
          builder: (contextModal, setModalState) {
            final cs = Theme.of(ctx).colorScheme;
            double areaOcupada = 0.0;

            qtdPorPlanta.forEach((planta, qtd) {
              final info =
                  guiaCompleto[planta] ?? {'eLinha': 0.5, 'ePlanta': 0.5};
              areaOcupada += (qtd *
                  ((info['eLinha'] as num).toDouble() *
                      (info['ePlanta'] as num).toDouble()));
            });

            final percentualOcupado =
                (areaOcupada / areaEfetiva).clamp(0.0, 1.0);
            final estourou = (areaEfetiva - areaOcupada) < 0;

            void adicionarPlanta(String p) {
              final info = guiaCompleto[p] ?? {'eLinha': 0.5, 'ePlanta': 0.5};
              final areaUnit = ((info['eLinha'] as num).toDouble() *
                      (info['ePlanta'] as num).toDouble())
                  .clamp(0.0001, 999999.0);
              int qtdInicial =
                  ((qtdPorPlanta.isNotEmpty && (areaEfetiva - areaOcupada) > 0)
                      ? ((areaEfetiva - areaOcupada) / areaUnit).floor()
                      : (areaEfetiva / areaUnit).floor());
              if (qtdInicial < 1) qtdInicial = 1;
              qtdPorPlanta[p] = qtdInicial;
            }

            final recomendadas = guiaCompleto.keys.toList()..sort();

            final Map<String, List<String>> categorias = {};
            for (var p in recomendadas) {
              final cat =
                  (guiaCompleto[p]?['categoria'] ?? 'Outros').toString();
              categorias.putIfAbsent(cat, () => []).add(p);
            }

            Widget buildChip(String planta) {
              final isSel = qtdPorPlanta.containsKey(planta);
              final icone = (guiaCompleto[planta]?['icone'] ?? '🌱').toString();
              return FilterChip(
                label: Text('$icone $planta'),
                selected: isSel,
                checkmarkColor: cs.onPrimary,
                selectedColor: cs.primary,
                backgroundColor: cs.surfaceContainerHighest,
                labelStyle: TextStyle(
                    fontSize: 12, color: isSel ? cs.onPrimary : cs.onSurface),
                onSelected: (v) => setModalState(() {
                  if (v)
                    adicionarPlanta(planta);
                  else
                    qtdPorPlanta.remove(planta);
                }),
              );
            }

            return Container(
              height: MediaQuery.sizeOf(ctx).height * 0.9,
              decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24))),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Novo Plantio',
                          style: Theme.of(contextModal)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: estourou
                            ? cs.errorContainer
                            : cs.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Ocupação do Lote',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: estourou ? cs.error : cs.primary)),
                            Text(
                                '${(percentualOcupado * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: estourou ? cs.error : cs.primary)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                              value: percentualOcupado,
                              color: estourou ? cs.error : cs.primary,
                              minHeight: 8,
                              backgroundColor: cs.surface),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...categorias.entries.map((entry) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 16, bottom: 8),
                                    child: Text(entry.key.toUpperCase(),
                                        style: TextStyle(
                                            color: cs.outline,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            letterSpacing: 1.2)),
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: entry.value
                                        .map((p) => buildChip(p))
                                        .toList(),
                                  ),
                                ],
                              )),
                          const SizedBox(height: 24),
                          if (qtdPorPlanta.isNotEmpty) ...[
                            const Divider(),
                            const SizedBox(height: 16),
                            Text('Ajustar Quantidades',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: cs.onSurface)),
                            const SizedBox(height: 16),
                            ...qtdPorPlanta.entries.map((entry) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: cs.outlineVariant),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                        child: Text(entry.key,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14))),
                                    IconButton(
                                        icon: Icon(Icons.remove_circle_outline,
                                            color: cs.error),
                                        onPressed: () => setModalState(() {
                                              if (entry.value > 1) {
                                                qtdPorPlanta[entry.key] =
                                                    entry.value - 1;
                                              } else {
                                                qtdPorPlanta.remove(entry.key);
                                              }
                                            })),
                                    Text('${entry.value} un',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold)),
                                    IconButton(
                                        icon: Icon(Icons.add_circle_outline,
                                            color: cs.primary),
                                        onPressed: () => setModalState(() {
                                              qtdPorPlanta[entry.key] =
                                                  entry.value + 1;
                                            })),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                            TextField(
                                controller: obsController,
                                decoration: const InputDecoration(
                                    labelText: 'Observação do Plantio',
                                    border: OutlineInputBorder())),
                            const SizedBox(height: 16),
                            TextField(
                                controller: custoMudasController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    labelText: 'Custo de Mudas/Sementes (R\$)',
                                    prefixIcon: Icon(Icons.monetization_on),
                                    border: OutlineInputBorder())),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (qtdPorPlanta.isNotEmpty)
                    SizedBox(
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: estourou
                            ? null
                            : () async {
                                final custo = double.tryParse(
                                        custoMudasController.text
                                            .trim()
                                            .replaceAll(',', '.')) ??
                                    0.0;
                                Navigator.pop(ctx);

                                String resumo = "Plantio Registrado:\n";
                                final nomes = <String>[];
                                qtdPorPlanta.forEach((planta, qtd) {
                                  nomes.add(planta);
                                  resumo += "- $planta: $qtd mudas\n";
                                });

                                try {
                                  await _repo!.registrarPlantio(
                                      uid: _uid!,
                                      canteiroId: widget.canteiroId,
                                      qtdPorPlanta: qtdPorPlanta,
                                      resumo: resumo,
                                      observacao: obsController.text.trim(),
                                      custo: custo,
                                      produto: nomes.join(' + '));
                                  _snack(
                                      '✅ Plantio registrado! Lote em PRODUÇÃO.');
                                  await _refreshHistorico();
                                } catch (e) {
                                  _snack('Erro: $e', isError: true);
                                }
                              },
                        icon:
                            Icon(estourou ? Icons.warning : Icons.check_circle),
                        label: Text(estourou
                            ? 'ESPAÇO INSUFICIENTE'
                            : 'CONFIRMAR PLANTIO'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: estourou ? cs.error : cs.primary,
                            foregroundColor:
                                estourou ? cs.onError : cs.onPrimary),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ).whenComplete(() {
      obsController.dispose();
      custoMudasController.dispose();
    });
  }

  void _mostrarDialogoManutencao() {
    if (!_isLogado || _repo == null) return;

    String tipoManutencao = 'Descanso / Pousio Livre';
    int diasEstimados = 15;
    final obsController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Container(
          decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surfaceContainerLowest,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(AppTokens.xl),
          child: StatefulBuilder(builder: (contextModal, setModalState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.build_circle, color: Colors.orange.shade800),
                      const SizedBox(width: 8),
                      Text('Colocar em Manutenção',
                          style: Theme.of(ctx)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                      'Para quebrar o ciclo de doenças ou recuperar o solo, o descanso é fundamental.',
                      style: TextStyle(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                          fontSize: 13)),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: tipoManutencao,
                    decoration: const InputDecoration(
                        labelText: 'Motivo / Tratamento',
                        border: OutlineInputBorder()),
                    items: [
                      'Descanso / Pousio Livre',
                      'Solarização (Mata Nematóides)',
                      'Adubação Verde (Recuperação)',
                      'Reação de Calagem'
                    ]
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) {
                      setModalState(() {
                        tipoManutencao = v!;
                        if (tipoManutencao.contains('Solarização'))
                          diasEstimados = 30;
                        else if (tipoManutencao.contains('Adubação Verde'))
                          diasEstimados = 60;
                        else if (tipoManutencao.contains('Calagem'))
                          diasEstimados = 20;
                        else
                          diasEstimados = 15;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Dias Estimados de Bloqueio:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(ctx).colorScheme.outline)),
                      ),
                      IconButton(
                          icon: Icon(Icons.remove_circle_outline,
                              color: Theme.of(ctx).colorScheme.error),
                          onPressed: () => setModalState(() {
                                if (diasEstimados > 1) diasEstimados--;
                              })),
                      Text('$diasEstimados',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                          icon: Icon(Icons.add_circle_outline,
                              color: Theme.of(ctx).colorScheme.primary),
                          onPressed: () => setModalState(() {
                                diasEstimados++;
                              })),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: obsController,
                    decoration: const InputDecoration(
                        labelText: 'Observação (Opcional)',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),
                  AppButtons.elevatedIcon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        final dataFim =
                            DateTime.now().add(Duration(days: diasEstimados));
                        await _repo!.editarCanteiro(widget.canteiroId, {
                          'status': 'manutencao',
                          'manutencao_motivo': tipoManutencao,
                          'manutencao_data_inicio':
                              FieldValue.serverTimestamp(),
                          'manutencao_dias': diasEstimados,
                          'manutencao_data_fim': Timestamp.fromDate(dataFim),
                        });

                        await FirebaseFirestore.instance
                            .collection('tenants')
                            .doc(_tenantIdOrNull)
                            .collection('historico_manejo')
                            .add({
                          'canteiro_id': widget.canteiroId,
                          'uid_usuario': _uid,
                          'tipo_manejo': 'Manutenção',
                          'produto': 'Pousio / Tratamento',
                          'detalhes':
                              '$tipoManutencao por $diasEstimados dias. ${obsController.text}',
                          'data': FieldValue.serverTimestamp(),
                          'custo_estimado': 0.0,
                        });

                        _snack('✅ Lote em manutenção. O solo agradece!');
                        await _refreshHistorico();
                      } catch (e) {
                        _snack('Erro ao salvar', isError: true);
                      }
                    },
                    icon: const Icon(Icons.lock_clock),
                    label: const Text('INICIAR TRATAMENTO'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        foregroundColor: Colors.white),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    ).whenComplete(() => obsController.dispose());
  }

  void _mostrarDialogoColheita({
    required String idPlantioAtivo,
    required Map<String, int> mapaPlantioAtual,
    required String finalidadeCanteiro,
  }) {
    if (!_isLogado || _repo == null) return;
    final selecionados = <String, bool>{};
    final ctrlsQtd = <String, TextEditingController>{};
    final receitaCtrl = TextEditingController(text: '0,00');
    final obsCtrl = TextEditingController();

    final culturas = mapaPlantioAtual.keys.toList()..sort();
    for (final c in culturas) {
      selecionados[c] = false;
      ctrlsQtd[c] = TextEditingController();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: StatefulBuilder(
          builder: (contextModal, setModalState) {
            final cs = Theme.of(ctx).colorScheme;
            bool temErro = false;

            String? validar(String cultura) {
              if (selecionados[cultura] != true) return null;
              final max = mapaPlantioAtual[cultura] ?? 0;
              final txt = ctrlsQtd[cultura]?.text.trim() ?? '';
              if (txt.isEmpty) return 'Obrigatório';
              final qtd = int.tryParse(txt) ?? 0;
              if (qtd <= 0) return '> 0';
              if (qtd > max) return 'Máx $max';
              return null;
            }

            for (final c in culturas) {
              if (validar(c) != null) temErro = true;
            }

            return Container(
              height: MediaQuery.sizeOf(ctx).height * 0.85,
              decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24))),
              padding: const EdgeInsets.all(AppTokens.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Registrar Colheita',
                          style: Theme.of(ctx)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close)),
                    ],
                  ),
                  Text(
                      'Finalidade do Lote: ${_labelFinalidade(finalidadeCanteiro)}',
                      style: TextStyle(
                          color: cs.outline, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          ...culturas.map((cultura) {
                            final max = mapaPlantioAtual[cultura] ?? 0;
                            return Card(
                              elevation: 0,
                              color: cs.primaryContainer,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: cs.outlineVariant)),
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Checkbox(
                                            value: selecionados[cultura],
                                            onChanged: (v) => setModalState(
                                                () => selecionados[cultura] =
                                                    v ?? false),
                                            activeColor: cs.primary),
                                        Expanded(
                                            child: Text(cultura,
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: cs
                                                        .onPrimaryContainer))),
                                        Chip(
                                            label: Text('Restante: $max'),
                                            backgroundColor: cs.surface,
                                            side: BorderSide.none),
                                      ],
                                    ),
                                    if (selecionados[cultura] == true)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: TextField(
                                            controller: ctrlsQtd[cultura],
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                                labelText: 'Quantidade colhida',
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8)),
                                                errorText: validar(cultura),
                                                isDense: true,
                                                filled: true,
                                                fillColor: cs.surface),
                                            onChanged: (_) =>
                                                setModalState(() {})),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                          if (finalidadeCanteiro == 'comercio')
                            TextField(
                                controller: receitaCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                    labelText: 'Receita da venda (R\$)',
                                    prefixIcon:
                                        const Icon(Icons.monetization_on),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12))))
                          else
                            TextField(
                                controller: obsCtrl,
                                decoration: InputDecoration(
                                    labelText: 'Observação (Opcional)',
                                    prefixIcon: const Icon(Icons.notes),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppButtons.elevatedIcon(
                    onPressed: temErro
                        ? null
                        : () async {
                            final colhidos = <String, int>{};
                            for (final c in culturas) {
                              if (selecionados[c] == true) {
                                final qtd =
                                    int.tryParse(ctrlsQtd[c]!.text.trim()) ?? 0;
                                if (qtd > 0) colhidos[c] = qtd;
                              }
                            }
                            if (colhidos.isEmpty) {
                              Navigator.pop(ctx);
                              return;
                            }

                            final receita = double.tryParse(
                                    receitaCtrl.text.replaceAll(',', '.')) ??
                                0.0;
                            Navigator.pop(ctx);

                            try {
                              bool liberado = await _repo!.registrarColheita(
                                  uid: _uid!,
                                  canteiroId: widget.canteiroId,
                                  idPlantioAtivo: idPlantioAtivo,
                                  colhidos: colhidos,
                                  finalidade: finalidadeCanteiro,
                                  receita: finalidadeCanteiro == 'comercio'
                                      ? receita
                                      : 0.0,
                                  observacao: finalidadeCanteiro == 'consumo'
                                      ? obsCtrl.text.trim()
                                      : '');
                              _snack(liberado
                                  ? '✅ Lote Colhido e Liberado!'
                                  : '✅ Colheita Parcial registrada.');
                              await _refreshHistorico();
                            } catch (e) {
                              _snack('Erro: $e', isError: true);
                            }
                          },
                    icon: const Icon(Icons.agriculture),
                    label: const Text('FINALIZAR COLHEITA'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ).whenComplete(() {
      for (final c in ctrlsQtd.values) {
        c.dispose();
      }
      receitaCtrl.dispose();
      obsCtrl.dispose();
    });
  }

  // ===========================================================================
  // MENU PRINCIPAL DE MANEJO
  // ===========================================================================
  void _mostrarOpcoesManejo(double areaCanteiro, String statusAtual,
      String tipoLocal, Map<String, int> cicloMapa, String cicloId) {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.sizeOf(ctx).height * 0.75,
        decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Painel de Manejo',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildListAction(
                    title: 'Irrigação',
                    subtitle: 'Registrar rega e volume de água',
                    icon: Icons.water_drop,
                    color: Colors.blue.shade700,
                    onTap: () {
                      Navigator.pop(ctx);
                      _mostrarDialogoIrrigacao(areaCanteiro);
                    },
                  ),
                  _buildListAction(
                    title: 'Novo Plantio',
                    subtitle: 'Adicionar sementes ou mudas ao lote',
                    icon: Icons.spa,
                    color: (statusAtual == 'livre')
                        ? Colors.green.shade700
                        : cs.outline,
                    onTap: () {
                      Navigator.pop(ctx);
                      if (statusAtual != 'livre') {
                        _snack(
                            'O lote não está livre para um novo plantio total.',
                            isError: true);
                        return;
                      }
                      _mostrarDialogoPlantio(areaCanteiro, tipoLocal);
                    },
                  ),
                  _buildListAction(
                    title: 'Adubação de Cobertura',
                    subtitle: 'Esterco, Bokashi, Mamona (Mensal)',
                    icon: Icons.eco,
                    color: Colors.brown.shade600,
                    onTap: () {
                      Navigator.pop(ctx);
                      _mostrarDialogoGenerico(
                        titulo: 'Registrar Adubação',
                        icone: Icons.eco,
                        cor: Colors.brown.shade600,
                        opcoesDropdown: [
                          'Esterco Bovino',
                          'Bokashi',
                          'Torta de Mamona',
                          'NPK',
                          'Composto Orgânico'
                        ],
                        labelDropdown: 'Tipo de Adubo',
                        labelObs: 'Quantidade / Observações',
                        tipoManejo: 'Adubação',
                      );
                    },
                  ),
                  _buildListAction(
                    title: 'Pulverização e Defensivos',
                    subtitle: 'Calda Bordalesa, Óleo de Nim, etc',
                    icon: Icons.bug_report,
                    color: Colors.purple.shade600,
                    onTap: () {
                      Navigator.pop(ctx);
                      _mostrarDialogoGenerico(
                        titulo: 'Controle / Pulverização',
                        icone: Icons.bug_report,
                        cor: Colors.purple.shade600,
                        opcoesDropdown: [
                          'Óleo de Nim',
                          'Calda Bordalesa',
                          'Calda Sulfocálcica',
                          'Supermagro',
                          'Calda de Pimenta',
                          'Outros'
                        ],
                        labelDropdown: 'Produto Utilizado',
                        labelObs: 'Alvo (Ex: Pulgão, Ferrugem)',
                        tipoManejo: 'Pulverização',
                      );
                    },
                  ),
                  _buildListAction(
                    title: 'Tratos Culturais',
                    subtitle: 'Capina, Poda, Raleio e Limpeza',
                    icon: Icons.content_cut,
                    color: Colors.teal.shade700,
                    onTap: () {
                      Navigator.pop(ctx);
                      _mostrarDialogoGenerico(
                        titulo: 'Tratos Culturais',
                        icone: Icons.content_cut,
                        cor: Colors.teal.shade700,
                        opcoesDropdown: [
                          'Capina / Limpeza',
                          'Poda',
                          'Raleio',
                          'Tutoramento'
                        ],
                        labelDropdown: 'Atividade',
                        labelObs: 'Detalhes da operação',
                        tipoManejo: 'Tratos Culturais',
                      );
                    },
                  ),
                  _buildListAction(
                    title: 'Clínica da Planta',
                    subtitle: 'Diagnosticar pragas e doenças',
                    icon: Icons.health_and_safety,
                    color: cs.error,
                    onTap: () {
                      Navigator.pop(ctx);
                      _irParaDiagnostico();
                    },
                  ),
                  _buildListAction(
                    title: 'Calculadora de Calagem',
                    subtitle: 'Corrigir acidez do solo',
                    icon: Icons.landscape,
                    color: Colors.orange.shade700,
                    onTap: () {
                      Navigator.pop(ctx);
                      _irParaCalagem();
                    },
                  ),
                  if (statusAtual == 'livre')
                    _buildListAction(
                      title: 'Iniciar Manutenção / Pousio',
                      subtitle: 'Descanso, Solarização ou Adubo Verde',
                      icon: Icons.build_circle,
                      color: Colors.orange.shade800,
                      onTap: () {
                        Navigator.pop(ctx);
                        _mostrarDialogoManutencao();
                      },
                    ),
                  if (statusAtual != 'livre' && statusAtual != 'manutencao')
                    _buildListAction(
                      title: 'Baixa / Perda',
                      subtitle: 'Registrar perdas por clima ou pragas',
                      icon: Icons.warning_amber,
                      color: cs.error,
                      onTap: () {
                        Navigator.pop(ctx);
                        _mostrarDialogoPerda(
                            idPlantioAtivo: cicloId,
                            mapaPlantioAtual: cicloMapa);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListAction(
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
          side: BorderSide(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12)),
      color: color.withOpacity(0.05),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title,
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  // ===========================================================================
  // Dialogo Genérico para Adubação, Pulverização e Tratos
  // ===========================================================================
  void _mostrarDialogoGenerico({
    required String titulo,
    required IconData icone,
    required Color cor,
    required List<String> opcoesDropdown,
    required String labelDropdown,
    required String labelObs,
    required String tipoManejo,
  }) {
    if (!_isLogado || _tenantIdOrNull == null) return;
    String selecionado = opcoesDropdown.first;
    final obsCtrl = TextEditingController();
    final custoCtrl = TextEditingController(text: '0,00');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Container(
          decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surfaceContainerLowest,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(AppTokens.xl),
          child: StatefulBuilder(builder: (contextModal, setModalState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(icone, color: cor),
                      const SizedBox(width: 8),
                      Text(titulo,
                          style: Theme.of(ctx)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: selecionado,
                    decoration: InputDecoration(
                        labelText: labelDropdown,
                        border: const OutlineInputBorder()),
                    items: opcoesDropdown
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) => setModalState(() => selecionado = v!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: obsCtrl,
                    decoration: InputDecoration(
                        labelText: labelObs,
                        border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: custoCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Custo da Operação (R\$)',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),
                  AppButtons.elevatedIcon(
                    onPressed: () async {
                      final custo = double.tryParse(
                              custoCtrl.text.replaceAll(',', '.')) ??
                          0.0;
                      Navigator.pop(ctx);

                      try {
                        await FirebaseFirestore.instance
                            .collection('tenants')
                            .doc(_tenantIdOrNull)
                            .collection('historico_manejo')
                            .add({
                          'canteiro_id': widget.canteiroId,
                          'uid_usuario': _uid,
                          'tipo_manejo': tipoManejo,
                          'produto': selecionado,
                          'detalhes': obsCtrl.text.trim(),
                          'data': FieldValue.serverTimestamp(),
                          'custo_estimado': custo,
                        });
                        _snack('✅ Registro salvo com sucesso!');
                        await _refreshHistorico();
                      } catch (e) {
                        _snack('Erro ao salvar', isError: true);
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('SALVAR REGISTRO'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: cor, foregroundColor: Colors.white),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    ).whenComplete(() {
      obsCtrl.dispose();
      custoCtrl.dispose();
    });
  }

  void _mostrarDialogoEditarCanteiro(Map<String, dynamic> d) {
    if (_repo == null) return;
    _nomeController.text = (d['nome'] ?? '').toString();
    _compController.text = _toDouble(d['comprimento']).toString();
    _largController.text = _toDouble(d['largura']).toString();
    String finalidade = (d['finalidade'] ?? 'consumo').toString();
    if (finalidade != 'consumo' && finalidade != 'comercio') {
      finalidade = 'consumo';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setLocalState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Editar Lote',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: _nomeController,
                    decoration: InputDecoration(
                        labelText: 'Nome',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: finalidade,
                  items: const [
                    DropdownMenuItem(
                        value: 'consumo', child: Text('Consumo (doméstico)')),
                    DropdownMenuItem(
                        value: 'comercio', child: Text('Comércio (venda)')),
                  ],
                  onChanged: (v) =>
                      setLocalState(() => finalidade = v ?? finalidade),
                  decoration: InputDecoration(
                      labelText: 'Finalidade',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: _compController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                                labelText: 'Comp.(m)',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12))))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: _largController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                                labelText: 'Larg.(m)',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12))))),
                  ],
                )
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCELAR')),
            ElevatedButton(
              onPressed: () async {
                final nome = _nomeController.text.trim();
                final comp = double.tryParse(
                        _compController.text.replaceAll(',', '.')) ??
                    0.0;
                final larg = double.tryParse(
                        _largController.text.replaceAll(',', '.')) ??
                    0.0;

                if (nome.isEmpty || comp <= 0 || larg <= 0) {
                  _snack('Preencha os dados corretamente.', isError: true);
                  return;
                }

                try {
                  await _repo!.editarCanteiro(widget.canteiroId, {
                    'nome': nome,
                    'comprimento': comp,
                    'largura': larg,
                    'area_m2': comp * larg,
                    'finalidade': finalidade
                  });
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _snack('Lote atualizado!');
                } catch (e) {
                  _snack('Erro: $e', isError: true);
                }
              },
              child: const Text('SALVAR'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoEditarTexto(
      String id, String detalheAtual, String obsAtual) {
    if (_repo == null) return;
    final detalheCtrl = TextEditingController(text: detalheAtual);
    final obsCtrl = TextEditingController(text: obsAtual);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Registro'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: detalheCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                      labelText: 'Detalhes', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(
                  controller: obsCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Observação', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _repo!
                    .editarTextoHistorico(id, detalheCtrl.text, obsCtrl.text);
                if (!mounted) return;
                Navigator.pop(ctx);
                await _refreshHistorico();
              } catch (_) {}
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoPerda(
      {required String idPlantioAtivo,
      required Map<String, int> mapaPlantioAtual}) {
    if (!_isLogado || _repo == null) return;
    final culturas = mapaPlantioAtual.keys.toList()..sort();
    if (culturas.isEmpty) return;

    String culturaSel = culturas.first;
    final qtdCtrl = TextEditingController();
    final motivoCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Container(
          decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surfaceContainerLowest,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(AppTokens.xl),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Registrar Perda',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(ctx).colorScheme.error)),
                    IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: culturaSel,
                  items: culturas
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => culturaSel = v ?? culturaSel,
                  decoration: InputDecoration(
                      labelText: 'Cultura Afetada',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 16),
                TextField(
                    controller: qtdCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: 'Quantidade perdida',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 16),
                TextField(
                    controller: motivoCtrl,
                    decoration: InputDecoration(
                        labelText: 'Motivo (Ex: Praga, Chuva)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 24),
                AppButtons.elevatedIcon(
                  onPressed: () async {
                    final qtd = int.tryParse(qtdCtrl.text.trim()) ?? 0;
                    final max = mapaPlantioAtual[culturaSel] ?? 0;
                    if (qtd <= 0 || qtd > max || motivoCtrl.text.isEmpty) {
                      _snack('Preencha corretamente', isError: true);
                      return;
                    }

                    Navigator.pop(ctx);
                    try {
                      bool liberado = await _repo!.registrarPerda(
                          uid: _uid!,
                          canteiroId: widget.canteiroId,
                          idPlantioAtivo: idPlantioAtivo,
                          cultura: culturaSel,
                          qtdPerdida: qtd,
                          motivo: motivoCtrl.text.trim());
                      _snack(liberado ? 'Lote liberado.' : 'Perda registrada.');
                      await _refreshHistorico();
                    } catch (e) {
                      _snack('Erro: $e', isError: true);
                    }
                  },
                  icon: const Icon(Icons.warning),
                  label: const Text('CONFIRMAR PERDA'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(ctx).colorScheme.error,
                      foregroundColor: Theme.of(ctx).colorScheme.onError),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      qtdCtrl.dispose();
      motivoCtrl.dispose();
    });
  }

  // ===========================================================================
  // Dashboard Premium
  // ===========================================================================
  Widget _buildDashboard(
      {required Map<String, dynamic> dadosCanteiro,
      required double area,
      required String status,
      required String finalidade}) {
    final cs = Theme.of(context).colorScheme;
    final corFundo = _getCorStatus(status, cs);
    final corTexto = (status == 'livre')
        ? cs.primary
        : (status == 'manutencao' ? Colors.orange.shade800 : cs.error);

    final totalCusto = _toDouble(dadosCanteiro['agg_total_custo']);
    final totalReceita = _toDouble(dadosCanteiro['agg_total_receita']);
    final lucroTotal = totalReceita - totalCusto;

    final cicloId = (dadosCanteiro['agg_ciclo_id'] ?? '').toString();
    final cicloConcluido =
        (dadosCanteiro['agg_ciclo_concluido'] ?? false) == true;
    final cicloInicio = dadosCanteiro['agg_ciclo_inicio'] is Timestamp
        ? dadosCanteiro['agg_ciclo_inicio'] as Timestamp
        : null;
    final cicloMapa = _intMapFromAny(dadosCanteiro['agg_ciclo_mapa']);
    final temPlantioAtivo =
        (status == 'ocupado') && cicloId.isNotEmpty && !cicloConcluido;

    // Lógica para Exibição do Card de Manutenção
    final dataFimManutencao = dadosCanteiro['manutencao_data_fim'] is Timestamp
        ? (dadosCanteiro['manutencao_data_fim'] as Timestamp).toDate()
        : null;
    int diasRestantesManutencao = 0;
    if (dataFimManutencao != null) {
      diasRestantesManutencao =
          dataFimManutencao.difference(DateTime.now()).inDays;
    }

    return Column(
      children: [
        if (finalidade == 'comercio')
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: cs.shadow.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MiniStat(
                    label: 'Custo', value: _money(totalCusto), color: cs.error),
                Container(width: 1, height: 40, color: cs.outlineVariant),
                _MiniStat(
                    label: 'Faturamento',
                    value: _money(totalReceita),
                    color: cs.primary),
                Container(width: 1, height: 40, color: cs.outlineVariant),
                _MiniStat(
                    label: 'Lucro Lote',
                    value: _money(lucroTotal),
                    color: lucroTotal >= 0 ? Colors.blue.shade700 : cs.error),
              ],
            ),
          ),
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: corFundo.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: corFundo.withOpacity(0.5))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: corFundo,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(_getTextoStatus(status),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: Colors.white))),
                  const Spacer(),
                  if (temPlantioAtivo && cicloMapa.isNotEmpty)
                    AppButtons.elevatedIcon(
                      onPressed: () => _mostrarDialogoColheita(
                          idPlantioAtivo: cicloId,
                          mapaPlantioAtual: cicloMapa,
                          finalidadeCanteiro: finalidade),
                      icon: const Icon(Icons.check, size: 16),
                      label:
                          const Text('Colher', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          minimumSize: const Size(80, 30)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('${area.toStringAsFixed(1)} m²',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: corTexto)),
              Text('Área útil',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),

              // -------------------------------------------------------------
              // 🟠 NOVO: CARD DE MANUTENÇÃO (POUSIO/TRATAMENTO)
              // -------------------------------------------------------------
              if (status == 'manutencao') ...[
                const Divider(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.build_circle,
                              color: Colors.orange.shade800, size: 20),
                          const SizedBox(width: 8),
                          Text(
                              dadosCanteiro['manutencao_motivo'] ?? 'Em Pousio',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (dataFimManutencao != null)
                        Text(
                            diasRestantesManutencao > 0
                                ? 'Faltam $diasRestantesManutencao dias para concluir o tratamento.'
                                : 'O período de tratamento já terminou!',
                            style: TextStyle(
                                fontSize: 12, color: Colors.orange.shade900)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            await _repo!.editarCanteiro(widget.canteiroId, {
                              'status': 'livre',
                            });
                            _snack(
                                '✅ Manutenção concluída! O lote está livre.');
                          } catch (_) {}
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade800,
                            foregroundColor: Colors.white),
                        child: const Text('FINALIZAR MANUTENÇÃO'),
                      )
                    ],
                  ),
                )
              ],

              // -------------------------------------------------------------
              // 🟢 CARD DE SAFRA ATIVA (PRODUÇÃO)
              // -------------------------------------------------------------
              if (temPlantioAtivo) ...[
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Safra Ativa',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        cicloInicio == null
                            ? ''
                            : 'Início: ${_fmtData(cicloInicio)}',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 12),
                if (cicloInicio != null)
                  ...cicloMapa.keys.map((planta) {
                    final ciclo = _toInt(guiaCompleto[planta]?['ciclo'] ?? 90);
                    final diasPassados =
                        DateTime.now().difference(cicloInicio.toDate()).inDays;
                    final progresso = (diasPassados / (ciclo <= 0 ? 1 : ciclo))
                        .clamp(0.0, 1.0);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('$planta (${cicloMapa[planta]} un)',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              Text('${diasPassados}d / ${ciclo}d',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: cs.onSurfaceVariant)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progresso,
                              backgroundColor: cs.surface.withOpacity(0.6),
                              color:
                                  (progresso >= 1) ? cs.primary : Colors.orange,
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_tenantIdOrNull == null) {
      return Scaffold(
          body: Center(
              child: Text('Tenant não selecionado.',
                  style: TextStyle(color: cs.outline))));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _repo?.watchCanteiro(widget.canteiroId),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Scaffold(
              appBar: AppBar(), body: _buildFirestoreError(snapshot.error));
        if (!snapshot.hasData)
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));

        final raw = snapshot.data!.data();
        if (raw == null)
          return const Scaffold(body: Center(child: Text('Lote apagado.')));

        final dados = Map<String, dynamic>.from(raw);

        if (!_aggInitChecked) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _ensureAggFields(dados);
          });
        }

        final bool ativo = (dados['ativo'] ?? true) == true;
        final String status = (dados['status'] ?? 'livre').toString();
        final double comp = _toDouble(dados['comprimento']);
        final double larg = _toDouble(dados['largura']);
        final String tipoLocal = (dados['tipo'] ?? 'Canteiro').toString();

        final double area = _toDouble(dados['area_m2']) > 0
            ? _toDouble(dados['area_m2'])
            : (comp * larg);
        String finalidade = (dados['finalidade'] ?? 'consumo').toString();
        if (finalidade != 'consumo' && finalidade != 'comercio')
          finalidade = 'consumo';

        final cicloId = (dados['agg_ciclo_id'] ?? '').toString();
        final cicloMapa = _intMapFromAny(dados['agg_ciclo_mapa']);

        return Scaffold(
          backgroundColor: cs.surfaceContainerLowest,
          appBar: AppBar(
            title: Text((dados['nome'] ?? 'Lote').toString(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: _getCorStatus(status, cs),
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'e') _mostrarDialogoEditarCanteiro(dados);
                  if (v == 's') _alternarStatus(ativo);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'e', child: Text('Editar Medidas')),
                  PopupMenuItem(
                      value: 's',
                      child: Text(ativo ? 'Arquivar Lote' : 'Reativar Lote')),
                ],
              ),
            ],
          ),
          floatingActionButton: ativo
              ? FloatingActionButton.extended(
                  onPressed: () => _mostrarOpcoesManejo(
                      area, status, tipoLocal, cicloMapa, cicloId),
                  backgroundColor: _getCorStatus(status, cs),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_task),
                  label: const Text('MANEJO',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                )
              : null,
          body: RefreshIndicator(
            onRefresh: _refreshHistorico,
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(
                  child: _buildDashboard(
                      dadosCanteiro: dados,
                      area: area,
                      status: status,
                      finalidade: finalidade),
                ),
                if (_loadingFirst)
                  const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()))
                else if (_docs.isEmpty)
                  const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('Sem histórico.')))
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((ctx, i) {
                      final e = _docs[i].data();
                      final tipo = (e['tipo_manejo'] ?? '').toString();
                      final produto = (e['produto'] ?? '').toString();
                      final detalhes = (e['detalhes'] ?? '').toString();
                      final ts = e['data'] is Timestamp
                          ? e['data'] as Timestamp
                          : null;

                      Color cor() {
                        if (tipo == 'Plantio') return cs.primary;
                        if (tipo == 'Irrigação') return Colors.blue.shade700;
                        if (tipo == 'Colheita') return Colors.teal.shade700;
                        if (tipo == 'Perda') return cs.error;
                        if (tipo == 'Adubação') return Colors.brown.shade600;
                        if (tipo == 'Pulverização')
                          return Colors.purple.shade600;
                        if (tipo == 'Tratos Culturais')
                          return Colors.teal.shade700;
                        if (tipo == 'Manutenção') return Colors.orange.shade800;
                        return cs.outline;
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            side: BorderSide(color: cs.outlineVariant),
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                              backgroundColor: cor().withOpacity(0.1),
                              child: Icon(Icons.history, color: cor())),
                          title: Text(produto.isEmpty ? tipo : produto,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tipo,
                                  style: TextStyle(
                                      color: cor(),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                              Text(_fmtData(ts),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurfaceVariant)),
                              if (detalhes.isNotEmpty)
                                Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(detalhes)),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.edit_outlined, color: cs.outline),
                            onPressed: () => _mostrarDialogoEditarTexto(
                                _docs[i].id,
                                detalhes,
                                (e['observacao_extra'] ?? '').toString()),
                          ),
                        ),
                      );
                    }, childCount: _docs.length),
                  ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w900, color: color, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

// =======================================================================
// COMPONENTE: SHEET DE IRRIGAÇÃO
// =======================================================================
class _SheetIrrigacao extends StatefulWidget {
  final String canteiroId;
  final double areaCanteiro;
  final String uid;
  final String tenantId;
  final VoidCallback onSaved;

  const _SheetIrrigacao({
    required this.canteiroId,
    required this.areaCanteiro,
    required this.uid,
    required this.tenantId,
    required this.onSaved,
  });

  @override
  State<_SheetIrrigacao> createState() => _SheetIrrigacaoState();
}

class _SheetIrrigacaoState extends State<_SheetIrrigacao> {
  String _metodo = 'Aspersão';
  int _tempo = 4;
  bool _salvando = false;

  double get _metaDiariaLitros => widget.areaCanteiro * 5.0;

  double get _volumeEstimadoLitros {
    double vazaoLPM = 2.0;
    if (_metodo == 'Aspersão') vazaoLPM = 10.0;
    if (_metodo == 'Manual (Mangueira)') vazaoLPM = 15.0;
    if (_metodo == 'Regador') vazaoLPM = 5.0;
    return _tempo * vazaoLPM;
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(widget.tenantId)
          .collection('historico_manejo')
          .add({
        'canteiro_id': widget.canteiroId,
        'uid_usuario': widget.uid,
        'tipo_manejo': 'Irrigação',
        'produto': 'Água',
        'metodo': _metodo,
        'tempo_minutos': _tempo,
        'volume_l': _volumeEstimadoLitros,
        'detalhes':
            'Regado por $_tempo min via $_metodo. Volume est.: ${_volumeEstimadoLitros.toStringAsFixed(1)}L',
        'data': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      AppMessenger.error('Erro ao registrar irrigação.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.water_drop, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text('Registrar Irrigação',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _metodo,
                    decoration: const InputDecoration(
                        labelText: 'Método', border: OutlineInputBorder()),
                    items: [
                      'Gotejamento',
                      'Aspersão',
                      'Manual (Mangueira)',
                      'Regador'
                    ]
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) => setState(() => _metodo = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                        labelText: 'Tempo',
                        suffixText: 'min',
                        border: OutlineInputBorder()),
                    initialValue: _tempo.toString(),
                    onChanged: (v) =>
                        setState(() => _tempo = int.tryParse(v) ?? 0),
                  ),
                )
              ]),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade100)),
                child: Column(
                  children: [
                    Text('Volume Estimado',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900.withOpacity(0.7))),
                    const SizedBox(height: 4),
                    Text('${_volumeEstimadoLitros.toStringAsFixed(0)} L',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.blue.shade900)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.eco, color: Colors.green.shade700, size: 18),
                        const SizedBox(width: 8),
                        Text('Dica Agronômica',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                        'Sua meta diária (sem chuva) é de ${_metaDiariaLitros.toStringAsFixed(0)}L para a área de ${widget.areaCanteiro.toStringAsFixed(1)}m².',
                        style: TextStyle(
                            fontSize: 12, color: Colors.green.shade900)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _salvando ? null : _salvar,
                  icon: const Icon(Icons.save),
                  label: const Text('CONFIRMAR REGISTRO'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
