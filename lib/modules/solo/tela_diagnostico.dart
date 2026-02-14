import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/firebase/firebase_paths.dart';
import '../../core/session/app_session.dart';
import '../../core/session/session_scope.dart';

class TelaDiagnostico extends StatefulWidget {
  final String? canteiroIdOrigem;
  final String? culturaAtual;

  const TelaDiagnostico({super.key, this.canteiroIdOrigem, this.culturaAtual});

  @override
  State<TelaDiagnostico> createState() => _TelaDiagnosticoState();
}

class _TelaDiagnosticoState extends State<TelaDiagnostico>
    with SingleTickerProviderStateMixin {
  // Auth
  User? get _user => FirebaseAuth.instance.currentUser;

  // SaaS / Multi-tenant
  AppSession? get _sessionOrNull => SessionScope.of(context).session;
  AppSession get appSession =>
      _sessionOrNull ?? (throw StateError('Sessão não inicializada'));

  // UI
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  bool _salvando = false;
  bool _carregandoCanteiro = false;

  // Canteiro (premium: seleção + header)
  String? _canteiroSelecionadoId;
  String _nomeCanteiro = '';
  double _areaCanteiro = 0;
  bool _bloquearSelecaoCanteiro = false;

  // Diagnóstico Manual
  String? _texturaEstimada;
  String? _sintomaVisual;

  // Pré-diagnóstico (live)
  String _previewStatus = 'neutro'; // neutro|ok|atencao|critico
  List<String> _previewAlertas = [];
  List<String> _previewAcoes = [];

  // --- Referência de culturas (mínimo viável premium) ---
  final Map<String, Map<String, double>> _referenciaCulturas = const {
    'Alface': {'ph_min': 6.0, 'ph_max': 6.8, 'v_ideal': 70},
    'Tomate': {'ph_min': 5.5, 'ph_max': 6.8, 'v_ideal': 80},
    'Morango': {'ph_min': 5.5, 'ph_max': 6.5, 'v_ideal': 75},
    'Cenoura': {'ph_min': 5.5, 'ph_max': 6.5, 'v_ideal': 60},
    'Geral (Horta)': {'ph_min': 5.5, 'ph_max': 6.5, 'v_ideal': 70},
  };

  String _culturaSelecionada = 'Geral (Horta)';

  // Controladores
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

    // Se veio canteiro travado
    if (widget.canteiroIdOrigem != null) {
      _canteiroSelecionadoId = widget.canteiroIdOrigem;
      _bloquearSelecaoCanteiro = true;
      _carregarDadosCanteiro(widget.canteiroIdOrigem!);
    }

    // Live preview quando digitar pH/V%
    _phController.addListener(_recalcularPreview);
    _vPercentController.addListener(_recalcularPreview);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phController.removeListener(_recalcularPreview);
    _vPercentController.removeListener(_recalcularPreview);

    _phController.dispose();
    _vPercentController.dispose();
    _moController.dispose();
    _fosforoController.dispose();
    _potassioController.dispose();
    _calcioController.dispose();
    _magnesioController.dispose();
    super.dispose();
  }

  // ---------- Helpers ----------
  double? _parseNullable(TextEditingController controller) {
    final raw = controller.text.trim();
    if (raw.isEmpty) return null;
    final txt = raw.replaceAll(',', '.');
    return double.tryParse(txt);
  }

  String _fmt(num v, {int dec = 2}) {
    return v.toStringAsFixed(dec).replaceAll('.', ',');
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

  Future<void> _carregarDadosCanteiro(String id) async {
    final user = _user;
    if (user == null) return;

    setState(() => _carregandoCanteiro = true);
    try {
      final appSession = SessionScope.of(context).session;
      if (appSession == null) return;

      final doc = await FirebasePaths.canteirosCol(appSession.tenantId)
          .doc(id)
          .get();
      if (!doc.exists || !mounted) return;

      final data = doc.data() ?? {};
      // Segurança: se o doc tiver uid_usuario, confere
      final uidDoc = (data['uid_usuario'] ?? '').toString();
      if (uidDoc.isNotEmpty && uidDoc != user.uid) return;

      setState(() {
        _nomeCanteiro = (data['nome'] ?? 'Canteiro').toString();
        final area = data['area_m2'];
        if (area is num) _areaCanteiro = area.toDouble();
        if (area is String) _areaCanteiro = double.tryParse(area) ?? 0;
      });
    } catch (e) {
      _snack('Erro ao carregar canteiro: $e', cor: Colors.red);
    } finally {
      if (mounted) setState(() => _carregandoCanteiro = false);
    }
  }

  // ---------- Diagnóstico (premium) ----------
  void _recalcularPreview() {
    if (_tabController.index != 1) return; // só no Laudo Técnico

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

    final ref =
        _referenciaCulturas[_culturaSelecionada] ??
        _referenciaCulturas['Geral (Horta)']!;
    final diag = _avaliarSolo(ph: ph, v: v, ref: ref);

    if (!mounted) return;
    setState(() {
      _previewStatus = diag.status;
      _previewAlertas = diag.alertas;
      _previewAcoes = diag.acoes;
    });
  }

  _DiagnosticoResult _avaliarSolo({
    required double? ph,
    required double? v,
    required Map<String, double> ref,
  }) {
    final alertas = <String>[];
    final acoes = <String>[];

    var status = 'ok';

    // pH
    if (ph != null) {
      if (ph < (ref['ph_min'] ?? 5.5)) {
        alertas.add('Solo muito ácido (pH baixo).');
        acoes.add('Considere calagem (corrigir acidez).');
        status = 'critico';
      } else if (ph > (ref['ph_max'] ?? 6.5)) {
        alertas.add('Solo alcalino (pH alto).');
        acoes.add('Evite calagem. Ajuste adubação e matéria orgânica.');
        if (status != 'critico') status = 'atencao';
      } else {
        alertas.add('pH dentro da faixa boa pra ${_culturaSelecionada}.');
      }
    }

    // V%
    if (v != null) {
      final vIdeal = (ref['v_ideal'] ?? 70);
      if (v < (vIdeal - 15)) {
        alertas.add('Fertilidade baixa (V% bem abaixo do ideal).');
        acoes.add('Calagem + plano de adubação (subir saturação).');
        status = 'critico';
      } else if (v < vIdeal) {
        alertas.add('Fertilidade ok, mas abaixo do ideal (V%).');
        acoes.add('Ajuste fino com calagem/adubação.');
        if (status != 'critico') status = 'atencao';
      } else {
        alertas.add('V% ótimo (próximo/acima do ideal).');
      }
    }

    // Refinamento: se nada gerou alerta relevante, mantém ok
    if (alertas.isEmpty && acoes.isEmpty) {
      status = 'neutro';
    }

    // Enxuga duplicadas
    return _DiagnosticoResult(
      status: status,
      alertas: alertas.toSet().toList(),
      acoes: acoes.toSet().toList(),
    );
  }

  // ---------- Salvamento (batch + cache premium no canteiro) ----------
  Future<void> _salvarDados() async {
    FocusScope.of(context).unfocus();
    final user = _user;
    if (user == null) {
      _snack('Faça login para salvar.', cor: Colors.red);
      return;
    }

    // Precisa canteiro
    final canteiroId = _canteiroSelecionadoId ?? widget.canteiroIdOrigem;
    if (canteiroId == null) {
      _snack('Selecione um canteiro antes de salvar.', cor: Colors.red);
      return;
    }

    // Manual exige textura
    if (_tabController.index == 0 && _texturaEstimada == null) {
      _snack('Selecione a textura do solo.', cor: Colors.red);
      return;
    }

    // Laudo exige validação do form
    if (_tabController.index == 1) {
      final ok = _formKey.currentState?.validate() ?? false;
      if (!ok) {
        _snack('Verifique os campos obrigatórios do laudo.', cor: Colors.red);
        return;
      }
    }

    setState(() => _salvando = true);

    try {
      final metodo = _tabController.index == 0 ? 'manual' : 'laboratorial';
      final precisao = _tabController.index == 0 ? 'baixa' : 'alta';

      final nowServer = FieldValue.serverTimestamp();

      // Base
      final dadosAnalise = <String, dynamic>{
        'uid_usuario': user.uid,
        'canteiro_id': canteiroId,
        'canteiro_nome': _nomeCanteiro.isEmpty ? null : _nomeCanteiro,
        'cultura_referencia': _culturaSelecionada,
        'metodo': metodo,
        'precisao': precisao,
        'createdAt': nowServer,
        'updatedAt': nowServer,
      };

      String resumoHistorico = '';
      String? obsAlerta;
      String statusFinal = 'neutro';
      List<String> alertasFinal = [];
      List<String> acoesFinal = [];

      if (metodo == 'manual') {
        dadosAnalise['textura_estimada'] = _texturaEstimada;
        dadosAnalise['sintoma_visual'] = _sintomaVisual;

        // “diagnóstico provável” (sem prometer milagre)
        final acoes = <String>[];
        final alertas = <String>[];

        alertas.add('Diagnóstico por observação (sem laudo).');
        if (_texturaEstimada == 'Arenoso') {
          acoes.add(
            'Reforçar matéria orgânica e irrigação (solo drena rápido).',
          );
        } else if (_texturaEstimada == 'Argiloso') {
          acoes.add(
            'Atenção a encharcamento/compactação. Use cobertura e composto.',
          );
        } else {
          acoes.add('Solo médio: mantenha adubação orgânica e cobertura.');
        }

        if (_sintomaVisual != null && _sintomaVisual != 'Sem sintomas') {
          alertas.add('Sintoma informado: $_sintomaVisual');
          acoes.add('Ajustar adubação conforme o sintoma (N/P/K/Fe/S).');
        }

        statusFinal = 'atencao';
        alertasFinal = alertas;
        acoesFinal = acoes;

        resumoHistorico = 'Análise Visual: Solo $_texturaEstimada.';
        if (_sintomaVisual != null) {
          resumoHistorico += ' Sintoma: $_sintomaVisual.';
        }
      } else {
        final ph = _parseNullable(_phController)!;
        final v = _parseNullable(_vPercentController)!;

        final mo = _parseNullable(_moController);
        final p = _parseNullable(_fosforoController);
        final k = _parseNullable(_potassioController);
        final ca = _parseNullable(_calcioController);
        final mg = _parseNullable(_magnesioController);

        // Salva só o que veio preenchido (premium: sem "0" fake)
        dadosAnalise['ph'] = ph;
        dadosAnalise['v_percent'] = v;
        if (mo != null) dadosAnalise['mo'] = mo;
        if (p != null) dadosAnalise['fosforo'] = p;
        if (k != null) dadosAnalise['potassio'] = k;
        if (ca != null) dadosAnalise['calcio'] = ca;
        if (mg != null) dadosAnalise['magnesio'] = mg;

        // Unidades (do jeito que a UI pede hoje — evita confusão depois)
        dadosAnalise['unidades'] = {
          'ph': 'H2O',
          'v_percent': '%',
          'mo': 'g/dm³',
          'fosforo': 'mg/dm³',
          'potassio': 'mmol',
          'calcio': 'mmol',
          'magnesio': 'mmol',
        };

        resumoHistorico = 'Laudo Técnico: pH ${_fmt(ph)} | V% ${_fmt(v)}';

        final ref =
            _referenciaCulturas[_culturaSelecionada] ??
            _referenciaCulturas['Geral (Horta)']!;
        final diag = _avaliarSolo(ph: ph, v: v, ref: ref);

        statusFinal = diag.status;
        alertasFinal = diag.alertas;
        acoesFinal = diag.acoes;

        if (statusFinal == 'critico') {
          obsAlerta = '⚠️ Atenção: condição crítica. Veja recomendações.';
        } else if (statusFinal == 'atencao') {
          obsAlerta = '⚠️ Ajustes recomendados para melhorar desempenho.';
        } else {
          obsAlerta = '✅ Solo em boa condição para a cultura.';
        }
      }

      dadosAnalise['diagnostico'] = {
        'status': statusFinal,
        'alertas': alertasFinal,
        'acoes': acoesFinal,
      };

      // Batch (premium: grava tudo junto)
      final appSession = SessionScope.of(context).session;
      if (appSession == null) throw Exception('Sem tenant selecionado');

      final fs = FirebaseFirestore.instance;
      final batch = fs.batch();

      final analiseRef = FirebasePaths.analisesSoloCol(appSession.tenantId).doc();
      batch.set(analiseRef, _limparNulos(dadosAnalise));

      final historicoRef = FirebasePaths.historicoManejoCol(appSession.tenantId).doc();
      batch.set(
        historicoRef,
        _limparNulos({
          'canteiro_id': canteiroId,
          'uid_usuario': user.uid,
          'data': FieldValue.serverTimestamp(),
          'tipo_manejo': 'Análise de Solo',
          'produto': metodo == 'manual'
              ? 'Teste Físico/Visual'
              : 'Laudo Químico',
          'detalhes': resumoHistorico,
          'observacao_extra': obsAlerta,
          'quantidade_g': 0,
          'ref_analise_id': analiseRef.id,
          'status': statusFinal,
        }),
      );

      // Cache no canteiro (zera recalcular lendo tudo depois)
      final canteiroRef = FirebasePaths.canteirosCol(appSession.tenantId).doc(canteiroId);
      batch.set(
        canteiroRef,
        _limparNulos({
          'updatedAt': FieldValue.serverTimestamp(),
          'ult_analise_solo': {
            'analise_id': analiseRef.id,
            'metodo': metodo,
            'precisao': precisao,
            'status': statusFinal,
            'cultura_referencia': _culturaSelecionada,
            'resumo': resumoHistorico,
            // Só salva pH/V no cache quando laudo
            'ph': metodo == 'laboratorial'
                ? _parseNullable(_phController)
                : null,
            'v_percent': metodo == 'laboratorial'
                ? _parseNullable(_vPercentController)
                : null,
            'atualizadoEm': FieldValue.serverTimestamp(),
          },
        }),
        SetOptions(merge: true),
      );

      await batch.commit();

      if (!mounted) return;
      _snack('✅ Diagnóstico salvo com sucesso!', cor: Colors.green);
      Navigator.pop(context);
    } catch (e) {
      _snack('Erro ao salvar: $e', cor: Colors.red);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Map<String, dynamic> _limparNulos(Map<String, dynamic> map) {
    final out = <String, dynamic>{};
    map.forEach((k, v) {
      if (v == null) return;
      if (v is Map<String, dynamic>) {
        final vv = _limparNulos(v);
        if (vv.isEmpty) return;
        out[k] = vv;
        return;
      }
      out[k] = v;
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Diagnóstico Inteligente'),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Faça login para usar o diagnóstico.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Diagnóstico Inteligente',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.green[800],
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.green[800],
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.green,
          indicatorWeight: 3,
          onTap: (_) => _recalcularPreview(),
          tabs: const [
            Tab(text: 'Teste Prático', icon: Icon(Icons.back_hand)),
            Tab(text: 'Laudo Técnico', icon: Icon(Icons.science)),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [_buildAbaManual(), _buildAbaLaboratorio()],
          ),
          if (_salvando) _SavingOverlay(),
        ],
      ),
    );
  }

  // ---------- UI: Header Canteiro ----------
  Widget _headerLocal() {
    final user = _user!;
    if (_carregandoCanteiro) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: LinearProgressIndicator(),
      );
    }

    if (_bloquearSelecaoCanteiro) {
      return _CanteiroCard(
        titulo: _nomeCanteiro.isEmpty ? 'Canteiro' : _nomeCanteiro,
        subtitulo: _areaCanteiro > 0 ? 'Área: ${_fmt(_areaCanteiro)} m²' : null,
        travado: true,
      );
    }

    // Seleção de canteiro (premium)
    return StreamBuilder<QuerySnapshot>(
      stream: FirebasePaths.canteirosCol(appSession.tenantId)
          .where('ativo', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _InfoBox(
            icon: Icons.error_outline,
            cor: Colors.red,
            texto: 'Erro ao carregar canteiros: ${snap.error}',
          );
        }
        if (!snap.hasData) return const LinearProgressIndicator();

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _InfoBox(
            icon: Icons.warning_amber,
            cor: Colors.orange,
            texto: 'Nenhum canteiro ativo. Crie um primeiro.',
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.place, color: Colors.green[700]),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _canteiroSelecionadoId,
                    hint: const Text('Selecione um canteiro'),
                    items: docs.map((d) {
                      final data = (d.data() as Map<String, dynamic>? ?? {});
                      final nome = (data['nome'] ?? 'Canteiro').toString();
                      final area = data['area_m2'];
                      double areaM2 = 0;
                      if (area is num) areaM2 = area.toDouble();
                      if (area is String) areaM2 = double.tryParse(area) ?? 0;
                      return DropdownMenuItem<String>(
                        value: d.id,
                        child: Text('$nome (${_fmt(areaM2)} m²)'),
                      );
                    }).toList(),
                    onChanged: (id) async {
                      if (id == null) return;
                      setState(() {
                        _canteiroSelecionadoId = id;
                        _nomeCanteiro = '';
                        _areaCanteiro = 0;
                      });
                      await _carregarDadosCanteiro(id);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------- Aba Manual ----------
  Widget _buildAbaManual() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerLocal(),
          const SizedBox(height: 14),

          _InfoBox(
            icon: Icons.lightbulb,
            cor: Colors.orange,
            texto:
                'Sem análise química? Use o "teste da mão" e observe as folhas para um diagnóstico rápido (sem promessas mágicas).',
          ),
          const SizedBox(height: 18),

          _SectionTitle('1. Textura do Solo'),
          const SizedBox(height: 10),
          _OpcaoManual(
            titulo: 'Arenoso',
            descricao: 'Esfarela na mão, não molda. Drena rápido.',
            valor: 'Arenoso',
            grupo: _texturaEstimada,
            onChanged: (v) => setState(() => _texturaEstimada = v),
          ),
          _OpcaoManual(
            titulo: 'Médio (Franco)',
            descricao: 'Molda mas quebra ao dobrar. Ideal.',
            valor: 'Médio',
            grupo: _texturaEstimada,
            onChanged: (v) => setState(() => _texturaEstimada = v),
          ),
          _OpcaoManual(
            titulo: 'Argiloso',
            descricao: 'Molda bem (massinha). Retém água.',
            valor: 'Argiloso',
            grupo: _texturaEstimada,
            onChanged: (v) => setState(() => _texturaEstimada = v),
          ),

          const SizedBox(height: 18),
          _SectionTitle('2. Sintomas nas Plantas (Opcional)'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _sintomaVisual,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 15,
              ),
            ),
            isExpanded: true,
            hint: const Text('Selecione um sintoma...'),
            items: const [
              DropdownMenuItem(
                value: 'Sem sintomas',
                child: Text('🌱 Plantas Saudáveis'),
              ),
              DropdownMenuItem(
                value: 'Falta N',
                child: Text('🍂 Folhas VELHAS amareladas (Falta N)'),
              ),
              DropdownMenuItem(
                value: 'Falta Fe/S',
                child: Text('🌿 Folhas NOVAS amareladas (Falta Fe/S)'),
              ),
              DropdownMenuItem(
                value: 'Falta P',
                child: Text('🟣 Folhas arroxeadas (Falta P)'),
              ),
              DropdownMenuItem(
                value: 'Falta K',
                child: Text('🔥 Bordas queimadas (Falta K)'),
              ),
            ],
            onChanged: (v) => setState(() => _sintomaVisual = v),
          ),

          const SizedBox(height: 18),
          _InfoBox(
            icon: Icons.shield_outlined,
            cor: Colors.blue,
            texto:
                'Dica premium: esse diagnóstico manual serve como registro e direção. O laudo técnico é o que “bate martelo”.',
          ),

          const SizedBox(height: 24),
          _PrimaryButton(texto: 'SALVAR OBSERVAÇÃO', onPressed: _salvarDados),
        ],
      ),
    );
  }

  // ---------- Aba Laboratório ----------
  Widget _buildAbaLaboratorio() {
    final ref =
        _referenciaCulturas[_culturaSelecionada] ??
        _referenciaCulturas['Geral (Horta)']!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerLocal(),
            const SizedBox(height: 14),

            // Cultura alvo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.local_florist, color: Colors.green[700]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _culturaSelecionada,
                        icon: const Icon(Icons.keyboard_arrow_down),
                        items: _referenciaCulturas.keys.map((cultura) {
                          return DropdownMenuItem<String>(
                            value: cultura,
                            child: Text('Cultura alvo: $cultura'),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _culturaSelecionada = v);
                          _recalcularPreview();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Caixa de referência rápida
            _InfoBox(
              icon: Icons.rule,
              cor: Colors.green,
              texto:
                  'Referência (${_culturaSelecionada}): pH ${_fmt(ref['ph_min']!)}–${_fmt(ref['ph_max']!)} | V% ideal ~ ${_fmt(ref['v_ideal']!, dec: 0)}',
            ),

            const SizedBox(height: 14),

            // Pré-diagnóstico live
            if (_previewStatus != 'neutro')
              _DiagnosticoPreview(
                status: _previewStatus,
                alertas: _previewAlertas,
                acoes: _previewAcoes,
              ),

            if (_previewStatus != 'neutro') const SizedBox(height: 14),

            // Campos principais
            Row(
              children: [
                Expanded(
                  child: _InputComMonitoramento(
                    controller: _phController,
                    label: 'pH (H2O)',
                    referencias: ref,
                    tipoDado: 'ph',
                    obrigatorio: true,
                    ajudaTitulo: 'pH do Solo',
                    ajudaTexto:
                        'Mede a acidez. Muito baixo (ácido) trava nutrientes; muito alto também atrapalha.',
                    validator: (v) {
                      final val = _toNum(v);
                      if (val == null) return 'Obrigatório';
                      if (val < 0 || val > 14) return 'pH inválido';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InputComMonitoramento(
                    controller: _vPercentController,
                    label: 'V% (Saturação)',
                    referencias: ref,
                    tipoDado: 'v',
                    obrigatorio: true,
                    ajudaTitulo: 'V% - Saturação por Bases',
                    ajudaTexto:
                        'É o “nível da bateria” do solo. Quanto mais perto do ideal da cultura, melhor.',
                    validator: (v) {
                      final val = _toNum(v);
                      if (val == null) return 'Obrigatório';
                      if (val < 0 || val > 100) return '0 a 100';
                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            _SectionTitle('Nutrientes (opcional)'),
            const SizedBox(height: 10),

            _InputSimples(
              controller: _moController,
              label: 'Matéria Orgânica (M.O.)',
              unidade: 'g/dm³',
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _InputSimples(
                    controller: _fosforoController,
                    label: 'Fósforo (P)',
                    unidade: 'mg/dm³',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InputSimples(
                    controller: _potassioController,
                    label: 'Potássio (K)',
                    unidade: 'mmol',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _InputSimples(
                    controller: _calcioController,
                    label: 'Cálcio (Ca)',
                    unidade: 'mmol',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InputSimples(
                    controller: _magnesioController,
                    label: 'Magnésio (Mg)',
                    unidade: 'mmol',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),
            _PrimaryButton(texto: 'ANALISAR E SALVAR', onPressed: _salvarDados),
          ],
        ),
      ),
    );
  }

  double? _toNum(String? v) {
    if (v == null) return null;
    final t = v.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }
}

// ================== COMPONENTES PREMIUM ==================

class _SavingOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.20),
      child: const Center(
        child: Card(
          elevation: 8,
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 14),
                Text('Salvando...'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: Colors.black87,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String texto;
  final VoidCallback onPressed;

  const _PrimaryButton({required this.texto, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          texto,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: .5,
          ),
        ),
      ),
    );
  }
}

class _CanteiroCard extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final bool travado;

  const _CanteiroCard({
    required this.titulo,
    this.subtitulo,
    this.travado = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.place, color: Colors.green[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitulo != null)
                  Text(
                    subtitulo!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (travado) const Icon(Icons.lock, size: 18, color: Colors.grey),
        ],
      ),
    );
  }
}

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
        return Colors.orange;
      case 'ok':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  String get _titulo {
    switch (status) {
      case 'critico':
        return 'Situação crítica';
      case 'atencao':
        return 'Atenção';
      case 'ok':
        return 'Tudo certo';
      default:
        return 'Pré-diagnóstico';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cor.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: _cor),
              const SizedBox(width: 8),
              Text(
                _titulo,
                style: TextStyle(
                  color: _cor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (alertas.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...alertas
                .take(4)
                .map(
                  (a) => Text(
                    '• $a',
                    style: TextStyle(color: _cor.withOpacity(0.9)),
                  ),
                ),
          ],
          if (acoes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Ações sugeridas:',
              style: TextStyle(color: _cor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ...acoes
                .take(4)
                .map(
                  (a) => Text(
                    '→ $a',
                    style: TextStyle(color: _cor.withOpacity(0.9)),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _InputComMonitoramento extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final Map<String, double> referencias;
  final String tipoDado; // 'ph' ou 'v'
  final bool obrigatorio;
  final String ajudaTitulo;
  final String ajudaTexto;
  final String? Function(String?)? validator;

  const _InputComMonitoramento({
    required this.controller,
    required this.label,
    required this.referencias,
    required this.tipoDado,
    required this.ajudaTitulo,
    required this.ajudaTexto,
    this.obrigatorio = false,
    this.validator,
  });

  @override
  State<_InputComMonitoramento> createState() => _InputComMonitoramentoState();
}

class _InputComMonitoramentoState extends State<_InputComMonitoramento> {
  String? _alerta;
  Color _corBorda = Colors.grey.shade300;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_validar);
    _validar();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_validar);
    super.dispose();
  }

  void _validar() {
    final txt = widget.controller.text.replaceAll(',', '.').trim();
    if (txt.isEmpty) {
      if (!mounted) return;
      setState(() {
        _alerta = null;
        _corBorda = Colors.grey.shade300;
      });
      return;
    }

    final val = double.tryParse(txt);
    if (val == null) return;

    String novoAlerta = '';
    Color novaCor = Colors.green;

    if (widget.tipoDado == 'ph') {
      final min = widget.referencias['ph_min'] ?? 5.5;
      final max = widget.referencias['ph_max'] ?? 6.5;
      if (val < min) {
        novoAlerta = 'Muito ácido';
        novaCor = Colors.red;
      } else if (val > max) {
        novoAlerta = 'Muito alcalino';
        novaCor = Colors.orange;
      } else {
        novoAlerta = 'Faixa ok';
        novaCor = Colors.green;
      }
    } else {
      final ideal = widget.referencias['v_ideal'] ?? 70;
      if (val < (ideal - 15)) {
        novoAlerta = 'Fertilidade baixa';
        novaCor = Colors.red;
      } else if (val < ideal) {
        novoAlerta = 'Abaixo do ideal';
        novaCor = Colors.orange;
      } else {
        novoAlerta = 'Ótimo';
        novaCor = Colors.green;
      }
    }

    if (!mounted) return;
    setState(() {
      _alerta = novoAlerta;
      _corBorda = novaCor;
    });
  }

  void _mostrarAjuda(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.ajudaTitulo,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(widget.ajudaTexto),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            GestureDetector(
              onTap: () => _mostrarAjuda(context),
              child: Icon(
                Icons.help_outline,
                size: 18,
                color: Colors.blue[300],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          validator: widget.validator,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            hintText: widget.obrigatorio ? 'Obrigatório' : 'Opcional',
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _corBorda),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _corBorda, width: 2),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: _alerta != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(Icons.circle, color: _corBorda, size: 12),
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(minWidth: 20),
          ),
        ),
        if (_alerta != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              _alerta!,
              style: TextStyle(
                color: _corBorda,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

class _InputSimples extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String unidade;

  const _InputSimples({
    required this.controller,
    required this.label,
    required this.unidade,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label ($unidade)',
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.green.shade600, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _OpcaoManual extends StatelessWidget {
  final String titulo;
  final String descricao;
  final String valor;
  final String? grupo;
  final ValueChanged<String?> onChanged;

  const _OpcaoManual({
    required this.titulo,
    required this.descricao,
    required this.valor,
    required this.grupo,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sel = valor == grupo;
    return GestureDetector(
      onTap: () => onChanged(valor),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: sel ? Colors.green.shade50 : Colors.white,
          border: Border.all(color: sel ? Colors.green : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              sel ? Icons.radio_button_checked : Icons.radio_button_off,
              color: sel ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    descricao,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final Color cor;
  final String texto;

  const _InfoBox({required this.icon, required this.cor, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: cor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                color: cor.withOpacity(0.90),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Model ----------
class _DiagnosticoResult {
  final String status;
  final List<String> alertas;
  final List<String> acoes;

  _DiagnosticoResult({
    required this.status,
    required this.alertas,
    required this.acoes,
  });
}
