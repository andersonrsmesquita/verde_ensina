// FILE: lib/modules/solo/tela_diagnostico.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/firebase/firebase_paths.dart';
import '../../core/session/app_session.dart';
import '../../core/session/session_scope.dart';
import '../../core/ui/app_ui.dart'; // ✅ Usando a base de design premium

class TelaDiagnostico extends StatefulWidget {
  final String? canteiroIdOrigem;
  final String? culturaAtual;

  const TelaDiagnostico({super.key, this.canteiroIdOrigem, this.culturaAtual});

  @override
  State<TelaDiagnostico> createState() => _TelaDiagnosticoState();
}

class _TelaDiagnosticoState extends State<TelaDiagnostico>
    with SingleTickerProviderStateMixin {
  User? get _user => FirebaseAuth.instance.currentUser;

  AppSession? get _sessionOrNull => SessionScope.of(context).session;
  AppSession get appSession =>
      _sessionOrNull ?? (throw StateError('Sessão não inicializada'));

  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  bool _salvando = false;
  bool _carregandoCanteiro = false;

  String? _canteiroSelecionadoId;
  String _nomeCanteiro = '';
  double _areaCanteiro = 0;
  bool _bloquearSelecaoCanteiro = false;

  // --- Inteligência Agronômica Visual (Baseado no PDF) ---
  String? _texturaEstimada;
  String _sintomaLocal = 'nenhum'; // nenhum, novas, velhas, frutos
  String _sintomaAparencia = 'nenhum';

  // Pré-diagnóstico (live)
  String _previewStatus = 'neutro';
  List<String> _previewAlertas = [];
  List<String> _previewAcoes = [];

  final Map<String, Map<String, double>> _referenciaCulturas = const {
    'Alface': {'ph_min': 6.0, 'ph_max': 6.8, 'v_ideal': 70},
    'Tomate': {'ph_min': 5.5, 'ph_max': 6.8, 'v_ideal': 80},
    'Morango': {'ph_min': 5.5, 'ph_max': 6.5, 'v_ideal': 75},
    'Cenoura': {'ph_min': 5.5, 'ph_max': 6.5, 'v_ideal': 60},
    'Geral (Horta)': {'ph_min': 5.5, 'ph_max': 6.5, 'v_ideal': 70},
  };

  String _culturaSelecionada = 'Geral (Horta)';

  // Controladores do Laudo
  final _phController = TextEditingController();
  final _vPercentController = TextEditingController();
  final _moController = TextEditingController();
  final _fosforoController = TextEditingController();
  final _potassioController = TextEditingController();
  final _calcioController = TextEditingController();
  final _magnesioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (widget.culturaAtual != null &&
        _referenciaCulturas.containsKey(widget.culturaAtual)) {
      _culturaSelecionada = widget.culturaAtual!;
    }

    if (widget.canteiroIdOrigem != null) {
      _canteiroSelecionadoId = widget.canteiroIdOrigem;
      _bloquearSelecaoCanteiro = true;
      _carregarDadosCanteiro(widget.canteiroIdOrigem!);
    }

    _phController.addListener(_recalcularPreviewLaboratorio);
    _vPercentController.addListener(_recalcularPreviewLaboratorio);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phController.dispose();
    _vPercentController.dispose();
    _moController.dispose();
    _fosforoController.dispose();
    _potassioController.dispose();
    _calcioController.dispose();
    _magnesioController.dispose();
    super.dispose();
  }

  double? _parseNullable(TextEditingController controller) {
    final raw = controller.text.trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw.replaceAll(',', '.'));
  }

  String _fmt(num v, {int dec = 2}) =>
      v.toStringAsFixed(dec).replaceAll('.', ',');

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AppMessenger.error(msg);
    } else {
      AppMessenger.success(msg);
    }
  }

  Future<void> _carregarDadosCanteiro(String id) async {
    final user = _user;
    if (user == null) return;

    setState(() => _carregandoCanteiro = true);
    try {
      final doc =
          await FirebasePaths.canteirosCol(appSession.tenantId).doc(id).get();
      if (!doc.exists || !mounted) return;

      final data = doc.data() ?? {};
      setState(() {
        _nomeCanteiro = (data['nome'] ?? 'Canteiro').toString();
        _areaCanteiro =
            double.tryParse(data['area_m2']?.toString() ?? '0') ?? 0;
      });
    } catch (e) {
      _toast('Erro ao carregar canteiro: $e', isError: true);
    } finally {
      if (mounted) setState(() => _carregandoCanteiro = false);
    }
  }

  // ✅ INTELIGÊNCIA AGRONÔMICA: Chave de Diagnóstico Visual (PDF Controle Orgânico)
  void _recalcularPreviewVisual() {
    List<String> alertas = [];
    List<String> acoes = [];
    String status = 'ok';
    String sintomaFinal = 'Sem sintomas aparentes';

    if (_sintomaLocal == 'velhas') {
      status = 'atencao';
      if (_sintomaAparencia == 'amarelas') {
        alertas.add('Falta de Nitrogênio (N) ou Magnésio (Mg).');
        acoes.add('Aplicar adubo rico em N (Esterco, Bokashi).');
        sintomaFinal = 'Folhas velhas amarelas';
      } else if (_sintomaAparencia == 'roxas') {
        alertas.add('Falta de Fósforo (P).');
        acoes.add('Aplicar Farinha de Osso ou Termofosfato.');
        sintomaFinal = 'Folhas velhas arroxeadas';
      } else if (_sintomaAparencia == 'queimadas') {
        alertas.add('Falta de Potássio (K).');
        acoes.add('Aplicar Cinzas de Madeira.');
        sintomaFinal = 'Bordas queimadas nas folhas velhas';
      }
    } else if (_sintomaLocal == 'novas') {
      status = 'atencao';
      if (_sintomaAparencia == 'amarelas') {
        alertas.add('Falta de Enxofre (S), Ferro (Fe) ou Manganês (Mn).');
        acoes.add(
            'Verificar pH do solo. Pulverizar biofertilizante (Supermagro).');
        sintomaFinal = 'Folhas novas amarelas';
      } else if (_sintomaAparencia == 'queimadas') {
        alertas.add('Falta de Cálcio (Ca) ou Boro (B).');
        acoes.add('Realizar calagem ou aplicar farinha de casca de ovo.');
        sintomaFinal = 'Folhas novas deformadas/queimadas';
      }
    } else if (_sintomaLocal == 'frutos') {
      status = 'critico';
      alertas.add('Fundo preto (Falta Ca) ou Rachaduras (Falta B).');
      acoes.add('Aumentar fornecimento de Cálcio e Boro na base.');
      sintomaFinal = 'Frutos com defeito nutricional';
    }

    if (_texturaEstimada == 'Arenoso') {
      acoes.add('Solo arenoso: fracione a adubação em mais vezes.');
    } else if (_texturaEstimada == 'Argiloso') {
      acoes.add('Solo argiloso: cuidado com o excesso de água.');
    }

    if (alertas.isEmpty && _texturaEstimada == null) {
      status = 'neutro';
    }

    setState(() {
      _previewStatus = status;
      _previewAlertas = alertas;
      _previewAcoes = acoes;
    });
  }

  void _recalcularPreviewLaboratorio() {
    if (_tabController.index != 1) return;

    final ph = _parseNullable(_phController);
    final v = _parseNullable(_vPercentController);

    if (ph == null && v == null) {
      if (!mounted) return;
      setState(() {
        _previewStatus = 'neutro';
        _previewAlertas = [];
        _previewAcoes = [];
      });
      return;
    }

    final ref = _referenciaCulturas[_culturaSelecionada] ??
        _referenciaCulturas['Geral (Horta)']!;
    final alertas = <String>[];
    final acoes = <String>[];
    var status = 'ok';

    if (ph != null) {
      if (ph < (ref['ph_min'] ?? 5.5)) {
        alertas.add('Solo muito ácido (pH baixo).');
        acoes.add('Considere calagem (corrigir acidez).');
        status = 'critico';
      } else if (ph > (ref['ph_max'] ?? 6.5)) {
        alertas.add('Solo alcalino (pH alto).');
        acoes.add('Evite calagem. Ajuste matéria orgânica.');
        if (status != 'critico') status = 'atencao';
      } else {
        alertas.add('pH dentro da faixa ideal.');
      }
    }

    if (v != null) {
      final vIdeal = (ref['v_ideal'] ?? 70);
      if (v < (vIdeal - 15)) {
        alertas.add('Fertilidade baixa (V% muito baixo).');
        acoes.add('Aumentar dosagem de adubo base e calcário.');
        status = 'critico';
      } else if (v < vIdeal) {
        alertas.add('Fertilidade ok, mas abaixo do teto.');
        if (status != 'critico') status = 'atencao';
      } else {
        alertas.add('Saturação por bases (V%) excelente.');
      }
    }

    setState(() {
      _previewStatus = status;
      _previewAlertas = alertas;
      _previewAcoes = acoes;
    });
  }

  Future<void> _salvarDados() async {
    FocusScope.of(context).unfocus();
    if (_user == null) return _toast('Faça login para salvar.', isError: true);

    final canteiroId = _canteiroSelecionadoId ?? widget.canteiroIdOrigem;
    if (canteiroId == null)
      return _toast('Selecione um canteiro.', isError: true);

    if (_tabController.index == 0 && _texturaEstimada == null) {
      return _toast('Selecione a textura do solo na Etapa 1.', isError: true);
    }

    if (_tabController.index == 1 &&
        !(_formKey.currentState?.validate() ?? false)) {
      return _toast('Preencha os campos obrigatórios do laudo.', isError: true);
    }

    setState(() => _salvando = true);

    try {
      final metodo = _tabController.index == 0 ? 'manual' : 'laboratorial';
      final precisao = _tabController.index == 0 ? 'baixa' : 'alta';
      final nowServer = FieldValue.serverTimestamp();

      final dadosAnalise = <String, dynamic>{
        'uid_usuario': _user!.uid,
        'canteiro_id': canteiroId,
        'canteiro_nome': _nomeCanteiro.isEmpty ? null : _nomeCanteiro,
        'cultura_referencia': _culturaSelecionada,
        'metodo': metodo,
        'precisao': precisao,
        'createdAt': nowServer,
        'updatedAt': nowServer,
        'diagnostico': {
          'status': _previewStatus,
          'alertas': _previewAlertas,
          'acoes': _previewAcoes,
        }
      };

      String resumoHistorico = '';
      String? obsAlerta;

      if (metodo == 'manual') {
        dadosAnalise['textura_estimada'] = _texturaEstimada;
        dadosAnalise['sintoma_local'] = _sintomaLocal;
        dadosAnalise['sintoma_aparencia'] = _sintomaAparencia;

        resumoHistorico = 'Clínica Visual: Solo $_texturaEstimada.';
        if (_previewAlertas.isNotEmpty) {
          resumoHistorico += ' Diagnóstico: ${_previewAlertas.first}';
        }
      } else {
        final ph = _parseNullable(_phController)!;
        final v = _parseNullable(_vPercentController)!;

        dadosAnalise['ph'] = ph;
        dadosAnalise['v_percent'] = v;
        dadosAnalise['mo'] = _parseNullable(_moController);
        dadosAnalise['fosforo'] = _parseNullable(_fosforoController);
        dadosAnalise['potassio'] = _parseNullable(_potassioController);
        dadosAnalise['calcio'] = _parseNullable(_calcioController);
        dadosAnalise['magnesio'] = _parseNullable(_magnesioController);

        resumoHistorico =
            'Laudo de Laboratório: pH ${_fmt(ph)} | V% ${_fmt(v)}';

        if (_previewStatus == 'critico') {
          obsAlerta = '⚠️ Atenção: condição crítica do solo.';
        } else if (_previewStatus == 'ok') {
          obsAlerta = '✅ Solo em excelente condição.';
        }
      }

      final fs = FirebaseFirestore.instance;
      final batch = fs.batch();

      final analiseRef =
          FirebasePaths.analisesSoloCol(appSession.tenantId).doc();
      batch.set(analiseRef, _limparNulos(dadosAnalise));

      final historicoRef =
          FirebasePaths.historicoManejoCol(appSession.tenantId).doc();
      batch.set(
        historicoRef,
        _limparNulos({
          'canteiro_id': canteiroId,
          'uid_usuario': _user!.uid,
          'data': FieldValue.serverTimestamp(),
          'tipo_manejo': 'Análise de Solo / Clínica',
          'produto':
              metodo == 'manual' ? 'Diagnóstico Visual' : 'Laudo Químico',
          'detalhes': resumoHistorico,
          'observacao_extra': obsAlerta ?? _previewAcoes.join(', '),
          'quantidade_g': 0,
          'ref_analise_id': analiseRef.id,
          'status': _previewStatus,
        }),
      );

      final canteiroRef =
          FirebasePaths.canteirosCol(appSession.tenantId).doc(canteiroId);
      batch.set(
        canteiroRef,
        _limparNulos({
          'updatedAt': FieldValue.serverTimestamp(),
          'ult_analise_solo': {
            'analise_id': analiseRef.id,
            'metodo': metodo,
            'status': _previewStatus,
            'resumo': resumoHistorico,
            'atualizadoEm': FieldValue.serverTimestamp(),
          },
        }),
        SetOptions(merge: true),
      );

      await batch.commit();

      if (!mounted) return;
      _toast('✅ Diagnóstico salvo com sucesso!');
      Navigator.pop(context);
    } catch (e) {
      _toast('Erro ao salvar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Map<String, dynamic> _limparNulos(Map<String, dynamic> map) {
    final out = <String, dynamic>{};
    map.forEach((k, v) {
      if (v != null) out[k] = v;
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const PageContainer(
        title: 'Clínica da Planta',
        body: Center(child: Text('Faça login para usar.')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Clínica e Solo',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).colorScheme.primary,
          indicatorWeight: 3,
          onTap: (index) {
            if (index == 0) _recalcularPreviewVisual();
            if (index == 1) _recalcularPreviewLaboratorio();
          },
          tabs: const [
            Tab(text: 'Diagnóstico Visual', icon: Icon(Icons.visibility)),
            Tab(text: 'Laudo de Laboratório', icon: Icon(Icons.science)),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [_buildAbaManual(), _buildAbaLaboratorio()],
          ),
          if (_salvando)
            const ModalBarrier(dismissible: false, color: Colors.black26),
          if (_salvando) const Center(child: CircularProgressIndicator()),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.md),
          child: AppButtons.elevatedIcon(
            onPressed: _salvando ? null : _salvarDados,
            icon: const Icon(Icons.save),
            label: const Text('SALVAR DIAGNÓSTICO'),
          ),
        ),
      ),
    );
  }

  Widget _headerLocal() {
    final cs = Theme.of(context).colorScheme;

    if (_carregandoCanteiro) return const LinearProgressIndicator();

    if (_bloquearSelecaoCanteiro) {
      return Container(
        padding: const EdgeInsets.all(AppTokens.md),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.place, color: cs.primary),
            const SizedBox(width: AppTokens.sm),
            Text(
              _nomeCanteiro.isEmpty ? 'Canteiro Atual' : _nomeCanteiro,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebasePaths.canteirosCol(appSession.tenantId)
          .where('ativo', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        final docs = snap.data!.docs;

        return DropdownButtonFormField<String>(
          value: _canteiroSelecionadoId,
          decoration: InputDecoration(
            labelText: 'Selecione o Lote / Canteiro',
            prefixIcon: Icon(Icons.place, color: cs.primary),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
            filled: true,
            fillColor: Colors.white,
          ),
          items: docs.map((d) {
            final nome = ((d.data() as Map)['nome'] ?? 'Lote').toString();
            return DropdownMenuItem(value: d.id, child: Text(nome));
          }).toList(),
          onChanged: (id) async {
            if (id != null) {
              setState(() => _canteiroSelecionadoId = id);
              await _carregarDadosCanteiro(id);
            }
          },
        );
      },
    );
  }

  // ✅ ABA MANUAL (VISUAL E INTELIGENTE)
  Widget _buildAbaManual() {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTokens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _headerLocal(),
          const SizedBox(height: AppTokens.lg),
          SectionCard(
            title: 'Etapa 1: Textura do Solo',
            child: Column(
              children: [
                _chipOpcao('Arenoso', 'Solto, drena rápido.', _texturaEstimada,
                    (v) {
                  setState(() {
                    _texturaEstimada = v;
                    _recalcularPreviewVisual();
                  });
                }, cs),
                _chipOpcao('Médio (Franco)', 'Molda como massinha leve.',
                    _texturaEstimada, (v) {
                  setState(() {
                    _texturaEstimada = v;
                    _recalcularPreviewVisual();
                  });
                }, cs),
                _chipOpcao('Argiloso', 'Pesado, gruda e retém muita água.',
                    _texturaEstimada, (v) {
                  setState(() {
                    _texturaEstimada = v;
                    _recalcularPreviewVisual();
                  });
                }, cs),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.lg),
          SectionCard(
            title: 'Etapa 2: Sintomas nas Folhas',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Onde está o problema?',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'nenhum', label: Text('Tudo Verde')),
                    ButtonSegment(
                        value: 'velhas', label: Text('Folhas Velhas (Baixo)')),
                    ButtonSegment(
                        value: 'novas', label: Text('Folhas Novas (Topo)')),
                  ],
                  selected: {_sintomaLocal},
                  onSelectionChanged: (set) => setState(() {
                    _sintomaLocal = set.first;
                    _recalcularPreviewVisual();
                  }),
                ),
                if (_sintomaLocal != 'nenhum') ...[
                  const SizedBox(height: 16),
                  const Text('Qual a aparência?',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                          label: const Text('Amareladas'),
                          selected: _sintomaAparencia == 'amarelas',
                          onSelected: (v) => setState(() {
                                _sintomaAparencia = 'amarelas';
                                _recalcularPreviewVisual();
                              })),
                      ChoiceChip(
                          label: const Text('Arroxeadas'),
                          selected: _sintomaAparencia == 'roxas',
                          onSelected: (v) => setState(() {
                                _sintomaAparencia = 'roxas';
                                _recalcularPreviewVisual();
                              })),
                      ChoiceChip(
                          label: const Text('Bordas Queimadas'),
                          selected: _sintomaAparencia == 'queimadas',
                          onSelected: (v) => setState(() {
                                _sintomaAparencia = 'queimadas';
                                _recalcularPreviewVisual();
                              })),
                    ],
                  )
                ]
              ],
            ),
          ),
          if (_previewStatus != 'neutro') ...[
            const SizedBox(height: AppTokens.lg),
            _DiagnosticoPreview(
                status: _previewStatus,
                alertas: _previewAlertas,
                acoes: _previewAcoes),
          ]
        ],
      ),
    );
  }

  Widget _chipOpcao(String titulo, String desc, String? selecionado,
      ValueChanged<String> onTap, ColorScheme cs) {
    bool isSel = selecionado == titulo;
    return InkWell(
      onTap: () => onTap(titulo),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: isSel ? cs.primaryContainer : Colors.white,
            border: Border.all(color: isSel ? cs.primary : cs.outlineVariant),
            borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
        child: Row(
          children: [
            Icon(isSel ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isSel ? cs.primary : cs.outline),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(desc,
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // ✅ ABA LABORATÓRIO (USANDO APP UI COMPONENTES)
  Widget _buildAbaLaboratorio() {
    final ref = _referenciaCulturas[_culturaSelecionada] ??
        _referenciaCulturas['Geral (Horta)']!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTokens.md),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _headerLocal(),
            const SizedBox(height: AppTokens.lg),
            SectionCard(
              title: 'Cultura de Referência',
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(border: InputBorder.none),
                value: _culturaSelecionada,
                items: _referenciaCulturas.keys
                    .map(
                        (c) => DropdownMenuItem(value: c, child: Text('🌱 $c')))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _culturaSelecionada = v);
                    _recalcularPreviewLaboratorio();
                  }
                },
              ),
            ),
            const SizedBox(height: AppTokens.sm),
            Text(
              '  Valores ideais: pH ${_fmt(ref['ph_min']!)}–${_fmt(ref['ph_max']!)} | V% ~ ${_fmt(ref['v_ideal']!, dec: 0)}',
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppTokens.lg),
            if (_previewStatus != 'neutro') ...[
              _DiagnosticoPreview(
                  status: _previewStatus,
                  alertas: _previewAlertas,
                  acoes: _previewAcoes),
              const SizedBox(height: AppTokens.lg),
            ],
            SectionCard(
              title: 'Índices Essenciais',
              child: Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _phController,
                      labelText: 'pH (H2O)',
                      hintText: 'Ex: 6,5',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]'))
                      ],
                      validator: (v) =>
                          _toNum(v) == null ? 'Obrigatório' : null,
                    ),
                  ),
                  const SizedBox(width: AppTokens.md),
                  Expanded(
                    child: AppTextField(
                      controller: _vPercentController,
                      labelText: 'V% (Sat.)',
                      hintText: 'Ex: 70',
                      suffixText: '%',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]'))
                      ],
                      validator: (v) =>
                          _toNum(v) == null ? 'Obrigatório' : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.lg),
            SectionCard(
              title: 'Nutrientes (Opcional)',
              child: Column(
                children: [
                  AppTextField(
                    controller: _moController,
                    labelText: 'Matéria Orgânica (M.O.)',
                    suffixText: 'g/dm³',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: AppTokens.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _fosforoController,
                          labelText: 'Fósforo (P)',
                          suffixText: 'mg/dm³',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                      const SizedBox(width: AppTokens.md),
                      Expanded(
                        child: AppTextField(
                          controller: _potassioController,
                          labelText: 'Potássio (K)',
                          suffixText: 'mmol',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _calcioController,
                          labelText: 'Cálcio (Ca)',
                          suffixText: 'mmol',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                      const SizedBox(width: AppTokens.md),
                      Expanded(
                        child: AppTextField(
                          controller: _magnesioController,
                          labelText: 'Magnésio (Mg)',
                          suffixText: 'mmol',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double? _toNum(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return double.tryParse(v.trim().replaceAll(',', '.'));
  }
}

// ================== COMPONENTE VISUAL DO DIAGNÓSTICO ==================
class _DiagnosticoPreview extends StatelessWidget {
  final String status;
  final List<String> alertas;
  final List<String> acoes;

  const _DiagnosticoPreview({
    required this.status,
    required this.alertas,
    required this.acoes,
  });

  Color get _cor {
    switch (status) {
      case 'critico':
        return Colors.red;
      case 'atencao':
        return Colors.orange.shade800;
      case 'ok':
        return Colors.green.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: _cor),
              const SizedBox(width: 8),
              Text(
                'Parecer do Assistente Agronômico',
                style: TextStyle(
                    color: _cor, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          if (alertas.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...alertas.map((a) => Text('• $a',
                style: TextStyle(color: Colors.grey.shade800, fontSize: 13))),
          ],
          if (acoes.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(),
            ),
            const Text('Ação Recomendada:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            ...acoes.map((a) => Text('👉 $a',
                style: TextStyle(
                    color: _cor, fontWeight: FontWeight.bold, fontSize: 13))),
          ],
        ],
      ),
    );
  }
}
