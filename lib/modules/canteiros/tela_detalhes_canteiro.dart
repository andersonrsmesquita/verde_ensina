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

  // -----------------------
  // Helpers
  // -----------------------
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }

  String _money(double v) => 'R\$ ${v.toStringAsFixed(2)}';

  String _fmtData(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$mi';
  }

  Widget _buildFirestoreError(Object? error) {
    final msg = (error ?? 'Erro desconhecido').toString();
    final low = msg.toLowerCase();
    final isIndex =
        low.contains('requires an index') || low.contains('create it here');

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
                ? 'Essa tela usa WHERE + ORDER BY.\n'
                      'Se aparecer erro de índice, clique no link do erro e crie o índice sugerido.'
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

  // -----------------------
  // Guia técnico (mantido)
  // -----------------------
  final Map<String, Map<String, dynamic>> _guiaCompleto = {
    'Abobrinha italiana': {
      'cat': 'Frutos',
      'par': 'Milho, Feijão',
      'evitar': 'Batata',
      'ciclo': 55,
      'eLinha': 1.0,
      'ePlanta': 0.7,
    },
    'Abobrinha brasileira': {
      'cat': 'Frutos',
      'par': 'Milho, Feijão',
      'evitar': 'Batata',
      'ciclo': 60,
      'eLinha': 2.0,
      'ePlanta': 2.0,
    },
    'Abóboras e morangas': {
      'cat': 'Frutos',
      'par': 'Milho, Feijão',
      'evitar': 'Batata',
      'ciclo': 120,
      'eLinha': 3.0,
      'ePlanta': 2.0,
    },
    'Acelga': {
      'cat': 'Folhas',
      'par': 'Alface, Couve',
      'evitar': 'Nenhum',
      'ciclo': 60,
      'eLinha': 0.45,
      'ePlanta': 0.5,
    },
    'Agrião': {
      'cat': 'Folhas',
      'par': 'Nenhum',
      'evitar': 'Nenhum',
      'ciclo': 50,
      'eLinha': 0.2,
      'ePlanta': 0.3,
    },
    'Salsão (Aipo)': {
      'cat': 'Temperos',
      'par': 'Tomate, Feijão',
      'evitar': 'Milho',
      'ciclo': 100,
      'eLinha': 0.9,
      'ePlanta': 0.4,
    },
    'Alface': {
      'cat': 'Folhas',
      'par': 'Cenoura, Rabanete',
      'evitar': 'Salsa',
      'ciclo': 45,
      'eLinha': 0.25,
      'ePlanta': 0.3,
    },
    'Alho': {
      'cat': 'Bulbos',
      'par': 'Tomate, Cenoura',
      'evitar': 'Feijão',
      'ciclo': 180,
      'eLinha': 0.25,
      'ePlanta': 0.1,
    },
    'Alho poró': {
      'cat': 'Bulbos',
      'par': 'Cenoura, Tomate',
      'evitar': 'Feijão',
      'ciclo': 120,
      'eLinha': 0.4,
      'ePlanta': 0.2,
    },
    'Almeirão': {
      'cat': 'Folhas',
      'par': 'Alface, Cenoura',
      'evitar': 'Nenhum',
      'ciclo': 70,
      'eLinha': 0.25,
      'ePlanta': 0.25,
    },
    'Batata doce': {
      'cat': 'Raízes',
      'par': 'Abóbora',
      'evitar': 'Tomate',
      'ciclo': 120,
      'eLinha': 0.9,
      'ePlanta': 0.3,
    },
    'Berinjela': {
      'cat': 'Frutos',
      'par': 'Feijão, Alho',
      'evitar': 'Nenhum',
      'ciclo': 110,
      'eLinha': 1.0,
      'ePlanta': 0.8,
    },
    'Beterraba': {
      'cat': 'Raízes',
      'par': 'Cebola, Alface',
      'evitar': 'Milho',
      'ciclo': 70,
      'eLinha': 0.25,
      'ePlanta': 0.1,
    },
    'Brócolis': {
      'cat': 'Flores',
      'par': 'Beterraba, Cebola',
      'evitar': 'Morango',
      'ciclo': 100,
      'eLinha': 0.8,
      'ePlanta': 0.5,
    },
    'Cará (Inhame)': {
      'cat': 'Raízes',
      'par': 'Nenhum',
      'evitar': 'Nenhum',
      'ciclo': 240,
      'eLinha': 0.8,
      'ePlanta': 0.4,
    },
    'Cebola': {
      'cat': 'Bulbos',
      'par': 'Beterraba, Tomate',
      'evitar': 'Feijão',
      'ciclo': 140,
      'eLinha': 0.3,
      'ePlanta': 0.1,
    },
    'Cebolinha': {
      'cat': 'Temperos',
      'par': 'Cenoura, Morango',
      'evitar': 'Feijão',
      'ciclo': 60,
      'eLinha': 0.25,
      'ePlanta': 0.2,
    },
    'Cenoura': {
      'cat': 'Raízes',
      'par': 'Alface, Tomate',
      'evitar': 'Salsa',
      'ciclo': 100,
      'eLinha': 0.25,
      'ePlanta': 0.1,
    },
    'Chicória': {
      'cat': 'Folhas',
      'par': 'Alface, Rúcula',
      'evitar': 'Nenhum',
      'ciclo': 70,
      'eLinha': 0.3,
      'ePlanta': 0.3,
    },
    'Chuchu': {
      'cat': 'Frutos',
      'par': 'Abóbora, Milho',
      'evitar': 'Nenhum',
      'ciclo': 120,
      'eLinha': 5.0,
      'ePlanta': 5.0,
    },
    'Coentro': {
      'cat': 'Temperos',
      'par': 'Tomate',
      'evitar': 'Cenoura',
      'ciclo': 50,
      'eLinha': 0.2,
      'ePlanta': 0.2,
    },
    'Couve de folha': {
      'cat': 'Folhas',
      'par': 'Alecrim, Sálvia',
      'evitar': 'Morango, Tomate',
      'ciclo': 80,
      'eLinha': 0.8,
      'ePlanta': 0.5,
    },
    'Ervilha': {
      'cat': 'Leguminosas',
      'par': 'Cenoura, Milho',
      'evitar': 'Alho',
      'ciclo': 80,
      'eLinha': 1.0,
      'ePlanta': 0.5,
    },
    'Jiló': {
      'cat': 'Frutos',
      'par': 'Berinjela, Pimentão',
      'evitar': 'Nenhum',
      'ciclo': 100,
      'eLinha': 1.2,
      'ePlanta': 1.0,
    },
    'Mandioca': {
      'cat': 'Raízes',
      'par': 'Feijão, Milho',
      'evitar': 'Nenhum',
      'ciclo': 300,
      'eLinha': 3.0,
      'ePlanta': 2.0,
    },
    'Melancia': {
      'cat': 'Frutos',
      'par': 'Milho',
      'evitar': 'Nenhum',
      'ciclo': 90,
      'eLinha': 3.0,
      'ePlanta': 2.0,
    },
    'Melão': {
      'cat': 'Frutos',
      'par': 'Milho',
      'evitar': 'Nenhum',
      'ciclo': 90,
      'eLinha': 2.0,
      'ePlanta': 1.5,
    },
    'Morango': {
      'cat': 'Frutos',
      'par': 'Cebola, Alho',
      'evitar': 'Couve',
      'ciclo': 80,
      'eLinha': 0.35,
      'ePlanta': 0.35,
    },
    'Pepino': {
      'cat': 'Frutos',
      'par': 'Feijão, Milho',
      'evitar': 'Tomate',
      'ciclo': 60,
      'eLinha': 1.0,
      'ePlanta': 0.5,
    },
    'Pimenta': {
      'cat': 'Temperos',
      'par': 'Manjericão, Tomate',
      'evitar': 'Feijão',
      'ciclo': 100,
      'eLinha': 1.0,
      'ePlanta': 0.5,
    },
    'Pimentão': {
      'cat': 'Frutos',
      'par': 'Manjericão, Cebola',
      'evitar': 'Feijão',
      'ciclo': 100,
      'eLinha': 1.0,
      'ePlanta': 0.5,
    },
    'Quiabo': {
      'cat': 'Frutos',
      'par': 'Pimentão, Tomate',
      'evitar': 'Nenhum',
      'ciclo': 80,
      'eLinha': 1.0,
      'ePlanta': 0.3,
    },
    'Repolho': {
      'cat': 'Folhas',
      'par': 'Beterraba, Cebola',
      'evitar': 'Morango',
      'ciclo': 100,
      'eLinha': 0.8,
      'ePlanta': 0.4,
    },
    'Rúcula': {
      'cat': 'Folhas',
      'par': 'Alface, Beterraba',
      'evitar': 'Repolho',
      'ciclo': 40,
      'eLinha': 0.2,
      'ePlanta': 0.1,
    },
    'Tomate': {
      'cat': 'Frutos',
      'par': 'Manjericão, Alho',
      'evitar': 'Batata',
      'ciclo': 110,
      'eLinha': 1.0,
      'ePlanta': 0.3,
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
        'Repolho',
      ],
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
        'Pimentão',
      ],
    },
    'Nordeste': {
      'Fevereiro': [
        'Alface',
        'Berinjela',
        'Cenoura',
        'Quiabo',
        'Pepino',
        'Pimenta',
        'Tomate',
      ],
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
        'Couve de folha',
      ],
    },
    'Norte': {
      'Fevereiro': [
        'Alface',
        'Batata doce',
        'Cenoura',
        'Quiabo',
        'Couve de folha',
        'Cebola',
      ],
    },
  };

  @override
  void dispose() {
    _nomeController.dispose();
    _compController.dispose();
    _largController.dispose();
    super.dispose();
  }

  // -----------------------
  // Navegação
  // -----------------------
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

  // -----------------------
  // Status + Cores
  // -----------------------
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
    if (status == 'ocupado') return 'EM PRODUÇÃO';
    if (status == 'manutencao') return 'MANUTENÇÃO / DESCANSO';
    return 'LIVRE';
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

  // -----------------------
  // Finalidade (consumo x comercio)
  // -----------------------
  String _labelFinalidade(String f) {
    if (f == 'comercio') return 'Comércio';
    return 'Consumo';
  }

  Color _corFinalidade(String f) =>
      (f == 'comercio') ? Colors.indigo : Colors.teal;

  // -----------------------
  // Recupera mapa_plantio (com fallback)
  // -----------------------
  Map<String, int> _intMapFromAny(dynamic mp) {
    if (mp is Map) {
      final out = <String, int>{};
      mp.forEach((k, v) {
        final key = k.toString();
        out[key] = _toInt(v);
      });
      return out;
    }
    return {};
  }

  // Fallback: tenta extrair do texto "detalhes"
  Map<String, int> _extrairMapaDoDetalhe(String detalhes) {
    // Espera linhas tipo: "- Batata doce: 4 mudas (120 dias)"
    final out = <String, int>{};
    final lines = detalhes.split('\n');
    for (final ln in lines) {
      final s = ln.trim();
      if (!s.startsWith('-')) continue;
      final noDash = s.substring(1).trim(); // "Batata doce: 4 mudas (120 dias)"
      final parts = noDash.split(':');
      if (parts.length < 2) continue;
      final nome = parts[0].trim();
      final resto = parts.sublist(1).join(':').trim();
      final numMatch = RegExp(r'(\d+)').firstMatch(resto);
      if (numMatch == null) continue;
      final qtd = int.tryParse(numMatch.group(1) ?? '') ?? 0;
      if (nome.isNotEmpty && qtd > 0) out[nome] = qtd;
    }
    return out;
  }

  // -----------------------
  // Renomear
  // -----------------------
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
          ),
        ],
      ),
    );
  }

  // -----------------------
  // Irrigação
  // -----------------------
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.water_drop, color: Colors.blue, size: 28),
                  SizedBox(width: 10),
                  Text(
                    'Irrigação',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: chuvaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Chuva (mm)',
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
                    final chuva =
                        double.tryParse(
                          chuvaController.text.replaceAll(',', '.'),
                        ) ??
                        0.0;
                    final custo =
                        double.tryParse(
                          custoController.text.replaceAll(',', '.'),
                        ) ??
                        0.0;

                    Navigator.pop(ctx);
                    await _salvarIrrigacao(metodo, tempo, chuva, custo);
                  },
                  child: const Text('SALVAR'),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      tempoController.dispose();
      chuvaController.dispose();
      custoController.dispose();
    });
  }

  Future<void> _salvarIrrigacao(
    String metodo,
    int tempo,
    double chuva,
    double custo,
  ) async {
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

  // -----------------------
  // Colheita (PROFISSIONAL)
  // - baixa quantidade
  // - mantém saldo
  // - se zerar: conclui ciclo + libera canteiro
  // -----------------------
  void _mostrarDialogoColheita({
    required String idPlantioAtivo,
    required Map<String, int> mapaPlantioAtual,
    required String finalidadeCanteiro,
  }) {
    final selecionados = <String, bool>{};
    final ctrlsQtd = <String, TextEditingController>{};
    final receitaCtrl = TextEditingController(text: '0.00');
    final obsCtrl = TextEditingController();

    final culturas = mapaPlantioAtual.keys.toList()..sort();
    for (final c in culturas) {
      selecionados[c] = false;
      ctrlsQtd[c] = TextEditingController();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (contextModal, setModalState) {
          bool temErro = false;

          String? validar(String cultura) {
            if (selecionados[cultura] != true) return null;
            final max = mapaPlantioAtual[cultura] ?? 0;
            final txt = ctrlsQtd[cultura]?.text.trim() ?? '';
            if (txt.isEmpty) return 'Informe a qtd';
            final qtd = int.tryParse(txt) ?? 0;
            if (qtd <= 0) return 'Qtd > 0';
            if (qtd > max) return 'Máx: $max';
            return null;
          }

          for (final c in culturas) {
            if (validar(c) != null) temErro = true;
          }

          return Container(
            height: MediaQuery.of(contextModal).size.height * 0.92,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(contextModal).viewInsets.bottom + 16,
              top: 18,
              left: 18,
              right: 18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.agriculture,
                      color: Colors.green,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Registrar Colheita',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setModalState(() {
                          for (final c in culturas) {
                            selecionados[c] = true;
                            // Sugere colher tudo por padrão
                            ctrlsQtd[c]!.text = (mapaPlantioAtual[c] ?? 0)
                                .toString();
                          }
                        });
                      },
                      icon: const Icon(Icons.select_all),
                      label: const Text('Colher tudo'),
                    ),
                  ],
                ),
                Text(
                  'Finalidade: ${_labelFinalidade(finalidadeCanteiro)}',
                  style: TextStyle(
                    color: _corFinalidade(finalidadeCanteiro),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(),
                Expanded(
                  child: ListView(
                    children: [
                      ...culturas.map((cultura) {
                        final max = mapaPlantioAtual[cultura] ?? 0;
                        return Card(
                          elevation: 0,
                          color: Colors.grey.shade50,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: selecionados[cultura],
                                      onChanged: (v) => setModalState(
                                        () =>
                                            selecionados[cultura] = v ?? false,
                                      ),
                                      activeColor: Colors.green,
                                    ),
                                    Expanded(
                                      child: Text(
                                        cultura,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Chip(
                                      label: Text('Restante: $max'),
                                      backgroundColor: Colors.white,
                                    ),
                                  ],
                                ),
                                if (selecionados[cultura] == true)
                                  TextField(
                                    controller: ctrlsQtd[cultura],
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Qtd colhida',
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                      errorText: validar(cultura),
                                    ),
                                    onChanged: (_) => setModalState(() {}),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 8),
                      if (finalidadeCanteiro == 'comercio') ...[
                        TextField(
                          controller: receitaCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Receita da venda (R\$)',
                            prefixIcon: Icon(Icons.monetization_on),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ] else ...[
                        TextField(
                          controller: obsCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Observação (opcional)',
                            prefixIcon: Icon(Icons.notes),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _mostrarDialogoPerda(
                            idPlantioAtivo: idPlantioAtivo,
                            mapaPlantioAtual: mapaPlantioAtual,
                          );
                        },
                        icon: const Icon(Icons.bug_report, color: Colors.red),
                        label: const Text('Registrar Perda / Estrago / Praga'),
                      ),
                      const SizedBox(height: 90),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: temErro
                          ? null
                          : () async {
                              final colhidos = <String, int>{};
                              for (final c in culturas) {
                                if (selecionados[c] == true) {
                                  final qtd =
                                      int.tryParse(ctrlsQtd[c]!.text.trim()) ??
                                      0;
                                  if (qtd > 0) colhidos[c] = qtd;
                                }
                              }

                              if (colhidos.isEmpty) {
                                Navigator.pop(ctx);
                                return;
                              }

                              final receita =
                                  double.tryParse(
                                    receitaCtrl.text.replaceAll(',', '.'),
                                  ) ??
                                  0.0;
                              final obs = obsCtrl.text.trim();

                              Navigator.pop(ctx);
                              await _processarColheitaTransacao(
                                idPlantioAtivo: idPlantioAtivo,
                                colhidos: colhidos,
                                finalidadeCanteiro: finalidadeCanteiro,
                                receita: (finalidadeCanteiro == 'comercio')
                                    ? receita
                                    : 0.0,
                                observacao: (finalidadeCanteiro == 'consumo')
                                    ? obs
                                    : '',
                              );
                            },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('FINALIZAR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      for (final c in ctrlsQtd.values) {
        c.dispose();
      }
      receitaCtrl.dispose();
      obsCtrl.dispose();
    });
  }

  Future<void> _processarColheitaTransacao({
    required String idPlantioAtivo,
    required Map<String, int> colhidos,
    required String finalidadeCanteiro,
    required double receita,
    required String observacao,
  }) async {
    if (_uid == null) {
      _snack('⚠️ Você precisa estar logado.', bg: Colors.orange);
      return;
    }

    final db = FirebaseFirestore.instance;
    final plantioRef = db.collection('historico_manejo').doc(idPlantioAtivo);
    final canteiroRef = db.collection('canteiros').doc(widget.canteiroId);
    final colheitaRef = db.collection('historico_manejo').doc();

    try {
      bool cicloFinalizado = false;
      Map<String, int> mapaRestanteFinal = {};

      await db.runTransaction((tx) async {
        final plantioSnap = await tx.get(plantioRef);
        if (!plantioSnap.exists) {
          throw Exception('Plantio ativo não encontrado.');
        }

        final data = (plantioSnap.data() as Map<String, dynamic>?) ?? {};
        if (data['concluido'] == true) {
          throw Exception('Esse plantio já está concluído.');
        }

        // Mapa atual (prioriza mapa_plantio; fallback: extrai do texto)
        Map<String, int> mapaAtual = _intMapFromAny(data['mapa_plantio']);
        if (mapaAtual.isEmpty) {
          final detalhes = (data['detalhes'] ?? '').toString();
          mapaAtual = _extrairMapaDoDetalhe(detalhes);
        }

        if (mapaAtual.isEmpty) {
          throw Exception(
            'Não consegui identificar as quantidades plantadas. '
            'Garanta que o Plantio salve o campo "mapa_plantio".',
          );
        }

        // Aplica colheita (baixa quantidade)
        final mapaRestante = Map<String, int>.from(mapaAtual);
        colhidos.forEach((cultura, qtdColhida) {
          final atual = mapaRestante[cultura] ?? 0;
          final novo = atual - qtdColhida;
          if (novo <= 0) {
            mapaRestante.remove(cultura);
          } else {
            mapaRestante[cultura] = novo;
          }
        });

        mapaRestanteFinal = mapaRestante;

        final novoProduto = mapaRestante.keys.toList()..sort();

        cicloFinalizado = mapaRestante.isEmpty;

        // Cria registro de colheita (sempre)
        tx.set(colheitaRef, {
          'canteiro_id': widget.canteiroId,
          'uid_usuario': _uid,
          'data': FieldValue.serverTimestamp(),
          'tipo_manejo': 'Colheita',
          'produto': colhidos.keys.join(' + '),
          'detalhes':
              'Colhido: ${colhidos.entries.map((e) => '${e.key} (${e.value} un)').join(' | ')}',
          'concluido': true,
          'finalidade': finalidadeCanteiro,
          'mapa_movimento': colhidos,
          if (finalidadeCanteiro == 'comercio') 'receita': receita,
          if (finalidadeCanteiro == 'consumo' && observacao.isNotEmpty)
            'observacao_extra': observacao,
        });

        // Atualiza o plantio ativo (mantém saldo)
        tx.update(plantioRef, {
          'mapa_plantio': mapaRestante,
          'produto': novoProduto.join(' + '),
          if (cicloFinalizado) 'concluido': true,
          if (cicloFinalizado)
            'observacao_extra': 'Ciclo finalizado por colheita total.',
        });

        if (cicloFinalizado) {
          tx.update(canteiroRef, {'status': 'livre'});
        }
      });

      if (!mounted) return;
      _snack(
        cicloFinalizado
            ? '✅ Colheita registrada. Canteiro liberado.'
            : '✅ Colheita parcial registrada. Saldo mantido.',
        bg: Colors.green,
      );
      setState(() {});
    } catch (e) {
      _snack('❌ Falha ao processar colheita: $e', bg: Colors.red);
    }
  }

  // -----------------------
  // Perda / Baixa (com motivo)
  // -----------------------
  void _mostrarDialogoPerda({
    required String idPlantioAtivo,
    required Map<String, int> mapaPlantioAtual,
  }) {
    final culturas = mapaPlantioAtual.keys.toList()..sort();
    if (culturas.isEmpty) {
      _snack('⚠️ Não há culturas ativas para dar baixa.', bg: Colors.orange);
      return;
    }

    String culturaSel = culturas.first;
    final qtdCtrl = TextEditingController();
    final motivoCtrl = TextEditingController();

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
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          top: 18,
          left: 18,
          right: 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bug_report, color: Colors.red, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Registrar Perda',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: culturaSel,
                items: culturas
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => culturaSel = v ?? culturaSel,
                decoration: const InputDecoration(
                  labelText: 'Cultura',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Restante atual: ${mapaPlantioAtual[culturaSel] ?? 0}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: qtdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Qtd perdida',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: motivoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Motivo',
                  hintText: 'Ex: praga, chuva, mela, formiga, queimou no sol…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final qtd = int.tryParse(qtdCtrl.text.trim()) ?? 0;
                    final max = mapaPlantioAtual[culturaSel] ?? 0;
                    final motivo = motivoCtrl.text.trim();

                    if (qtd <= 0) {
                      _snack(
                        '⚠️ Informe uma quantidade > 0.',
                        bg: Colors.orange,
                      );
                      return;
                    }
                    if (qtd > max) {
                      _snack(
                        '⚠️ Não pode baixar mais que o restante ($max).',
                        bg: Colors.orange,
                      );
                      return;
                    }
                    if (motivo.isEmpty) {
                      _snack('⚠️ Informe o motivo.', bg: Colors.orange);
                      return;
                    }

                    Navigator.pop(ctx);
                    await _processarPerdaTransacao(
                      idPlantioAtivo: idPlantioAtivo,
                      cultura: culturaSel,
                      qtdPerdida: qtd,
                      motivo: motivo,
                    );
                  },
                  icon: const Icon(Icons.warning),
                  label: const Text('CONFIRMAR PERDA'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      qtdCtrl.dispose();
      motivoCtrl.dispose();
    });
  }

  Future<void> _processarPerdaTransacao({
    required String idPlantioAtivo,
    required String cultura,
    required int qtdPerdida,
    required String motivo,
  }) async {
    if (_uid == null) {
      _snack('⚠️ Você precisa estar logado.', bg: Colors.orange);
      return;
    }

    final db = FirebaseFirestore.instance;
    final plantioRef = db.collection('historico_manejo').doc(idPlantioAtivo);
    final canteiroRef = db.collection('canteiros').doc(widget.canteiroId);
    final perdaRef = db.collection('historico_manejo').doc();

    try {
      bool cicloFinalizado = false;

      await db.runTransaction((tx) async {
        final snap = await tx.get(plantioRef);
        if (!snap.exists) throw Exception('Plantio ativo não encontrado.');

        final data = (snap.data() as Map<String, dynamic>?) ?? {};
        if (data['concluido'] == true)
          throw Exception('Esse plantio já está concluído.');

        Map<String, int> mapaAtual = _intMapFromAny(data['mapa_plantio']);
        if (mapaAtual.isEmpty) {
          final detalhes = (data['detalhes'] ?? '').toString();
          mapaAtual = _extrairMapaDoDetalhe(detalhes);
        }
        if (mapaAtual.isEmpty) {
          throw Exception(
            'Não consegui identificar as quantidades plantadas. '
            'Garanta que o Plantio salve o campo "mapa_plantio".',
          );
        }

        final atual = mapaAtual[cultura] ?? 0;
        final novo = atual - qtdPerdida;
        if (novo <= 0) {
          mapaAtual.remove(cultura);
        } else {
          mapaAtual[cultura] = novo;
        }

        final novoProduto = mapaAtual.keys.toList()..sort();
        cicloFinalizado = mapaAtual.isEmpty;

        tx.set(perdaRef, {
          'canteiro_id': widget.canteiroId,
          'uid_usuario': _uid,
          'data': FieldValue.serverTimestamp(),
          'tipo_manejo': 'Perda',
          'produto': cultura,
          'detalhes': 'Baixa: $qtdPerdida un | Motivo: $motivo',
          'concluido': true,
          'mapa_movimento': {cultura: qtdPerdida},
        });

        tx.update(plantioRef, {
          'mapa_plantio': mapaAtual,
          'produto': novoProduto.join(' + '),
          if (cicloFinalizado) 'concluido': true,
          if (cicloFinalizado)
            'observacao_extra':
                'Ciclo finalizado por perda total / baixa final.',
        });

        if (cicloFinalizado) {
          tx.update(canteiroRef, {'status': 'livre'});
        }
      });

      if (!mounted) return;
      _snack(
        cicloFinalizado
            ? '✅ Perda registrada. Canteiro liberado.'
            : '✅ Perda registrada. Saldo atualizado.',
        bg: cicloFinalizado ? Colors.green : Colors.orange,
      );
      setState(() {});
    } catch (e) {
      _snack('❌ Falha ao registrar perda: $e', bg: Colors.red);
    }
  }

  // -----------------------
  // Editar / Baixa manual (mantido)
  // -----------------------
  void _mostrarDialogoPerdaOuEditar(
    String id,
    String detalheAtual,
    String obsAtual,
  ) {
    final detalheCtrl = TextEditingController(text: detalheAtual);
    final obsCtrl = TextEditingController(text: obsAtual);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar / Ajustar'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Aqui você edita o texto do registro.\n'
                'Para baixa inteligente (que mexe no saldo), use "Registrar Perda".',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: detalheCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Detalhes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: obsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Observação',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
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
            child: const Text('Salvar'),
          ),
        ],
      ),
    ).whenComplete(() {
      detalheCtrl.dispose();
      obsCtrl.dispose();
    });
  }

  // -----------------------
  // Plantio (mantido, mas salva mapa_plantio)
  // -----------------------
  void _mostrarDialogoPlantio(double cCanteiro, double lCanteiro) {
    if (_uid == null) {
      _snack('⚠️ Você precisa estar logado.', bg: Colors.orange);
      return;
    }
    if (cCanteiro <= 0 || lCanteiro <= 0) {
      _snack(
        '⚠️ Medidas inválidas. Edite o canteiro e corrija as medidas.',
        bg: Colors.orange,
      );
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

          final percentualOcupado = (areaOcupada / areaTotalCanteiro).clamp(
            0.0,
            1.0,
          );
          final estourou = (areaTotalCanteiro - areaOcupada) < 0;

          void adicionarPlanta(String p) {
            final info = _guiaCompleto[p] ?? {'eLinha': 0.5, 'ePlanta': 0.5};
            final eLinha = (info['eLinha'] as num).toDouble();
            final ePlanta = (info['ePlanta'] as num).toDouble();
            final areaUnit = (eLinha * ePlanta).clamp(0.0001, 999999.0);

            int qtdInicial = (areaTotalCanteiro / areaUnit).floor();
            if (qtdPorPlanta.isNotEmpty &&
                (areaTotalCanteiro - areaOcupada) > 0) {
              qtdInicial = ((areaTotalCanteiro - areaOcupada) / areaUnit)
                  .floor();
            }
            if (qtdInicial < 1) qtdInicial = 1;
            qtdPorPlanta[p] = qtdInicial;
          }

          final recomendadas = List<String>.from(
            _calendarioRegional[regiao]?[mes] ?? const [],
          );

          final porCategoria = <String, List<String>>{};
          for (final p in recomendadas) {
            final cat = (_guiaCompleto[p]?['cat'] ?? 'Outros').toString();
            porCategoria.putIfAbsent(cat, () => []);
            porCategoria[cat]!.add(p);
          }

          final outras =
              _guiaCompleto.keys
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
                fontSize: 11,
                color: isSel ? Colors.white : Colors.black87,
              ),
              onSelected: (v) {
                setModalState(() {
                  if (v) {
                    adicionarPlanta(planta);
                    if (!isRecommended)
                      _snack('⚠️ Atenção: Fora de época!', bg: Colors.orange);
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
                const Text(
                  'Planejamento de Plantio',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                LinearProgressIndicator(
                  value: percentualOcupado,
                  color: estourou ? Colors.red : Colors.green,
                ),
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
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                        ...porCategoria.entries.map(
                          (e) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 4,
                                ),
                                child: Text(
                                  e.key.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
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
                          data: Theme.of(
                            contextModal,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            title: const Text(
                              '⚠️ Outras Culturas (Fora de Época)',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            children: [
                              ...outrasPorCategoria.entries.map(
                                (e) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 8,
                                        bottom: 4,
                                      ),
                                      child: Text(
                                        e.key.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade300,
                                        ),
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
                            child: Column(
                              children: [
                                const Text(
                                  'Ajuste a Quantidade:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
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
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => setModalState(() {
                                          if (entry.value > 1)
                                            qtdPorPlanta[entry.key] =
                                                entry.value - 1;
                                        }),
                                      ),
                                      Text(
                                        '${entry.value}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle,
                                          color: Colors.green,
                                        ),
                                        onPressed: () => setModalState(() {
                                          qtdPorPlanta[entry.key] =
                                              entry.value + 1;
                                        }),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: obsController,
                            decoration: const InputDecoration(
                              labelText: 'Observação do Plantio',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: custoMudasController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Custo de Mudas/Sementes (R\$)',
                              prefixIcon: Icon(Icons.monetization_on),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ],
                    ),
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
                                    _guiaCompleto[planta]?['ciclo'] ?? 90,
                                  );
                                  resumo +=
                                      "- $planta: $qtd mudas ($ciclo dias)\n";
                                });

                                final custo =
                                    double.tryParse(
                                      custoMudasController.text.replaceAll(
                                        ',',
                                        '.',
                                      ),
                                    ) ??
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
                                      'mapa_plantio':
                                          qtdPorPlanta, // ✅ IMPORTANTÍSSIMO
                                    });

                                await _atualizarStatusCanteiro('ocupado');
                                if (!mounted) return;
                                Navigator.pop(ctx);
                                _snack(
                                  '✅ Plantio registrado! Canteiro agora está EM PRODUÇÃO.',
                                  bg: Colors.green,
                                );
                              } catch (e) {
                                _snack(
                                  '❌ Falha ao registrar plantio: $e',
                                  bg: Colors.red,
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: estourou
                            ? Colors.grey
                            : Theme.of(contextModal).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        estourou
                            ? 'FALTA ESPAÇO NO CANTEIRO'
                            : 'CONFIRMAR PLANTIO',
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      obsController.dispose();
      custoMudasController.dispose();
    });
  }

  // -----------------------
  // Menu de operações
  // -----------------------
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
        child: Column(
          children: [
            const Text(
              'Menu de Operações',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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
                    color: (statusAtual == 'livre')
                        ? Colors.green
                        : Colors.grey,
                    title: 'Novo Plantio',
                    subtitle: (statusAtual == 'livre')
                        ? 'Planejar'
                        : 'Bloqueado',
                    onTap: () {
                      Navigator.pop(ctx);
                      if (statusAtual != 'livre') {
                        _snack(
                          '⚠️ Finalize a safra (colheita/perda) antes de plantar de novo.',
                          bg: Colors.orange,
                        );
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
          ],
        ),
      ),
    );
  }

  // -----------------------
  // Financeiro separado
  // -----------------------
  Widget _financeCard({
    required double custoTotal,
    required double receitaTotal,
    required String finalidade,
  }) {
    // Se for consumo, eu não empurro "faturamento" na cara do usuário.
    // Mas ainda dá pra mostrar "custos" se você quiser futuramente.
    if (finalidade != 'comercio') return const SizedBox.shrink();

    final lucro = receitaTotal - custoTotal;

    return Container(
      margin: const EdgeInsets.fromLTRB(15, 12, 15, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet, size: 18),
              SizedBox(width: 8),
              Text('Financeiro', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Investido',
                  value: _money(custoTotal),
                  color: Colors.red,
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Faturamento',
                  value: _money(receitaTotal),
                  color: Colors.green,
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Balanço',
                  value: _money(lucro),
                  color: lucro >= 0 ? Colors.blue : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -----------------------
  // Dashboard novo (sem a faixa feia)
  // -----------------------
  Widget _buildDashboard({
    required Map<String, dynamic> dadosCanteiro,
    required double area,
    required String status,
    required String finalidade,
  }) {
    final corFundo = _getCorStatus(status);
    final corTexto = (status == 'livre')
        ? Colors.green.shade900
        : (status == 'manutencao'
              ? Colors.orange.shade900
              : Colors.red.shade900);

    final textoStatus = _getTextoStatus(status);

    Query q = FirebaseFirestore.instance
        .collection('historico_manejo')
        .where('canteiro_id', isEqualTo: widget.canteiroId);

    // Se estiver logado, filtra pelo uid (mais seguro e usa índice que você já criou).
    if (_uid != null) {
      q = q.where('uid_usuario', isEqualTo: _uid);
    }
    q = q.orderBy('data', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildFirestoreError(snapshot.error);
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(15),
            child: LinearProgressIndicator(),
          );
        }

        String? docIdPlantioAtivo;
        Map<String, int> mapaPlantio = {};
        Timestamp? dataPlantio;
        String produtosPlantados = '';

        double custoTotal = 0.0;
        double receitaTotal = 0.0;

        final docs = snapshot.data?.docs ?? [];

        for (final doc in docs) {
          final d = (doc.data() as Map<String, dynamic>?) ?? {};

          final custo = d['custo'];
          if (custo is num) custoTotal += custo.toDouble();

          final receita = d['receita'];
          if (receita is num) receitaTotal += receita.toDouble();

          if (d['tipo_manejo'] == 'Plantio' && d['concluido'] == false) {
            docIdPlantioAtivo = doc.id;
            produtosPlantados = (d['produto'] ?? '').toString();

            final mp = d['mapa_plantio'];
            mapaPlantio = _intMapFromAny(mp);

            if (mapaPlantio.isEmpty) {
              final detalhes = (d['detalhes'] ?? '').toString();
              mapaPlantio = _extrairMapaDoDetalhe(detalhes);
            }

            final ts = d['data'];
            if (ts is Timestamp) dataPlantio = ts;
          }
        }

        final temPlantioAtivo =
            (status == 'ocupado' && docIdPlantioAtivo != null);
        final culturasAtivas = mapaPlantio.keys.toList()..sort();

        return Column(
          children: [
            _financeCard(
              custoTotal: custoTotal,
              receitaTotal: receitaTotal,
              finalidade: finalidade,
            ),

            Container(
              margin: const EdgeInsets.all(15),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: corFundo,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: corTexto.withOpacity(0.25)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          textoStatus,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(color: corTexto),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          'Finalidade: ${_labelFinalidade(finalidade)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: _corFinalidade(finalidade),
                        ),
                      ),
                      const Spacer(),
                      if (temPlantioAtivo)
                        ElevatedButton.icon(
                          onPressed: () => _mostrarDialogoColheita(
                            idPlantioAtivo: docIdPlantioAtivo!,
                            mapaPlantioAtual: mapaPlantio,
                            finalidadeCanteiro: finalidade,
                          ),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text(
                            'Colher',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${area.toStringAsFixed(1)} m²',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: corTexto,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Área total',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          Icons.build_circle,
                          color: status == 'manutencao'
                              ? Colors.orange
                              : (status == 'ocupado'
                                    ? Colors.grey.withOpacity(0.35)
                                    : Colors.grey),
                        ),
                        tooltip: 'Manutenção',
                        onPressed: status == 'ocupado'
                            ? () => _snack(
                                '❌ Canteiro em produção. Finalize a safra antes de manutenção.',
                                bg: Colors.red,
                              )
                            : () => _atualizarStatusCanteiro(
                                status == 'manutencao' ? 'livre' : 'manutencao',
                              ),
                      ),
                    ],
                  ),

                  if (temPlantioAtivo &&
                      culturasAtivas.isNotEmpty &&
                      dataPlantio != null) ...[
                    const Divider(),
                    Row(
                      children: [
                        const Text(
                          'Safra atual',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          'Início: ${_fmtData(dataPlantio)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Chips das culturas com saldo
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: culturasAtivas.map((c) {
                        final rest = mapaPlantio[c] ?? 0;
                        return Chip(
                          label: Text('$c: $rest'),
                          backgroundColor: Colors.white,
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 10),
                    // Progresso por cultura (estimado)
                    ...culturasAtivas.map((planta) {
                      final ciclo = _toInt(
                        _guiaCompleto[planta]?['ciclo'] ?? 90,
                      );
                      final diasPassados = DateTime.now()
                          .difference(dataPlantio!.toDate())
                          .inDays;
                      final progresso =
                          (diasPassados / (ciclo <= 0 ? 1 : ciclo)).clamp(
                            0.0,
                            1.0,
                          );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$planta • ${diasPassados}d / ${ciclo}d',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progresso,
                                backgroundColor: Colors.white.withOpacity(0.55),
                                color: (progresso >= 1)
                                    ? Colors.green
                                    : Colors.orangeAccent,
                                minHeight: 8,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    // Ação rápida de perda (sem precisar entrar no menu)
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _mostrarDialogoPerda(
                          idPlantioAtivo: docIdPlantioAtivo!,
                          mapaPlantioAtual: mapaPlantio,
                        ),
                        icon: const Icon(Icons.bug_report, color: Colors.red),
                        label: const Text('Perda'),
                      ),
                    ),
                  ],

                  if (status == 'ocupado' && !temPlantioAtivo)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton(
                        onPressed: () => _atualizarStatusCanteiro('livre'),
                        child: const Text(
                          'Forçar liberação (sem plantio ativo)',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // -----------------------
  // HARD DELETE (DEV)
  // -----------------------
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
        Query q = db
            .collection('historico_manejo')
            .where('canteiro_id', isEqualTo: widget.canteiroId);
        if (_uid != null) q = q.where('uid_usuario', isEqualTo: _uid);
        final snap = await q.limit(400).get();
        if (snap.docs.isEmpty) break;

        final batch = db.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      await db.collection('canteiros').doc(widget.canteiroId).delete();

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);
      _snack(
        '✅ Excluído com sucesso (canteiro + histórico).',
        bg: Colors.green,
      );
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
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
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
          ),
        ],
      ),
    );
  }

  // -----------------------
  // Editar canteiro (agora com finalidade)
  // -----------------------
  void _mostrarDialogoEditarCanteiro(Map<String, dynamic> d) {
    _nomeController.text = (d['nome'] ?? '').toString();
    _compController.text = _toDouble(d['comprimento']).toString();
    _largController.text = _toDouble(d['largura']).toString();

    String finalidade = (d['finalidade'] ?? 'consumo').toString();
    if (finalidade != 'consumo' && finalidade != 'comercio')
      finalidade = 'consumo';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setLocalState) => AlertDialog(
          title: const Text('Editar Canteiro'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: finalidade,
                  items: const [
                    DropdownMenuItem(
                      value: 'consumo',
                      child: Text('Consumo (doméstico/familiar)'),
                    ),
                    DropdownMenuItem(
                      value: 'comercio',
                      child: Text('Comércio (venda/mercado)'),
                    ),
                  ],
                  onChanged: (v) =>
                      setLocalState(() => finalidade = v ?? finalidade),
                  decoration: const InputDecoration(
                    labelText: 'Finalidade',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _compController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Comprimento (m)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _largController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Largura (m)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nome = _nomeController.text.trim();
                final comp =
                    double.tryParse(
                      _compController.text.replaceAll(',', '.'),
                    ) ??
                    0.0;
                final larg =
                    double.tryParse(
                      _largController.text.replaceAll(',', '.'),
                    ) ??
                    0.0;

                if (nome.isEmpty || comp <= 0 || larg <= 0) {
                  _snack(
                    '⚠️ Preencha nome e medidas válidas.',
                    bg: Colors.orange,
                  );
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
                        'finalidade': finalidade, // ✅
                      });

                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _snack('✅ Canteiro atualizado.', bg: Colors.green);
                } catch (e) {
                  _snack('❌ Falha ao salvar: $e', bg: Colors.red);
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
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
      _snack(
        '🚫 Excluir definitivo desativado em produção. Use Arquivar.',
        bg: Colors.orange,
      );
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
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _hardDeleteCanteiroCascade();
            },
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );
  }

  // -----------------------
  // UI principal
  // -----------------------
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
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            body: _buildFirestoreError(snapshot.error),
          );
        }

        if (!snapshot.hasData ||
            snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
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

        String finalidade = (dados['finalidade'] ?? 'consumo').toString();
        if (finalidade != 'consumo' && finalidade != 'comercio')
          finalidade = 'consumo';

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    (dados['nome'] ?? 'Canteiro').toString(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () =>
                      _editarNomeCanteiro((dados['nome'] ?? '').toString()),
                  tooltip: 'Renomear',
                ),
              ],
            ),
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
                    value: 's',
                    child: Text(ativo ? 'Arquivar' : 'Reativar'),
                  ),
                  if (_enableHardDelete)
                    const PopupMenuItem(
                      value: 'x',
                      child: Text('Excluir DEFINITIVO (DEV)'),
                    ),
                ],
              ),
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
              _buildDashboard(
                dadosCanteiro: dados,
                area: area,
                status: status,
                finalidade: finalidade,
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: (() {
                    Query q = FirebaseFirestore.instance
                        .collection('historico_manejo')
                        .where('canteiro_id', isEqualTo: widget.canteiroId);
                    if (_uid != null)
                      q = q.where('uid_usuario', isEqualTo: _uid);
                    return q.orderBy('data', descending: true).snapshots();
                  })(),
                  builder: (context, snapH) {
                    if (snapH.hasError)
                      return _buildFirestoreError(snapH.error);
                    if (!snapH.hasData ||
                        snapH.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final list = snapH.data!.docs.toList();

                    if (list.isEmpty) {
                      return const Center(
                        child: Text(
                          'Sem histórico ainda. Use o botão MANEJO 👇',
                        ),
                      );
                    }

                    IconData iconByTipo(String tipo) {
                      switch (tipo) {
                        case 'Plantio':
                          return Icons.spa;
                        case 'Irrigação':
                          return Icons.water_drop;
                        case 'Colheita':
                          return Icons.agriculture;
                        case 'Perda':
                          return Icons.bug_report;
                        case 'Calagem':
                          return Icons.landscape;
                        default:
                          return Icons.event_note;
                      }
                    }

                    Color colorByTipo(String tipo) {
                      switch (tipo) {
                        case 'Plantio':
                          return Colors.green;
                        case 'Irrigação':
                          return Colors.blue;
                        case 'Colheita':
                          return Colors.teal;
                        case 'Perda':
                          return Colors.red;
                        case 'Calagem':
                          return Colors.orange;
                        default:
                          return Colors.grey;
                      }
                    }

                    return ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (ctx, i) {
                        final e =
                            (list[i].data() as Map<String, dynamic>?) ?? {};
                        final concluido = (e['concluido'] ?? false) == true;
                        final tipo = (e['tipo_manejo'] ?? '').toString();
                        final produto = (e['produto'] ?? '').toString();
                        final detalhes = (e['detalhes'] ?? '').toString();
                        final custo = _toDouble(e['custo']);
                        final receita = _toDouble(e['receita']);
                        final ts = e['data'] is Timestamp
                            ? e['data'] as Timestamp
                            : null;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 6,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: colorByTipo(
                                tipo,
                              ).withOpacity(0.12),
                              child: Icon(
                                iconByTipo(tipo),
                                color: colorByTipo(tipo),
                              ),
                            ),
                            title: Text(
                              produto.isEmpty ? tipo : produto,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                decoration: concluido
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (tipo.isNotEmpty)
                                  Text(
                                    tipo,
                                    style: TextStyle(
                                      color: colorByTipo(tipo),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (_fmtData(ts).isNotEmpty)
                                  Text(
                                    _fmtData(ts),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54,
                                    ),
                                  ),
                                if (detalhes.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(detalhes),
                                ],
                                if (custo > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Custo: ${_money(custo)}',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                if (receita > 0) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Receita: ${_money(receita)}',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
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
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.edit,
                                        color: Colors.orange,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Editar texto'),
                                    ],
                                  ),
                                ),
                                if (_enableHardDelete)
                                  const PopupMenuItem(
                                    value: 'excluir',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text('Excluir (DEV)'),
                                      ],
                                    ),
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

// -----------------------
// UI widgets pequenos
// -----------------------
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

// Card de menu
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
