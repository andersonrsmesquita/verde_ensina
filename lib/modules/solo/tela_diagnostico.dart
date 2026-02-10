import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TelaDiagnostico extends StatefulWidget {
  final String? canteiroIdOrigem;
  // Se já soubermos a cultura do canteiro, passamos aqui. Se não, o usuário escolhe.
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
  String? _resultadoManual;

  // --- CÉREBRO AGRONÔMICO: Faixas ideais por cultura ---
  // Estrutura: 'Nome': {'ph_min', 'ph_max', 'v_ideal' (Saturação)}
  final Map<String, Map<String, double>> _referenciaCulturas = {
    'Alface': {'ph_min': 6.0, 'ph_max': 6.8, 'v_ideal': 70},
    'Tomate': {'ph_min': 5.5, 'ph_max': 6.8, 'v_ideal': 80},
    'Morango': {'ph_min': 5.5, 'ph_max': 6.5, 'v_ideal': 75},
    'Cenoura': {'ph_min': 5.5, 'ph_max': 6.5, 'v_ideal': 60},
    'Geral (Horta)': {'ph_min': 5.5, 'ph_max': 6.5, 'v_ideal': 70}, // Fallback
  };

  String _culturaSelecionada = 'Geral (Horta)'; // Padrão

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

    // Se veio uma cultura específica do canteiro, usamos ela
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
      Map<String, dynamic> dados = {
        'uid_usuario': user?.uid,
        'data': FieldValue.serverTimestamp(),
        'metodo': _tabController.index == 0 ? 'manual' : 'laboratorial',
        'canteiro_id': widget.canteiroIdOrigem,
        'cultura_referencia': _culturaSelecionada,
      };

      if (_tabController.index == 0) {
        if (_resultadoManual == null)
          throw Exception("Selecione um tipo de solo.");
        dados['textura_estimada'] = _resultadoManual;
        dados['precisao'] = 'baixa';
      } else {
        if (!_formKey.currentState!.validate())
          throw Exception("Verifique campos obrigatórios.");

        dados['ph'] = _parseValue(_phController);
        dados['v_percent'] = _parseValue(_vPercentController);
        dados['mo'] = _parseValue(_moController);
        dados['fosforo'] = _parseValue(_fosforoController);

        double k = _parseValue(_potassioController);
        double ca = _parseValue(_calcioController);
        double mg = _parseValue(_magnesioController);

        dados['potassio'] = k;
        dados['calcio'] = ca;
        dados['magnesio'] = mg;
        dados['soma_bases_calc'] = ca + mg + (k / 391);
        dados['precisao'] = 'alta';
      }

      await FirebaseFirestore.instance.collection('analises_solo').add(dados);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('✅ Diagnóstico registrado!'),
              backgroundColor: Colors.green.shade700),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Erro: ${e.toString().replaceAll("Exception: ", "")}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Diagnóstico Inteligente'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Teste de Mão', icon: Icon(Icons.back_hand)),
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

  // --- ABA 1: MANUAL (Visual mantido, foco na simplicidade) ---
  Widget _buildAbaManual() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _InfoBox(
              icon: Icons.lightbulb,
              cor: Colors.orange,
              texto:
                  'Sem laudo? Faça o teste da "minhoquinha" com terra úmida para descobrir a textura base.'),
          const SizedBox(height: 20),
          _OpcaoManual(
              titulo: 'Arenoso',
              descricao: 'Esfarela, não molda.',
              valor: 'Arenoso',
              grupo: _resultadoManual,
              onChanged: (v) => setState(() => _resultadoManual = v)),
          _OpcaoManual(
              titulo: 'Médio (Franco)',
              descricao: 'Molda mas quebra.',
              valor: 'Médio',
              grupo: _resultadoManual,
              onChanged: (v) => setState(() => _resultadoManual = v)),
          _OpcaoManual(
              titulo: 'Argiloso',
              descricao: 'Molda perfeito (massinha).',
              valor: 'Argiloso',
              grupo: _resultadoManual,
              onChanged: (v) => setState(() => _resultadoManual = v)),
          const SizedBox(height: 20),
          SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                  onPressed: _salvando ? null : _salvarDados,
                  child: const Text('SALVAR TEXTURA')))
        ],
      ),
    );
  }

  // --- ABA 2: LABORATÓRIO (AQUI ESTÁ A LÓGICA PEDIDA) ---
  Widget _buildAbaLaboratorio() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. SELETOR DE CULTURA PARA CONTEXTO
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _referenciaCulturas.containsKey(_culturaSelecionada)
                      ? _culturaSelecionada
                      : 'Geral (Horta)',
                  icon: const Icon(Icons.grass, color: Colors.green),
                  items: _referenciaCulturas.keys.map((String cultura) {
                    return DropdownMenuItem<String>(
                      value: cultura,
                      child: Text("Focar na cultura: $cultura",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _culturaSelecionada = newValue!;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. CAMPOS INTELIGENTES COM MONITORAMENTO
            _InputComMonitoramento(
              controller: _phController,
              label: 'pH (H2O)',
              unidade: '',
              cultura: _culturaSelecionada,
              referencias: _referenciaCulturas[_culturaSelecionada]!,
              tipoDado: 'ph',
              obrigatorio: true,
              ajudaTitulo: 'pH do Solo',
              ajudaTexto:
                  'O pH mede a acidez. Solos muito ácidos (pH baixo) "prendem" os nutrientes, e a planta passa fome mesmo com adubo.',
            ),

            const SizedBox(height: 20),

            _InputComMonitoramento(
              controller: _vPercentController,
              label: 'V% (Saturação)',
              unidade: '%',
              cultura: _culturaSelecionada,
              referencias: _referenciaCulturas[_culturaSelecionada]!,
              tipoDado: 'v',
              obrigatorio: true,
              ajudaTitulo: 'Saturação por Bases (V%)',
              ajudaTexto:
                  'Indica quanto do solo está ocupado por nutrientes bons (Ca, Mg, K). Se estiver baixo, precisa de calcário (Calagem).',
            ),

            const SizedBox(height: 20),

            // M.O. e Nutrientes (Sem alerta crítico de cultura por enquanto, mas com Help)
            _InputSimplesComAjuda(
                controller: _moController,
                label: 'Matéria Orgânica',
                unidade: 'g/dm³',
                ajudaTexto:
                    'A "vida" do solo. Ajuda a reter água e nutrientes. Ideal acima de 20g/dm³.'),
            const SizedBox(height: 15),
            Row(children: [
              Expanded(
                  child: _InputSimplesComAjuda(
                      controller: _fosforoController,
                      label: 'Fósforo (P)',
                      unidade: 'mg',
                      ajudaTexto: 'Energia para raízes e flores.')),
              const SizedBox(width: 15),
              Expanded(
                  child: _InputSimplesComAjuda(
                      controller: _potassioController,
                      label: 'Potássio (K)',
                      unidade: 'mmol',
                      ajudaTexto: 'Qualidade dos frutos e resistência.')),
            ]),
            const SizedBox(height: 15),
            Row(children: [
              Expanded(
                  child: _InputSimplesComAjuda(
                      controller: _calcioController,
                      label: 'Cálcio (Ca)',
                      unidade: 'mmol',
                      ajudaTexto: 'Estrutura das folhas e raízes.')),
              const SizedBox(width: 15),
              Expanded(
                  child: _InputSimplesComAjuda(
                      controller: _magnesioController,
                      label: 'Magnésio (Mg)',
                      unidade: 'mmol',
                      ajudaTexto:
                          'Essencial para a fotossíntese (cor verde).')),
            ]),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvarDados,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white),
                child: _salvando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SALVAR DIAGNÓSTICO',
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// --- O CORAÇÃO DO SISTEMA: INPUT COM MONITORAMENTO E AJUDA ---
class _InputComMonitoramento extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String unidade;
  final String cultura;
  final Map<String, double> referencias; // Mapa com ph_min, ph_max, etc.
  final String tipoDado; // 'ph' ou 'v'
  final bool obrigatorio;
  final String ajudaTitulo;
  final String ajudaTexto;

  const _InputComMonitoramento({
    required this.controller,
    required this.label,
    required this.unidade,
    required this.cultura,
    required this.referencias,
    required this.tipoDado,
    required this.ajudaTitulo,
    required this.ajudaTexto,
    this.obrigatorio = false,
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
    widget.controller.addListener(_validarEmTempoReal);
  }

  void _validarEmTempoReal() {
    final texto = widget.controller.text.replaceAll(',', '.');
    if (texto.isEmpty) {
      setState(() {
        _alerta = null;
        _corBorda = Colors.grey.shade300;
      });
      return;
    }

    double valor = double.tryParse(texto) ?? 0.0;
    String novoAlerta = '';
    Color novaCor = Colors.green; // Assume bom até provar contrário

    if (widget.tipoDado == 'ph') {
      double min = widget.referencias['ph_min']!;
      double max = widget.referencias['ph_max']!;

      if (valor < min) {
        novoAlerta =
            '⚠️ Muito Ácido para ${widget.cultura}! Pode queimar raízes e travar nutrientes. Ideal: $min - $max.';
        novaCor = Colors.red;
      } else if (valor > max) {
        novoAlerta =
            '⚠️ Muito Alcalino para ${widget.cultura}! Nutrientes ficam indisponíveis. Ideal: $min - $max.';
        novaCor = Colors.orange;
      } else {
        // Está na faixa!
        novoAlerta = '✅ Excelente para ${widget.cultura}.';
        novaCor = Colors.green;
      }
    } else if (widget.tipoDado == 'v') {
      double ideal = widget.referencias['v_ideal']!;
      // Tolerância de 10% para baixo
      if (valor < (ideal - 10)) {
        novoAlerta =
            '⚠️ Fertilidade Baixa para ${widget.cultura}. Necessário Calagem para atingir $ideal%.';
        novaCor = Colors.red;
      } else if (valor > (ideal + 10)) {
        novoAlerta = '⚠️ Fertilidade acima do necessário. Evite adubar mais.';
        novaCor = Colors.orange;
      } else {
        novoAlerta = '✅ Solo fértil para ${widget.cultura}.';
        novaCor = Colors.green;
      }
    }

    setState(() {
      _alerta = novoAlerta;
      _corBorda = novaCor;
    });
  }

  void _mostrarAjuda() {
    double idealMin = widget.tipoDado == 'ph'
        ? widget.referencias['ph_min']!
        : widget.referencias['v_ideal']!;
    double? idealMax =
        widget.tipoDado == 'ph' ? widget.referencias['ph_max']! : null;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.school, color: Colors.blue, size: 30),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(widget.ajudaTitulo,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold))),
            ]),
            const Divider(),
            Text(widget.ajudaTexto,
                style: const TextStyle(fontSize: 16, height: 1.5)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.eco, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Para ${widget.cultura}, o recomendado é:\n' +
                          (widget.tipoDado == 'ph'
                              ? 'pH entre $idealMin e $idealMax'
                              : 'V% próximo de ${idealMin.toInt()}%'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  )
                ],
              ),
            ),
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
            RichText(
              text: TextSpan(
                  text: widget.label,
                  style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                  children: [
                    if (widget.obrigatorio)
                      const TextSpan(
                          text: ' *', style: TextStyle(color: Colors.red)),
                    if (widget.unidade.isNotEmpty)
                      TextSpan(
                          text: ' (${widget.unidade})',
                          style: const TextStyle(
                              fontWeight: FontWeight.normal,
                              color: Colors.grey)),
                  ]),
            ),
            IconButton(
              icon:
                  const Icon(Icons.help_outline, size: 20, color: Colors.blue),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
              onPressed: _mostrarAjuda,
            )
          ],
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: widget.controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _corBorda)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _corBorda, width: 2)),
            suffixIcon: _alerta != null
                ? Icon(
                    _corBorda == Colors.green
                        ? Icons.check_circle
                        : Icons.warning,
                    color: _corBorda)
                : null,
          ),
          validator: (v) => (widget.obrigatorio && (v == null || v.isEmpty))
              ? 'Obrigatório'
              : null,
        ),
        if (_alerta != null)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 5),
            child: Text(_alerta!,
                style: TextStyle(
                    color: _corBorda == Colors.green
                        ? Colors.green.shade700
                        : _corBorda,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}

// --- INPUT SIMPLES APENAS COM AJUDA (SEM VALIDAÇÃO CRÍTICA) ---
class _InputSimplesComAjuda extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String unidade;
  final String ajudaTexto;

  const _InputSimplesComAjuda(
      {required this.controller,
      required this.label,
      required this.unidade,
      required this.ajudaTexto});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$label ($unidade)',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            GestureDetector(
              onTap: () {
                showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                          title: Text(label),
                          content: Text(ajudaTexto),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(c),
                                child: const Text('OK'))
                          ],
                        ));
              },
              child:
                  const Icon(Icons.help_outline, size: 16, color: Colors.grey),
            )
          ],
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade50,
            isDense: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
          ),
        )
      ],
    );
  }
}

// Widget auxiliar para opção manual (mantido igual para economizar espaço visual)
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
                Border.all(color: sel ? Colors.green : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(Icons.circle, size: 12, color: sel ? Colors.green : Colors.grey),
          const SizedBox(width: 10),
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: cor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(icon, color: cor),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 12)))
        ]));
  }
}
