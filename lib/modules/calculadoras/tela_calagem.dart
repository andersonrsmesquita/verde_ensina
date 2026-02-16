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
  bool _dadosIniciaisCarregados = false;

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
    if (v is String)
      return double.tryParse(v.trim().replaceAll(',', '.')) ?? 0.0;
    return 0.0;
  }

  double _parseCtrl(TextEditingController c, {double def = -1.0}) {
    final t = c.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return def;
    return double.tryParse(t) ?? def;
  }

  String _fmt(num v, {int dec = 2}) =>
      v.toStringAsFixed(dec).replaceAll('.', ',');

  @override
  void initState() {
    super.initState();
    if (widget.canteiroIdOrigem != null &&
        widget.canteiroIdOrigem!.isNotEmpty) {
      _canteiroSelecionadoId = widget.canteiroIdOrigem;
      _bloquearSelecaoCanteiro = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dadosIniciaisCarregados && _canteiroSelecionadoId != null) {
      final session = SessionScope.of(context).session;
      if (session != null) {
        _dadosIniciaisCarregados = true;
        _carregarDadosCanteiro(session.tenantId, _canteiroSelecionadoId!);
      }
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

  Future<void> _carregarDadosCanteiro(String tenantId, String id) async {
    if (id.isEmpty) return;
    setState(() => _carregandoCanteiro = true);

    try {
      final doc = await FirebasePaths.canteirosCol(tenantId).doc(id).get();
      if (!doc.exists || !mounted) {
        setState(() => _bloquearSelecaoCanteiro = false);
        return;
      }

      final data = doc.data() ?? {};
      double area = _toDouble(data['area_m2']);

      if (area <= 0) {
        final tipo = (data['tipo'] ?? '').toString();
        if (tipo == 'Vaso') {
          area = _toDouble(data['volume_l']) * 0.005;
        } else {
          area = _toDouble(data['comprimento']) * _toDouble(data['largura']);
        }
      }

      setState(() {
        _nomeCanteiro = (data['nome'] ?? 'Canteiro').toString();
        _areaCanteiro = area;
        _zerarResultado();
      });
    } catch (e) {
      setState(() => _bloquearSelecaoCanteiro = false);
      AppMessenger.error('Falha ao puxar os dados do lote. Escolha na lista.');
    } finally {
      if (mounted) setState(() => _carregandoCanteiro = false);
    }
  }

  void _zerarResultado() {
    setState(() {
      _resultadoGramas = null;
      _resultadoKg = null;
      _doseGramasM2 = null;
      _ncTonHa = null;
    });
  }

  String? _valNum(String? v, {double min = 0.0, double max = 999999}) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Obrigatório';
    final n = double.tryParse(t.replaceAll(',', '.'));
    if (n == null) return 'Número inválido';
    if (n < min) return 'Mínimo ${_fmt(min)}';
    if (n > max) return 'Máximo ${_fmt(max)}';
    return null;
  }

  // ✅ MOTOR DE CÁLCULO (BUG DO DUPLO CLIQUE RESOLVIDO)
  void _calcular() {
    if (_canteiroSelecionadoId == null) {
      AppMessenger.warn('Por favor, selecione um Lote/Canteiro no passo 1.');
      return;
    }

    if (_temLaudo) {
      if (!(_formKey.currentState?.validate() ?? false)) {
        AppMessenger.error('Preencha os campos obrigatórios em vermelho.');
        return;
      }
    }

    double doseGm2 = 0;
    double ncTonHa = 0;

    try {
      if (_temLaudo) {
        double v1 = _parseCtrl(_vAtualController, def: -1.0);
        double ctc = _parseCtrl(_ctcController, def: -1.0);
        double v2 = _parseCtrl(_vDesejadoController, def: -1.0);
        double prnt = _parseCtrl(_prntController, def: -1.0);

        if (v1 < 0) {
          AppMessenger.error('Preencha o V% Atual.');
          return;
        }
        if (ctc < 0) {
          AppMessenger.error('Preencha a CTC (T).');
          return;
        }
        if (v2 <= 0) {
          AppMessenger.error('O V% Alvo deve ser maior que zero.');
          return;
        }
        if (prnt <= 0) {
          AppMessenger.error('O PRNT deve ser maior que zero.');
          return;
        }

        ncTonHa = ((v2 - v1) * ctc) / prnt;
        if (ncTonHa < 0) ncTonHa = 0;
        doseGm2 = ncTonHa * 100;
      } else {
        if (_texturaEstimada == 'Argiloso') {
          doseGm2 = 250.0;
        } else {
          doseGm2 = 200.0;
        }
        ncTonHa = doseGm2 / 100;
      }

      double areaConsiderada = _areaCanteiro;
      if (areaConsiderada <= 0) {
        areaConsiderada = 1.0;
        AppMessenger.info(
            'O Lote não possui área definida. Simulando para 1 m².');
      } else {
        AppMessenger.success('Cálculo realizado com sucesso!');
      }

      final totalG = doseGm2 * areaConsiderada;
      final totalKg = totalG / 1000;

      setState(() {
        _ncTonHa = ncTonHa;
        _doseGramasM2 = doseGm2;
        _resultadoGramas = totalG;
        _resultadoKg = totalKg;
      });

      // ✅ O SEGREDO DO DUPLO CLIQUE: Descer o teclado com atraso para não cancelar o toque do botão
      Future.delayed(const Duration(milliseconds: 150), () {
        FocusManager.instance.primaryFocus?.unfocus();
      });
    } catch (e) {
      AppMessenger.error('Erro matemático no cálculo. Revise os números.');
    }
  }

  // ✅ SALVAMENTO: EXIGE QUE O USUÁRIO VEJA O CÁLCULO ANTES
  Future<void> _registrarAplicacao() async {
    final user = _user;
    if (user == null) {
      AppMessenger.error('Você precisa estar logado.');
      return;
    }

    // A regra de ouro da UX: Exigir o cálculo primeiro!
    if (_resultadoGramas == null || _canteiroSelecionadoId == null) {
      AppMessenger.warn(
          'Por favor, clique em "CALCULAR" primeiro para conferir a recomendação antes de registrar.');
      return;
    }

    setState(() => _salvando = true);

    try {
      final fs = FirebaseFirestore.instance;
      final batch = fs.batch();
      final agora = FieldValue.serverTimestamp();

      final sess = SessionScope.of(context).session;
      if (sess == null) throw Exception('Sessão inválida');

      final histRef = FirebasePaths.historicoManejoCol(sess.tenantId).doc();
      final detalhes = _temLaudo
          ? 'Correção via Laudo (Alvo V%: ${_vDesejadoController.text})'
          : 'Correção Recomendada ($_texturaEstimada)';

      batch.set(histRef, {
        'canteiro_id': _canteiroSelecionadoId,
        'uid_usuario': user.uid,
        'data': agora,
        'tipo_manejo': 'Calagem',
        'produto': 'Calcário',
        'detalhes': detalhes,
        'observacao_extra':
            'Quantidade aplicada: ${_fmt(_resultadoKg!, dec: 2)} kg',
        'concluido': true,
        'status': 'concluido',
        'estado': 'realizado',
        'createdAt': agora,
      });

      final canteiroRef =
          FirebasePaths.canteirosCol(sess.tenantId).doc(_canteiroSelecionadoId);
      batch.update(canteiroRef, {
        'updatedAt': agora,
        'data_atualizacao': agora,
        'totais_insumos.calcario_g': FieldValue.increment(_resultadoGramas!),
        'totais_insumos.aplicacoes_calagem': FieldValue.increment(1),
        'ult_manejo.tipo': 'Calagem',
        'ult_manejo.hist_id': histRef.id,
        'ult_manejo.resumo': detalhes,
        'ult_manejo.atualizadoEm': agora,
      });

      await batch.commit();

      if (!mounted) return;
      AppMessenger.success('✅ Registrado no diário do Lote como Concluído!');
      Navigator.of(context).maybePop();
    } catch (e) {
      AppMessenger.error('Falha de conexão. Tente novamente.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _mostrarAjuda(String titulo, String mensagem) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.help, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
                child: Text(titulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16))),
          ],
        ),
        content: Text(mensagem, style: const TextStyle(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ENTENDI'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appSession = SessionScope.of(context).session;
    final cs = Theme.of(context).colorScheme;

    if (appSession == null || _user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Aguardando Sessão...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Calculadora de Calagem',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: cs.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: cs.primary),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'A calagem neutraliza a acidez e fornece Cálcio e Magnésio. Sem ela, o adubo não faz efeito completo no solo.',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: '1) Local da Aplicação',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_carregandoCanteiro) const LinearProgressIndicator(),
                    if (_carregandoCanteiro) const SizedBox(height: 10),
                    if (_bloquearSelecaoCanteiro)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline,
                                color: cs.primary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _nomeCanteiro.isNotEmpty
                                    ? _nomeCanteiro
                                    : 'Carregando...',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _buildCanteiroDropdown(appSession.tenantId),
                    if (_nomeCanteiro.isNotEmpty && _areaCanteiro > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.square_foot,
                                size: 16, color: cs.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Área de correção: ${_fmt(_areaCanteiro)} m²',
                              style: TextStyle(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: '2) Dados do Solo',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: cs.primary,
                      title: const Text('Tenho Análise de Laboratório',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                          _temLaudo
                              ? 'Modo Exato (Preencher V% e CTC)'
                              : 'Modo Padrão (Sem laudo)',
                          style: const TextStyle(fontSize: 12)),
                      value: _temLaudo,
                      onChanged: (v) {
                        setState(() {
                          _temLaudo = v;
                          _zerarResultado();
                        });
                      },
                    ),
                    const Divider(),
                    const SizedBox(height: 12),
                    if (_temLaudo) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _InputComAjuda(
                              controller: _vAtualController,
                              label: 'V% Atual',
                              hint: 'Ex: 45',
                              validator: (v) => _valNum(v, min: 0, max: 100),
                              onChanged: _zerarResultado,
                              onHelp: () => _mostrarAjuda('V% Atual',
                                  'Saturação de Bases atual do solo. Procure por "V" ou "V%" no seu laudo de análise. Geralmente é um número entre 10 e 90.'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InputComAjuda(
                              controller: _ctcController,
                              label: 'CTC (T)',
                              hint: 'Ex: 7,5',
                              validator: (v) => _valNum(v, min: 0, max: 100),
                              onChanged: _zerarResultado,
                              onHelp: () => _mostrarAjuda('CTC a pH 7.0 (T)',
                                  'Capacidade de Troca Catiônica. Procure por "CTC" ou a letra "T" maiúscula no seu laudo. Ex: 7,5 ou 10,2.'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _InputComAjuda(
                              controller: _vDesejadoController,
                              label: 'V% Alvo',
                              hint: '70',
                              validator: (v) => _valNum(v, min: 0, max: 100),
                              onChanged: _zerarResultado,
                              onHelp: () => _mostrarAjuda('V% Alvo',
                                  'Saturação desejada após correção. Hortaliças: 70 a 80%. Frutíferas: ~60%. Se não souber, deixe em 70.'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InputComAjuda(
                              controller: _prntController,
                              label: 'PRNT (%)',
                              hint: '80',
                              validator: (v) => _valNum(v, min: 0, max: 100),
                              onChanged: _zerarResultado,
                              onHelp: () => _mostrarAjuda('PRNT (%)',
                                  'Poder Relativo de Neutralização Total. Está impresso na embalagem do calcário que você comprou. Padrão geral: 80%.'),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      DropdownButtonFormField<String>(
                        value: _texturaEstimada,
                        decoration: InputDecoration(
                          labelText: 'Textura do Lote',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'Arenoso',
                              child: Text('Arenoso (Leve, esfarela na mão)')),
                          DropdownMenuItem(
                              value: 'Médio',
                              child: Text('Médio (Franco, ideal)')),
                          DropdownMenuItem(
                              value: 'Argiloso',
                              child: Text('Argiloso (Pesado, vira barro)')),
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
              const SizedBox(height: 16),
              if (_resultadoGramas != null) ...[
                SectionCard(
                  title: 'Recomendação Agronômica',
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
                        '(${_fmt(_resultadoKg!, dec: 2)} kg) de Calcário Dolomítico',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info,
                                color: Colors.orange.shade800, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Aguarde cerca de 2 a 3 meses para a ação total. Na pressa, irrigue bem e revolva a terra, aguardando no mínimo 15 dias para plantar. Opcional: Misture 70g de Termofosfato/m² no dia do plantio.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade900,
                                    height: 1.3),
                              ),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
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
                      height: 52,
                      child: AppButtons.elevatedIcon(
                        onPressed: _salvando ? null : _registrarAplicacao,
                        icon: Icon(
                            _salvando ? Icons.hourglass_top : Icons.save_alt),
                        label: Text(_salvando ? 'SALVANDO...' : 'REGISTRAR'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
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
          return const Text('Nenhum lote ativo encontrado.',
              style: TextStyle(color: Colors.red));
        }

        final hasSelected = _canteiroSelecionadoId != null &&
            docs.any((d) => d.id == _canteiroSelecionadoId);
        final currentValue = hasSelected ? _canteiroSelecionadoId : null;

        return DropdownButtonFormField<String>(
          value: currentValue,
          decoration: InputDecoration(
            labelText: 'Selecione o Lote',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
          items: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final nome = (data['nome'] ?? 'Lote').toString();

            double area = _toDouble(data['area_m2']);
            if (area <= 0) {
              final tipo = (data['tipo'] ?? '').toString();
              if (tipo == 'Vaso') {
                area = _toDouble(data['volume_l']) * 0.005;
              } else {
                area =
                    _toDouble(data['comprimento']) * _toDouble(data['largura']);
              }
            }

            return DropdownMenuItem(
              value: d.id,
              child: Text('$nome (${_fmt(area)} m²)'),
            );
          }).toList(),
          onChanged: (id) {
            if (id == null) return;
            final doc = docs.firstWhere((d) => d.id == id);
            final data = doc.data() as Map<String, dynamic>;

            double area = _toDouble(data['area_m2']);
            if (area <= 0) {
              final tipo = (data['tipo'] ?? '').toString();
              if (tipo == 'Vaso') {
                area = _toDouble(data['volume_l']) * 0.005;
              } else {
                area =
                    _toDouble(data['comprimento']) * _toDouble(data['largura']);
              }
            }

            setState(() {
              _canteiroSelecionadoId = id;
              _nomeCanteiro = (data['nome'] ?? 'Lote').toString();
              _areaCanteiro = area;
              _zerarResultado();
            });
          },
        );
      },
    );
  }
}

class _InputComAjuda extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  final VoidCallback onChanged;
  final VoidCallback onHelp;

  const _InputComAjuda({
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
    required this.onChanged,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]'))],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
        suffixIcon: IconButton(
          icon: const Icon(Icons.help_outline, size: 20),
          color: Colors.blue.shade300,
          onPressed: onHelp,
        ),
      ),
      validator: validator,
      onChanged: (_) => onChanged(),
    );
  }
}
