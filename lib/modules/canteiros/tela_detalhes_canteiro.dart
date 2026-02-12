import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../solo/tela_diagnostico.dart';
import '../calculadoras/tela_calagem.dart';

class TelaDetalhesCanteiro extends StatefulWidget {
  final String canteiroId;
  const TelaDetalhesCanteiro({super.key, required this.canteiroId});

  @override
  State<TelaDetalhesCanteiro> createState() => _TelaDetalhesCanteiroState();
}

class _TelaDetalhesCanteiroState extends State<TelaDetalhesCanteiro> {
  final _nomeController = TextEditingController();
  final _compController = TextEditingController();
  final _largController = TextEditingController();

  bool get _enableHardDelete => kDebugMode;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  void _snack(String msg, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bg,
      ),
    );
  }

  Widget _buildFirestoreError(Object? error) {
    final msg = (error ?? 'Erro desconhecido').toString();
    final isIndex = msg.toLowerCase().contains('requires an index') ||
        msg.toLowerCase().contains('create it here');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isIndex ? Colors.orange.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isIndex ? Colors.orange.shade200 : Colors.red.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isIndex
                ? '⚠️ Falta criar um índice no Firestore'
                : '❌ Erro no Firestore',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isIndex ? Colors.orange.shade900 : Colors.red.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isIndex
                ? 'Sua consulta usa WHERE + ORDER BY e precisa de índice composto.\n'
                    'Crie o índice para "historico_manejo" com (canteiro_id ASC, data DESC).'
                : msg,
            style: TextStyle(
              color: isIndex ? Colors.orange.shade900 : Colors.red.shade900,
              fontSize: 12,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // --- BASE TÉCNICA (MANTIDA) ---
  final Map<String, Map<String, dynamic>> _guiaCompleto = {
    'Abobrinha italiana': {
      'cat': 'Frutos',
      'par': 'Milho, Feijão',
      'evitar': 'Batata',
      'ciclo': 55,
      'eLinha': 1.0,
      'ePlanta': 0.7
    },
    'Abobrinha brasileira': {
      'cat': 'Frutos',
      'par': 'Milho, Feijão',
      'evitar': 'Batata',
      'ciclo': 60,
      'eLinha': 2.0,
      'ePlanta': 2.0
    },
    'Abóboras e morangas': {
      'cat': 'Frutos',
      'par': 'Milho, Feijão',
      'evitar': 'Batata',
      'ciclo': 120,
      'eLinha': 3.0,
      'ePlanta': 2.0
    },
    'Acelga': {
      'cat': 'Folhas',
      'par': 'Alface, Couve',
      'evitar': 'Nenhum',
      'ciclo': 60,
      'eLinha': 0.45,
      'ePlanta': 0.5
    },
    'Agrião': {
      'cat': 'Folhas',
      'par': 'Nenhum',
      'evitar': 'Nenhum',
      'ciclo': 50,
      'eLinha': 0.2,
      'ePlanta': 0.3
    },
    'Salsão (Aipo)': {
      'cat': 'Temperos',
      'par': 'Tomate, Feijão',
      'evitar': 'Milho',
      'ciclo': 100,
      'eLinha': 0.9,
      'ePlanta': 0.4
    },
    'Alface': {
      'cat': 'Folhas',
      'par': 'Cenoura, Rabanete',
      'evitar': 'Salsa',
      'ciclo': 45,
      'eLinha': 0.25,
      'ePlanta': 0.3
    },
    'Alho': {
      'cat': 'Bulbos',
      'par': 'Tomate, Cenoura',
      'evitar': 'Feijão',
      'ciclo': 180,
      'eLinha': 0.25,
      'ePlanta': 0.1
    },
    'Alho poró': {
      'cat': 'Bulbos',
      'par': 'Cenoura, Tomate',
      'evitar': 'Feijão',
      'ciclo': 120,
      'eLinha': 0.4,
      'ePlanta': 0.2
    },
    'Almeirão': {
      'cat': 'Folhas',
      'par': 'Alface, Cenoura',
      'evitar': 'Nenhum',
      'ciclo': 70,
      'eLinha': 0.25,
      'ePlanta': 0.25
    },
    'Batata doce': {
      'cat': 'Raízes',
      'par': 'Abóbora',
      'evitar': 'Tomate',
      'ciclo': 120,
      'eLinha': 0.9,
      'ePlanta': 0.3
    },
    'Berinjela': {
      'cat': 'Frutos',
      'par': 'Feijão, Alho',
      'evitar': 'Nenhum',
      'ciclo': 110,
      'eLinha': 1.0,
      'ePlanta': 0.8
    },
    'Beterraba': {
      'cat': 'Raízes',
      'par': 'Cebola, Alface',
      'evitar': 'Milho',
      'ciclo': 70,
      'eLinha': 0.25,
      'ePlanta': 0.1
    },
    'Brócolis': {
      'cat': 'Flores',
      'par': 'Beterraba, Cebola',
      'evitar': 'Morango',
      'ciclo': 100,
      'eLinha': 0.8,
      'ePlanta': 0.5
    },
    'Cará (Inhame)': {
      'cat': 'Raízes',
      'par': 'Nenhum',
      'evitar': 'Nenhum',
      'ciclo': 240,
      'eLinha': 0.8,
      'ePlanta': 0.4
    },
    'Cebola': {
      'cat': 'Bulbos',
      'par': 'Beterraba, Tomate',
      'evitar': 'Feijão',
      'ciclo': 140,
      'eLinha': 0.3,
      'ePlanta': 0.1
    },
    'Cebolinha': {
      'cat': 'Temperos',
      'par': 'Cenoura, Morango',
      'evitar': 'Feijão',
      'ciclo': 60,
      'eLinha': 0.25,
      'ePlanta': 0.2
    },
    'Cenoura': {
      'cat': 'Raízes',
      'par': 'Alface, Tomate',
      'evitar': 'Salsa',
      'ciclo': 100,
      'eLinha': 0.25,
      'ePlanta': 0.1
    },
    'Chicória': {
      'cat': 'Folhas',
      'par': 'Alface, Rúcula',
      'evitar': 'Nenhum',
      'ciclo': 70,
      'eLinha': 0.3,
      'ePlanta': 0.3
    },
    'Chuchu': {
      'cat': 'Frutos',
      'par': 'Abóbora, Milho',
      'evitar': 'Nenhum',
      'ciclo': 120,
      'eLinha': 5.0,
      'ePlanta': 5.0
    },
    'Coentro': {
      'cat': 'Temperos',
      'par': 'Tomate',
      'evitar': 'Cenoura',
      'ciclo': 50,
      'eLinha': 0.2,
      'ePlanta': 0.2
    },
    'Couve de folha': {
      'cat': 'Folhas',
      'par': 'Alecrim, Sálvia',
      'evitar': 'Morango, Tomate',
      'ciclo': 80,
      'eLinha': 0.8,
      'ePlanta': 0.5
    },
    'Ervilha': {
      'cat': 'Leguminosas',
      'par': 'Cenoura, Milho',
      'evitar': 'Alho',
      'ciclo': 80,
      'eLinha': 1.0,
      'ePlanta': 0.5
    },
    'Jiló': {
      'cat': 'Frutos',
      'par': 'Berinjela, Pimentão',
      'evitar': 'Nenhum',
      'ciclo': 100,
      'eLinha': 1.2,
      'ePlanta': 1.0
    },
    'Mandioca': {
      'cat': 'Raízes',
      'par': 'Feijão, Milho',
      'evitar': 'Nenhum',
      'ciclo': 300,
      'eLinha': 3.0,
      'ePlanta': 2.0
    },
    'Melancia': {
      'cat': 'Frutos',
      'par': 'Milho',
      'evitar': 'Nenhum',
      'ciclo': 90,
      'eLinha': 3.0,
      'ePlanta': 2.0
    },
    'Melão': {
      'cat': 'Frutos',
      'par': 'Milho',
      'evitar': 'Nenhum',
      'ciclo': 90,
      'eLinha': 2.0,
      'ePlanta': 1.5
    },
    'Morango': {
      'cat': 'Frutos',
      'par': 'Cebola, Alho',
      'evitar': 'Couve',
      'ciclo': 80,
      'eLinha': 0.35,
      'ePlanta': 0.35
    },
    'Pepino': {
      'cat': 'Frutos',
      'par': 'Feijão, Milho',
      'evitar': 'Tomate',
      'ciclo': 60,
      'eLinha': 1.0,
      'ePlanta': 0.5
    },
    'Pimenta': {
      'cat': 'Temperos',
      'par': 'Manjericão, Tomate',
      'evitar': 'Feijão',
      'ciclo': 100,
      'eLinha': 1.0,
      'ePlanta': 0.5
    },
    'Pimentão': {
      'cat': 'Frutos',
      'par': 'Manjericão, Cebola',
      'evitar': 'Feijão',
      'ciclo': 100,
      'eLinha': 1.0,
      'ePlanta': 0.5
    },
    'Quiabo': {
      'cat': 'Frutos',
      'par': 'Pimentão, Tomate',
      'evitar': 'Nenhum',
      'ciclo': 80,
      'eLinha': 1.0,
      'ePlanta': 0.3
    },
    'Repolho': {
      'cat': 'Folhas',
      'par': 'Beterraba, Cebola',
      'evitar': 'Morango',
      'ciclo': 100,
      'eLinha': 0.8,
      'ePlanta': 0.4
    },
    'Rúcula': {
      'cat': 'Folhas',
      'par': 'Alface, Beterraba',
      'evitar': 'Repolho',
      'ciclo': 40,
      'eLinha': 0.2,
      'ePlanta': 0.1
    },
    'Tomate': {
      'cat': 'Frutos',
      'par': 'Manjericão, Alho',
      'evitar': 'Batata',
      'ciclo': 110,
      'eLinha': 1.0,
      'ePlanta': 0.3
    },
  };

  final Map<String, Map<String, List<String>>> _calendarioRegional = {
    'Sul': {
      'Fevereiro': [
        'Alface',
        'Beterraba',
        'Cebolinha',
        'Couve de folha',
        'Cenoura',
        'Tomate',
        'Pepino',
        'Repolho'
      ]
    },
    'Sudeste': {
      'Fevereiro': [
        'Alface',
        'Beterraba',
        'Berinjela',
        'Cebolinha',
        'Couve de folha',
        'Tomate',
        'Quiabo',
        'Pimentão'
      ]
    },
    'Nordeste': {
      'Fevereiro': [
        'Alface',
        'Berinjela',
        'Cenoura',
        'Quiabo',
        'Pepino',
        'Pimenta',
        'Tomate'
      ]
    },
    'Centro-Oeste': {
      'Fevereiro': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Almeirão',
        'Berinjela',
        'Cebola',
        'Brócolis',
        'Couve de folha'
      ]
    },
    'Norte': {
      'Fevereiro': [
        'Alface',
        'Batata doce',
        'Cenoura',
        'Quiabo',
        'Couve de folha',
        'Cebola'
      ]
    },
  };

  @override
  void dispose() {
    _nomeController.dispose();
    _compController.dispose();
    _largController.dispose();
    super.dispose();
  }

  // --- NAVEGAÇÃO ---
  void _irParaDiagnostico() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaDiagnostico(canteiroIdOrigem: widget.canteiroId),
      ),
    ).then((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  void _irParaCalagem() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaCalagem(canteiroIdOrigem: widget.canteiroId),
      ),
    );
  }

  // --- LÓGICA DE CORES E STATUS ---
  Color _getCorStatus(String status) {
    if (status == 'ocupado') return Colors.red.shade50;
    if (status == 'manutencao') return Colors.orange.shade50;
    return Colors.green.shade50;
  }

  Color _getCorAppBar(String status) {
    if (status == 'ocupado') return Colors.red.shade700;
    if (status == 'manutencao') return Colors.orange.shade800;
    return Theme.of(context).colorScheme.primary;
  }

  String _getTextoStatus(String status) {
    if (status == 'ocupado') return 'EM PRODUÇÃO (OCUPADO)';
    if (status == 'manutencao') return 'EM MANUTENÇÃO / DESCANSO';
    return 'DISPONÍVEL PARA PLANTIO';
  }

  Future<void> _atualizarStatusCanteiro(String novoStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('canteiros')
          .doc(widget.canteiroId)
          .update({'status': novoStatus});
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      _snack('❌ Falha ao atualizar status: $e', bg: Colors.red);
    }
  }

  void _editarNomeCanteiro(String nomeAtual) {
    final controller = TextEditingController(text: nomeAtual);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renomear'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nome',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final novoNome = controller.text.trim();
              if (novoNome.isEmpty) {
                _snack('⚠️ Informe um nome.', bg: Colors.orange);
                return;
              }
              try {
                await FirebaseFirestore.instance
                    .collection('canteiros')
                    .doc(widget.canteiroId)
                    .update({'nome': novoNome});
                if (!mounted) return;
                Navigator.pop(ctx);
              } catch (e) {
                _snack('❌ Falha ao renomear: $e', bg: Colors.red);
              }
            },
            child: const Text('Salvar'),
          )
        ],
      ),
    );
  }

  // --- IRRIGAÇÃO ---
  void _mostrarDialogoIrrigacao() {
    if (_uid == null) {
      _snack('⚠️ Você precisa estar logado.', bg: Colors.orange);
      return;
    }

    String metodo = 'Gotejamento';
    final tempoController = TextEditingController(text: '30');
    final chuvaController = TextEditingController(text: '0');
    final custoController = TextEditingController(text: '0.00');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Row(children: [
              Icon(Icons.water_drop, color: Colors.blue, size: 28),
              SizedBox(width: 10),
              Text(
                'Irrigação',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              )
            ]),
            const SizedBox(height: 20),
            TextField(
              controller: chuvaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Choveu hoje? (mm)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.cloud),
              ),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: metodo,
              items: ['Manual', 'Gotejamento', 'Aspersão']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => metodo = v ?? metodo,
              decoration: const InputDecoration(
                labelText: 'Sistema',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: tempoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tempo (min)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timer),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: custoController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Custo Operacional (R\$)',
                hintText: 'Água, Luz...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final tempo = int.tryParse(tempoController.text) ?? 0;
                  final chuva = double.tryParse(
                          chuvaController.text.replaceAll(',', '.')) ??
                      0.0;
                  final custo = double.tryParse(
                          custoController.text.replaceAll(',', '.')) ??
                      0.0;

                  Navigator.pop(ctx);
                  await _salvarIrrigacao(metodo, tempo, chuva, custo);
                },
                child: const Text('SALVAR IRRIGAÇÃO'),
              ),
            )
          ]),
        ),
      ),
    );
  }

  Future<void> _salvarIrrigacao(
      String metodo, int tempo, double chuva, double custo) async {
    if (_uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('historico_manejo').add({
        'canteiro_id': widget.canteiroId,
        'uid_usuario': _uid,
        'data': FieldValue.serverTimestamp(),
        'tipo_manejo': 'Irrigação',
        'produto': metodo,
        'detalhes': 'Duração: $tempo min | Chuva: ${chuva}mm',
        'quantidade_g': 0,
        'custo': custo,
      });
    } catch (e) {
      _snack('❌ Falha ao salvar irrigação: $e', bg: Colors.red);
    }
  }

  // --- COLHEITA ---
  void _mostrarDialogoColheitaSeletiva(
    String idHistorico,
    String produtosString,
    Map<String, dynamic> mapaPlantioOriginal,
  ) {
    final culturasAtivas =
        produtosString.split(' + ').where((e) => e.trim().isNotEmpty).toList();
    final selecionadosParaColher = <String, bool>{};
    final controllers = <String, TextEditingController>{};
    final valorVendaController = TextEditingController(text: '0.00');

    for (final c in culturasAtivas) {
      selecionadosParaColher[c] = false;
      controllers[c] = TextEditingController();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (contextModal, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(contextModal).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Registrar Colheita',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green),
                ),
                const Text('Informe o que foi colhido e o valor de venda.',
                    style: TextStyle(color: Colors.grey)),
                const Divider(),
                const SizedBox(height: 10),
                ...culturasAtivas.map((cultura) {
                  final maxPlantado = _toInt(mapaPlantioOriginal[cultura]);
                  return Column(
                    children: [
                      CheckboxListTile(
                        title: Text(
                          '$cultura (Plantado: ${maxPlantado == 0 ? "?" : maxPlantado})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        value: selecionadosParaColher[cultura],
                        activeColor: Colors.green,
                        onChanged: (val) => setModalState(() =>
                            selecionadosParaColher[cultura] = val ?? false),
                      ),
                      if (selecionadosParaColher[cultura] == true)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: TextField(
                            controller: controllers[cultura],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Qtd Colhida',
                              isDense: true,
                              border: const OutlineInputBorder(),
                              errorText: _validarQtdColheita(
                                controllers[cultura]!.text,
                                maxPlantado == 0 ? 999999 : maxPlantado,
                              ),
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                      const Divider(),
                    ],
                  );
                }),
                const SizedBox(height: 10),
                TextField(
                  controller: valorVendaController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Receita Total da Venda (R\$)',
                    prefixIcon: Icon(Icons.monetization_on),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => _processarColheita(
                      ctx,
                      idHistorico,
                      selecionadosParaColher,
                      controllers,
                      valorVendaController.text,
                      mapaPlantioOriginal,
                    ),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('FINALIZAR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validarQtdColheita(String texto, int maximo) {
    if (texto.isEmpty) return null;
    final qtd = int.tryParse(texto) ?? 0;
    if (qtd <= 0) return "Informe um número > 0";
    if (qtd > maximo) return "Erro: Maior que o plantado ($maximo)";
    return null;
  }

  Future<void> _processarColheita(
    BuildContext ctx,
    String idHistorico,
    Map<String, bool> selecionados,
    Map<String, TextEditingController> ctrls,
    String valorVendaStr,
    Map<String, dynamic> mapaPlantio,
  ) async {
    if (_uid == null) {
      _snack('⚠️ Você precisa estar logado.', bg: Colors.orange);
      return;
    }

    final colhidosAgora = <String>[];
    final restamNoCanteiro = <String>[];
    var resumoColheita = "";
    var erroValidacao = false;

    selecionados.forEach((cultura, colheu) {
      if (colheu) {
        final qtd = int.tryParse(ctrls[cultura]?.text ?? '0') ?? 0;
        final max = _toInt(mapaPlantio[cultura]);
        final maxSafe = max == 0 ? 999999 : max;

        if (qtd <= 0) erroValidacao = true;
        if (qtd > maxSafe) erroValidacao = true;

        colhidosAgora.add(cultura);
        resumoColheita += "$cultura ($qtd un) ";
      } else {
        restamNoCanteiro.add(cultura);
      }
    });

    if (erroValidacao) {
      _snack('❌ Erro: verifique as quantidades colhidas.', bg: Colors.red);
      return;
    }

    if (colhidosAgora.isEmpty) {
      if (!mounted) return;
      Navigator.pop(ctx);
      return;
    }

    final receita = double.tryParse(valorVendaStr.replaceAll(',', '.')) ?? 0.0;

    try {
      // 1) Registro de Colheita
      await FirebaseFirestore.instance.collection('historico_manejo').add({
        'canteiro_id': widget.canteiroId,
        'uid_usuario': _uid,
        'data': FieldValue.serverTimestamp(),
        'tipo_manejo': 'Colheita',
        'produto': colhidosAgora.join(' + '),
        'detalhes': 'Colheita: $resumoColheita',
        'concluido': true,
        'receita': receita,
      });

      // 2) Atualiza Ciclo Original
      if (restamNoCanteiro.isEmpty) {
        await FirebaseFirestore.instance
            .collection('historico_manejo')
            .doc(idHistorico)
            .update({
          'concluido': true,
          'observacao_extra': 'Ciclo Finalizado. $resumoColheita',
        });
        await _atualizarStatusCanteiro('livre');
      } else {
        await FirebaseFirestore.instance
            .collection('historico_manejo')
            .doc(idHistorico)
            .update({
          'produto': restamNoCanteiro.join(' + '),
        });
      }

      if (!mounted) return;
      Navigator.pop(ctx);
      _snack(
        restamNoCanteiro.isEmpty
            ? '✅ Canteiro esvaziado! Receita registrada.'
            : '✅ Colheita parcial registrada!',
        bg: Colors.green,
      );
    } catch (e) {
      _snack('❌ Falha ao processar colheita: $e', bg: Colors.red);
    }
  }

  // --- EDITAR / BAIXA ---
  void _mostrarDialogoPerdaOuEditar(
      String id, String detalheAtual, String obsAtual) {
    final detalheCtrl = TextEditingController(text: detalheAtual);
    final obsCtrl = TextEditingController(text: obsAtual);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar ou Registrar Perda'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              'Ajuste a quantidade atual de plantas (Ex: Se morreram 2, diminua o número).',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: detalheCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Resumo do Plantio (Qtd)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: obsCtrl,
              decoration: const InputDecoration(
                labelText: 'Motivo da Baixa / Obs',
                border: OutlineInputBorder(),
                hintText: 'Ex: Formigas comeram 2 mudas',
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('historico_manejo')
                    .doc(id)
                    .update({
                  'detalhes': detalheCtrl.text,
                  'observacao_extra': obsCtrl.text,
                });
                if (!mounted) return;
                Navigator.pop(ctx);
                _snack('✅ Registro atualizado!', bg: Colors.green);
              } catch (e) {
                _snack('❌ Falha ao atualizar: $e', bg: Colors.red);
              }
            },
            child: const Text('Salvar Alterações'),
          ),
        ],
      ),
    );
  }

  // --- PLANTIO ---
  void _mostrarDialogoPlantio(double cCanteiro, double lCanteiro) {
    if (_uid == null) {
      _snack('⚠️ Você precisa estar logado.', bg: Colors.orange);
      return;
    }

    if (cCanteiro <= 0 || lCanteiro <= 0) {
      _snack(
          '⚠️ Comprimento/largura inválidos. Edite o canteiro e corrija as medidas.',
          bg: Colors.orange);
      return;
    }

    final qtdPorPlanta = <String, int>{};
    const regiao = 'Sudeste';
    const mes = 'Fevereiro';
    final obsController = TextEditingController();
    final custoMudasController = TextEditingController(text: '0.00');

    final areaTotalCanteiro = cCanteiro * lCanteiro;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (contextModal, setModalState) {
          double areaOcupada = 0.0;

          qtdPorPlanta.forEach((planta, qtd) {
            final info =
                _guiaCompleto[planta] ?? {'eLinha': 0.5, 'ePlanta': 0.5};
            final eLinha = (info['eLinha'] as num).toDouble();
            final ePlanta = (info['ePlanta'] as num).toDouble();
            areaOcupada += (qtd * (eLinha * ePlanta));
          });

          final percentualOcupado =
              (areaOcupada / areaTotalCanteiro).clamp(0.0, 1.0);
          final estourou = (areaTotalCanteiro - areaOcupada) < 0;

          void adicionarPlanta(String p) {
            final info = _guiaCompleto[p] ?? {'eLinha': 0.5, 'ePlanta': 0.5};
            final eLinha = (info['eLinha'] as num).toDouble();
            final ePlanta = (info['ePlanta'] as num).toDouble();
            final areaUnit = (eLinha * ePlanta).clamp(0.0001, 999999.0);

            int qtdInicial = (areaTotalCanteiro / areaUnit).floor();
            if (qtdPorPlanta.isNotEmpty &&
                (areaTotalCanteiro - areaOcupada) > 0) {
              qtdInicial =
                  ((areaTotalCanteiro - areaOcupada) / areaUnit).floor();
            }
            if (qtdInicial < 1) qtdInicial = 1;
            qtdPorPlanta[p] = qtdInicial;
          }

          final recomendadas =
              List<String>.from(_calendarioRegional[regiao]?[mes] ?? const []);

          final porCategoria = <String, List<String>>{};
          for (final p in recomendadas) {
            final cat = (_guiaCompleto[p]?['cat'] ?? 'Outros').toString();
            porCategoria.putIfAbsent(cat, () => []);
            porCategoria[cat]!.add(p);
          }

          final outras = _guiaCompleto.keys
              .where((c) => !recomendadas.contains(c))
              .toList()
            ..sort();
          final outrasPorCategoria = <String, List<String>>{};
          for (final p in outras) {
            final cat = (_guiaCompleto[p]?['cat'] ?? 'Outros').toString();
            outrasPorCategoria.putIfAbsent(cat, () => []);
            outrasPorCategoria[cat]!.add(p);
          }

          Widget buildChip(String planta, bool isRecommended) {
            final isSel = qtdPorPlanta.containsKey(planta);
            return FilterChip(
              label: Text(planta),
              selected: isSel,
              checkmarkColor: Colors.white,
              selectedColor: isRecommended ? Colors.green : Colors.orange,
              backgroundColor: Colors.grey.shade100,
              labelStyle: TextStyle(
                  fontSize: 11, color: isSel ? Colors.white : Colors.black87),
              onSelected: (v) {
                setModalState(() {
                  if (v) {
                    adicionarPlanta(planta);
                    if (!isRecommended) {
                      _snack('⚠️ Atenção: Fora de época!', bg: Colors.orange);
                    }
                  } else {
                    qtdPorPlanta.remove(planta);
                  }
                });
              },
            );
          }

          return Container(
            height: MediaQuery.of(contextModal).size.height * 0.95,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text('Planejamento de Plantio',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Divider(),
                LinearProgressIndicator(
                    value: percentualOcupado,
                    color: estourou ? Colors.red : Colors.green),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            color: Colors.green.shade50,
                            child: Text(
                              '✅ Recomendados:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800),
                            ),
                          ),
                          ...porCategoria.entries.map(
                            (e) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 8, bottom: 4),
                                  child: Text(
                                    e.key.toUpperCase(),
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey),
                                  ),
                                ),
                                Wrap(
                                  spacing: 5,
                                  children: e.value
                                      .map((p) => buildChip(p, true))
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                          Theme(
                            data: Theme.of(contextModal)
                                .copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              title: const Text(
                                '⚠️ Outras Culturas (Fora de Época)',
                                style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                              children: [
                                ...outrasPorCategoria.entries.map(
                                  (e) => Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 8, bottom: 4),
                                        child: Text(
                                          e.key.toUpperCase(),
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange.shade300),
                                        ),
                                      ),
                                      Wrap(
                                        spacing: 5,
                                        children: e.value
                                            .map((p) => buildChip(p, false))
                                            .toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (qtdPorPlanta.isNotEmpty) ...[
                            const Divider(),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(children: [
                                const Text('Ajuste a Quantidade de Mudas:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 10),
                                ...qtdPorPlanta.entries.map((entry) {
                                  return Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          entry.key,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle,
                                            color: Colors.red),
                                        onPressed: () => setModalState(() {
                                          if (entry.value > 1) {
                                            qtdPorPlanta[entry.key] =
                                                entry.value - 1;
                                          }
                                        }),
                                      ),
                                      Text('${entry.value}',
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle,
                                            color: Colors.green),
                                        onPressed: () => setModalState(() {
                                          qtdPorPlanta[entry.key] =
                                              entry.value + 1;
                                        }),
                                      ),
                                    ],
                                  );
                                }),
                              ]),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: obsController,
                              decoration: const InputDecoration(
                                labelText: 'Observação do Plantio',
                                border: OutlineInputBorder(),
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 10),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: custoMudasController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Custo de Mudas/Sementes (R\$)',
                                prefixIcon: Icon(Icons.monetization_on),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ]),
                  ),
                ),
                if (qtdPorPlanta.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: estourou
                          ? null
                          : () async {
                              try {
                                var resumo = "Plantio ($regiao/$mes):\n";
                                final nomes = <String>[];

                                qtdPorPlanta.forEach((planta, qtd) {
                                  nomes.add(planta);
                                  final ciclo = _toInt(
                                      _guiaCompleto[planta]?['ciclo'] ?? 90);
                                  resumo +=
                                      "- $planta: $qtd mudas ($ciclo dias)\n";
                                });

                                final custo = double.tryParse(
                                        custoMudasController.text
                                            .replaceAll(',', '.')) ??
                                    0.0;

                                await FirebaseFirestore.instance
                                    .collection('historico_manejo')
                                    .add({
                                  'canteiro_id': widget.canteiroId,
                                  'uid_usuario': _uid,
                                  'data': FieldValue.serverTimestamp(),
                                  'tipo_manejo': 'Plantio',
                                  'produto': nomes.join(' + '),
                                  'detalhes': resumo,
                                  'observacao_extra': obsController.text,
                                  'quantidade_g': 0,
                                  'concluido': false,
                                  'custo': custo,
                                  'mapa_plantio': qtdPorPlanta,
                                });

                                await _atualizarStatusCanteiro('ocupado');
                                if (!mounted) return;
                                Navigator.pop(ctx);
                                _snack(
                                    '✅ Plantio registrado! Canteiro agora está OCUPADO.',
                                    bg: Colors.green);
                              } catch (e) {
                                _snack('❌ Falha ao registrar plantio: $e',
                                    bg: Colors.red);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: estourou
                            ? Colors.grey
                            : Theme.of(contextModal).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(estourou
                          ? 'FALTA ESPAÇO NO CANTEIRO'
                          : 'CONFIRMAR PLANTIO'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _mostrarOpcoesManejo(double c, double l, String statusAtual) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(20),
        height: 380,
        child: Column(children: [
          const Text('Menu de Operações',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: 1.4,
              children: [
                _CardMenu(
                  icon: Icons.water_drop,
                  color: Colors.blue,
                  title: 'Irrigação',
                  subtitle: 'Regar',
                  onTap: () {
                    Navigator.pop(ctx);
                    _mostrarDialogoIrrigacao();
                  },
                ),
                _CardMenu(
                  icon: Icons.spa,
                  color: (statusAtual == 'livre') ? Colors.green : Colors.grey,
                  title: 'Novo Plantio',
                  subtitle: (statusAtual == 'livre') ? 'Planejar' : 'Bloqueado',
                  onTap: () {
                    Navigator.pop(ctx);
                    if (statusAtual != 'livre') {
                      _snack('⚠️ Colha tudo antes de plantar!',
                          bg: Colors.orange);
                      return;
                    }
                    _mostrarDialogoPlantio(c, l);
                  },
                ),
                _CardMenu(
                  icon: Icons.science,
                  color: Colors.brown,
                  title: 'Análise Solo',
                  subtitle: 'Registrar',
                  onTap: () {
                    Navigator.pop(ctx);
                    _irParaDiagnostico();
                  },
                ),
                _CardMenu(
                  icon: Icons.landscape,
                  color: Colors.orange,
                  title: 'Calagem',
                  subtitle: 'Calcular',
                  onTap: () {
                    Navigator.pop(ctx);
                    _irParaCalagem();
                  },
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // --- DASHBOARD ---
  Widget _buildDashboard(
      Map<String, dynamic> dados, double area, String status) {
    final corFundo = _getCorStatus(status);
    final corTexto = (status == 'livre')
        ? Colors.green.shade900
        : (status == 'manutencao'
            ? Colors.orange.shade900
            : Colors.red.shade900);
    final textoStatus = _getTextoStatus(status);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('historico_manejo')
          .where('canteiro_id', isEqualTo: widget.canteiroId)
          .orderBy('data', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildFirestoreError(snapshot.error);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(15),
            child: LinearProgressIndicator(),
          );
        }

        String? docIdPlantioAtivo;
        String produtosPlantados = "";
        Map<String, dynamic> mapaPlantio = {};
        Timestamp? dataPlantio;

        double custoTotal = 0.0;
        double receitaTotal = 0.0;

        final docs = snapshot.data?.docs ?? [];

        for (final doc in docs) {
          final d = (doc.data() as Map<String, dynamic>?) ?? {};

          if (d['tipo_manejo'] == 'Plantio' && d['concluido'] == false) {
            docIdPlantioAtivo = doc.id;
            produtosPlantados = (d['produto'] ?? '').toString();

            final mp = d['mapa_plantio'];
            if (mp is Map) {
              mapaPlantio = Map<String, dynamic>.from(mp);
            } else {
              mapaPlantio = {};
            }

            final ts = d['data'];
            if (ts is Timestamp) dataPlantio = ts;
          }

          final custo = d['custo'];
          if (custo is num) custoTotal += custo.toDouble();

          final receita = d['receita'];
          if (receita is num) receitaTotal += receita.toDouble();
        }

        final lucro = receitaTotal - custoTotal;

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(15, 15, 15, 0),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _InfoFin(
                      label: 'Investido', valor: custoTotal, cor: Colors.red),
                  _InfoFin(
                      label: 'Faturamento',
                      valor: receitaTotal,
                      cor: Colors.green),
                  _InfoFin(
                      label: 'Balanço',
                      valor: lucro,
                      cor: lucro >= 0 ? Colors.blue : Colors.red),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.all(15),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: corFundo,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: corTexto.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Chip(
                          label: Text(textoStatus,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 10)),
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(color: corTexto),
                        ),
                        if (status == 'ocupado' && docIdPlantioAtivo != null)
                          ElevatedButton.icon(
                            onPressed: () => _mostrarDialogoColheitaSeletiva(
                                docIdPlantioAtivo!,
                                produtosPlantados,
                                mapaPlantio),
                            icon: const Icon(Icons.check, size: 14),
                            label: const Text('Colher',
                                style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                            ),
                          )
                        else if (status == 'ocupado')
                          ElevatedButton(
                            onPressed: () => _atualizarStatusCanteiro('livre'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                                foregroundColor: Colors.white),
                            child: const Text('Forçar Liberação'),
                          )
                      ]),
                  if (status == 'ocupado' &&
                      produtosPlantados.isNotEmpty &&
                      dataPlantio != null) ...[
                    const SizedBox(height: 10),
                    const Text("Progresso da Safra:",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    ...produtosPlantados.split(' + ').map((planta) {
                      final ciclo =
                          _toInt(_guiaCompleto[planta]?['ciclo'] ?? 90);
                      final diasPassados = DateTime.now()
                          .difference(dataPlantio!.toDate())
                          .inDays;
                      final progresso =
                          (diasPassados / (ciclo <= 0 ? 1 : ciclo))
                              .clamp(0.0, 1.0);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progresso,
                            backgroundColor: Colors.white.withOpacity(0.5),
                            color: progresso >= 1
                                ? Colors.green
                                : Colors.orangeAccent,
                            minHeight: 6,
                          ),
                        ),
                      );
                    }),
                    const Divider(),
                  ],
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${area.toStringAsFixed(1)} m²',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: corTexto),
                              ),
                              const Text('Área Total',
                                  style: TextStyle(fontSize: 10))
                            ]),
                        IconButton(
                          icon: Icon(
                            Icons.build_circle,
                            color: status == 'manutencao'
                                ? Colors.orange
                                : (status == 'ocupado'
                                    ? Colors.grey.withOpacity(0.3)
                                    : Colors.grey),
                          ),
                          tooltip: 'Manutenção',
                          onPressed: status == 'ocupado'
                              ? () => _snack(
                                  '❌ Canteiro ocupado! Colha tudo antes da manutenção.',
                                  bg: Colors.red)
                              : () => _atualizarStatusCanteiro(
                                  status == 'manutencao'
                                      ? 'livre'
                                      : 'manutencao'),
                        )
                      ]),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // --- HARD DELETE (DEV) ---
  Future<void> _hardDeleteCanteiroCascade() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Excluindo canteiro e histórico...')),
          ],
        ),
      ),
    );

    try {
      final db = FirebaseFirestore.instance;

      while (true) {
        final q = await db
            .collection('historico_manejo')
            .where('canteiro_id', isEqualTo: widget.canteiroId)
            .limit(400)
            .get();

        if (q.docs.isEmpty) break;

        final batch = db.batch();
        for (final doc in q.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      await db.collection('canteiros').doc(widget.canteiroId).delete();

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);
      _snack('✅ Excluído com sucesso (canteiro + histórico).',
          bg: Colors.green);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _snack('❌ Falha ao excluir: $e', bg: Colors.red);
    }
  }

  void _confirmarExclusaoItem(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Registro?'),
        content: const Text('Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('historico_manejo')
                    .doc(id)
                    .delete();
                if (!mounted) return;
                Navigator.pop(ctx);
                _snack('✅ Registro excluído.', bg: Colors.green);
              } catch (e) {
                _snack('❌ Falha ao excluir: $e', bg: Colors.red);
              }
            },
            child: const Text('Excluir'),
          )
        ],
      ),
    );
  }

  void _mostrarDialogoEditarCanteiro(Map<String, dynamic> d) {
    _nomeController.text = (d['nome'] ?? '').toString();
    _compController.text = _toDouble(d['comprimento']).toString();
    _largController.text = _toDouble(d['largura']).toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Canteiro'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: _nomeController,
              decoration: const InputDecoration(
                  labelText: 'Nome', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _compController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Comprimento (m)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _largController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Largura (m)', border: OutlineInputBorder()),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final nome = _nomeController.text.trim();
              final comp =
                  double.tryParse(_compController.text.replaceAll(',', '.')) ??
                      0.0;
              final larg =
                  double.tryParse(_largController.text.replaceAll(',', '.')) ??
                      0.0;

              if (nome.isEmpty || comp <= 0 || larg <= 0) {
                _snack('⚠️ Preencha nome e medidas válidas.',
                    bg: Colors.orange);
                return;
              }

              try {
                await FirebaseFirestore.instance
                    .collection('canteiros')
                    .doc(widget.canteiroId)
                    .update({
                  'nome': nome,
                  'comprimento': comp,
                  'largura': larg,
                  'area_m2': comp * larg,
                });

                if (!mounted) return;
                Navigator.pop(ctx);
                _snack('✅ Canteiro atualizado.', bg: Colors.green);
              } catch (e) {
                _snack('❌ Falha ao salvar: $e', bg: Colors.red);
              }
            },
            child: const Text('Salvar'),
          )
        ],
      ),
    );
  }

  Future<void> _alternarStatus(bool ativoAtual) async {
    try {
      await FirebaseFirestore.instance
          .collection('canteiros')
          .doc(widget.canteiroId)
          .update({'ativo': !ativoAtual});
      _snack(!ativoAtual ? '✅ Reativado.' : '✅ Arquivado.', bg: Colors.green);
    } catch (e) {
      _snack('❌ Falha ao alterar status: $e', bg: Colors.red);
    }
  }

  void _confirmarExclusaoCanteiro() {
    if (!_enableHardDelete) {
      _snack('🚫 Excluir definitivo desativado em produção. Use Arquivar.',
          bg: Colors.orange);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir DEFINITIVO (DEV)?'),
        content: const Text(
          'Isso apaga o canteiro E todo o histórico dele.\n\n'
          'Use isso só em desenvolvimento pra “limpar” o banco.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _hardDeleteCanteiroCascade();
            },
            child: const Text('EXCLUIR'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('canteiros')
          .doc(widget.canteiroId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
                title: const Text('Canteiro'),
                backgroundColor: Theme.of(context).colorScheme.primary),
            body: _buildFirestoreError(snapshot.error),
          );
        }

        if (!snapshot.hasData ||
            snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final raw = snapshot.data!.data();
        if (raw == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Canteiro não encontrado'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Text(
                  'Esse canteiro não existe mais (foi apagado/arquivado).\nVolte e selecione outro.',
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final dados = Map<String, dynamic>.from(raw as Map);

        final bool ativo = (dados['ativo'] ?? true) == true;
        final String status = (dados['status'] ?? 'livre').toString();
        final double comp = _toDouble(dados['comprimento']);
        final double larg = _toDouble(dados['largura']);
        final double area = _toDouble(dados['area_m2']);

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: Row(children: [
              Expanded(
                  child: Text((dados['nome'] ?? 'Canteiro').toString(),
                      overflow: TextOverflow.ellipsis)),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () =>
                    _editarNomeCanteiro((dados['nome'] ?? '').toString()),
                tooltip: 'Renomear',
              )
            ]),
            backgroundColor: _getCorAppBar(status),
            foregroundColor: Colors.white,
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'e') _mostrarDialogoEditarCanteiro(dados);
                  if (v == 's') _alternarStatus(ativo);
                  if (v == 'x') _confirmarExclusaoCanteiro();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'e', child: Text('Editar')),
                  PopupMenuItem(
                      value: 's', child: Text(ativo ? 'Arquivar' : 'Reativar')),
                  if (_enableHardDelete)
                    const PopupMenuItem(
                        value: 'x', child: Text('Excluir DEFINITIVO (DEV)')),
                ],
              )
            ],
          ),
          floatingActionButton: ativo
              ? FloatingActionButton.extended(
                  onPressed: () => _mostrarOpcoesManejo(comp, larg, status),
                  label: const Text('MANEJO'),
                  backgroundColor: _getCorAppBar(status),
                  icon: const Icon(Icons.add_task),
                )
              : null,
          body: Column(
            children: [
              _buildDashboard(dados, area, status),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('historico_manejo')
                      .where('canteiro_id', isEqualTo: widget.canteiroId)
                      .orderBy('data', descending: true)
                      .snapshots(),
                  builder: (context, snapH) {
                    if (snapH.hasError)
                      return _buildFirestoreError(snapH.error);
                    if (!snapH.hasData ||
                        snapH.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final list = snapH.data!.docs.toList();

                    return ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (ctx, i) {
                        final e =
                            (list[i].data() as Map<String, dynamic>?) ?? {};
                        final concluido = (e['concluido'] ?? false) == true;
                        final isPlantio = e['tipo_manejo'] == 'Plantio';
                        final custo = _toDouble(e['custo']);
                        final receita = _toDouble(e['receita']);

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 6),
                          color: concluido ? Colors.red.shade50 : Colors.white,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: concluido
                                  ? Colors.grey
                                  : (isPlantio
                                      ? Colors.green.shade100
                                      : Colors.blue.shade100),
                              child: Icon(
                                concluido
                                    ? Icons.done_all
                                    : (isPlantio
                                        ? Icons.spa
                                        : Icons.water_drop),
                                color: Colors.black54,
                              ),
                            ),
                            title: Text(
                              (e['produto'] ?? '').toString(),
                              style: TextStyle(
                                  decoration: concluido
                                      ? TextDecoration.lineThrough
                                      : null),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text((e['detalhes'] ?? '').toString()),
                                if (custo > 0)
                                  Text(
                                    'Custo: R\$ ${custo.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: Colors.red, fontSize: 12),
                                  ),
                                if (receita > 0)
                                  Text(
                                    'Receita: R\$ ${receita.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'excluir')
                                  _confirmarExclusaoItem(list[i].id);
                                if (value == 'editar') {
                                  _mostrarDialogoPerdaOuEditar(
                                    list[i].id,
                                    (e['detalhes'] ?? '').toString(),
                                    (e['observacao_extra'] ?? '').toString(),
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'editar',
                                  child: Row(children: [
                                    Icon(Icons.edit,
                                        color: Colors.orange, size: 18),
                                    SizedBox(width: 8),
                                    Text('Editar / Baixa')
                                  ]),
                                ),
                                if (_enableHardDelete)
                                  const PopupMenuItem(
                                    value: 'excluir',
                                    child: Row(children: [
                                      Icon(Icons.delete,
                                          color: Colors.red, size: 18),
                                      SizedBox(width: 8),
                                      Text('Excluir (DEV)')
                                    ]),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Widget Financeiro
class _InfoFin extends StatelessWidget {
  final String label;
  final double valor;
  final Color cor;
  const _InfoFin({required this.label, required this.valor, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'R\$ ${valor.toStringAsFixed(2)}',
          style:
              TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cor),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey))
      ],
    );
  }
}

// Widget Card Simples
class _CardMenu extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CardMenu({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(title,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          Text(subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ]),
      ),
    );
  }
}
