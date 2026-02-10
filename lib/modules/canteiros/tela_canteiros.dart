import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TelaCanteiros extends StatefulWidget {
  const TelaCanteiros({super.key});

  @override
  State<TelaCanteiros> createState() => _TelaCanteirosState();
}

class _TelaCanteirosState extends State<TelaCanteiros> {
  final user = FirebaseAuth.instance.currentUser;

  // Função para Deletar Canteiro
  void _deletarCanteiro(String id) {
    FirebaseFirestore.instance.collection('canteiros').doc(id).delete();
  }

  // Função para abrir o Formulário de Cadastro (CORRIGIDO)
  void _mostrarFormulario(BuildContext context) {
    final nomeController = TextEditingController();
    final compController = TextEditingController();
    final largController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que o modal ocupe mais espaço se precisar
      builder: (ctx) => Padding(
        // AQUI ESTÁ A CORREÇÃO: O Padding vem aqui dentro para empurrar com o teclado
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Novo Canteiro', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(labelText: 'Nome (Ex: Canteiro da Alface)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: compController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Comprimento (m)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: largController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Largura (m)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: () async {
                // LÓGICA DE CÁLCULO DE ÁREA AUTOMÁTICA
                final nome = nomeController.text;
                // Troca vírgula por ponto para o cálculo não quebrar
                final comp = double.tryParse(compController.text.replaceAll(',', '.')) ?? 0;
                final larg = double.tryParse(largController.text.replaceAll(',', '.')) ?? 0;
                final area = comp * larg;

                if (nome.isNotEmpty && area > 0) {
                  // Salva no Firestore
                  await FirebaseFirestore.instance.collection('canteiros').add({
                    'uid_usuario': user?.uid, // Vincula ao usuário logado
                    'nome': nome,
                    'comprimento': comp,
                    'largura': larg,
                    'area_m2': area,
                    'data_criacao': FieldValue.serverTimestamp(),
                  });
                  Navigator.pop(ctx); // Fecha o formulário
                }
              },
              child: const Text('SALVAR CANTEIRO'),
            ),
            const SizedBox(height: 20), // Espaço extra no final
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Canteiros', style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // BOTÃO FLUTUANTE (+)
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormulario(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      
      // LISTA EM TEMPO REAL
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('canteiros')
            .where('uid_usuario', isEqualTo: user?.uid)
            .orderBy('data_criacao', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum canteiro cadastrado.\nToque no + para começar!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final canteiros = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: canteiros.length,
            itemBuilder: (context, index) {
              final dados = canteiros[index].data();
              final id = canteiros[index].id;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: const Icon(Icons.grid_on, color: Colors.green),
                  ),
                  title: Text(dados['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${dados['comprimento']}m x ${dados['largura']}m = ${dados['area_m2'].toStringAsFixed(2)} m²'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deletarCanteiro(id),
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