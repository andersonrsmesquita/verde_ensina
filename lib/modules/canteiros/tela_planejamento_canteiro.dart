import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ui/app_ui.dart';
import '../../core/firebase/firebase_paths.dart';
import '../../core/session/session_scope.dart';
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

  bool _salvandoDim = false;

  @override
  void initState() {
    super.initState();

    _buscaCtrl.addListener(() {
      if (mounted) setState(() {});
    });

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

  // =========================
  // Helpers
  // =========================
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

  CulturaInfo? get _infoSelecionada {
    final nome = _culturaSelecionada;
    if (nome == null) return null;
    return getCulturaInfo(nome);
  }

  double? _parsePositive(String text) {
    final t = text.trim().replaceAll(',', '.');
    final v = double.tryParse(t);
    if (v == null || v <= 0) return null;
    return v;
  }

  double? _larguraFinal() {
    if (_larguraM != null && _larguraM! > 0) return _larguraM;
    return _parsePositive(_larguraCtrl.text);
  }

  double? _comprimentoFinal() {
    if (_comprimentoM != null && _comprimentoM! > 0) return _comprimentoM;
    return _parsePositive(_comprimentoCtrl.text);
  }

  // =========================
  // Canteiro
  // =========================
  Future<void> _carregarCanteiro(String id) async {
    final user = _user;
    if (user == null) return;

    try {
      final appSession = SessionScope.of(context).session;
      if (appSession == null) return;

      final doc = await FirebasePaths.canteirosCol(appSession.tenantId)
          .doc(id)
          .get();
      if (!doc.exists || !mounted) return;

      final data = doc.data() ?? {};
      final uid = (data['uid_usuario'] ?? '').toString();
      if (uid.isNotEmpty && uid != user.uid) return;

      final nome = (data['nome'] ?? 'Canteiro').toString();
      final area = _toDouble(data['area_m2']);

      // Compat: aceita "largura/comprimento" (gerador) e "largura_m/comprimento_m" (legado)
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

      setState(() {
        _canteiroId = id;
        _nomeCanteiro = nome;
        _areaM2 = area;

        _larguraM = largura > 0 ? largura : null;
        _comprimentoM = comp > 0 ? comp : null;

        _larguraCtrl.text = _larguraM != null ? _fmt(_larguraM!, dec: 2) : '';
        _comprimentoCtrl.text =
            _comprimentoM != null ? _fmt(_comprimentoM!, dec: 2) : '';
      });
    } catch (e) {
      _snack('Erro ao carregar canteiro: $e', cor: Colors.red);
    }
  }

  // =========================
  // Plano por dimensões
  // =========================
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

  // =========================
  // Região/Mês (sem mutação no build)
  // =========================
  void _onChangeRegiao(String? v) {
    final nova = v ?? _regiao;
    final meses = (calendarioRegional[nova]?.keys.toList() ?? [])..sort();
    final novoMes =
        meses.contains(_mes) ? _mes : (meses.isNotEmpty ? meses.first : _mes);

    setState(() {
      _regiao = nova;
      _mes = novoMes;
    });
  }

  void _onChangeMes(String? v) {
    if (v == null) return;
    setState(() => _mes = v);
  }

  // =========================
  // Salvar dimensões
  // =========================
  Future<void> _salvarDimensoes() async {
    final user = _user;
    if (user == null) {
      _snack('Faça login.', cor: Colors.red);
      return;
    }
    if (_canteiroId == null) {
      _snack('Selecione um canteiro primeiro.', cor: Colors.red);
      return;
    }
    if (_salvandoDim) return;

    final larg = _larguraFinal();
    final comp = _comprimentoFinal();

    if (larg == null || comp == null || larg <= 0 || comp <= 0) {
      _snack('Preencha largura e comprimento com valores válidos.',
          cor: Colors.red);
      return;
    }

    setState(() => _salvandoDim = true);

    try {
      final appSession = SessionScope.of(context).session;
      if (appSession == null) throw Exception('Sem tenant selecionado');

      await FirebasePaths.canteirosCol(appSession.tenantId)
          .doc(_canteiroId)
          .set(
        {
          // Canon: mantém consistente com o gerador de canteiros
          'largura': double.parse(larg.toStringAsFixed(2)),
          'comprimento': double.parse(comp.toStringAsFixed(2)),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _larguraM = larg;
        _comprimentoM = comp;
      });

      _snack('✅ Dimensões salvas no canteiro!', cor: Colors.green);
    } catch (e) {
      _snack('Erro ao salvar dimensões: $e', cor: Colors.red);
    } finally {
      if (mounted) setState(() => _salvandoDim = false);
    }
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    final user = _user;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Planejamento do Canteiro')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Login necessário',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Você precisa estar logado pra puxar seus canteiros e salvar dimensões.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  AppButtons.elevatedIcon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('VOLTAR'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final regioes = calendarioRegional.keys.toList()..sort();
    final mesesDisponiveis = (calendarioRegional[_regiao]?.keys.toList() ?? [])
      ..sort();

    final sugestoesMes = culturasPorRegiaoMes(_regiao, _mes);
    final resultadosBusca = buscarCulturas(_buscaCtrl.text);

    final info = _infoSelecionada;
    final qtdPorArea = (info != null && _areaM2 > 0)
        ? info.estimarQtdPlantasPorArea(_areaM2)
        : 0;

    final planoDim = (info != null)
        ? _planoPorDimensoes(info)
        : (linhas: 0, plantasPorLinha: 0, total: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planejamento do Canteiro'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          // 1) Selecionar canteiro
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '1) Selecione o canteiro',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Puxa a área automaticamente. Se tiver largura/comprimento, usa também.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  _CanteiroPicker(
                    selectedId: _canteiroId,
                    onSelect: (id) async {
                      await _carregarCanteiro(id);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Dados do canteiro + dimensões
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Dados do canteiro',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _KeyValueRow(
                    label: 'Nome',
                    value: _nomeCanteiro.isEmpty ? '—' : _nomeCanteiro,
                  ),
                  _KeyValueRow(
                    label: 'Área',
                    value: _areaM2 > 0 ? '${_fmt(_areaM2)} m²' : '—',
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Dimensões (opcional)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Melhora o “plano por linhas”. Se você salvar, fica automático.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _larguraCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9\.,]'),
                            ),
                            LengthLimitingTextInputFormatter(8),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Largura (m)',
                            hintText: 'Ex: 1,20',
                            prefixIcon: Icon(Icons.straighten),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _comprimentoCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9\.,]'),
                            ),
                            LengthLimitingTextInputFormatter(8),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Comprimento (m)',
                            hintText: 'Ex: 4,00',
                            prefixIcon: Icon(Icons.straighten),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: AppButtons.elevatedIcon(
                      onPressed: (_canteiroId == null || _salvandoDim)
                          ? null
                          : _salvarDimensoes,
                      icon:
                          Icon(_salvandoDim ? Icons.hourglass_top : Icons.save),
                      label: Text(_salvandoDim
                          ? 'SALVANDO...'
                          : 'SALVAR DIMENSÕES NO CANTEIRO'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 2) Região e mês
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '2) Região e mês',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pra mostrar sugestões do calendário.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _regiao,
                    decoration: const InputDecoration(
                      labelText: 'Região',
                      prefixIcon: Icon(Icons.map_outlined),
                    ),
                    items: regioes
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: _onChangeRegiao,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: mesesDisponiveis.contains(_mes) ? _mes : null,
                    decoration: const InputDecoration(
                      labelText: 'Mês',
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    items: mesesDisponiveis
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: _onChangeMes,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 3) Cultura
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '3) Escolha a cultura',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pode escolher do mês ou buscar qualquer uma do guia.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  if (sugestoesMes.isNotEmpty) ...[
                    Text(
                      'Sugestões: $_regiao • $_mes',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: sugestoesMes.map((nome) {
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
                    Divider(color: Colors.black.withOpacity(0.08)),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _buscaCtrl,
                    decoration: InputDecoration(
                      labelText: 'Buscar cultura',
                      hintText: 'Ex: Alface, Tomate, Berinjela…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: (_buscaCtrl.text.trim().isEmpty)
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _buscaCtrl.clear();
                                setState(() {});
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _culturaSelecionada,
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
                  const SizedBox(height: 10),
                  Text(
                    'Dica: a busca filtra no guia inteiro.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Resultado
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: info == null
                  ? Text(
                      'Escolha uma cultura acima pra calcular.',
                      style: theme.textTheme.bodyMedium,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Resultado / Plano',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _KeyValueRow(label: 'Cultura', value: info.nome),
                        _KeyValueRow(label: 'Categoria', value: info.categoria),
                        _KeyValueRow(
                            label: 'Ciclo', value: '${info.cicloDias} dias'),
                        _KeyValueRow(
                          label: 'Espaçamento',
                          value:
                              '${info.espacamentoLinhaM} m (linhas) × ${info.espacamentoPlantaM} m (plantas)',
                        ),
                        const SizedBox(height: 12),
                        Divider(color: Colors.black.withOpacity(0.08)),
                        const SizedBox(height: 12),
                        _KeyValueRow(
                          label: 'Estimativa por área',
                          value: _areaM2 > 0
                              ? '~ $qtdPorArea plantas'
                              : 'Selecione um canteiro válido',
                        ),
                        _KeyValueRow(
                          label: 'Plano por dimensões',
                          value: (planoDim.total > 0)
                              ? '${planoDim.linhas} linhas × ${planoDim.plantasPorLinha} por linha = ${planoDim.total}'
                              : 'Preencha largura/comprimento',
                        ),
                        if (planoDim.total > 0) ...[
                          const SizedBox(height: 14),
                          _PlantPreviewGrid(
                            rows: planoDim.linhas,
                            cols: planoDim.plantasPorLinha,
                            color: scheme.primary,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),

      // Botão fixo pra “voltar” (UX mais limpa)
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SizedBox(
            height: 48,
            child: AppButtons.elevatedIcon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('VOLTAR'),
            ),
          ),
        ),
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

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebasePaths.canteirosCol(SessionScope.of(context).session!.tenantId)
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
            final data = d.data();
            final nome = (data['nome'] ?? 'Canteiro').toString();
            final areaM2 = _toDouble(data['area_m2']);

            return DropdownMenuItem(
              value: d.id,
              child: Text('$nome (${areaM2.toStringAsFixed(2)} m²)'),
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

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _KeyValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.black.withOpacity(0.65),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlantPreviewGrid extends StatelessWidget {
  final int rows;
  final int cols;
  final Color color;

  const _PlantPreviewGrid({
    required this.rows,
    required this.cols,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // limites pra não travar
    final r = rows.clamp(1, 10);
    final c = cols.clamp(1, 14);

    final border = color.withOpacity(0.25);
    final fill = color.withOpacity(0.08);
    final dot = color.withOpacity(0.70);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Visual (simplificado): ${r}×${c} (limitado)',
            style:
                TextStyle(color: Colors.black.withOpacity(0.65), fontSize: 12),
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
                          color: dot,
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
