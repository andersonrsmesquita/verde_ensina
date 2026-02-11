import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TelaDiagnostico extends StatefulWidget {
  final String? canteiroIdOrigem;
  final String? culturaAtual;

  const TelaDiagnostico({super.key, this.canteiroIdOrigem, this.culturaAtual});

  @override
  State<TelaDiagnostico> createState() => _TelaDiagnosticoState();
}

class _TelaDiagnosticoState extends State<TelaDiagnostico>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  bool _salvando = false;

  // Diagnóstico Manual
  String? _texturaEstimada;
  String? _sintomaVisual;

  // --- CÉREBRO AGRONÔMICO ---
  final Map<String, Map<String, double>> _referenciaCulturas = {
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

  double _parseValue(TextEditingController controller) {
    if (controller.text.isEmpty) return 0.0;
    return double.tryParse(controller.text.replaceAll(',', '.')) ?? 0.0;
  }

  Future<void> _salvarDados() async {
    FocusScope.of(context).unfocus();
    setState(() => _salvando = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      Map<String, dynamic> dadosAnalise = {
        'uid_usuario': user?.uid,
        'data': FieldValue.serverTimestamp(),
        'metodo': _tabController.index == 0 ? 'manual' : 'laboratorial',
        'canteiro_id': widget.canteiroIdOrigem,
        'cultura_referencia': _culturaSelecionada,
      };

      String resumoHistorico = "";
      String? obsAlerta;

      if (_tabController.index == 0) {
        if (_texturaEstimada == null)
          throw Exception("Selecione um tipo de solo.");

        dadosAnalise['textura_estimada'] = _texturaEstimada;
        dadosAnalise['sintoma_visual'] = _sintomaVisual;
        dadosAnalise['precisao'] = 'baixa';

        resumoHistorico = "Análise Visual: Solo $_texturaEstimada.";
        if (_sintomaVisual != null)
          resumoHistorico += " Sintoma: $_sintomaVisual";
      } else {
        if (!_formKey.currentState!.validate())
          throw Exception("Verifique campos obrigatórios.");

        double ph = _parseValue(_phController);
        double v = _parseValue(_vPercentController);

        dadosAnalise['ph'] = ph;
        dadosAnalise['v_percent'] = v;
        dadosAnalise['mo'] = _parseValue(_moController);
        dadosAnalise['fosforo'] = _parseValue(_fosforoController);
        dadosAnalise['potassio'] = _parseValue(_potassioController);
        dadosAnalise['calcio'] = _parseValue(_calcioController);
        dadosAnalise['magnesio'] = _parseValue(_magnesioController);
        dadosAnalise['precisao'] = 'alta';

        resumoHistorico = "Laudo Técnico: pH $ph | V% $v%";

        if (v < 50)
          obsAlerta = "Fertilidade muito baixa. Calagem urgente.";
        else if (ph < 5.5) obsAlerta = "Acidez elevada. Raízes sofrendo.";
      }

      await FirebaseFirestore.instance
          .collection('analises_solo')
          .add(dadosAnalise);

      if (widget.canteiroIdOrigem != null) {
        await FirebaseFirestore.instance.collection('historico_manejo').add({
          'canteiro_id': widget.canteiroIdOrigem,
          'uid_usuario': user?.uid,
          'data': FieldValue.serverTimestamp(),
          'tipo_manejo': 'Análise de Solo',
          'produto': _tabController.index == 0
              ? 'Teste Físico/Visual'
              : 'Laudo Químico',
          'detalhes': resumoHistorico,
          'observacao_extra': obsAlerta,
          'quantidade_g': 0,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Diagnóstico salvo com sucesso!'),
            backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Diagnóstico Inteligente',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
          tabs: const [
            Tab(text: 'Teste Prático', icon: Icon(Icons.back_hand)),
            Tab(text: 'Laudo Técnico', icon: Icon(Icons.science)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAbaManual(),
          _buildAbaLaboratorio(),
        ],
      ),
    );
  }

  Widget _buildAbaManual() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoBox(
              icon: Icons.lightbulb,
              cor: Colors.orange,
              texto:
                  'Sem análise química? Use o "teste da mão" e observe as folhas para um diagnóstico rápido.'),
          const SizedBox(height: 25),
          const Text('1. Textura do Solo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          _OpcaoManual(
              titulo: 'Arenoso',
              descricao: 'Esfarela na mão, não molda. Drena rápido.',
              valor: 'Arenoso',
              grupo: _texturaEstimada,
              onChanged: (v) => setState(() => _texturaEstimada = v)),
          _OpcaoManual(
              titulo: 'Médio (Franco)',
              descricao: 'Molda mas quebra se dobrar. Ideal.',
              valor: 'Médio',
              grupo: _texturaEstimada,
              onChanged: (v) => setState(() => _texturaEstimada = v)),
          _OpcaoManual(
              titulo: 'Argiloso',
              descricao: 'Molda perfeito (massinha). Retém água.',
              valor: 'Argiloso',
              grupo: _texturaEstimada,
              onChanged: (v) => setState(() => _texturaEstimada = v)),
          const SizedBox(height: 25),
          const Text('2. Sintomas nas Plantas (Opcional)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 5),
          DropdownButtonFormField<String>(
            value: _sintomaVisual,
            decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 15)),
            isExpanded: true,
            hint: const Text('Selecione um sintoma...'),
            items: const [
              DropdownMenuItem(
                  value: 'Sem sintomas', child: Text('🌱 Plantas Saudáveis')),
              DropdownMenuItem(
                  value: 'Falta N',
                  child: Text('🍂 Folhas VELHAS amareladas (Falta N)')),
              DropdownMenuItem(
                  value: 'Falta Fe/S',
                  child: Text('🌿 Folhas NOVAS amareladas (Falta Fe/S)')),
              DropdownMenuItem(
                  value: 'Falta P',
                  child: Text('🟣 Folhas arroxeadas (Falta P)')),
              DropdownMenuItem(
                  value: 'Falta K',
                  child: Text('🔥 Bordas queimadas (Falta K)')),
            ],
            onChanged: (v) => setState(() => _sintomaVisual = v),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _salvando ? null : _salvarDados,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: _salvando
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('SALVAR OBSERVAÇÃO',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAbaLaboratorio() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _referenciaCulturas.containsKey(_culturaSelecionada)
                      ? _culturaSelecionada
                      : 'Geral (Horta)',
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: Colors.green),
                  items: _referenciaCulturas.keys.map((String cultura) {
                    return DropdownMenuItem<String>(
                        value: cultura,
                        child: Text("Cultura Alvo: $cultura",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800)));
                  }).toList(),
                  onChanged: (v) => setState(() => _culturaSelecionada = v!),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                  child: _InputComMonitoramento(
                      controller: _phController,
                      label: 'pH (H2O)',
                      cultura: _culturaSelecionada,
                      referencias: _referenciaCulturas[_culturaSelecionada]!,
                      tipoDado: 'ph',
                      obrigatorio: true,
                      ajudaTitulo: 'pH do Solo',
                      ajudaTexto:
                          'Mede a acidez. pH ideal libera nutrientes. Muito baixo (ácido) trava tudo.')),
              const SizedBox(width: 15),
              Expanded(
                  child: _InputComMonitoramento(
                      controller: _vPercentController,
                      label: 'V% (Saturação)',
                      cultura: _culturaSelecionada,
                      referencias: _referenciaCulturas[_culturaSelecionada]!,
                      tipoDado: 'v',
                      obrigatorio: true,
                      ajudaTitulo: 'V% - Saturação por Bases',
                      ajudaTexto:
                          'É o "nível da bateria" do solo. Indica quanto ele está cheio de nutrientes bons.')),
            ]),
            const SizedBox(height: 20),
            _InputSimples(
                controller: _moController,
                label: 'Matéria Orgânica (M.O.)',
                unidade: 'g/dm³'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _InputSimples(
                      controller: _fosforoController,
                      label: 'Fósforo (P)',
                      unidade: 'mg/dm³')),
              const SizedBox(width: 15),
              Expanded(
                  child: _InputSimples(
                      controller: _potassioController,
                      label: 'Potássio (K)',
                      unidade: 'mmol')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _InputSimples(
                      controller: _calcioController,
                      label: 'Cálcio (Ca)',
                      unidade: 'mmol')),
              const SizedBox(width: 15),
              Expanded(
                  child: _InputSimples(
                      controller: _magnesioController,
                      label: 'Magnésio (Mg)',
                      unidade: 'mmol')),
            ]),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvarDados,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: _salvando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('ANALISAR E SALVAR',
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputComMonitoramento extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String cultura;
  final Map<String, double> referencias;
  final String tipoDado;
  final bool obrigatorio;
  final String ajudaTitulo;
  final String ajudaTexto;

  const _InputComMonitoramento(
      {required this.controller,
      required this.label,
      required this.cultura,
      required this.referencias,
      required this.tipoDado,
      required this.ajudaTitulo,
      required this.ajudaTexto,
      this.obrigatorio = false});

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
  }

  void _validar() {
    final txt = widget.controller.text.replaceAll(',', '.');
    if (txt.isEmpty) {
      setState(() {
        _alerta = null;
        _corBorda = Colors.grey.shade300;
      });
      return;
    }

    double val = double.tryParse(txt) ?? 0.0;
    String novoAlerta = '';
    Color novaCor = Colors.green;

    if (widget.tipoDado == 'ph') {
      if (val < widget.referencias['ph_min']!) {
        novoAlerta = 'Muito Ácido!';
        novaCor = Colors.red;
      } else if (val > widget.referencias['ph_max']!) {
        novoAlerta = 'Muito Alcalino!';
        novaCor = Colors.orange;
      }
    } else {
      if (val < (widget.referencias['v_ideal']! - 15)) {
        novoAlerta = 'Baixa Fertilidade';
        novaCor = Colors.red;
      }
    }
    setState(() {
      _alerta = novoAlerta.isEmpty ? null : novoAlerta;
      _corBorda = novaCor;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(widget.label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        GestureDetector(
            onTap: () => _mostrarAjuda(context),
            child: Icon(Icons.help_outline, size: 16, color: Colors.blue[300]))
      ]),
      const SizedBox(height: 5),
      TextFormField(
        controller: widget.controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _corBorda)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _corBorda, width: 2)),
            suffixIcon: _alerta != null
                ? Icon(Icons.circle, color: _corBorda, size: 12)
                : null),
      ),
      if (_alerta != null)
        Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(_alerta!,
                style: TextStyle(
                    color: _corBorda,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)))
    ]);
  }

  void _mostrarAjuda(BuildContext ctx) {
    showModalBottomSheet(
        context: ctx,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (c) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(widget.ajudaTitulo,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              Text(widget.ajudaTexto)
            ])));
  }
}

class _InputSimples extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String unidade;
  const _InputSimples(
      {required this.controller, required this.label, required this.unidade});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label ($unidade)',
          style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 5),
      TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300))),
      )
    ]);
  }
}

class _OpcaoManual extends StatelessWidget {
  final String titulo;
  final String descricao;
  final String valor;
  final String? grupo;
  final ValueChanged<String?> onChanged;
  const _OpcaoManual(
      {required this.titulo,
      required this.descricao,
      required this.valor,
      required this.grupo,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    bool sel = valor == grupo;
    return GestureDetector(
      onTap: () => onChanged(valor),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: sel ? Colors.green.shade50 : Colors.white,
            border:
                Border.all(color: sel ? Colors.green : Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off,
              color: sel ? Colors.green : Colors.grey),
          const SizedBox(width: 15),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(descricao,
                    style: const TextStyle(fontSize: 12, color: Colors.grey))
              ]))
        ]),
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
          color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, color: cor),
        const SizedBox(width: 15),
        Expanded(
            child: Text(texto,
                style: TextStyle(
                    color: cor.withOpacity(0.8),
                    fontWeight: FontWeight.bold,
                    fontSize: 13)))
      ]),
    );
  }
}
