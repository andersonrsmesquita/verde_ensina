import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../canteiros/tela_canteiros.dart';
import '../solo/tela_diagnostico.dart';
import '../calculadoras/tela_calagem.dart';
import '../planejamento/tela_planejamento_consumo.dart';

class TelaTrilha extends StatefulWidget {
  const TelaTrilha({super.key});

  @override
  State<TelaTrilha> createState() => _TelaTrilhaState();
}

class _TelaTrilhaState extends State<TelaTrilha> {
  final user = FirebaseAuth.instance.currentUser;

  // --- LÓGICA DE ATALHO INTELIGENTE (MANTIDA) ---
  void _iniciarAcaoComCanteiro(BuildContext context, String acao) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.place, color: Colors.green),
                SizedBox(width: 10),
                Text('Selecionar Local',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Onde você vai realizar esta ação?',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('canteiros')
                    .where('uid_usuario', isEqualTo: user?.uid)
                    .where('ativo', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          const Icon(Icons.warning_amber,
                              color: Colors.orange, size: 40),
                          const SizedBox(height: 10),
                          const Text('Nenhum local ativo encontrado.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.orange)),
                          const SizedBox(height: 15),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const TelaCanteiros()));
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white),
                            child: const Text('Cadastrar Novo Local'),
                          )
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: snapshot.data!.docs.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (ctx, index) {
                      var doc = snapshot.data!.docs[index];
                      var dados = doc.data() as Map<String, dynamic>;
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.grid_on,
                              color: Colors.green, size: 20),
                        ),
                        title: Text(dados['nome'] ?? 'Sem nome',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${dados['area_m2']} m²'),
                        trailing: const Icon(Icons.arrow_forward_ios,
                            size: 14, color: Colors.grey),
                        onTap: () {
                          Navigator.pop(ctx); // Fecha modal
                          if (acao == 'diagnostico') {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => TelaDiagnostico(
                                        canteiroIdOrigem: doc.id)));
                          } else if (acao == 'calagem') {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        TelaCalagem(canteiroIdOrigem: doc.id)));
                          }
                        },
                      );
                    },
                  );
                },
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
      backgroundColor: const Color(0xFFF5F7FA), // Fundo suave
      appBar: AppBar(
        title: const Text('Jornada do Produtor',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // HEADER BOAS VINDAS
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Colors.green.shade800, Colors.green.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8))
                  ]),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.rocket_launch,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Vamos começar!',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 5),
                        Text(
                            'Siga os passos abaixo para ter uma colheita de sucesso.',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 30),

            // TIMELINE
            _TimelineItem(
              step: '1',
              title: 'Planejamento',
              desc: 'Defina o que plantar e calcule o consumo.',
              icon: Icons.edit_note,
              color: Colors.blue,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TelaPlanejamentoConsumo())),
            ),
            _TimelineItem(
              step: '2',
              title: 'Meus Locais',
              desc: 'Cadastre vasos e canteiros.',
              icon: Icons.grid_view,
              color: Colors.green,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TelaCanteiros())),
            ),
            _TimelineItem(
              step: '3',
              title: 'Diagnóstico',
              desc: 'Analise a saúde do seu solo.',
              icon: Icons.science,
              color: Colors.amber.shade700,
              onTap: () => _iniciarAcaoComCanteiro(context, 'diagnostico'),
            ),
            _TimelineItem(
              step: '4',
              title: 'Correção (Calagem)',
              desc: 'Calcule o calcário necessário.',
              icon: Icons.landscape,
              color: Colors.brown,
              onTap: () => _iniciarAcaoComCanteiro(context, 'calagem'),
            ),
            _TimelineItem(
              step: '5',
              title: 'Adubação & Plantio',
              desc: 'Em breve: Receitas de adubo e guia de plantio.',
              icon: Icons.eco,
              color: Colors.teal,
              isLocked: true,
            ),
            _TimelineItem(
              step: '6',
              title: 'Colheita & Venda',
              desc: 'Em breve: Gestão de produção e lucro.',
              icon: Icons.storefront,
              color: Colors.purple,
              isLast: true,
              isLocked: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String step;
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isLast;
  final bool isLocked;

  const _TimelineItem({
    required this.step,
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
    this.onTap,
    this.isLast = false,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // LADO ESQUERDO (LINHA E BOLINHA)
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: isLocked ? Colors.grey.shade300 : Colors.white,
                    border: Border.all(
                        color: isLocked ? Colors.transparent : color, width: 2),
                    shape: BoxShape.circle,
                    boxShadow: isLocked
                        ? []
                        : [
                            BoxShadow(
                                color: color.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ]),
                child: Center(
                  child: Text(step,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isLocked ? Colors.grey : color)),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(1)),
                  ),
                )
            ],
          ),
          const SizedBox(width: 15),

          // LADO DIREITO (CARD)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isLocked ? null : onTap,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ]),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: isLocked
                                  ? Colors.grey.shade100
                                  : color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(icon,
                              color: isLocked ? Colors.grey : color, size: 24),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isLocked
                                          ? Colors.grey
                                          : Colors.black87)),
                              const SizedBox(height: 4),
                              Text(desc,
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                      height: 1.3)),
                            ],
                          ),
                        ),
                        if (!isLocked)
                          const Icon(Icons.arrow_forward_ios,
                              size: 14, color: Colors.grey)
                        else
                          const Icon(Icons.lock, size: 14, color: Colors.grey)
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
