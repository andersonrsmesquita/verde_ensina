import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TelaGeradorCanteiros extends StatefulWidget {
  final List<Map<String, dynamic>> itensPlanejados;

  const TelaGeradorCanteiros({super.key, required this.itensPlanejados});

  @override
  State<TelaGeradorCanteiros> createState() => _TelaGeradorCanteirosState();
}

class _TelaGeradorCanteirosState extends State<TelaGeradorCanteiros> {
  List<Map<String, dynamic>> _canteirosSugeridos = [];
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _processarInteligencia();
  }

  // --- ALGORITMO DE AGRUPAMENTO (O CÉREBRO) ---
  void _processarInteligencia() {
    // Clona a lista para não estragar a original
    List<Map<String, dynamic>> fila = List.from(widget.itensPlanejados);

    // Ordena: Plantas que ocupam mais área primeiro
    fila.sort((a, b) => (b['area'] as double).compareTo(a['area'] as double));

    List<Map<String, dynamic>> canteiros = [];

    while (fila.isNotEmpty) {
      var mestre = fila.removeAt(0); // Pega a maior planta

      Map<String, dynamic> canteiro = {
        'nome': 'Canteiro de ${mestre['planta']}',
        'plantas': [mestre],
        'areaTotal': mestre['area'],
        'evitar': List<String>.from(mestre['evitar'] ?? []),
        'par': List<String>.from(mestre['par'] ?? []),
      };

      // Tenta encaixar outras plantas neste mesmo canteiro (Consórcio)
      List<Map<String, dynamic>> sobrou = [];
      for (var candidata in fila) {
        String nome = candidata['planta'];
        List<String> inimigosCandidata =
            List<String>.from(candidata['evitar'] ?? []);

        bool canteiroOdeia = (canteiro['evitar'] as List).contains(nome);

        bool candidataOdeia = false;
        for (var p in canteiro['plantas']) {
          if (inimigosCandidata.contains(p['planta'])) candidataOdeia = true;
        }

        if (!canteiroOdeia && !candidataOdeia) {
          canteiro['plantas'].add(candidata);
          canteiro['areaTotal'] += candidata['area'];
          (canteiro['evitar'] as List).addAll(inimigosCandidata);

          if (canteiro['plantas'].length == 2) {
            canteiro['nome'] += ' & Cia';
          }
        } else {
          sobrou.add(candidata);
        }
      }
      fila = sobrou; // Atualiza a fila com quem não coube
      canteiros.add(canteiro);
    }

    setState(() {
      _canteirosSugeridos = canteiros;
    });
  }

  Future<void> _criarTodosCanteiros() async {
    setState(() => _salvando = true);
    final user = FirebaseAuth.instance.currentUser;
    final batch = FirebaseFirestore.instance.batch();

    try {
      for (var sugestao in _canteirosSugeridos) {
        // 1. Cria Canteiro JÁ COM STATUS OCUPADO
        var docRef = FirebaseFirestore.instance.collection('canteiros').doc();
        double area = sugestao['areaTotal'];
        double comp = area > 0 ? area / 1.0 : 1.0; // Assume largura 1.0m

        batch.set(docRef, {
          'uid_usuario': user?.uid,
          'nome': sugestao['nome'],
          'area_m2': double.parse(area.toStringAsFixed(2)),
          'largura': 1.0,
          'comprimento': double.parse(comp.toStringAsFixed(2)),
          'ativo': true,
          'status': 'ocupado', // <--- AQUI ESTÁ A CORREÇÃO! NASCE OCUPADO.
          'data_criacao': FieldValue.serverTimestamp(),
        });

        // 2. Cria Histórico de Plantio Vinculado
        var histRef =
            FirebaseFirestore.instance.collection('historico_manejo').doc();
        List<String> nomes = [];
        String detalhes = "Plantio Automático (Planejamento):\n";

        for (var p in sugestao['plantas']) {
          nomes.add(p['planta']);
          detalhes += "- ${p['planta']}: ${p['mudas']} mudas\n";
        }

        batch.set(histRef, {
          'canteiro_id': docRef.id,
          'uid_usuario': user?.uid,
          'tipo_manejo': 'Plantio',
          'produto': nomes.join(' + '),
          'detalhes': detalhes,
          'data': FieldValue.serverTimestamp(),
          'quantidade_g': 0,
          'concluido': false, // <--- Importante para aparecer o botão colher
          'data_colheita_prevista':
              Timestamp.fromDate(DateTime.now().add(const Duration(days: 90)))
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Canteiros criados e plantados!')));
        // Fecha as telas para voltar à Home (precisa fechar o gerador e o planejador)
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
          title: const Text('Plano de Canteiros'),
          backgroundColor: Colors.blue[800],
          foregroundColor: Colors.white),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'A Inteligência Artificial organizou seu consumo em ${_canteirosSugeridos.length} canteiros otimizados:',
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _canteirosSugeridos.length,
              itemBuilder: (ctx, i) {
                var canteiro = _canteirosSugeridos[i];
                double area = canteiro['areaTotal'];

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Text(canteiro['nome'],
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueAccent))),
                            Chip(
                                label: Text('${area.toStringAsFixed(1)} m²',
                                    style:
                                        const TextStyle(color: Colors.white)),
                                backgroundColor: Colors.blue)
                          ],
                        ),
                        const Divider(),
                        const Text('Culturas deste canteiro:',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              (canteiro['plantas'] as List).map<Widget>((p) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border:
                                      Border.all(color: Colors.green.shade200)),
                              child: Text('${p['planta']} (${p['mudas']}x)',
                                  style: TextStyle(
                                      color: Colors.green.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            );
                          }).toList(),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _salvando ? null : _criarTodosCanteiros,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white),
                icon: _salvando
                    ? const SizedBox()
                    : const Icon(Icons.check_circle),
                label: _salvando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('APROVAR E PLANTAR AGORA',
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
    );
  }
}
