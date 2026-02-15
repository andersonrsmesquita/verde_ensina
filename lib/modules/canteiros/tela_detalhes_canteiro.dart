import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/ui/app_ui.dart';
import '../../core/session/session_scope.dart';
import '../../core/repositories/detalhes_canteiro_repository.dart';

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
  bool _isFetching = false; // 🛡️ Trava Anti-Duplicação

  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  Object? _err;

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
    if (status == 'manutencao') return Colors.orange.shade700;
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

  Timestamp _nowTs() => Timestamp.now();

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('requires an index')) {
      return 'Falta criar um índice no Firestore. Verifique o console.';
    }
    return msg;
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
        '❌ Erro: ${_friendlyError(error ?? "Desconhecido")}',
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
        // Só carrega o histórico UMA VEZ aqui de forma segura
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

  // ===========================================================================
  // Navegações e Banco de Dados
  // ===========================================================================
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
    if (_isFetching) return; // 🛡️ Evita chamadas concorrentes

    _isFetching = true;
    setState(() {
      _loadingFirst = true;
      _loadingMore = false;
      _hasMore = true;
      _lastDoc = null;
      _docs.clear();
      _err = null;
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

        // 🛡️ Filtro Anti-Duplicação Definitivo: Só adiciona se o ID não existir na lista
        final existingIds = _docs.map((d) => d.id).toSet();
        final newDocs =
            snap.docs.where((d) => !existingIds.contains(d.id)).toList();

        _docs.addAll(newDocs);
      }
      if (snap.docs.length < _pageSize) _hasMore = false;
    } catch (e) {
      _err = e;
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // ===========================================================================
  // Modais de Manejo Premium
  // ===========================================================================

  void _mostrarDialogoIrrigacao() {
    if (!_isLogado || _repo == null) return;

    String metodo = 'Gotejamento';
    final tempoController = TextEditingController(text: '30');
    final chuvaController = TextEditingController(text: '0');
    final custoController = TextEditingController(text: '0,00');

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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Registrar Irrigação',
                        style: Theme.of(ctx)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: AppTokens.md),
                DropdownButtonFormField<String>(
                  value: metodo,
                  items: ['Manual', 'Gotejamento', 'Aspersão', 'Regador']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => metodo = v ?? metodo,
                  decoration: InputDecoration(
                      labelText: 'Sistema',
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTokens.radiusMd))),
                ),
                const SizedBox(height: AppTokens.md),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: tempoController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                                labelText: 'Tempo (min)',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppTokens.radiusMd)),
                                prefixIcon: const Icon(Icons.timer)))),
                    const SizedBox(width: AppTokens.md),
                    Expanded(
                        child: TextField(
                            controller: chuvaController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                                labelText: 'Chuva (mm)',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppTokens.radiusMd)),
                                prefixIcon: const Icon(Icons.cloud)))),
                  ],
                ),
                const SizedBox(height: AppTokens.md),
                TextField(
                    controller: custoController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: 'Custo Operacional (R\$)',
                        hintText: 'Água, Luz...',
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusMd)),
                        prefixIcon: const Icon(Icons.attach_money))),
                const SizedBox(height: AppTokens.xl),
                AppButtons.elevatedIcon(
                  onPressed: () async {
                    final tempo =
                        int.tryParse(tempoController.text.trim()) ?? 0;
                    final chuva = double.tryParse(
                            chuvaController.text.trim().replaceAll(',', '.')) ??
                        0.0;
                    final custo = double.tryParse(
                            custoController.text.trim().replaceAll(',', '.')) ??
                        0.0;

                    Navigator.pop(ctx);
                    try {
                      await _repo!.registrarIrrigacao(
                          uid: _uid!,
                          canteiroId: widget.canteiroId,
                          metodo: metodo,
                          tempo: tempo,
                          chuva: chuva,
                          custo: custo);
                      _snack('✅ Irrigação registrada.');
                      await _refreshHistorico();
                    } catch (e) {
                      _snack('Erro: $e', isError: true);
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('SALVAR REGISTRO'),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      tempoController.dispose();
      chuvaController.dispose();
      custoController.dispose();
    });
  }

  void _mostrarDialogoPlantio(double areaCanteiro, String tipoLocal) {
    if (!_isLogado || _repo == null) return;

    // 🛡️ Correção do Vaso: Permite plantar em vasos ou espaços pequenos sem travar
    double areaEfetiva = areaCanteiro > 0 ? areaCanteiro : 0.5;

    final qtdPorPlanta = <String, int>{};
    const regiao = 'Sudeste';
    const mes = 'Fevereiro';
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

            final recomendadas = culturasPorRegiaoMes(regiao, mes);
            final porCategoria = <String, List<String>>{};
            for (final p in recomendadas) {
              final cat = (guiaCompleto[p]?['cat'] ?? 'Outros').toString();
              porCategoria.putIfAbsent(cat, () => []).add(p);
            }

            Widget buildChip(String planta) {
              final isSel = qtdPorPlanta.containsKey(planta);
              return FilterChip(
                label: Text(planta),
                selected: isSel,
                checkmarkColor: cs.onPrimary,
                selectedColor: cs.primary,
                backgroundColor: cs.surfaceContainerHighest,
                labelStyle: TextStyle(
                    fontSize: 11, color: isSel ? cs.onPrimary : cs.onSurface),
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
              padding: const EdgeInsets.all(AppTokens.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Novo Plantio',
                          style: Theme.of(contextModal)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                        value: percentualOcupado,
                        color: estourou ? cs.error : cs.primary,
                        minHeight: 10,
                        backgroundColor: cs.surfaceContainerHighest),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text('✅ Recomendados para a Época:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: cs.onPrimaryContainer))),
                          const SizedBox(height: 8),
                          ...porCategoria.entries.map((e) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                      padding: const EdgeInsets.only(
                                          top: 8, bottom: 4),
                                      child: Text(e.key.toUpperCase(),
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: cs.outline))),
                                  Wrap(
                                      spacing: 5,
                                      children: e.value
                                          .map((p) => buildChip(p))
                                          .toList()),
                                ],
                              )),
                          const SizedBox(height: 16),
                          if (qtdPorPlanta.isNotEmpty) ...[
                            const Divider(),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: cs.secondaryContainer,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('Ajuste a Quantidade',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: cs.onSecondaryContainer)),
                                  const SizedBox(height: 10),
                                  ...qtdPorPlanta.entries.map((entry) {
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                            child: Text(entry.key,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14))),
                                        IconButton(
                                            icon: Icon(Icons.remove_circle,
                                                color: cs.error),
                                            onPressed: () => setModalState(() {
                                                  if (entry.value > 1)
                                                    qtdPorPlanta[entry.key] =
                                                        entry.value - 1;
                                                })),
                                        Text('${entry.value}',
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold)),
                                        IconButton(
                                            icon: Icon(Icons.add_circle,
                                                color: cs.primary),
                                            onPressed: () => setModalState(() {
                                                  qtdPorPlanta[entry.key] =
                                                      entry.value + 1;
                                                })),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                                controller: obsController,
                                decoration: InputDecoration(
                                    labelText: 'Observação do Plantio',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)))),
                            const SizedBox(height: 16),
                            TextField(
                                controller: custoMudasController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                    labelText: 'Custo de Mudas/Sementes (R\$)',
                                    prefixIcon:
                                        const Icon(Icons.monetization_on),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)))),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (qtdPorPlanta.isNotEmpty)
                    AppButtons.elevatedIcon(
                      onPressed: estourou
                          ? null
                          : () async {
                              final custo = double.tryParse(custoMudasController
                                      .text
                                      .trim()
                                      .replaceAll(',', '.')) ??
                                  0.0;
                              Navigator.pop(ctx);

                              String resumo = "Plantio ($regiao/$mes):\n";
                              final nomes = <String>[];
                              qtdPorPlanta.forEach((planta, qtd) {
                                nomes.add(planta);
                                final ciclo = _toInt(
                                    guiaCompleto[planta]?['ciclo'] ?? 90);
                                resumo +=
                                    "- $planta: $qtd mudas ($ciclo dias)\n";
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
                      icon: Icon(estourou ? Icons.warning : Icons.check_circle),
                      label: Text(estourou
                          ? 'ESPAÇO INSUFICIENTE'
                          : 'CONFIRMAR PLANTIO'),
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

  void _mostrarDialogoEditarCanteiro(Map<String, dynamic> d) {
    if (_repo == null) return;
    _nomeController.text = (d['nome'] ?? '').toString();
    _compController.text = _toDouble(d['comprimento']).toString();
    _largController.text = _toDouble(d['largura']).toString();
    String finalidade = (d['finalidade'] ?? 'consumo').toString();
    if (finalidade != 'consumo' && finalidade != 'comercio')
      finalidade = 'consumo';

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

  void _mostrarOpcoesManejo(
      double areaCanteiro, String statusAtual, String tipoLocal) {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(AppTokens.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Menu de Operações',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                _buildActionCard(
                    'Irrigação', Icons.water_drop, Colors.blue.shade700, () {
                  Navigator.pop(ctx);
                  _mostrarDialogoIrrigacao();
                }),
                _buildActionCard('Novo Plantio', Icons.spa,
                    (statusAtual == 'livre') ? cs.primary : cs.outline, () {
                  Navigator.pop(ctx);
                  if (statusAtual != 'livre') {
                    _snack('Finalize a safra atual antes de plantar.',
                        isError: true);
                    return;
                  }
                  _mostrarDialogoPlantio(
                      areaCanteiro, tipoLocal); // ✅ Área efetiva injetada aqui
                }),
                _buildActionCard('Clínica', Icons.health_and_safety, cs.error,
                    () {
                  Navigator.pop(ctx);
                  _irParaDiagnostico();
                }),
                _buildActionCard(
                    'Calagem', Icons.landscape, Colors.orange.shade700, () {
                  Navigator.pop(ctx);
                  _irParaCalagem();
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
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
        : (status == 'manutencao' ? Colors.orange.shade900 : cs.error);

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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _mostrarDialogoPerda(
                        idPlantioAtivo: cicloId, mapaPlantioAtual: cicloMapa),
                    icon: Icon(Icons.bug_report, color: cs.error, size: 16),
                    label: Text('Baixa / Perda',
                        style: TextStyle(color: cs.error, fontSize: 12)),
                  ),
                ),
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

        // 🛡️ A chamada recursiva e bugada foi limpa e removida daqui.

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
                  onPressed: () => _mostrarOpcoesManejo(area, status,
                      tipoLocal), // ✅ Passando a área limpa para o Modal
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
