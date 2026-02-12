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

  // --- ALGORITMO DE AGRUPAMENTO ---
  void _processarInteligencia() {
    final fila = List<Map<String, dynamic>>.from(widget.itensPlanejados);

    fila.sort((a, b) => (b['area'] as double).compareTo(a['area'] as double));

    final canteiros = <Map<String, dynamic>>[];

    while (fila.isNotEmpty) {
      final mestre = fila.removeAt(0);

      final canteiro = <String, dynamic>{
        'nome': 'Canteiro de ${mestre['planta']}',
        'plantas': [mestre],
        'areaTotal': (mestre['area'] as double),
        'evitar': List<String>.from(mestre['evitar'] ?? const []),
        'par': List<String>.from(mestre['par'] ?? const []),
      };

      final sobrou = <Map<String, dynamic>>[];

      for (final candidata in fila) {
        final nome = (candidata['planta'] ?? '').toString();
        final inimigosCandidata = List<String>.from(
          candidata['evitar'] ?? const [],
        );

        final canteiroOdeia = (canteiro['evitar'] as List).contains(nome);

        bool candidataOdeia = false;
        for (final p in (canteiro['plantas'] as List)) {
          final plantaNoCanteiro = (p['planta'] ?? '').toString();
          if (inimigosCandidata.contains(plantaNoCanteiro)) {
            candidataOdeia = true;
            break;
          }
        }

        if (!canteiroOdeia && !candidataOdeia) {
          (canteiro['plantas'] as List).add(candidata);
          canteiro['areaTotal'] =
              (canteiro['areaTotal'] as double) + (candidata['area'] as double);
          (canteiro['evitar'] as List).addAll(inimigosCandidata);

          if ((canteiro['plantas'] as List).length == 2) {
            canteiro['nome'] = '${canteiro['nome']} & Cia';
          }
        } else {
          sobrou.add(candidata);
        }
      }

      fila
        ..clear()
        ..addAll(sobrou);

      canteiros.add(canteiro);
    }

    setState(() => _canteirosSugeridos = canteiros);
  }

  Future<void> _criarTodosCanteiros() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Você precisa estar logado para salvar o planejamento.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _salvando = true);

    final fs = FirebaseFirestore.instance;
    final batch = fs.batch();

    try {
      for (final sugestao in _canteirosSugeridos) {
        final canteiroRef = fs.collection('canteiros').doc();

        final area = (sugestao['areaTotal'] as num?)?.toDouble() ?? 0.0;
        final largura = 1.0;
        final comprimento = area > 0 ? area / largura : 1.0;

        batch.set(canteiroRef, {
          'uid_usuario': user.uid,
          'nome': (sugestao['nome'] ?? 'Canteiro').toString(),
          'area_m2': double.parse(area.toStringAsFixed(2)),
          'largura': largura,
          'comprimento': double.parse(comprimento.toStringAsFixed(2)),
          'ativo': true,
          'status': 'ocupado',
          'data_criacao': FieldValue.serverTimestamp(),
          'data_atualizacao': FieldValue.serverTimestamp(),
        });

        final histRef = fs.collection('historico_manejo').doc();

        final plantas = List<Map<String, dynamic>>.from(
          sugestao['plantas'] as List,
        );
        final nomes = <String>[];
        var detalhes = "Plantio Automático (Planejamento):\n";

        for (final p in plantas) {
          final nome = (p['planta'] ?? '').toString();
          final mudas = (p['mudas'] ?? 0).toString();
          nomes.add(nome);
          detalhes += "- $nome: $mudas mudas\n";
        }

        batch.set(histRef, {
          'canteiro_id': canteiroRef.id,
          'uid_usuario': user.uid,
          'tipo_manejo': 'Plantio',
          'produto': nomes.join(' + '),
          'detalhes': detalhes,
          'data': FieldValue.serverTimestamp(),
          'quantidade_g': 0,
          'concluido': false,
          'data_colheita_prevista': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 90)),
          ),
        });
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Canteiros criados e plantados!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar planejamento: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'A Inteligência organizou seu consumo em ${_canteirosSugeridos.length} canteiros:',
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _canteirosSugeridos.length,
              itemBuilder: (ctx, i) {
                final canteiro = _canteirosSugeridos[i];
                final area = (canteiro['areaTotal'] as num?)?.toDouble() ?? 0.0;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                (canteiro['nome'] ?? 'Canteiro').toString(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ),
                            Chip(
                              label: Text(
                                '${area.toStringAsFixed(1)} m²',
                                style: const TextStyle(color: Colors.white),
                              ),
                              backgroundColor: Colors.blue,
                            ),
                          ],
                        ),
                        const Divider(),
                        const Text(
                          'Culturas deste canteiro:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (canteiro['plantas'] as List).map<Widget>((
                            p,
                          ) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              child: Text(
                                '${p['planta']} (${p['mudas']}x)',
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
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
                  foregroundColor: Colors.white,
                ),
                icon: _salvando
                    ? const SizedBox()
                    : const Icon(Icons.check_circle),
                label: _salvando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'APROVAR E PLANTAR AGORA',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
