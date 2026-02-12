import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TelaCalagem extends StatefulWidget {
  final String? canteiroIdOrigem;

  const TelaCalagem({super.key, this.canteiroIdOrigem});

  @override
  State<TelaCalagem> createState() => _TelaCalagemState();
}

class _TelaCalagemState extends State<TelaCalagem> {
  User? get _user => FirebaseAuth.instance.currentUser;

  bool _temLaudo = true;
  bool _salvando = false;

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
    try {
      final doc = await FirebaseFirestore.instance
          .collection('canteiros')
          .doc(id)
          .get();
      if (!doc.exists || !mounted) return;

      final data = doc.data() ?? {};
      setState(() {
        _nomeCanteiro = (data['nome'] ?? 'Canteiro').toString();
        _areaCanteiro = _toDouble(data['area_m2']);
      });
    } catch (e) {
      debugPrint("Erro ao carregar canteiro: $e");
    }
  }

  void _calcular() {
    if (_areaCanteiro <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um canteiro válido (área > 0).'),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    double v1, v2, ctc, prnt;

    if (_temLaudo) {
      v1 = _parseCtrl(_vAtualController);
      ctc = _parseCtrl(_ctcController);
      if (ctc <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preencha a CTC para calcular.')),
        );
        return;
      }
    } else {
      v1 = 40;
      if (_texturaEstimada == 'Arenoso')
        ctc = 6.0;
      else if (_texturaEstimada == 'Argiloso')
        ctc = 9.0;
      else
        ctc = 7.5;
    }

    v2 = _parseCtrl(_vDesejadoController, def: 70);
    prnt = _parseCtrl(_prntController, def: 80);

    if (prnt <= 0) prnt = 80;
    if (v2 < 0) v2 = 0;
    if (v2 > 100) v2 = 100;

    double ncTonHa = ((v2 - v1) * ctc) / prnt;
    if (ncTonHa < 0) ncTonHa = 0;

    // 1 t/ha = 100 g/m²
    final gramasPorMetro = ncTonHa * 100;
    final totalGramas = gramasPorMetro * _areaCanteiro;

    setState(() => _resultadoGramas = totalGramas);
  }

  Future<void> _registrarAplicacao() async {
    final user = _user;
    if (user == null) return;
    if (_resultadoGramas == null || _canteiroSelecionadoId == null) return;

    setState(() => _salvando = true);

    try {
      await FirebaseFirestore.instance.collection('historico_manejo').add({
        'uid_usuario': user.uid,
        'canteiro_id': _canteiroSelecionadoId,
        'nome_canteiro': _nomeCanteiro,
        'data': FieldValue.serverTimestamp(),
        'tipo_manejo': 'Adubação de Correção',
        'produto': 'Calcário',
        'quantidade_g': double.parse(_resultadoGramas!.toStringAsFixed(2)),
        'detalhes': _temLaudo
            ? 'Via Laudo Técnico'
            : 'Via Estimativa Manual ($_texturaEstimada)',
        'concluido': true,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Aplicação registrada no Caderno de Campo! 📖✅'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Calculadora de Calagem'),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Faça login para usar a calagem.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Calculadora de Calagem',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade700),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        'Use dados do seu laudo ou a estimativa pela textura do solo.',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            const Text(
              '1. Local da Aplicação',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),

            if (_bloquearSelecaoCanteiro)
              _canteiroTravado()
            else
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('canteiros')
                    .where('uid_usuario', isEqualTo: user.uid)
                    .where('ativo', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  final lista = snapshot.data!.docs;

                  if (lista.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Nenhum canteiro ativo. Crie um primeiro.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _canteiroSelecionadoId,
                      hint: const Text('Selecione um canteiro'),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 5,
                        ),
                        prefixIcon: Icon(Icons.search),
                      ),
                      items: lista.map((doc) {
                        final dados =
                            (doc.data() as Map<String, dynamic>? ?? {});
                        final nome = (dados['nome'] ?? 'Canteiro').toString();
                        final area = _toDouble(dados['area_m2']);
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text('$nome (${area.toStringAsFixed(2)} m²)'),
                        );
                      }).toList(),
                      onChanged: (id) {
                        if (id == null) return;
                        final doc = lista.firstWhere((d) => d.id == id);
                        final dados =
                            (doc.data() as Map<String, dynamic>? ?? {});
                        setState(() {
                          _canteiroSelecionadoId = id;
                          _nomeCanteiro = (dados['nome'] ?? 'Canteiro')
                              .toString();
                          _areaCanteiro = _toDouble(dados['area_m2']);
                          _resultadoGramas = null;
                        });
                      },
                    ),
                  );
                },
              ),

            const SizedBox(height: 30),

            const Text(
              '2. Dados do Solo',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Tenho Análise de Solo',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _temLaudo
                      ? 'Preencher dados técnicos (V%, CTC)'
                      : 'Usar estimativa por textura',
                ),
                value: _temLaudo,
                activeColor: Colors.green,
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _temLaudo
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _temLaudo ? Icons.science : Icons.touch_app,
                    color: _temLaudo ? Colors.green : Colors.orange,
                  ),
                ),
                onChanged: (val) => setState(() {
                  _temLaudo = val;
                  _resultadoGramas = null;
                }),
              ),
            ),

            const SizedBox(height: 20),

            if (_temLaudo) ...[
              Row(
                children: [
                  Expanded(
                    child: _InputNum(
                      controller: _vAtualController,
                      label: 'V% Atual',
                      infoTitulo: 'V% Atual',
                      infoTexto:
                          'Saturação por Bases.\n\nProcure “V%” no seu laudo.',
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _InputNum(
                      controller: _ctcController,
                      label: 'CTC (T)',
                      infoTitulo: 'CTC (T)',
                      infoTexto:
                          'Capacidade de Troca de Cátions.\n\nProcure “CTC” ou “T” no laudo.',
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text(
                'Qual a textura do seu solo?',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonFormField<String>(
                  value: _texturaEstimada,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 5,
                    ),
                    prefixIcon: Icon(Icons.grass),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Arenoso',
                      child: Text('Arenoso (Esfarela)'),
                    ),
                    DropdownMenuItem(
                      value: 'Médio',
                      child: Text('Médio / Franco'),
                    ),
                    DropdownMenuItem(
                      value: 'Argiloso',
                      child: Text('Argiloso (Barro)'),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _texturaEstimada = v ?? 'Médio'),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8.0, left: 5),
                child: Text(
                  '⚠️ Cálculo estimado baseado em médias. Use com cautela.',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _InputNum(
                    controller: _vDesejadoController,
                    label: 'V% Meta',
                    infoTitulo: 'V% Meta',
                    infoTexto:
                        'Para a maioria das hortaliças, o ideal é 70% a 80%.',
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _InputNum(
                    controller: _prntController,
                    label: 'PRNT %',
                    infoTitulo: 'PRNT',
                    infoTexto:
                        'Potência do calcário. Está no saco. Geralmente 80%.',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: _calcular,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: Colors.green.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'CALCULAR QUANTIDADE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),

            if (_resultadoGramas != null) ...[
              const SizedBox(height: 30),
              _resultadoCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _canteiroTravado() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: Colors.green[700]),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _nomeCanteiro.isNotEmpty ? _nomeCanteiro : 'Carregando...',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'Área: ${_areaCanteiro.toStringAsFixed(2)} m²',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
          const Spacer(),
          const Icon(Icons.lock, size: 18, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _resultadoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.green.shade100, width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(19),
                topRight: Radius.circular(19),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'RECOMENDAÇÃO TÉCNICA',
                  style: TextStyle(
                    color: Colors.green[800],
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              children: [
                const Text(
                  'Você deve aplicar:',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _resultadoGramas!.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.green.shade800,
                      ),
                    ),
                    Text(
                      ' g',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
                Text(
                  'de CALCÁRIO',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 15),
                _ResultRow(label: 'Local:', value: _nomeCanteiro),
                const SizedBox(height: 8),
                _ResultRow(
                  label: 'Área:',
                  value: '${_areaCanteiro.toStringAsFixed(2)} m²',
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _salvando ? null : _registrarAplicacao,
                    icon: _salvando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_alt),
                    label: Text(
                      _salvando ? 'REGISTRANDO...' : 'CONFIRMAR APLICAÇÃO',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ao clicar, isso será salvo no Caderno de Campo.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 15)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}

class _InputNum extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String infoTitulo;
  final String infoTexto;

  const _InputNum({
    required this.controller,
    required this.label,
    required this.infoTitulo,
    required this.infoTexto,
  });

  void _showInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              infoTitulo,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(infoTexto),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
        ],
        style: const TextStyle(fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[700]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.blueGrey),
            onPressed: () => _showInfo(context),
          ),
        ),
      ),
    );
  }
}
