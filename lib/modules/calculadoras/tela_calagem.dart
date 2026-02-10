import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TelaCalagem extends StatefulWidget {
  final String? canteiroIdOrigem; // Novo parâmetro

  const TelaCalagem({super.key, this.canteiroIdOrigem});

  @override
  State<TelaCalagem> createState() => _TelaCalagemState();
}

class _TelaCalagemState extends State<TelaCalagem> {
  final user = FirebaseAuth.instance.currentUser;
  
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

  @override
  void initState() {
    super.initState();
    // Se veio de um canteiro específico, configura o estado inicial
    if (widget.canteiroIdOrigem != null) {
      _canteiroSelecionadoId = widget.canteiroIdOrigem;
      _bloquearSelecaoCanteiro = true; // Impede trocar de canteiro
      _carregarDadosCanteiro(widget.canteiroIdOrigem!);
    }
  }

  // Busca o nome e área do canteiro para preencher a tela
  Future<void> _carregarDadosCanteiro(String id) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('canteiros').doc(id).get();
      if (doc.exists && mounted) {
        setState(() {
          _nomeCanteiro = doc['nome'] ?? 'Canteiro';
          _areaCanteiro = (doc['area_m2'] ?? 0).toDouble();
        });
      }
    } catch (e) {
      debugPrint("Erro ao carregar canteiro: $e");
    }
  }

  // --- CALCULAR ---
  void _calcular() {
    if (_areaCanteiro == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um canteiro ativo ou aguarde o carregamento.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    double v1, v2, ctc, prnt;

    if (_temLaudo) {
      v1 = double.tryParse(_vAtualController.text.replaceAll(',', '.')) ?? 0;
      ctc = double.tryParse(_ctcController.text.replaceAll(',', '.')) ?? 0;
    } else {
      v1 = 40; // Ácido padrão
      if (_texturaEstimada == 'Arenoso') ctc = 5.0;
      else if (_texturaEstimada == 'Argiloso') ctc = 13.0;
      else ctc = 9.0;
    }

    v2 = double.tryParse(_vDesejadoController.text.replaceAll(',', '.')) ?? 70;
    prnt = double.tryParse(_prntController.text.replaceAll(',', '.')) ?? 80;

    if (ctc == 0 && _temLaudo) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha a CTC para calcular.')));
      return;
    }

    double ncTonHa = ((v2 - v1) * ctc) / prnt;
    if (ncTonHa < 0) ncTonHa = 0;

    double gramasPorMetro = ncTonHa * 100;
    double totalGramas = gramasPorMetro * _areaCanteiro;

    setState(() {
      _resultadoGramas = totalGramas;
    });
  }

  // --- REGISTRAR NO HISTÓRICO ---
  Future<void> _registrarAplicacao() async {
    if (_resultadoGramas == null || _canteiroSelecionadoId == null) return;

    setState(() => _salvando = true);

    try {
      await FirebaseFirestore.instance.collection('historico_manejo').add({
        'uid_usuario': user?.uid,
        'canteiro_id': _canteiroSelecionadoId,
        'nome_canteiro': _nomeCanteiro,
        'data': FieldValue.serverTimestamp(),
        'tipo_manejo': 'Adubação de Correção',
        'produto': 'Calcário',
        'quantidade_g': _resultadoGramas,
        'detalhes': _temLaudo ? 'Via Laudo Técnico' : 'Via Estimativa Manual ($_texturaEstimada)',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Aplicação registrada no Caderno de Campo! 📖✅'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculadora de Calagem', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- INSTRUÇÃO ---
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Toque no ícone (?) para ajuda.',
                      style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- SELEÇÃO DE CANTEIRO ---
            const Text('1. Onde vai aplicar?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 5),
            
            // Se veio travado, mostra apenas o texto fixo
            if (_bloquearSelecaoCanteiro)
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock, size: 18, color: Colors.grey),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _nomeCanteiro.isNotEmpty ? '$_nomeCanteiro ($_areaCanteiro m²)' : 'Carregando...',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              )
            else
              StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('canteiros')
                    .where('uid_usuario', isEqualTo: user?.uid)
                    .where('ativo', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  var lista = snapshot.data!.docs;
                  
                  if (lista.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                      child: const Text('Nenhum canteiro ativo. Crie um primeiro.', style: TextStyle(color: Colors.orange)),
                    );
                  }

                  return DropdownButtonFormField<String>(
                    value: _canteiroSelecionadoId,
                    hint: const Text('Selecione um canteiro ativo'),
                    decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                    items: lista.map((doc) {
                      var dados = doc.data();
                      return DropdownMenuItem<String>(
                        value: doc.id,
                        child: Text('${dados['nome']} (${dados['area_m2']} m²)'),
                        onTap: () {
                          setState(() {
                            _areaCanteiro = double.tryParse(dados['area_m2'].toString()) ?? 0;
                            _nomeCanteiro = dados['nome'];
                            _resultadoGramas = null;
                          });
                        },
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _canteiroSelecionadoId = v),
                  );
                },
              ),
            const SizedBox(height: 25),

            // --- MODO ---
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SwitchListTile(
                title: const Text('Tenho Análise de Solo', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_temLaudo ? 'Preencher dados do papel' : 'Usar estimativa manual'),
                value: _temLaudo,
                activeColor: Colors.green,
                secondary: Icon(_temLaudo ? Icons.science : Icons.back_hand, color: _temLaudo ? Colors.green : Colors.orange),
                onChanged: (val) => setState(() {
                  _temLaudo = val;
                  _resultadoGramas = null;
                }),
              ),
            ),
            const SizedBox(height: 20),

            // --- INPUTS ---
            if (_temLaudo) ...[
              Row(
                children: [
                  Expanded(
                    child: _InputNum(
                      controller: _vAtualController, 
                      label: 'V% Atual', 
                      info: 'Saturação por Bases.\n\nIndica o quanto seu solo está "cheio" de nutrientes bons. Olhe no seu laudo de solo a sigla "V%".'
                    )
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _InputNum(
                      controller: _ctcController, 
                      label: 'CTC (T)', 
                      info: 'Capacidade de Troca de Cátions.\n\nÉ o tamanho do "estômago" do seu solo. Quanto maior, mais adubo ele segura. Procure por "CTC" ou "T" no laudo.'
                    )
                  ),
                ],
              ),
            ] else ...[
              const Text('Qual a textura do seu solo?', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              DropdownButtonFormField<String>(
                value: _texturaEstimada,
                decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'Arenoso', child: Text('Arenoso (Esfarela)')),
                  DropdownMenuItem(value: 'Médio', child: Text('Médio / Franco')),
                  DropdownMenuItem(value: 'Argiloso', child: Text('Argiloso (Barro)')),
                ],
                onChanged: (v) => setState(() => _texturaEstimada = v!),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('⚠️ Cálculo estimado. Use com cautela.', style: TextStyle(color: Colors.orange, fontSize: 12)),
              ),
            ],

            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: _InputNum(
                    controller: _vDesejadoController, 
                    label: 'V% Meta', 
                    info: 'Quanto você quer atingir?\n\nPara a maioria das hortaliças (Alface, Couve, Tomate), o ideal é entre 70% e 80%.'
                  )
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _InputNum(
                    controller: _prntController, 
                    label: 'PRNT %', 
                    info: 'Poder Relativo de Neutralização Total.\n\nÉ a "potência" do calcário que você comprou. Está escrito bem grande no saco do produto. Geralmente é 80%.'
                  )
                ),
              ],
            ),

            const SizedBox(height: 30),
            
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _calcular,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('CALCULAR QUANTIDADE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),

            // --- RESULTADO ---
            if (_resultadoGramas != null) ...[
              const SizedBox(height: 30),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1), // NOVO FLUTTER
                      blurRadius: 10, 
                      offset: const Offset(0, 5)
                    )
                  ],
                  border: Border.all(color: Colors.green.shade200, width: 2),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(13), topRight: Radius.circular(13)),
                      ),
                      child: const Text(
                        'RECOMENDAÇÃO TÉCNICA',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text('Você deve aplicar:', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 5),
                          Text(
                            '${_resultadoGramas!.toStringAsFixed(0)} g',
                            style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.green.shade800),
                          ),
                          const Text('de CALCÁRIO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 10),
                          const Divider(),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Local:', style: TextStyle(color: Colors.grey[600])),
                              Text(_nomeCanteiro, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Área:', style: TextStyle(color: Colors.grey[600])),
                              Text('${_areaCanteiro.toStringAsFixed(2)} m²', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _salvando ? null : _registrarAplicacao,
                              icon: _salvando 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                                : const Icon(Icons.check_circle_outline),
                              label: Text(_salvando ? 'REGISTRANDO...' : 'CONFIRMAR APLICAÇÃO'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Ao clicar, isso será salvo no Caderno de Campo.',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

class _InputNum extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String info; 
  
  const _InputNum({required this.controller, required this.label, required this.info});
  
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
        suffixIcon: Tooltip(
          message: info,
          triggerMode: TooltipTriggerMode.tap,
          showDuration: const Duration(seconds: 6),
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.blueGrey[900],
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(color: Colors.white, fontSize: 14),
          child: const Icon(Icons.help_outline, color: Colors.blueGrey),
        ),
      ),
    );
  }
}