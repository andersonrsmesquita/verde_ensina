// FILE: lib/modules/calculadoras/tela_calagem.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/ui/app_ui.dart';
import '../../core/firebase/firebase_paths.dart';
import '../../core/session/session_scope.dart';

class TelaCalagem extends StatefulWidget {
  final String? canteiroIdOrigem;

  const TelaCalagem({super.key, this.canteiroIdOrigem});

  @override
  State<TelaCalagem> createState() => _TelaCalagemState();
}

class _TelaCalagemState extends State<TelaCalagem> {
  User? get _user => FirebaseAuth.instance.currentUser;

  final _formKey = GlobalKey<FormState>();

  bool _temLaudo = true;
  bool _salvando = false;
  bool _carregandoCanteiro = false;

  String? _canteiroSelecionadoId;
  double _areaCanteiro = 0;
  String _nomeCanteiro = "";
  bool _bloquearSelecaoCanteiro = false;

  String _texturaEstimada = 'Médio';

  final _vAtualController = TextEditingController();
  final _vDesejadoController = TextEditingController(text: '70');
  final _ctcController = TextEditingController();
  final _prntController = TextEditingController(text: '80');

  double? _resultadoGramas;
  double? _resultadoKg;
  double? _doseGramasM2;
  double? _ncTonHa;

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
    return 0.0;
  }

  double _parseCtrl(TextEditingController c, {double def = 0}) {
    final t = c.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return def;
    return double.tryParse(t) ?? def;
  }

  String _fmt(num v, {int dec = 2}) =>
      v.toStringAsFixed(dec).replaceAll('.', ',');

  @override
  void initState() {
    super.initState();
    if (widget.canteiroIdOrigem != null) {
      _canteiroSelecionadoId = widget.canteiroIdOrigem;
      _bloquearSelecaoCanteiro = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _carregarDadosCanteiro(widget.canteiroIdOrigem!);
      });
    }
  }

  @override
  void dispose() {
    _vAtualController.dispose();
    _vDesejadoController.dispose();
    _ctcController.dispose();
    _prntController.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosCanteiro(String id) async {
    final user = _user;
    if (user == null) return;

    setState(() => _carregandoCanteiro = true);

    try {
      final sess = SessionScope.of(context).session;
      if (sess == null) return;

      final doc = await FirebasePaths.canteirosCol(sess.tenantId).doc(id).get();
      if (!doc.exists || !mounted) return;

      final data = doc.data() ?? {};
      final uid = (data['uid_usuario'] ?? '').toString();
      if (uid.isNotEmpty && uid != user.uid) return;

      setState(() {
        _nomeCanteiro = (data['nome'] ?? 'Canteiro').toString();
        _areaCanteiro = _toDouble(data['area_m2']);
        _zerarResultado();
      });
    } catch (e) {
      AppMessenger.error('Erro ao carregar canteiro: $e');
    } finally {
      if (mounted) setState(() => _carregandoCanteiro = false);
    }
  }

  void _zerarResultado() {
    _resultadoGramas = null;
    _resultadoKg = null;
    _doseGramasM2 = null;
    _ncTonHa = null;
  }

  String? _valNum(String? v, {double min = 0.0, double max = 999999}) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Obrigatório';
    final n = double.tryParse(t.replaceAll(',', '.'));
    if (n == null) return 'Número inválido';
    if (n <= min) return 'Precisa ser > ${_fmt(min)}';
    if (n > max) return 'Máximo ${_fmt(max)}';
    return null;
  }

  // 🔥 INTELIGÊNCIA AGRONÔMICA APLICADA
  void _calcular() {
    FocusScope.of(context).unfocus();

    if (_canteiroSelecionadoId == null || _areaCanteiro <= 0) {
      AppMessenger.warn('Selecione um canteiro válido (área > 0).');
      return;
    }

    if (_temLaudo) {
      final ok = _formKey.currentState?.validate() ?? false;
      if (!ok) return;
    }

    double doseGm2 = 0;
    double ncTonHa = 0;

    if (_temLaudo) {
      // Cálculo exato por Análise Química
      double v1 = _parseCtrl(_vAtualController);
      double ctc = _parseCtrl(_ctcController);
      double v2 = _parseCtrl(_vDesejadoController, def: 70).clamp(0, 100);
      double prnt = _parseCtrl(_prntController, def: 80).clamp(1, 100);

      ncTonHa = ((v2 - v1) * ctc) / prnt;
      if (ncTonHa < 0) ncTonHa = 0;
      doseGm2 = ncTonHa * 100; // 1 t/ha = 100 g/m²
    } else {
      // Regra de Ouro (E-book Organo15 - Sem Laudo)
      if (_texturaEstimada == 'Argiloso') {
        doseGm2 = 250.0;
      } else {
        doseGm2 = 200.0;
      }
      ncTonHa = doseGm2 / 100; // Equivalência
    }

    final totalG = doseGm2 * _areaCanteiro;
    final totalKg = totalG / 1000;

    setState(() {
      _ncTonHa = ncTonHa;
      _doseGramasM2 = doseGm2;
      _resultadoGramas = totalG;
      _resultadoKg = totalKg;
    });

    AppMessenger.success('Cálculo realizado! Verifique a recomendação.');
  }

  Future<void> _registrarAplicacao() async {
    final user = _user;
    if (user == null) {
      AppMessenger.error('Faça login para registrar.');
      return;
    }

    if (_resultadoGramas == null || _canteiroSelecionadoId == null) {
      AppMessenger.warn('Calcule antes de registrar.');
      return;
    }

    if (_salvando) return;
    setState(() => _salvando = true);

    try {
      final fs = FirebaseFirestore.instance;
      final batch = fs.batch();
      final agora = FieldValue.serverTimestamp();

      final vAtual = _temLaudo ? _parseCtrl(_vAtualController) : 0.0;
      final ctc = _temLaudo ? _parseCtrl(_ctcController) : 0.0;
      final vMeta = _temLaudo ? _parseCtrl(_vDesejadoController, def: 70) : 0.0;
      final prnt = _temLaudo ? _parseCtrl(_prntController, def: 80) : 0.0;

      final sess = SessionScope.of(context).session;
      if (sess == null) throw Exception('Sem tenant selecionado');

      final histRef = FirebasePaths.historicoManejoCol(sess.tenantId).doc();

      final detalhes = _temLaudo
          ? 'Via Laudo Técnico (V%: $vAtual para $vMeta)'
          : 'Via Recomendação Padrão ($_texturaEstimada)';

      final totalG = double.parse(_resultadoGramas!.toStringAsFixed(2));
      final totalKg = double.parse((_resultadoKg ?? 0).toStringAsFixed(3));
      final dose = double.parse(_doseGramasM2!.toStringAsFixed(2));
      final nc = double.parse(_ncTonHa!.toStringAsFixed(3));

      final parametros = <String, dynamic>{
        'tem_laudo': _temLaudo,
        'area_m2': double.parse(_areaCanteiro.toStringAsFixed(2)),
      };

      if (_temLaudo) {
        parametros.addAll({
          'v_atual': double.parse(vAtual.toStringAsFixed(2)),
          'v_meta': double.parse(vMeta.toStringAsFixed(2)),
          'ctc_t': double.parse(ctc.toStringAsFixed(2)),
          'prnt': double.parse(prnt.toStringAsFixed(2)),
        });
      } else {
        parametros['textura_estimada'] = _texturaEstimada;
      }

      batch.set(histRef, {
        'uid_usuario': user.uid,
        'canteiro_id': _canteiroSelecionadoId,
        'nome_canteiro': _nomeCanteiro,
        'data': agora,
        'tipo_manejo': 'Calagem',
        'produto': 'Calcário Dolomítico/Calcítico',
        'quantidade_g': totalG,
        'quantidade_kg': totalKg,
        'dose_g_m2': dose,
        'nc_ton_ha': nc,
        'parametros': parametros,
        'detalhes': detalhes,
        'concluido': true,
        'createdAt': agora,
        'updatedAt': agora,
        'origem': 'calagem',
      });

      // Atualiza o canteiro
      final canteiroRef =
          FirebasePaths.canteirosCol(sess.tenantId).doc(_canteiroSelecionadoId);
      batch.set(
        canteiroRef,
        {
          'updatedAt': agora,
          'data_atualizacao': agora,
          'totais_insumos.calcario_g': FieldValue.increment(totalG),
          'totais_insumos.aplicacoes_calagem': FieldValue.increment(1),
          'ult_manejo.tipo': 'Calagem',
          'ult_manejo.hist_id': histRef.id,
          'ult_manejo.resumo': detalhes,
          'ult_manejo.atualizadoEm': agora,
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (!mounted) return;
      AppMessenger.success('✅ Calagem registrada no Caderno de Campo!');
      Navigator.of(context).maybePop();
    } catch (e) {
      AppMessenger.error('Erro ao registrar: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appSession = SessionScope.of(context).session;
    final cs = Theme.of(context).colorScheme;

    if (appSession == null || _user == null) {
      return const PageContainer(
        title: 'Calagem',
        body: Center(child: Text('Sessão inválida ou usuário não logado.')),
      );
    }

    return PageContainer(
      title: 'Calculadora de Calagem',
      subtitle: 'Corrija a acidez do seu solo',
      scroll: true,
      actions: [
        if (Navigator.canPop(context))
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Fechar',
            onPressed: () => Navigator.pop(context),
          )
      ],
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dica de Uso
            Container(
              padding: const EdgeInsets.all(AppTokens.md),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: cs.primary),
                  const SizedBox(width: AppTokens.md),
                  const Expanded(
                    child: Text(
                      'Se possuir laudo laboratorial, preencha os dados exatos. Caso contrário, faremos uma recomendação segura baseada na textura.',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: AppTokens.md),

            // 1. Seleção do Local
            SectionCard(
              title: '1) Local da Aplicação',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_carregandoCanteiro) const LinearProgressIndicator(),
                  if (_carregandoCanteiro) const SizedBox(height: 10),
                  if (_bloquearSelecaoCanteiro)
                    Container(
                      padding: const EdgeInsets.all(AppTokens.md),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline, color: cs.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _nomeCanteiro.isNotEmpty
                                  ? _nomeCanteiro
                                  : 'Carregando...',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _buildCanteiroDropdown(appSession.tenantId),
                  if (_nomeCanteiro.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Área total a corrigir: ${_fmt(_areaCanteiro)} m²',
                      style: TextStyle(
                          color: cs.primary, fontWeight: FontWeight.w800),
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(height: AppTokens.md),

            // 2. Método de Cálculo
            SectionCard(
              title: '2) Dados do Solo',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: cs.primary,
                    title: const Text('Tenho análise de laboratório',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(_temLaudo
                        ? 'Modo Exato (Preencher V% e CTC)'
                        : 'Modo Padrão (Baseado em textura)'),
                    value: _temLaudo,
                    onChanged: (v) {
                      setState(() {
                        _temLaudo = v;
                        _zerarResultado();
                      });
                    },
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  if (_temLaudo) ...[
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _vAtualController,
                            labelText: 'V% Atual',
                            hintText: 'Ex: 45',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9\.,]'))
                            ],
                            validator: (v) => _valNum(v, min: 0, max: 100),
                            onChanged: (_) => setState(() => _zerarResultado()),
                          ),
                        ),
                        const SizedBox(width: AppTokens.md),
                        Expanded(
                          child: AppTextField(
                            controller: _ctcController,
                            labelText: 'CTC (T)',
                            hintText: 'Ex: 7,5',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9\.,]'))
                            ],
                            validator: (v) => _valNum(v, min: 0, max: 100),
                            onChanged: (_) => setState(() => _zerarResultado()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.md),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _vDesejadoController,
                            labelText: 'V% Alvo',
                            hintText: '70',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9\.,]'))
                            ],
                            validator: (v) => _valNum(v, min: 0, max: 100),
                            onChanged: (_) => setState(() => _zerarResultado()),
                          ),
                        ),
                        const SizedBox(width: AppTokens.md),
                        Expanded(
                          child: AppTextField(
                            controller: _prntController,
                            labelText: 'PRNT (%)',
                            hintText: '80',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9\.,]'))
                            ],
                            validator: (v) => _valNum(v, min: 0, max: 100),
                            onChanged: (_) => setState(() => _zerarResultado()),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    DropdownButtonFormField<String>(
                      value: _texturaEstimada,
                      decoration: const InputDecoration(
                        labelText: 'Textura do Canteiro',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'Arenoso',
                            child: Text('Arenoso (Leve, esfarela)')),
                        DropdownMenuItem(
                            value: 'Médio',
                            child: Text('Médio (Franco, ideal)')),
                        DropdownMenuItem(
                            value: 'Argiloso',
                            child: Text('Argiloso (Pesado, gruda)')),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _texturaEstimada = v ?? 'Médio';
                          _zerarResultado();
                        });
                      },
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(height: AppTokens.md),

            // 3. Resultado
            if (_resultadoGramas != null) ...[
              SectionCard(
                title: 'Recomendação de Calagem',
                child: Column(
                  children: [
                    Text(
                      '${_resultadoGramas!.toStringAsFixed(0)} g',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: cs.primary,
                      ),
                    ),
                    Text(
                      '(${_fmt(_resultadoKg!, dec: 2)} kg) de Calcário',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time,
                              color: Colors.orange.shade800),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'O calcário precisa de 2 a 3 meses para reagir plenamente. Na pressa, irrigue bem e revolva a terra, aguardando no mínimo 15 dias para plantar.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.orange.shade900),
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 60), // Espaço pro botão
            ],
          ],
        ),
      ),
      bottomBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: AppButtons.outlinedIcon(
                  onPressed: _salvando ? null : _calcular,
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('CALCULAR'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: AppButtons.elevatedIcon(
                  onPressed: (_resultadoGramas == null || _salvando)
                      ? null
                      : _registrarAplicacao,
                  icon: Icon(_salvando ? Icons.hourglass_top : Icons.save_alt),
                  label: Text(_salvando ? 'SALVANDO...' : 'REGISTRAR'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanteiroDropdown(String tenantId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebasePaths.canteirosCol(tenantId)
          .where('ativo', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Text('Nenhum canteiro ativo encontrado.',
              style: TextStyle(color: Colors.red));
        }

        final hasSelected = _canteiroSelecionadoId != null &&
            docs.any((d) => d.id == _canteiroSelecionadoId);
        final currentValue = hasSelected ? _canteiroSelecionadoId : null;

        return DropdownButtonFormField<String>(
          value: currentValue,
          decoration: const InputDecoration(
            labelText: 'Selecione o Canteiro',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final nome = (data['nome'] ?? 'Canteiro').toString();
            final area = _toDouble(data['area_m2']);
            return DropdownMenuItem(
              value: d.id,
              child: Text('$nome (${_fmt(area)} m²)'),
            );
          }).toList(),
          onChanged: (id) {
            if (id == null) return;
            final doc = docs.firstWhere((d) => d.id == id);
            final data = doc.data() as Map<String, dynamic>;
            setState(() {
              _canteiroSelecionadoId = id;
              _nomeCanteiro = (data['nome'] ?? 'Canteiro').toString();
              _areaCanteiro = _toDouble(data['area_m2']);
              _zerarResultado();
            });
          },
        );
      },
    );
  }
}
