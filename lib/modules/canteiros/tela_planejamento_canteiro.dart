import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ui/app_ui.dart';
import '../../core/firebase/firebase_paths.dart';
import '../../core/session/session_scope.dart';
import 'guia_culturas.dart';
import 'widgets/canteiro_picker_dropdown.dart';

class TelaPlanejamentoCanteiro extends StatefulWidget {
  final String? canteiroIdOrigem;
  const TelaPlanejamentoCanteiro({super.key, this.canteiroIdOrigem});

  @override
  State<TelaPlanejamentoCanteiro> createState() =>
      _TelaPlanejamentoCanteiroState();
}

class _TelaPlanejamentoCanteiroState extends State<TelaPlanejamentoCanteiro> {
  User? get _user => FirebaseAuth.instance.currentUser;

  String? _canteiroId;
  String _nomeCanteiro = '';
  double _areaM2 = 0;
  double? _larguraM;
  double? _comprimentoM;

  String _regiao = 'Sudeste';
  String _mes = 'Fevereiro';
  String? _culturaSelecionada;

  final _larguraCtrl = TextEditingController();
  final _comprimentoCtrl = TextEditingController();

  bool _salvandoDim = false;

  @override
  void initState() {
    super.initState();
    if (widget.canteiroIdOrigem != null) {
      _canteiroId = widget.canteiroIdOrigem;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final tenantId = SessionScope.of(context).session?.tenantId;
          if (tenantId != null) {
            _carregarCanteiro(widget.canteiroIdOrigem!, tenantId);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _larguraCtrl.dispose();
    _comprimentoCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AppMessenger.error(msg);
    } else {
      AppMessenger.success(msg);
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    final s = v.toString().trim().replaceAll(',', '.');
    return double.tryParse(s) ?? 0;
  }

  String _fmt(num v, {int dec = 2}) =>
      v.toStringAsFixed(dec).replaceAll('.', ',');

  CulturaInfo? get _infoSelecionada =>
      _culturaSelecionada == null ? null : getCulturaInfo(_culturaSelecionada!);

  double? _parsePositive(String text) {
    final v = double.tryParse(text.trim().replaceAll(',', '.'));
    return (v == null || v <= 0) ? null : v;
  }

  double? _larguraFinal() => (_larguraM != null && _larguraM! > 0)
      ? _larguraM
      : _parsePositive(_larguraCtrl.text);
  double? _comprimentoFinal() => (_comprimentoM != null && _comprimentoM! > 0)
      ? _comprimentoM
      : _parsePositive(_comprimentoCtrl.text);

  Future<void> _carregarCanteiro(String id, String tenantId) async {
    final user = _user;
    if (user == null) return;

    try {
      final doc = await FirebasePaths.canteirosCol(tenantId).doc(id).get();
      if (!doc.exists || !mounted) return;

      final data = doc.data() ?? {};
      if ((data['uid_usuario'] ?? '').toString() != user.uid) return;

      final largura = _toDouble(data['largura'] ?? data['largura_m']);
      final comp = _toDouble(data['comprimento'] ?? data['comprimento_m']);

      setState(() {
        _canteiroId = id;
        _nomeCanteiro = (data['nome'] ?? 'Canteiro').toString();
        _areaM2 = _toDouble(data['area_m2']);
        _larguraM = largura > 0 ? largura : null;
        _comprimentoM = comp > 0 ? comp : null;

        _larguraCtrl.text = _larguraM != null ? _fmt(_larguraM!) : '';
        _comprimentoCtrl.text =
            _comprimentoM != null ? _fmt(_comprimentoM!) : '';
      });
    } catch (e) {
      _snack('Erro ao carregar o lote.', isError: true);
    }
  }

  Future<void> _salvarDimensoes() async {
    if (_canteiroId == null)
      return _snack('Selecione um canteiro.', isError: true);
    final tenantId = SessionScope.of(context).session?.tenantId;
    if (tenantId == null) return;

    final larg = _larguraFinal();
    final comp = _comprimentoFinal();

    if (larg == null || comp == null)
      return _snack('Preencha largura e comprimento válidos.', isError: true);

    setState(() => _salvandoDim = true);

    try {
      await FirebasePaths.canteirosCol(tenantId).doc(_canteiroId).set(
        {
          'largura': double.parse(larg.toStringAsFixed(2)),
          'comprimento': double.parse(comp.toStringAsFixed(2)),
          'area_m2': double.parse((larg * comp).toStringAsFixed(2)),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (mounted) {
        setState(() {
          _larguraM = larg;
          _comprimentoM = comp;
          _areaM2 = larg * comp;
        });
        _snack('Dimensões atualizadas!');
      }
    } catch (e) {
      _snack('Erro ao salvar dimensões.', isError: true);
    } finally {
      if (mounted) setState(() => _salvandoDim = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tenantId = SessionScope.of(context).session?.tenantId;

    if (_user == null || tenantId == null) {
      return const PageContainer(
          scroll: false, body: Center(child: Text('Espaço não selecionado.')));
    }

    final info = _infoSelecionada;
    final regioes = calendarioRegional.keys.toList()..sort();
    final meses = (calendarioRegional[_regiao]?.keys.toList() ?? [])..sort();
    final sugestoes = culturasPorRegiaoMes(_regiao, _mes);

    return PageContainer(
      title: 'Plano de Manejo',
      subtitle: 'Estruture o lote baseando-se nas regras agronômicas',
      scroll: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. ÁREA DE CULTIVO
          SectionCard(
            title: '1) Local de Cultivo',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CanteiroPickerDropdown(
                  tenantId: tenantId,
                  selectedId: _canteiroId,
                  onSelect: (id) => _carregarCanteiro(id, tenantId),
                ),
                if (_areaM2 > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(Icons.crop_free, color: cs.onPrimaryContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Área útil',
                                  style: TextStyle(
                                      color: cs.onPrimaryContainer,
                                      fontSize: 12)),
                              Text('${_fmt(_areaM2)} m²',
                                  style: TextStyle(
                                      color: cs.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: TextFormField(
                            controller: _larguraCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Largura (m)',
                                border: OutlineInputBorder(),
                                isDense: true))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextFormField(
                            controller: _comprimentoCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Compr. (m)',
                                border: OutlineInputBorder(),
                                isDense: true))),
                  ],
                ),
                const SizedBox(height: 12),
                AppButtons.outlinedIcon(
                  onPressed: (_canteiroId == null || _salvandoDim)
                      ? null
                      : _salvarDimensoes,
                  icon: Icon(_salvandoDim ? Icons.hourglass_top : Icons.save),
                  label: Text(
                      _salvandoDim ? 'SALVANDO...' : 'ATUALIZAR ÁREA DO LOTE'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. CULTURA E ÉPOCA
          SectionCard(
            title: '2) Cultura e Época',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _regiao,
                        decoration: const InputDecoration(
                            labelText: 'Região',
                            border: OutlineInputBorder(),
                            isDense: true),
                        items: regioes
                            .map((r) =>
                                DropdownMenuItem(value: r, child: Text(r)))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _regiao = v ?? _regiao;
                          _culturaSelecionada = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: meses.contains(_mes) ? _mes : null,
                        decoration: const InputDecoration(
                            labelText: 'Mês',
                            border: OutlineInputBorder(),
                            isDense: true),
                        items: meses
                            .map((m) =>
                                DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _mes = v ?? _mes;
                          _culturaSelecionada = null;
                        }),
                      ),
                    ),
                  ],
                ),
                if (sugestoes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Recomendadas para a época:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: cs.primary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sugestoes
                        .map((nome) => ChoiceChip(
                              selected: _culturaSelecionada == nome,
                              label: Text(nome),
                              onSelected: (_) =>
                                  setState(() => _culturaSelecionada = nome),
                            ))
                        .toList(),
                  ),
                  const Divider(height: 32),
                ],
                Autocomplete<String>(
                  optionsBuilder: (val) => val.text.isEmpty
                      ? const Iterable<String>.empty()
                      : buscarCulturas(val.text),
                  onSelected: (sel) =>
                      setState(() => _culturaSelecionada = sel),
                  fieldViewBuilder: (ctx, ctrl, focus, onSub) => TextFormField(
                    controller: ctrl,
                    focusNode: focus,
                    decoration: InputDecoration(
                        labelText: 'Ou pesquise a cultura livremente...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. INTELIGÊNCIA AGRONÔMICA (MANUAIS EMBUTIDOS)
          if (info != null) ...[
            SectionCard(
              title: '3) Inteligência Agronômica',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(info.nome,
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: cs.primary)),
                      Chip(
                          label: Text('${info.cicloDias} dias',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (info.companheiras.isNotEmpty) ...[
                    Text('Bons consórcios:',
                        style: TextStyle(fontSize: 12, color: cs.outline)),
                    Text(info.companheiras.join(', '),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700)),
                    const SizedBox(height: 8),
                  ],
                  if (info.evitar.isNotEmpty) ...[
                    Text('Evitar perto:',
                        style: TextStyle(fontSize: 12, color: cs.outline)),
                    Text(info.evitar.join(', '),
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: cs.error)),
                  ],
                  if (_areaM2 > 0) ...[
                    const Divider(height: 32),

                    // REGRAS ORGANO 15
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.brown.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.brown.shade200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [
                            Icon(Icons.science, color: Colors.brown),
                            SizedBox(width: 8),
                            Text('Receituário Organo 15',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.brown))
                          ]),
                          const SizedBox(height: 12),
                          Text('Baseado em ${_fmt(_areaM2)} m² de área útil:',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.brown)),
                          const SizedBox(height: 8),
                          AppKeyValueRow(
                              label: 'Base em Calcário (200 g/m²)',
                              value: '${_fmt((_areaM2 * 0.200))} kg',
                              color: Colors.brown),
                          AppKeyValueRow(
                              label: 'Base em Fosfato (150 g/m²)',
                              value: '${_fmt((_areaM2 * 0.150))} kg',
                              color: Colors.brown),
                          AppKeyValueRow(
                              label: 'Matéria Orgânica (3 kg/m²)',
                              value: '${_fmt((_areaM2 * 3.0))} kg',
                              color: Colors.brown),
                          AppKeyValueRow(
                              label: 'Base em Gesso (200 g/m²)',
                              value: '${_fmt((_areaM2 * 0.200))} kg',
                              color: Colors.brown),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // CÁLCULO DE MÃO DE OBRA (CUSTOS)
                    Builder(builder: (context) {
                      final semanas = (info.cicloDias / 7).ceil();
                      final fase1 = _areaM2 * 0.25;
                      final fase2 = (semanas * 0.083) * _areaM2;
                      final fase3 = _areaM2 * 0.016;
                      final totalHoras = fase1 + fase2 + fase3;
                      final porSemana =
                          totalHoras / (semanas > 0 ? semanas : 1);

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [
                              Icon(Icons.handyman, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Mão de Obra',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.blue))
                            ]),
                            const SizedBox(height: 12),
                            AppKeyValueRow(
                                label: 'Fase de Preparo (1)',
                                value: '${_fmt(fase1)} h',
                                color: Colors.blue.shade900),
                            AppKeyValueRow(
                                label: 'Fase de Condução (2)',
                                value: '${_fmt(fase2)} h',
                                color: Colors.blue.shade900),
                            AppKeyValueRow(
                                label: 'Fase de Colheita (3)',
                                value: '${_fmt(fase3)} h',
                                color: Colors.blue.shade900),
                            const Divider(color: Colors.blue),
                            AppKeyValueRow(
                                label: 'Carga Semanal Estimada',
                                value: '${_fmt(porSemana)} h/sem',
                                isBold: true,
                                color: Colors.blue.shade900),
                          ],
                        ),
                      );
                    }),
                  ] else ...[
                    const SizedBox(height: 24),
                    Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: cs.errorContainer,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(
                            '⚠️ Salve as dimensões no "Passo 1" para calcular o Adubo e a Mão de Obra.',
                            style: TextStyle(
                                color: cs.onErrorContainer,
                                fontWeight: FontWeight.bold))),
                  ],
                ],
              ),
            ),
          ] else ...[
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                    child: Text('Nenhuma cultura selecionada.',
                        style: TextStyle(color: Colors.grey)))),
          ]
        ],
      ),
      bottomBar: SizedBox(
        height: 50,
        width: double.infinity,
        child: AppButtons.elevatedIcon(
          onPressed: (info == null || _areaM2 <= 0)
              ? null
              : () {
                  _snack('Planejamento pronto! Você já tem a receita.');
                  Navigator.of(context).maybePop();
                },
          icon: const Icon(Icons.check_circle),
          label: const Text('SALVAR PLANEJAMENTO'),
        ),
      ),
    );
  }
}
