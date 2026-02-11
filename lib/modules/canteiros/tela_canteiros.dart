import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'tela_detalhes_canteiro.dart';

class TelaCanteiros extends StatefulWidget {
  const TelaCanteiros({super.key});

  @override
  State<TelaCanteiros> createState() => _TelaCanteirosState();
}

class _TelaCanteirosState extends State<TelaCanteiros> {
  final user = FirebaseAuth.instance.currentUser;

  // --- FORMULÁRIO DE CADASTRO SIMPLIFICADO ---
  void _mostrarFormulario(BuildContext context) {
    final nomeController = TextEditingController();
    final compController = TextEditingController();
    final largController = TextEditingController();
    final volumeController = TextEditingController();

    // Estado local do modal para alternar entre Vaso/Canteiro
    String tipoLocal = 'Canteiro';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Para o teclado não cobrir
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(builder: (context, setModalState) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 25,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.add_circle_outline, color: Colors.green, size: 28),
                  SizedBox(width: 10),
                  Text('Novo Local de Cultivo',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),

              // 1. NOME
              TextField(
                controller: nomeController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nome (Ex: Horta 1, Vaso da Varanda)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 15),

              // 2. TIPO (SELECTOR VISUAL)
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Canteiro / Chão'),
                      selected: tipoLocal == 'Canteiro',
                      onSelected: (bool selected) {
                        setModalState(() => tipoLocal = 'Canteiro');
                      },
                      selectedColor: Colors.green.shade100,
                      labelStyle: TextStyle(
                          color: tipoLocal == 'Canteiro'
                              ? Colors.green.shade900
                              : Colors.black,
                          fontWeight: tipoLocal == 'Canteiro'
                              ? FontWeight.bold
                              : FontWeight.normal),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Vaso / Recipiente'),
                      selected: tipoLocal == 'Vaso',
                      onSelected: (bool selected) {
                        setModalState(() => tipoLocal = 'Vaso');
                      },
                      selectedColor: Colors.green.shade100,
                      labelStyle: TextStyle(
                          color: tipoLocal == 'Vaso'
                              ? Colors.green.shade900
                              : Colors.black,
                          fontWeight: tipoLocal == 'Vaso'
                              ? FontWeight.bold
                              : FontWeight.normal),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // 3. CAMPOS DINÂMICOS
              if (tipoLocal == 'Canteiro') ...[
                // Dimensões do Canteiro
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: compController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Comp. (m)',
                              suffixText: 'm',
                              border: OutlineInputBorder()))),
                  const SizedBox(width: 15),
                  Expanded(
                      child: TextField(
                          controller: largController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Larg. (m)',
                              suffixText: 'm',
                              border: OutlineInputBorder()))),
                ]),
                // REMOVIDO: Campo de Textura do Solo
              ] else ...[
                // Volume do Vaso
                TextField(
                  controller: volumeController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Volume do Vaso (Litros)',
                    suffixText: 'L',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_drink),
                    helperText: 'Ex: Baldes comuns têm ~12 Litros.',
                  ),
                ),
              ],

              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final nome = nomeController.text;

                    // Lógica de Salvamento
                    double areaOuVolume = 0;
                    double comp = 0;
                    double larg = 0;

                    if (tipoLocal == 'Canteiro') {
                      comp = double.tryParse(
                              compController.text.replaceAll(',', '.')) ??
                          0;
                      larg = double.tryParse(
                              largController.text.replaceAll(',', '.')) ??
                          0;
                      areaOuVolume = comp * larg; // Área em m2
                    } else {
                      areaOuVolume = double.tryParse(
                              volumeController.text.replaceAll(',', '.')) ??
                          0; // Volume em Litros
                    }

                    if (nome.isNotEmpty && areaOuVolume > 0) {
                      await FirebaseFirestore.instance
                          .collection('canteiros')
                          .add({
                        'uid_usuario': user?.uid,
                        'nome': nome,
                        'tipo': tipoLocal,
                        // removido: 'textura_solo'
                        'comprimento': comp,
                        'largura': larg,
                        'area_m2': areaOuVolume, // Salva m2 ou Litros
                        'ativo': true,
                        'status': 'livre',
                        'data_criacao': FieldValue.serverTimestamp(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('SALVAR LOCAL',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // Helper para cor do ícone e badge baseado no status
  Color _getCorStatus(String? status) {
    switch (status) {
      case 'ocupado':
        return Colors.red;
      case 'manutencao':
        return Colors.orange;
      default:
        return Colors.green; // 'livre'
    }
  }

  String _getTextoStatus(String? status) {
    switch (status) {
      case 'ocupado':
        return 'Ocupado';
      case 'manutencao':
        return 'Manutenção';
      default:
        return 'Livre';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Meus Locais',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormulario(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('NOVO LOCAL'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('canteiros')
            .where('uid_usuario', isEqualTo: user?.uid)
            .orderBy('data_criacao', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          if (snapshot.hasError) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Erro ao carregar.')));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Colors.green.shade50, shape: BoxShape.circle),
                    child: Icon(Icons.spa_outlined,
                        size: 60, color: Colors.green.shade300),
                  ),
                  const SizedBox(height: 20),
                  const Text('Sua horta está vazia.',
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  const Text('Adicione seu primeiro vaso ou canteiro.',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final canteiros = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
            itemCount: canteiros.length,
            itemBuilder: (context, index) {
              final doc = canteiros[index];
              final dados = doc.data() as Map<String, dynamic>;
              final id = doc.id;
              final nome = dados['nome'] ?? 'Sem Nome';
              final area =
                  (dados['area_m2'] ?? 0).toDouble(); // Pode ser m2 ou Litros
              final tipo = dados['tipo'] ?? 'Canteiro';
              final bool ativo = dados['ativo'] ?? true;
              final String status = dados['status'] ?? 'livre';

              final double percentualUso = (status == 'ocupado') ? 1.0 : 0.0;
              Color corStatus = _getCorStatus(status);

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                TelaDetalhesCanteiro(canteiroId: id)));
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Ícone muda dependendo se é Vaso ou Canteiro
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ativo
                                ? corStatus.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                              tipo == 'Vaso'
                                  ? Icons.local_florist
                                  : Icons.grid_on, // Ícone Inteligente
                              color: ativo ? corStatus : Colors.grey,
                              size: 28),
                        ),
                        const SizedBox(width: 15),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                      child: Text(nome,
                                          style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                              color: ativo
                                                  ? Colors.black87
                                                  : Colors.grey,
                                              decoration: ativo
                                                  ? null
                                                  : TextDecoration
                                                      .lineThrough))),
                                  if (ativo)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: corStatus.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color:
                                                  corStatus.withOpacity(0.3))),
                                      child: Text(_getTextoStatus(status),
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: corStatus)),
                                    )
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(children: [
                                Icon(
                                    tipo == 'Vaso'
                                        ? Icons.water_drop
                                        : Icons.aspect_ratio,
                                    size: 14,
                                    color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                // Mostra unidade correta (Litros ou m²)
                                Text(
                                    tipo == 'Vaso'
                                        ? '${area.toStringAsFixed(1)} Litros'
                                        : '${area.toStringAsFixed(2)} m²',
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 13)),
                                if (!ativo) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                      child: const Text('ARQUIVADO',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white)))
                                ]
                              ]),
                              if (ativo && status == 'ocupado') ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: percentualUso,
                                    backgroundColor: Colors.red.shade50,
                                    color: Colors.red.shade300,
                                    minHeight: 4,
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.arrow_forward_ios,
                            size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
