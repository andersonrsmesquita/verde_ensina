import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:verde_ensina/core/ui/widgets/page_container.dart';
import 'package:verde_ensina/core/ui/widgets/section_card.dart';
import 'package:verde_ensina/core/ui/widgets/app_button.dart';
import 'package:verde_ensina/core/ui/widgets/app_text_field.dart';

import 'guia_culturas.dart';

class TelaPlanejamentoCanteiro extends StatefulWidget {
  final String? canteiroIdOrigem;
  const TelaPlanejamentoCanteiro({super.key, this.canteiroIdOrigem});

  @override
  State<TelaPlanejamentoCanteiro> createState() =>
      _TelaPlanejamentoCanteiroState();
}

class _TelaPlanejamentoCanteiroState extends State<TelaPlanejamentoCanteiro> {
  User? get _user => FirebaseAuth.instance.currentUser;

  // seleção
  String? _canteiroId;
  String _nomeCanteiro = '';
  double _areaM2 = 0;
  double? _larguraM;
  double? _comprimentoM;

  // filtros
  String _regiao = 'Sudeste';
  String _mes = 'Fevereiro';

  // cultura
  final _buscaCtrl = TextEditingController();
  String? _culturaSelecionada;

  // dimensões manuais (fallback)
  final _larguraCtrl = TextEditingController();
  final _comprimentoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.canteiroIdOrigem != null) {
      _canteiroId = widget.canteiroIdOrigem;
      _carregarCanteiro(widget.canteiroIdOrigem!);
    }
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    _larguraCtrl.dispose();
    _comprimentoCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {Color? cor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    final s = v.toString().trim().replaceAll(',', '.');
    return double.tryParse(s) ?? 0;
  }

  String _fmt(num v, {int dec = 2}) =>
      v.toStringAsFixed(dec).replaceAll('.', ',');

  /// ✅ Carrega tanto o padrão novo (largura/comprimento) quanto o legado (_m)
  Future<void> _carregarCanteiro(String id) async {
    final user = _user;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('canteiros')
          .doc(id)
          .get();
      if (!doc.exists || !mounted) return;

      final data = doc.data() ?? {};
      final uid = (data['uid_usuario'] ?? '').toString();
      if (uid.isNotEmpty && uid != user.uid) return;

      final nome = (data['nome'] ?? 'Canteiro').toString();

      // área (se não existir, tenta recalcular pelas dimensões)
      final area = _toDouble(data['area_m2']);

      // ✅ lê largura/comprimento, e cai pro _m se for o que existir
      final largura = data.containsKey('largura')
          ? _toDouble(data['largura'])
          : (data.containsKey('largura_m')
              ? _toDouble(data['largura_m'])
              : 0.0);

      final comp = data.containsKey('comprimento')
          ? _toDouble(data['comprimento'])
          : (data.containsKey('comprimento_m')
              ? _toDouble(data['comprimento_m'])
              : 0.0);

      final areaFinal = (area > 0)
          ? area
          : ((largura > 0 && comp > 0) ? (largura * comp) : 0.0);

      setState(() {
        _canteiroId = id;
        _nomeCanteiro = nome;

        _larguraM = largura > 0 ? largura : null;
        _comprimentoM = comp > 0 ? comp : null;

        _areaM2 = areaFinal;

        _larguraCtrl.text = _larguraM != null ? _fmt(_larguraM!, dec: 2) : '';
        _comprimentoCtrl.text =
            _comprimentoM != null ? _fmt(_comprimentoM!, dec: 2) : '';
      });
    } catch (e) {
      _snack('Erro ao carregar canteiro: $e', cor: Colors.red);
    }
  }

  CulturaInfo? get _infoSelecionada {
    final nome = _culturaSelecionada;
    if (nome == null) return null;
    return getCulturaInfo(nome);
  }

  double? _larguraFinal() {
    if (_larguraM != null && _larguraM! > 0) return _larguraM;
    final t = _larguraCtrl.text.trim().replaceAll(',', '.');
    final v = double.tryParse(t);
    if (v == null || v <= 0) return null;
    return v;
  }

  double? _comprimentoFinal() {
    if (_comprimentoM != null && _comprimentoM! > 0) return _comprimentoM;
    final t = _comprimentoCtrl.text.trim().replaceAll(',', '.');
    final v = double.tryParse(t);
    if (v == null || v <= 0) return null;
    return v;
  }

  List<String> _uniqueList(Iterable<String> list) {
    final set = <String>{};
    final out = <String>[];
    for (final s in list) {
      final k = s.trim();
      if (k.isEmpty) continue;
      if (set.add(k)) out.add(k);
    }
    return out;
  }

  // cálculo “plano” por dimensões
  ({int linhas, int plantasPorLinha, int total}) _planoPorDimensoes(
      CulturaInfo info) {
    final larg = _larguraFinal();
    final comp = _comprimentoFinal();

    if (larg == null || comp == null || larg <= 0 || comp <= 0) {
      return (linhas: 0, plantasPorLinha: 0, total: 0);
    }

    final linhas = (larg / info.espacamentoLinhaM).floor();
    final porLinha = (comp / info.espacamentoPlantaM).floor();
    final total = (linhas * porLinha);

    return (
      linhas: linhas < 0 ? 0 : linhas,
      plantasPorLinha: porLinha < 0 ? 0 : porLinha,
      total: total < 0 ? 0 : total
    );
  }

  bool _ehForaDeEpoca(List<String> recomendadas, String cultura) {
    return !recomendadas.contains(cultura);
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) {
      return PageContainer(
        title: 'Planejamento do Canteiro',
        child: const SectionCard(
          title: 'Login necessário',
          subtitle: 'Você precisa estar logado pra puxar seus canteiros.',
          child: Text('Faça login e volte aqui.'),
        ),
      );
    }

    final regioes = calendarioRegional.keys.toList()..sort();
    final mesesDisponiveis = (calendarioRegional[_regiao]?.keys.toList() ?? [])
      ..sort();
    if (!mesesDisponiveis.contains(_mes) && mesesDisponiveis.isNotEmpty) {
      _mes = mesesDisponiveis.first;
    }

    final recomendadas = _uniqueList(culturasPorRegiaoMes(_regiao, _mes));
    final todasCulturas = (guiaCompleto.keys.toList()..sort());
    final foraDeEpoca =
        todasCulturas.where((c) => !recomendadas.contains(c)).toList();

    // busca (dedup p/ não explodir Dropdown)
    final resultadosBusca = _uniqueList(buscarCulturas(_buscaCtrl.text));

    final info = _infoSelecionada;

    final qtdPorArea = (info != null && _areaM2 > 0)
        ? info.estimarQtdPlantasPorArea(_areaM2)
        : 0;
    final planoDim = (info != null)
        ? _planoPorDimensoes(info)
        : (linhas: 0, plantasPorLinha: 0, total: 0);

    final selecionada = _culturaSelecionada;
    final selecionadaFora = (selecionada != null)
        ? _ehForaDeEpoca(recomendadas, selecionada)
        : false;

    return PageContainer(
      title: 'Planejamento do Canteiro',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: '1) Selecione o canteiro',
            subtitle:
                'Puxa área automaticamente. Se existir largura/comprimento, usa também.',
            child: _CanteiroPicker(
              selectedId: _canteiroId,
              onSelect: (id) async {
                await _carregarCanteiro(id);
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Dados do canteiro',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _linha('Nome', _nomeCanteiro.isEmpty ? '—' : _nomeCanteiro),
                _linha('Área', _areaM2 > 0 ? '${_fmt(_areaM2)} m²' : '—'),
                const SizedBox(height: 10),
                const Text(
                  'Dimensões (opcional, melhora o “plano em linhas”)',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _larguraCtrl,
                        label: 'Largura (m)',
                        hint: 'Ex: 1,20',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9\.,]')),
                          LengthLimitingTextInputFormatter(8),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppTextField(
                        controller: _comprimentoCtrl,
                        label: 'Comprimento (m)',
                        hint: 'Ex: 4,00',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9\.,]')),
                          LengthLimitingTextInputFormatter(8),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Dica: salvando aqui, “Meus canteiros” passa a mostrar certinho.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '2) Região e mês',
            subtitle: 'Pra mostrar sugestões do calendário.',
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _regiao,
                  decoration: const InputDecoration(
                    labelText: 'Região',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                  items: regioes
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setState(() => _regiao = v ?? 'Sudeste'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _mes,
                  decoration: const InputDecoration(
                    labelText: 'Mês',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  items: mesesDisponiveis
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setState(() => _mes = v ?? _mes),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '3) Escolha a cultura',
            subtitle:
                'Recomendadas do mês + opção de escolher fora de época com alerta.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (recomendadas.isNotEmpty) ...[
                  Text('✅ Recomendadas: $_regiao • $_mes',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: recomendadas.map((nome) {
                      final sel = _culturaSelecionada == nome;
                      return ChoiceChip(
                        selected: sel,
                        label: Text(nome),
                        onSelected: (_) =>
                            setState(() => _culturaSelecionada = nome),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                // ✅ Fora de época (colapsável, igual a ideia do seu print)
                Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    leading: const Icon(Icons.warning_amber_rounded),
                    title: const Text(
                      'Outras Culturas (Fora de Época)',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Pode escolher também, mas o sistema vai te alertar que não é o mês ideal.',
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: foraDeEpoca.take(60).map((nome) {
                          final sel = _culturaSelecionada == nome;
                          return ChoiceChip(
                            selected: sel,
                            label: Text(nome),
                            onSelected: (_) =>
                                setState(() => _culturaSelecionada = nome),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 14),

                AppTextField(
                  controller: _buscaCtrl,
                  label: 'Buscar cultura',
                  hint: 'Ex: Alface, Tomate, Berinjela…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _buscaCtrl.clear();
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: (resultadosBusca.contains(_culturaSelecionada)
                      ? _culturaSelecionada
                      : null),
                  decoration: const InputDecoration(
                    labelText: 'Resultado da busca',
                    prefixIcon: Icon(Icons.eco_outlined),
                  ),
                  items: resultadosBusca
                      .take(60)
                      .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                      .toList(),
                  onChanged: (v) => setState(() => _culturaSelecionada = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Resultado / Plano',
            subtitle:
                'Estimativa rápida + plano por linhas (se tiver dimensões).',
            child: info == null
                ? Text(
                    'Escolha uma cultura acima pra calcular.',
                    style: TextStyle(color: Colors.grey.shade700),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (selecionadaFora) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.orange.withOpacity(0.25)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Atenção: ${info.nome} está FORA DE ÉPOCA em $_regiao • $_mes. Dá pra plantar, mas o risco de desempenho é maior.',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _linha('Cultura', info.nome),
                      _linha('Categoria', info.categoria),
                      _linha('Ciclo', '${info.cicloDias} dias'),
                      _linha('Espaçamento',
                          '${info.espacamentoLinhaM} m (linhas) x ${info.espacamentoPlantaM} m (plantas)'),
                      const SizedBox(height: 10),
                      Divider(color: Colors.grey.shade200),
                      const SizedBox(height: 10),
                      _linha(
                          'Estimativa por área',
                          _areaM2 > 0
                              ? '~ $qtdPorArea plantas'
                              : 'Defina um canteiro válido'),
                      _linha(
                        'Plano por dimensões',
                        (planoDim.total > 0)
                            ? '${planoDim.linhas} linhas x ${planoDim.plantasPorLinha} por linha = ${planoDim.total}'
                            : 'Preencha largura/comprimento pra esse modo',
                      ),
                      const SizedBox(height: 12),
                      if (planoDim.total > 0)
                        _PlantPreviewGrid(
                            rows: planoDim.linhas,
                            cols: planoDim.plantasPorLinha),
                      const SizedBox(height: 12),

                      // ✅ AQUI é o ponto: salvar no padrão que o resto do app lê
                      AppButton(
                        text: 'SALVAR LARGURA/COMPRIMENTO NO CANTEIRO',
                        icon: Icons.save,
                        onPressed: (_canteiroId == null)
                            ? null
                            : () async {
                                final larg = _larguraFinal();
                                final comp = _comprimentoFinal();
                                if (larg == null ||
                                    comp == null ||
                                    larg <= 0 ||
                                    comp <= 0) {
                                  _snack(
                                      'Preencha largura e comprimento com valores válidos.',
                                      cor: Colors.red);
                                  return;
                                }

                                try {
                                  final area = double.parse(
                                      (larg * comp).toStringAsFixed(3));
                                  final ref = FirebaseFirestore.instance
                                      .collection('canteiros')
                                      .doc(_canteiroId);

                                  await ref.set({
                                    // ✅ padrão “principal” (Meus Canteiros / Detalhes)
                                    'largura':
                                        double.parse(larg.toStringAsFixed(2)),
                                    'comprimento':
                                        double.parse(comp.toStringAsFixed(2)),
                                    'area_m2': area,

                                    // ✅ compat (legado / outras telas)
                                    'largura_m':
                                        double.parse(larg.toStringAsFixed(2)),
                                    'comprimento_m':
                                        double.parse(comp.toStringAsFixed(2)),

                                    // ✅ metadados (mantém o padrão do app sem quebrar nada)
                                    'data_atualizacao':
                                        FieldValue.serverTimestamp(),

                                    // ✅ já deixa o planejamento salvo junto (pra virar “top” depois)
                                    if (_culturaSelecionada != null)
                                      'planejamento_atual': {
                                        'regiao': _regiao,
                                        'mes': _mes,
                                        'cultura': _culturaSelecionada,
                                        'qtd_por_area': qtdPorArea,
                                        'linhas': planoDim.linhas,
                                        'por_linha': planoDim.plantasPorLinha,
                                        'total_dim': planoDim.total,
                                        'criado_em':
                                            FieldValue.serverTimestamp(),
                                        'fora_de_epoca': selecionadaFora,
                                      },
                                  }, SetOptions(merge: true));

                                  // atualiza estado local na hora
                                  setState(() {
                                    _larguraM = larg;
                                    _comprimentoM = comp;
                                    _areaM2 = area;
                                  });

                                  _snack('✅ Dimensões salvas no canteiro!',
                                      cor: Colors.green);
                                } catch (e) {
                                  _snack('Erro ao salvar dimensões: $e',
                                      cor: Colors.red);
                                }
                              },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _linha(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
              child: Text(k, style: TextStyle(color: Colors.grey.shade700))),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _CanteiroPicker extends StatelessWidget {
  final String? selectedId;
  final void Function(String id) onSelect;

  const _CanteiroPicker({required this.onSelect, this.selectedId});

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    final s = v.toString().trim().replaceAll(',', '.');
    return double.tryParse(s) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Text('Faça login.');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('canteiros')
          .where('uid_usuario', isEqualTo: user.uid)
          .where('ativo', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text('Erro ao carregar canteiros: ${snap.error}');
        }
        if (!snap.hasData) return const LinearProgressIndicator();

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Text('Nenhum canteiro ativo. Crie um primeiro.');
        }

        return DropdownButtonFormField<String>(
          value: selectedId,
          decoration: const InputDecoration(
            labelText: 'Canteiro',
            prefixIcon: Icon(Icons.place),
          ),
          items: docs.map((d) {
            final data = (d.data() as Map<String, dynamic>? ?? {});
            final nome = (data['nome'] ?? 'Canteiro').toString();

            // tenta area_m2, senão recalcula do que tiver
            final area = _toDouble(data['area_m2']);
            final larg = data.containsKey('largura')
                ? _toDouble(data['largura'])
                : _toDouble(data['largura_m']);
            final comp = data.containsKey('comprimento')
                ? _toDouble(data['comprimento'])
                : _toDouble(data['comprimento_m']);

            final areaFinal = (area > 0)
                ? area
                : ((larg > 0 && comp > 0) ? (larg * comp) : 0);

            return DropdownMenuItem(
              value: d.id,
              child: Text('$nome (${areaFinal.toStringAsFixed(2)} m²)'),
            );
          }).toList(),
          onChanged: (id) {
            if (id == null) return;
            onSelect(id);
          },
        );
      },
    );
  }
}

class _PlantPreviewGrid extends StatelessWidget {
  final int rows;
  final int cols;

  const _PlantPreviewGrid({required this.rows, required this.cols});

  @override
  Widget build(BuildContext context) {
    // Limites pra não travar a UI
    final r = rows.clamp(1, 10);
    final c = cols.clamp(1, 14);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Visual (simplificado): ${r}x${c} (limitado)',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Column(
            children: List.generate(r, (_) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(c, (_) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.65),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
