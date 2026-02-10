import 'package:flutter/material.dart';
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

  // --- BASE TÉCNICA (MANTIDA IDÊNTICA) ---
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

  // --- NAVEGAÇÃO ---
  void _irParaDiagnostico() {
    Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    TelaDiagnostico(canteiroIdOrigem: widget.canteiroId)))
        .then((_) => setState(() {}));
  }

  void _irParaCalagem() => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => TelaCalagem(canteiroIdOrigem: widget.canteiroId)));

  // --- LÓGICA DE CORES E STATUS (MANTIDA) ---
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

  void _atualizarStatusCanteiro(String novoStatus) async {
    await FirebaseFirestore.instance
        .collection('canteiros')
        .doc(widget.canteiroId)
        .update({'status': novoStatus});
    setState(() {});
  }

  void _editarNomeCanteiro(String nomeAtual) {
    final controller = TextEditingController(text: nomeAtual);
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Renomear'),
                content: TextField(controller: controller),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar')),
                  ElevatedButton(
                      onPressed: () {
                        FirebaseFirestore.instance
                            .collection('canteiros')
                            .doc(widget.canteiroId)
                            .update({'nome': controller.text});
                        Navigator.pop(ctx);
                      },
                      child: const Text('Salvar'))
                ]));
  }

  // --- IRRIGAÇÃO (COM AJUSTE FINANCEIRO) ---
  void _mostrarDialogoIrrigacao() {
    String metodo = 'Gotejamento';
    final tempoController = TextEditingController(text: '30');
    final chuvaController = TextEditingController(text: '0');
    final custoController =
        TextEditingController(text: '0.00'); // Novo campo financeiro

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Row(children: [
              Icon(Icons.water_drop, color: Colors.blue, size: 28),
              SizedBox(width: 10),
              Text('Irrigação',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))
            ]),
            const SizedBox(height: 20),
            TextField(
                controller: chuvaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Choveu hoje? (mm)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.cloud))),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
                value: metodo,
                items: ['Manual', 'Gotejamento', 'Aspersão']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => metodo = v!,
                decoration: const InputDecoration(labelText: 'Sistema')),
            const SizedBox(height: 15),
            TextField(
                controller: tempoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Tempo (min)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.timer))),

            // --- NOVO: CUSTO OPERACIONAL ---
            const SizedBox(height: 15),
            TextField(
                controller: custoController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Custo Operacional (R\$)',
                    hintText: 'Água, Luz...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money))),

            const SizedBox(height: 25),
            SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _salvarIrrigacao(
                          metodo,
                          int.tryParse(tempoController.text) ?? 0,
                          double.tryParse(chuvaController.text) ?? 0,
                          double.tryParse(
                                  custoController.text.replaceAll(',', '.')) ??
                              0.0);
                    },
                    child: const Text('SALVAR IRRIGAÇÃO')))
          ]),
        ),
      ),
    );
  }

  void _salvarIrrigacao(String metodo, int tempo, double chuva, double custo) {
    FirebaseFirestore.instance.collection('historico_manejo').add({
      'canteiro_id': widget.canteiroId,
      'uid_usuario': FirebaseAuth.instance.currentUser?.uid,
      'data': FieldValue.serverTimestamp(),
      'tipo_manejo': 'Irrigação',
      'produto': metodo,
      'detalhes': 'Duração: $tempo min | Chuva: ${chuva}mm',
      'quantidade_g': 0,
      'custo': custo // Salva o custo
    });
  }

  int _calcularQtdMudas(String planta, int qtdVariedades, double areaTotal) {
    final info = _guiaCompleto[planta] ?? {'eLinha': 0.5, 'ePlanta': 0.5};
    final spacing = (info['eLinha'] ?? 0.5) * (info['ePlanta'] ?? 0.5);
    if (spacing <= 0) return 0;
    return (areaTotal / qtdVariedades / spacing).floor();
  }

  // --- NOVA COLHEITA (COM VALIDAÇÃO E FINANCEIRO) ---
  void _mostrarDialogoColheitaSeletiva(String idHistorico,
      String produtosString, Map<String, dynamic> mapaPlantioOriginal) {
    List<String> culturasAtivas = produtosString.split(' + ');
    Map<String, bool> selecionadosParaColher = {};
    Map<String, TextEditingController> controllers = {};
    final valorVendaController =
        TextEditingController(text: '0.00'); // Novo campo receita

    for (var c in culturasAtivas) {
      selecionadosParaColher[c] = false;
      controllers[c] = TextEditingController();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Registrar Colheita',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green)),
                const Text('Informe o que foi colhido e o valor de venda.',
                    style: TextStyle(color: Colors.grey)),
                const Divider(),
                const SizedBox(height: 10),

                ...culturasAtivas.map((cultura) {
                  int qtdPlantada = mapaPlantioOriginal[cultura] ?? 999;
                  return Column(children: [
                    CheckboxListTile(
                      title: Text('$cultura (Plantado: $qtdPlantada)',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      value: selecionadosParaColher[cultura],
                      activeColor: Colors.green,
                      onChanged: (val) => setModalState(
                          () => selecionadosParaColher[cultura] = val!),
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
                                  qtdPlantada)), // Validação Visual
                          onChanged: (v) => setModalState(() {}),
                        ),
                      ),
                    const Divider()
                  ]);
                }).toList(),

                // --- NOVO: CAMPO RECEITA ---
                const SizedBox(height: 10),
                TextField(
                    controller: valorVendaController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Receita Total da Venda (R\$)',
                        prefixIcon: Icon(Icons.monetization_on),
                        border: OutlineInputBorder())),

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
                        mapaPlantioOriginal),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('FINALIZAR'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white),
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
    int qtd = int.tryParse(texto) ?? 0;
    if (qtd > maximo) return "Erro: Maior que o plantado ($maximo)";
    return null;
  }

  void _processarColheita(
      BuildContext ctx,
      String idHistorico,
      Map<String, bool> selecionados,
      Map<String, TextEditingController> ctrls,
      String valorVendaStr,
      Map<String, dynamic> mapaPlantio) async {
    List<String> colhidosAgora = [];
    List<String> restamNoCanteiro = [];
    String resumoColheita = "";
    bool erroValidacao = false;

    selecionados.forEach((cultura, colheu) {
      if (colheu) {
        int qtd = int.tryParse(ctrls[cultura]?.text ?? '0') ?? 0;
        int max = mapaPlantio[cultura] ?? 999;
        if (qtd > max) erroValidacao = true;
        colhidosAgora.add(cultura);
        resumoColheita += "$cultura ($qtd un) ";
      } else {
        restamNoCanteiro.add(cultura);
      }
    });

    if (erroValidacao) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('❌ Erro: Quantidade colhida maior que a plantada!'),
          backgroundColor: Colors.red));
      return;
    }
    if (colhidosAgora.isEmpty) {
      Navigator.pop(ctx);
      return;
    }

    double receita = double.tryParse(valorVendaStr.replaceAll(',', '.')) ?? 0.0;

    // 1. Registro de Colheita
    await FirebaseFirestore.instance.collection('historico_manejo').add({
      'canteiro_id': widget.canteiroId,
      'uid_usuario': FirebaseAuth.instance.currentUser?.uid,
      'data': FieldValue.serverTimestamp(),
      'tipo_manejo': 'Colheita', 'produto': colhidosAgora.join(' + '),
      'detalhes': 'Colheita: $resumoColheita', 'concluido': true,
      'receita': receita // Salva o dinheiro
    });

    // 2. Atualiza Ciclo Original
    if (restamNoCanteiro.isEmpty) {
      await FirebaseFirestore.instance
          .collection('historico_manejo')
          .doc(idHistorico)
          .update({
        'concluido': true,
        'observacao_extra': 'Ciclo Finalizado. $resumoColheita'
      });
      _atualizarStatusCanteiro('livre');
    } else {
      await FirebaseFirestore.instance
          .collection('historico_manejo')
          .doc(idHistorico)
          .update({
        'produto': restamNoCanteiro.join(' + '),
      });
    }

    Navigator.pop(ctx);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(restamNoCanteiro.isEmpty
            ? '✅ Canteiro Esvaziado! Lucro registrado.'
            : '✅ Colheita Parcial Registrada!'),
        backgroundColor: Colors.green));
  }

  // --- DIALOGO DE PERDA / EDIÇÃO ---
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
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 10),
                TextField(
                    controller: detalheCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        labelText: 'Resumo do Plantio (Qtd)',
                        border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(
                    controller: obsCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Motivo da Baixa / Obs',
                        border: OutlineInputBorder(),
                        hintText: 'Ex: Formigas comeram 2 mudas')),
              ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar')),
                ElevatedButton(
                    onPressed: () {
                      FirebaseFirestore.instance
                          .collection('historico_manejo')
                          .doc(id)
                          .update({
                        'detalhes': detalheCtrl.text,
                        'observacao_extra': obsCtrl.text
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Registro atualizado!')));
                    },
                    child: const Text('Salvar Alterações'))
              ],
            ));
  }

  // --- PLANTIO (DESIGN RESTAURADO, LÓGICA ATUALIZADA) ---
  void _mostrarDialogoPlantio(double cCanteiro, double lCanteiro) {
    // Mapa para controlar QUANTIDADE de cada planta selecionada (Lógica Nova)
    Map<String, int> qtdPorPlanta = {};
    String regiao = 'Sudeste';
    String mes = 'Fevereiro';
    final obsController = TextEditingController();
    final custoMudasController =
        TextEditingController(text: '0.00'); // Novo campo financeiro
    double areaTotalCanteiro = cCanteiro * lCanteiro;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          // Cálculos (Mantidos)
          double areaOcupada = 0.0;
          qtdPorPlanta.forEach((planta, qtd) {
            final info =
                _guiaCompleto[planta] ?? {'eLinha': 0.5, 'ePlanta': 0.5};
            areaOcupada += (qtd * (info['eLinha'] * info['ePlanta']));
          });
          double percentualOcupado =
              (areaOcupada / areaTotalCanteiro).clamp(0.0, 1.0);
          bool estourou = (areaTotalCanteiro - areaOcupada) < 0;

          // Função Add (Mantida)
          void adicionarPlanta(String p) {
            final info = _guiaCompleto[p] ?? {'eLinha': 0.5, 'ePlanta': 0.5};
            int qtdInicial =
                (areaTotalCanteiro / (info['eLinha'] * info['ePlanta']))
                    .floor();
            if (qtdPorPlanta.isNotEmpty &&
                (areaTotalCanteiro - areaOcupada) > 0) {
              qtdInicial = ((areaTotalCanteiro - areaOcupada) /
                      (info['eLinha'] * info['ePlanta']))
                  .floor();
            }
            if (qtdInicial < 1) qtdInicial = 1;
            qtdPorPlanta[p] = qtdInicial;
          }

          List<String> recomendadas =
              List.from(_calendarioRegional[regiao]?[mes] ?? []);

          // Agrupamento (Visual Antigo Restaurado)
          Map<String, List<String>> porCategoria = {};
          for (var p in recomendadas) {
            String cat = _guiaCompleto[p]?['cat'] ?? 'Outros';
            if (!porCategoria.containsKey(cat)) porCategoria[cat] = [];
            porCategoria[cat]!.add(p);
          }
          List<String> outras = _guiaCompleto.keys
              .where((c) => !recomendadas.contains(c))
              .toList()
            ..sort();
          Map<String, List<String>> outrasPorCategoria = {};
          for (var p in outras) {
            String cat = _guiaCompleto[p]?['cat'] ?? 'Outros';
            if (!outrasPorCategoria.containsKey(cat))
              outrasPorCategoria[cat] = [];
            outrasPorCategoria[cat]!.add(p);
          }

          // CHIP VISUAL RESTAURADO (VERDE)
          Widget buildChip(String planta, bool isRecommended) {
            bool isSel = qtdPorPlanta.containsKey(planta);
            return FilterChip(
              label: Text(planta),
              selected: isSel,
              checkmarkColor: Colors.white,
              selectedColor: isRecommended
                  ? Colors.green
                  : Colors.orange, // Cor restaurada
              backgroundColor: Colors.grey.shade100,
              labelStyle: TextStyle(
                  fontSize: 11, color: isSel ? Colors.white : Colors.black87),
              onSelected: (v) {
                setModalState(() {
                  if (v) {
                    adicionarPlanta(planta);
                    if (!isRecommended)
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('⚠️ Atenção: Fora de época!'),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 1)));
                  } else {
                    qtdPorPlanta.remove(planta);
                  }
                });
              },
            );
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.95,
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text('Planejamento de Plantio',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Divider(),
                // Barra de Progresso (Necessária para a lógica de espaço)
                LinearProgressIndicator(
                    value: percentualOcupado,
                    color: estourou ? Colors.red : Colors.green),
                const SizedBox(height: 10),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // SEÇÃO RECOMENDADAS (VISUAL LIMPO RESTAURADO)
                          Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              color: Colors.green.shade50,
                              child: Text('✅ Recomendados:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800))),
                          ...porCategoria.entries.map((e) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                        padding: const EdgeInsets.only(
                                            top: 8, bottom: 4),
                                        child: Text(e.key.toUpperCase(),
                                            style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey))),
                                    Wrap(
                                        spacing: 5,
                                        children: e.value
                                            .map((p) => buildChip(p, true))
                                            .toList())
                                  ])),

                          const SizedBox(height: 15),

                          // SEÇÃO OUTRAS (VISUAL LIMPO RESTAURADO)
                          Theme(
                              data: Theme.of(context)
                                  .copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                  title: const Text(
                                      '⚠️ Outras Culturas (Fora de Época)',
                                      style: TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  children: [
                                    ...outrasPorCategoria.entries.map((e) =>
                                        Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 8, bottom: 4),
                                                  child: Text(
                                                      e.key.toUpperCase(),
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.orange
                                                              .shade300))),
                                              Wrap(
                                                  spacing: 5,
                                                  children: e.value
                                                      .map((p) =>
                                                          buildChip(p, false))
                                                      .toList())
                                            ]))
                                  ])),

                          // ÁREA DE AJUSTE (MUDAS) - Mantida pois é a nova funcionalidade
                          if (qtdPorPlanta.isNotEmpty) ...[
                            const Divider(),
                            Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(10)),
                                child: Column(children: [
                                  const Text('Ajuste a Quantidade de Mudas:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 10),
                                  ...qtdPorPlanta.entries.map((entry) {
                                    return Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                              child: Text(entry.key,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13))),
                                          IconButton(
                                              icon: const Icon(
                                                  Icons.remove_circle,
                                                  color: Colors.red),
                                              onPressed: () =>
                                                  setModalState(() {
                                                    if (entry.value > 1)
                                                      qtdPorPlanta[entry.key] =
                                                          entry.value - 1;
                                                  })),
                                          Text('${entry.value}',
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold)),
                                          IconButton(
                                              icon: const Icon(Icons.add_circle,
                                                  color: Colors.green),
                                              onPressed: () => setModalState(
                                                  () =>
                                                      qtdPorPlanta[entry.key] =
                                                          entry.value + 1)),
                                        ]);
                                  })
                                ])),
                            const SizedBox(height: 10),
                            TextField(
                                controller: obsController,
                                decoration: const InputDecoration(
                                    labelText: 'Observação do Plantio',
                                    border: OutlineInputBorder(),
                                    contentPadding:
                                        EdgeInsets.symmetric(horizontal: 10))),
                            const SizedBox(height: 10),
                            // CAMPO FINANCEIRO
                            TextField(
                                controller: custoMudasController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    labelText: 'Custo de Mudas/Sementes (R\$)',
                                    prefixIcon: Icon(Icons.monetization_on),
                                    border: OutlineInputBorder())),
                          ]
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
                                String resumo = "Plantio ($regiao/$mes):\n";
                                List<String> nomes = [];
                                qtdPorPlanta.forEach((planta, qtd) {
                                  nomes.add(planta);
                                  int ciclo =
                                      _guiaCompleto[planta]?['ciclo'] ?? 90;
                                  resumo +=
                                      "- $planta: $qtd mudas (${ciclo} dias)\n";
                                });

                                double custo = double.tryParse(
                                        custoMudasController.text
                                            .replaceAll(',', '.')) ??
                                    0.0;

                                await FirebaseFirestore.instance
                                    .collection('historico_manejo')
                                    .add({
                                  'canteiro_id': widget.canteiroId,
                                  'uid_usuario':
                                      FirebaseAuth.instance.currentUser?.uid,
                                  'data': FieldValue.serverTimestamp(),
                                  'tipo_manejo': 'Plantio',
                                  'produto': nomes.join(' + '),
                                  'detalhes': resumo,
                                  'observacao_extra': obsController.text,
                                  'quantidade_g': 0, 'concluido': false,
                                  'custo': custo, // Salva o custo
                                  'mapa_plantio':
                                      qtdPorPlanta // SALVA O MAPA PARA VALIDAR DEPOIS
                                });
                                _atualizarStatusCanteiro('ocupado');
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            '✅ Plantio registrado! Canteiro agora está OCUPADO.')));
                              },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: estourou
                                ? Colors.grey
                                : Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white),
                        child: Text(estourou
                            ? 'FALTA ESPAÇO NO CANTEIRO'
                            : 'CONFIRMAR PLANTIO'),
                      ))
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
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(25))),
              padding: const EdgeInsets.all(20),
              height: 380,
              child: Column(children: [
                const Text('Menu de Operações',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                          }),

                      // BOTÃO PLANTIO BLOQUEADO SE JÁ ESTIVER OCUPADO
                      _CardMenu(
                          icon: Icons.spa,
                          color: (statusAtual == 'livre')
                              ? Colors.green
                              : Colors.grey,
                          title: 'Novo Plantio',
                          subtitle: (statusAtual == 'livre')
                              ? 'Planejar'
                              : 'Bloqueado',
                          onTap: () {
                            if (statusAtual != 'livre') {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          '⚠️ Colha tudo antes de plantar!'),
                                      backgroundColor: Colors.orange));
                            } else {
                              Navigator.pop(ctx);
                              _mostrarDialogoPlantio(c, l);
                            }
                          }),

                      _CardMenu(
                          icon: Icons.science,
                          color: Colors.brown,
                          title: 'Análise Solo',
                          subtitle: 'Registrar',
                          onTap: () {
                            Navigator.pop(ctx);
                            _irParaDiagnostico();
                          }),
                      _CardMenu(
                          icon: Icons.landscape,
                          color: Colors.orange,
                          title: 'Calagem',
                          subtitle: 'Calcular',
                          onTap: () {
                            Navigator.pop(ctx);
                            _irParaCalagem();
                          }),
                    ]))
              ]),
            ));
  }

  // --- DASHBOARD COM FINANCEIRO E CORREÇÃO DE ERRO DE DATA ---
  Widget _buildDashboard(
      Map<String, dynamic> dados, double area, String status) {
    Color corFundo = _getCorStatus(status);
    Color corTexto = (status == 'livre')
        ? Colors.green.shade900
        : (status == 'manutencao'
            ? Colors.orange.shade900
            : Colors.red.shade900);
    String textoStatus = _getTextoStatus(status);

    return StreamBuilder<QuerySnapshot>(
        // Traz todos os registros para somar o financeiro
        stream: FirebaseFirestore.instance
            .collection('historico_manejo')
            .where('canteiro_id', isEqualTo: widget.canteiroId)
            .orderBy('data', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          String? docIdPlantioAtivo;
          String produtosPlantados = "";
          Map<String, dynamic> mapaPlantio = {};
          Timestamp? dataPlantio;

          double custoTotal = 0.0;
          double receitaTotal = 0.0;

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            for (var doc in snapshot.data!.docs) {
              var d = doc.data() as Map<String, dynamic>;
              // Detecta plantio ativo
              if (d['tipo_manejo'] == 'Plantio' && d['concluido'] == false) {
                docIdPlantioAtivo = doc.id;
                produtosPlantados = d['produto'] ?? '';
                mapaPlantio = d['mapa_plantio'] ?? {};
                dataPlantio = d['data'];
              }
              // Soma Financeiro
              if (d['custo'] != null)
                custoTotal += (d['custo'] as num).toDouble();
              if (d['receita'] != null)
                receitaTotal += (d['receita'] as num).toDouble();
            }
          }

          double lucro = receitaTotal - custoTotal;

          return Column(
            children: [
              // --- NOVO: CARD FINANCEIRO ---
              Container(
                margin: const EdgeInsets.fromLTRB(15, 15, 15, 0),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade300)),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _InfoFin(
                          label: 'Investido',
                          valor: custoTotal,
                          cor: Colors.red),
                      _InfoFin(
                          label: 'Faturamento',
                          valor: receitaTotal,
                          cor: Colors.green),
                      _InfoFin(
                          label: 'Balanço',
                          valor: lucro,
                          cor: lucro >= 0 ? Colors.blue : Colors.red),
                    ]),
              ),

              // --- CARD DO CANTEIRO ---
              Container(
                margin: const EdgeInsets.all(15),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                    color: corFundo,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: corTexto.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.grey.withOpacity(0.1), blurRadius: 5)
                    ]),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Chip(
                                label: Text(textoStatus,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10)),
                                backgroundColor: Colors.white,
                                labelStyle: TextStyle(color: corTexto)),
                            if (status == 'ocupado' &&
                                docIdPlantioAtivo != null)
                              ElevatedButton.icon(
                                  onPressed: () =>
                                      _mostrarDialogoColheitaSeletiva(
                                          docIdPlantioAtivo!,
                                          produtosPlantados,
                                          mapaPlantio),
                                  icon: const Icon(Icons.check, size: 14),
                                  label: const Text('Colher',
                                      style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10)))
                            else if (status == 'ocupado')
                              ElevatedButton(
                                  onPressed: () {
                                    _atualizarStatusCanteiro('livre');
                                  },
                                  child: const Text('Forçar Liberação'),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey,
                                      foregroundColor: Colors.white))
                          ]),

                      // CORREÇÃO DO ERRO NULL: Verifica se dataPlantio existe
                      if (status == 'ocupado' &&
                          produtosPlantados.isNotEmpty &&
                          dataPlantio != null) ...[
                        const SizedBox(height: 10),
                        const Text("Progresso da Safra:",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 8),
                        ...produtosPlantados.split(' + ').map((planta) {
                          int ciclo = _guiaCompleto[planta]?['ciclo'] ?? 90;
                          int diasPassados = DateTime.now()
                              .difference(dataPlantio!.toDate())
                              .inDays;
                          double progresso =
                              (diasPassados / ciclo).clamp(0.0, 1.0);
                          return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                      value: progresso,
                                      backgroundColor:
                                          Colors.white.withOpacity(0.5),
                                      color: progresso >= 1
                                          ? Colors.green
                                          : Colors.orangeAccent,
                                      minHeight: 6)));
                        }).toList(),
                        const Divider(),
                      ],

                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${area.toStringAsFixed(1)} m²',
                                      style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: corTexto)),
                                  const Text('Área Total',
                                      style: TextStyle(fontSize: 10))
                                ]),
                            // TRAVA DE MANUTENÇÃO: Bloqueado se ocupado
                            IconButton(
                              icon: Icon(Icons.build_circle,
                                  color: status == 'manutencao'
                                      ? Colors.orange
                                      : (status == 'ocupado'
                                          ? Colors.grey.withOpacity(0.3)
                                          : Colors.grey)),
                              tooltip: 'Manutenção',
                              onPressed: status == 'ocupado'
                                  ? () => ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                          content: Text(
                                              '❌ Canteiro Ocupado! Colha tudo antes da manutenção.'),
                                          backgroundColor: Colors.red))
                                  : () => _atualizarStatusCanteiro(
                                      status == 'manutencao'
                                          ? 'livre'
                                          : 'manutencao'),
                            )
                          ]),
                    ]),
              ),
            ],
          );
        });
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
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white),
                      onPressed: () {
                        FirebaseFirestore.instance
                            .collection('historico_manejo')
                            .doc(id)
                            .delete();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Excluir'))
                ]));
  }

  void _mostrarDialogoEditarCanteiro(Map<String, dynamic> d) {
    _nomeController.text = d['nome'];
    _compController.text = d['comprimento'].toString();
    _largController.text = d['largura'].toString();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Editar'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(controller: _nomeController),
                  TextField(controller: _compController),
                  TextField(controller: _largController)
                ]),
                actions: [
                  ElevatedButton(
                      onPressed: () {
                        FirebaseFirestore.instance
                            .collection('canteiros')
                            .doc(widget.canteiroId)
                            .update({
                          'nome': _nomeController.text,
                          'area_m2': double.parse(_compController.text) *
                              double.parse(_largController.text)
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('Salvar'))
                ]));
  }

  void _alternarStatus(bool s) {
    FirebaseFirestore.instance
        .collection('canteiros')
        .doc(widget.canteiroId)
        .update({'ativo': !s});
  }

  void _confirmarExclusaoCanteiro() {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Excluir?'),
                content: const Text('Apagar canteiro e histórico?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Não')),
                  ElevatedButton(
                      onPressed: () {
                        FirebaseFirestore.instance
                            .collection('canteiros')
                            .doc(widget.canteiroId)
                            .delete();
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Sim'))
                ]));
  }

  String _formatarData(Timestamp? t) {
    if (t == null) return '-';
    DateTime d = t.toDate();
    return '${d.day}/${d.month} ${d.hour}:${d.minute}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('canteiros')
          .doc(widget.canteiroId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));

        final dados = snapshot.data!.data() as Map<String, dynamic>;
        final bool ativo = dados['ativo'] ?? true;
        final String status = dados['status'] ?? 'livre';
        final double comp = (dados['comprimento'] ?? 0).toDouble();
        final double larg = (dados['largura'] ?? 0).toDouble();

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
              title: Row(children: [
                Expanded(
                    child:
                        Text(dados['nome'], overflow: TextOverflow.ellipsis)),
                IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _editarNomeCanteiro(dados['nome']),
                    tooltip: 'Renomear')
              ]),
              backgroundColor: _getCorAppBar(status),
              foregroundColor: Colors.white,
              actions: [
                PopupMenuButton(
                    onSelected: (v) {
                      if (v == 'e') _mostrarDialogoEditarCanteiro(dados);
                      if (v == 's') _alternarStatus(ativo);
                      if (v == 'x') _confirmarExclusaoCanteiro();
                    },
                    itemBuilder: (context) => [
                          const PopupMenuItem(
                              value: 'e', child: Text('Editar')),
                          PopupMenuItem(
                              value: 's',
                              child: Text(ativo ? 'Arquivar' : 'Reativar')),
                          const PopupMenuItem(
                              value: 'x', child: Text('Excluir'))
                        ])
              ]),
          floatingActionButton: ativo
              ? FloatingActionButton.extended(
                  onPressed: () => _mostrarOpcoesManejo(comp, larg, status),
                  label: const Text('MANEJO'),
                  backgroundColor: _getCorAppBar(status),
                  icon: const Icon(Icons.add_task))
              : null,
          body: Column(children: [
            _buildDashboard(dados, (dados['area_m2'] ?? 0).toDouble(), status),
            Expanded(
                child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('historico_manejo')
                        .where('canteiro_id', isEqualTo: widget.canteiroId)
                        .snapshots(),
                    builder: (context, snapH) {
                      if (!snapH.hasData)
                        return const Center(child: CircularProgressIndicator());
                      final list = snapH.data!.docs.toList()
                        ..sort((a, b) => ((b.data() as Map)['data']
                                as Timestamp)
                            .compareTo((a.data() as Map)['data'] as Timestamp));
                      return ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (ctx, i) {
                            final e = list[i].data() as Map<String, dynamic>;
                            bool concluido = e['concluido'] ?? false;
                            bool isPlantio = e['tipo_manejo'] == 'Plantio';
                            double custo = (e['custo'] ?? 0).toDouble();
                            double receita = (e['receita'] ?? 0).toDouble();

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 6),
                              color:
                                  concluido ? Colors.red.shade50 : Colors.white,
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
                                        color: Colors.black54)),
                                title: Text(e['produto'] ?? '',
                                    style: TextStyle(
                                        decoration: concluido
                                            ? TextDecoration.lineThrough
                                            : null)),
                                subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(e['detalhes'] ?? ''),
                                      if (custo > 0)
                                        Text(
                                            'Custo: R\$ ${custo.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                                color: Colors.red,
                                                fontSize: 12)),
                                      if (receita > 0)
                                        Text(
                                            'Receita: R\$ ${receita.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12)),
                                    ]),
                                trailing: PopupMenuButton(
                                  onSelected: (value) {
                                    if (value == 'excluir')
                                      _confirmarExclusaoItem(list[i].id);
                                    if (value == 'editar')
                                      _mostrarDialogoPerdaOuEditar(
                                          list[i].id,
                                          e['detalhes'],
                                          e['observacao_extra'] ?? '');
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                        value: 'editar',
                                        child: Row(children: [
                                          Icon(Icons.edit,
                                              color: Colors.orange, size: 18),
                                          SizedBox(width: 8),
                                          Text('Editar / Baixa')
                                        ])),
                                    const PopupMenuItem(
                                        value: 'excluir',
                                        child: Row(children: [
                                          Icon(Icons.delete,
                                              color: Colors.red, size: 18),
                                          SizedBox(width: 8),
                                          Text('Excluir')
                                        ]))
                                  ],
                                ),
                              ),
                            );
                          });
                    }))
          ]),
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
    return Column(children: [
      Text('R\$ ${valor.toStringAsFixed(2)}',
          style:
              TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cor)),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey))
    ]);
  }
}

// Widget Card Simples
class _CardMenu extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _CardMenu(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
            decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: color.withOpacity(0.2))),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color)),
              Text(subtitle,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600))
            ])));
  }
}
