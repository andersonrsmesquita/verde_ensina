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

  // --- FORMULÁRIO DE CADASTRO ---
  void _mostrarFormulario(BuildContext context) {
    final nomeController = TextEditingController();
    final compController = TextEditingController();
    final largController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
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
                Text('Novo Canteiro', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nomeController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nome (Ex: Horta de Alface)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 15),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: compController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Comp. (m)', suffixText: 'm', border: OutlineInputBorder()))),
              const SizedBox(width: 15),
              Expanded(
                  child: TextField(
                      controller: largController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Larg. (m)', suffixText: 'm', border: OutlineInputBorder()))),
            ]),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final nome = nomeController.text;
                  final comp = double.tryParse(compController.text.replaceAll(',', '.')) ?? 0;
                  final larg = double.tryParse(largController.text.replaceAll(',', '.')) ?? 0;
                  final area = comp * larg;

                  if (nome.isNotEmpty && area > 0) {
                    await FirebaseFirestore.instance.collection('canteiros').add({
                      'uid_usuario': user?.uid,
                      'nome': nome,
                      'comprimento': comp,
                      'largura': larg,
                      'area_m2': area,
                      'ativo': true,
                      'data_criacao': FieldValue.serverTimestamp(),
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('SALVAR CANTEIRO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Meus Canteiros', style: TextStyle(fontWeight: FontWeight.bold)),
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
        label: const Text('NOVO CANTEIRO'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('canteiros')
            .where('uid_usuario', isEqualTo: user?.uid)
            .orderBy('data_criacao', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (snapshot.hasError) {
            return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Erro de índice. Verifique o console.')));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                    child: Icon(Icons.spa_outlined, size: 60, color: Colors.green.shade300),
                  ),
                  const SizedBox(height: 20),
                  const Text('Sua horta está vazia.', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  const Text('Comece criando seu primeiro canteiro.', style: TextStyle(color: Colors.grey)),
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
              final area = dados['area_m2'] ?? 0;
              final bool ativo = dados['ativo'] ?? true;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TelaDetalhesCanteiro(canteiroId: id),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ativo 
                                ? Colors.green.withValues(alpha: 0.1) 
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.grid_on, color: ativo ? Colors.green : Colors.grey, size: 28),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nome, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: ativo ? Colors.black87 : Colors.grey, decoration: ativo ? null : TextDecoration.lineThrough)),
                              const SizedBox(height: 4),
                              Row(children: [
                                Icon(Icons.aspect_ratio, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text('${area.toStringAsFixed(2)} m²', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                if (!ativo) ...[
                                  const SizedBox(width: 8),
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)), child: const Text('ARQUIVADO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)))
                                ]
                              ]),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
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