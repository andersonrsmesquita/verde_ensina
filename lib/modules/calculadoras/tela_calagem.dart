import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/ui/app_ui.dart';
import '../../core/ui/widgets/page_container.dart';
import '../../core/ui/widgets/section_card.dart';
import '../../core/ui/widgets/app_button.dart';
import '../../core/ui/widgets/app_text_field.dart';

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
      _carregarDadosCanteiro(widget.canteiroIdOrigem!);
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
      final doc = await FirebaseFirestore.instance
          .collection('canteiros')
          .doc(id)
          .get();
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

  void _calcular() {
    FocusScope.of(context).unfocus();

    if (_canteiroSelecionadoId == null || _areaCanteiro <= 0) {
      AppMessenger.warn('Selecione um canteiro válido (área > 0).');
      return;
    }

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    double v1, v2, ctc, prnt;

    if (_temLaudo) {
      v1 = _parseCtrl(_vAtualController);
      ctc = _parseCtrl(_ctcController);
    } else {
      v1 = 40; // estimativa conservadora
      if (_texturaEstimada == 'Arenoso') {
        ctc = 6.0;
      } else if (_texturaEstimada == 'Argiloso') {
        ctc = 9.0;
      } else {
        ctc = 7.5;
      }
    }

    v2 = _parseCtrl(_vDesejadoController, def: 70);
    prnt = _parseCtrl(_prntController, def: 80);

    // clamp
    v2 = v2.clamp(0, 100);
    prnt = prnt.clamp(1, 100);

    double ncTonHa = ((v2 - v1) * ctc) / prnt;
    if (ncTonHa < 0) ncTonHa = 0;

    // 1 t/ha = 100 g/m²
    final doseGm2 = ncTonHa * 100;
    final totalG = doseGm2 * _areaCanteiro;
    final totalKg = totalG / 1000;

    setState(() {
      _ncTonHa = ncTonHa;
      _doseGramasM2 = doseGm2;
      _resultadoGramas = totalG;
      _resultadoKg = totalKg;
    });
  }

  Future<void> _registrarAplicacao() async {
    final user = _user;
    if (user == null) {
      AppMessenger.error('Faça login para registrar.');
      return;
    }

    if (_resultadoGramas == null ||
        _doseGramasM2 == null ||
        _ncTonHa == null ||
        _canteiroSelecionadoId == null) {
      AppMessenger.warn('Calcule antes de registrar.');
      return;
    }

    setState(() => _salvando = true);

    try {
      final fs = FirebaseFirestore.instance;
      final batch = fs.batch();
      final agora = FieldValue.serverTimestamp();

      final vAtual = _temLaudo ? _parseCtrl(_vAtualController) : 40.0;
      final ctc = _temLaudo
          ? _parseCtrl(_ctcController)
          : (_texturaEstimada == 'Arenoso'
              ? 6.0
              : _texturaEstimada == 'Argiloso'
                  ? 9.0
                  : 7.5);
      final vMeta = _parseCtrl(_vDesejadoController, def: 70);
      final prnt = _parseCtrl(_prntController, def: 80);

      final histRef = fs.collection('historico_manejo').doc();

      final detalhes = _temLaudo
          ? 'Via Laudo Técnico'
          : 'Via Estimativa Manual ($_texturaEstimada)';

      final totalG = double.parse(_resultadoGramas!.toStringAsFixed(2));
      final totalKg = double.parse((_resultadoKg ?? 0).toStringAsFixed(3));
      final dose = double.parse(_doseGramasM2!.toStringAsFixed(2));
      final nc = double.parse(_ncTonHa!.toStringAsFixed(3));

      batch.set(histRef, {
        'uid_usuario': user.uid,
        'canteiro_id': _canteiroSelecionadoId,
        'nome_canteiro': _nomeCanteiro,
        'data': agora,
        'tipo_manejo': 'Calagem',
        'produto': 'Calcário',
        'quantidade_g': totalG,
        'quantidade_kg': totalKg,
        'dose_g_m2': dose,
        'nc_ton_ha': nc,
        'parametros': {
          'tem_laudo': _temLaudo,
          'textura_estimada': _temLaudo ? null : _texturaEstimada,
          'v_atual': double.parse(vAtual.toStringAsFixed(2)),
          'v_meta': double.parse(vMeta.toStringAsFixed(2)),
          'ctc_t': double.parse(ctc.toStringAsFixed(2)),
          'prnt': double.parse(prnt.toStringAsFixed(2)),
          'area_m2': double.parse(_areaCanteiro.toStringAsFixed(2)),
        },
        'detalhes': detalhes,
        'concluido': true,
        'createdAt': agora,
        'updatedAt': agora,
        'origem': 'calagem',
      });

      // atualiza o canteiro (merge)
      final canteiroRef =
          fs.collection('canteiros').doc(_canteiroSelecionadoId);
      batch.set(
          canteiroRef,
          {
            'updatedAt': agora,
            'data_atualizacao': agora,
            'totais_insumos': {
              'calcario_g': FieldValue.increment(totalG),
              'aplicacoes_calagem': FieldValue.increment(1),
            },
            'ult_manejo': {
              'tipo': 'Calagem',
              'hist_id': histRef.id,
              'resumo': detalhes,
              'atualizadoEm': agora,
            },
          },
          SetOptions(merge: true));

      await batch.commit();

      if (!mounted) return;
      AppMessenger.success('Aplicação registrada no Caderno de Campo! 📖✅');
      Navigator.pop(context);
    } catch (e) {
      AppMessenger.error('Erro ao registrar: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) {
      return const PageContainer(
        title: 'Calagem',
        child: Center(child: Text('Faça login para usar a calagem.')),
      );
    }

    return PageContainer(
      title: 'Calculadora de Calagem',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            SectionCard(
              title: 'Como usar',
              subtitle:
                  'Com laudo (melhor) ou estimativa por textura (cautela).',
              child: Row(
                children: const [
                  Icon(Icons.info_outline),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Se tiver laudo, preencha V% atual e CTC (T). Se não tiver, selecione a textura do solo.',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, height: 1.2),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '1) Local da aplicação',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_carregandoCanteiro) const LinearProgressIndicator(),
                  const SizedBox(height: 10),
                  if (_bloquearSelecaoCanteiro)
                    _canteiroTravado()
                  else
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('canteiros')
                          .where('uid_usuario', isEqualTo: user.uid)
                          .where('ativo', isEqualTo: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text(
                              'Erro ao carregar canteiros: ${snapshot.error}');
                        }
                        if (!snapshot.hasData)
                          return const LinearProgressIndicator();

                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) {
                          return const Text(
                              'Nenhum canteiro ativo. Crie um primeiro.');
                        }

                        final hasSelected = _canteiroSelecionadoId != null &&
                            docs.any((d) => d.id == _canteiroSelecionadoId);
                        final currentValue =
                            hasSelected ? _canteiroSelecionadoId : null;

                        if (!hasSelected && _canteiroSelecionadoId != null) {
                          // evita assert do dropdown quando o item some da lista
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            setState(() {
                              _canteiroSelecionadoId = null;
                              _nomeCanteiro = '';
                              _areaCanteiro = 0;
                              _zerarResultado();
                            });
                          });
                        }

                        return DropdownButtonFormField<String>(
                          value: currentValue,
                          decoration: const InputDecoration(
                            labelText: 'Canteiro',
                            prefixIcon: Icon(Icons.place_outlined),
                          ),
                          items: docs.map((d) {
                            final data = d.data();
                            final nome =
                                (data['nome'] ?? 'Canteiro').toString();
                            final area = _toDouble(data['area_m2']);
                            return DropdownMenuItem(
                              value: d.id,
                              child: Text('$nome (${_fmt(area)} m²)'),
                            );
                          }).toList(),
                          onChanged: (id) {
                            if (id == null) return;
                            final doc = docs.firstWhere((d) => d.id == id);
                            final data = doc.data();
                            setState(() {
                              _canteiroSelecionadoId = id;
                              _nomeCanteiro =
                                  (data['nome'] ?? 'Canteiro').toString();
                              _areaCanteiro = _toDouble(data['area_m2']);
                              _zerarResultado();
                            });
                          },
                        );
                      },
                    ),
                  const SizedBox(height: 10),
                  if (_nomeCanteiro.isNotEmpty)
                    Text(
                      'Área do canteiro: ${_fmt(_areaCanteiro)} m²',
                      style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '2) Dados do solo',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tenho análise de solo'),
                    subtitle: Text(
                        _temLaudo ? 'V% e CTC (T)' : 'Estimativa por textura'),
                    value: _temLaudo,
                    onChanged: (v) {
                      setState(() {
                        _temLaudo = v;
                        _zerarResultado();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  if (_temLaudo) ...[
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField.number(
                            controller: _vAtualController,
                            label: 'V% Atual',
                            hint: 'Ex: 45',
                            validator: (v) => _valNum(v, min: 0, max: 100),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.help_outline),
                              onPressed: () => AppMessenger.info(
                                  'Procure “V%” no laudo. Ex: 45.'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppTextField.number(
                            controller: _ctcController,
                            label: 'CTC (T)',
                            hint: 'Ex: 7,5',
                            validator: (v) => _valNum(v, min: 0, max: 100),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.help_outline),
                              onPressed: () => AppMessenger.info(
                                  'Procure “CTC” ou “T” no laudo.'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    DropdownButtonFormField<String>(
                      value: _texturaEstimada,
                      decoration: const InputDecoration(
                        labelText: 'Textura estimada',
                        prefixIcon: Icon(Icons.grass_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'Arenoso',
                            child: Text('Arenoso (Esfarela)')),
                        DropdownMenuItem(
                            value: 'Médio', child: Text('Médio / Franco')),
                        DropdownMenuItem(
                            value: 'Argiloso', child: Text('Argiloso (Barro)')),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _texturaEstimada = v ?? 'Médio';
                          _zerarResultado();
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '⚠️ Estimativa baseada em média. Use com cautela.',
                      style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '3) Parâmetros',
              child: Row(
                children: [
                  Expanded(
                    child: AppTextField.number(
                      controller: _vDesejadoController,
                      label: 'V% Meta',
                      hint: '70',
                      validator: (v) => _valNum(v, min: 0, max: 100),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField.number(
                      controller: _prntController,
                      label: 'PRNT (%)',
                      hint: '80',
                      validator: (v) => _valNum(v, min: 0, max: 100),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppButton.primary(
              label: 'CALCULAR QUANTIDADE',
              icon: Icons.calculate_outlined,
              onPressed: _calcular,
            ),
            if (_resultadoGramas != null) ...[
              const SizedBox(height: 14),
              _resultadoCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _canteiroTravado() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _nomeCanteiro.isNotEmpty
                  ? '$_nomeCanteiro (${_fmt(_areaCanteiro)} m²)'
                  : 'Carregando canteiro...',
              style: const TextStyle(fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultadoCard() {
    final g = _resultadoGramas ?? 0;
    final kg = _resultadoKg ?? 0;
    final dose = _doseGramasM2 ?? 0;
    final nc = _ncTonHa ?? 0;

    return SectionCard(
      title: 'Recomendação',
      subtitle: 'Isso aqui já vai pro Caderno de Campo quando você confirmar.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  '${g.toStringAsFixed(0)} g',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: Colors.green.shade800,
                  ),
                ),
                Text(
                  '(${_fmt(kg, dec: 2)} kg) de calcário',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 12),
          _row('Local', _nomeCanteiro),
          _row('Área', '${_fmt(_areaCanteiro)} m²'),
          _row('Dose', '${_fmt(dose)} g/m²'),
          _row('NC', '${_fmt(nc, dec: 3)} t/ha'),
          const SizedBox(height: 12),
          AppButton.primary(
            label: 'CONFIRMAR APLICAÇÃO',
            icon: Icons.save_alt,
            loading: _salvando,
            onPressed: _registrarAplicacao,
          ),
          const SizedBox(height: 10),
          AppButton.secondary(
            label: 'RECALCULAR / AJUSTAR',
            icon: Icons.refresh,
            onPressed: () => setState(_zerarResultado),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) {
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
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
