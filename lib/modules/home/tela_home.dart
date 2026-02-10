import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../canteiros/tela_canteiros.dart';
import '../solo/tela_diagnostico.dart';
import '../calculadoras/tela_calagem.dart';
// Import da nova tela de planejamento
import '../planejamento/tela_planejamento_consumo.dart';

class TelaHome extends StatelessWidget {
  const TelaHome({super.key});

  // --- LÓGICA DE ATALHO INTELIGENTE (NÚCLEO) ---
  void _iniciarAcaoComCanteiro(BuildContext context, String acao) {
    final user = FirebaseAuth.instance.currentUser;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para qual canteiro?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Selecione o local para vincular este registro:',
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
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          const Text('Nenhum canteiro ativo encontrado.'),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const TelaCanteiros()));
                            },
                            child: const Text('Cadastrar Canteiro Agora'),
                          )
                        ],
                      ),
                    );
                  }

                  return ListView(
                    shrinkWrap: true,
                    children: snapshot.data!.docs.map((doc) {
                      return ListTile(
                        leading: const Icon(Icons.grid_on, color: Colors.green),
                        title: Text(doc['nome'],
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${doc['area_m2']} m²'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(ctx); // Fecha o seletor

                          // Direciona para a tela correta passando o ID do canteiro
                          if (acao == 'diagnostico') {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TelaDiagnostico(canteiroIdOrigem: doc.id),
                                ));
                          } else if (acao == 'calagem') {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TelaCalagem(canteiroIdOrigem: doc.id),
                                ));
                          }
                        },
                      );
                    }).toList(),
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Jornada do Cultivo',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
            onPressed: () {
              // Reseta a navegação para garantir estado limpo
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const TelaHome()),
                  (route) => false);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _HeaderBoasVindas(),
          const SizedBox(height: 25),

          // --- FASE 0: PLANEJAMENTO (NOVO!) ---
          _TimelineItem(
            fase: 0, // Fase Zero = Antes de começar
            titulo: 'Planejamento & Consumo',
            descricao:
                'Descubra quanto plantar para nunca faltar comida na mesa.',
            corIcone: Colors.blue,
            icone: Icons.calculate, // Ícone de calculadora/planejamento
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const TelaPlanejamentoConsumo())),
            isLast: false,
          ),

          // --- FASE 1: ESTRUTURA ---
          _TimelineItem(
            fase: 1,
            titulo: 'Meus Canteiros',
            descricao:
                'Organize sua área. Cadastre onde você vai plantar e veja o histórico.',
            corIcone: Colors.green,
            icone: Icons.grid_on,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TelaCanteiros())),
            isLast: false,
          ),

          // --- FASE 2: O SOLO (ATALHO) ---
          _TimelineItem(
            fase: 2,
            titulo: 'Diagnóstico de Solo',
            descricao:
                'Antes de adubar, precisamos conhecer a terra. Teste manual ou laudo.',
            corIcone: Colors.brown,
            icone: Icons.science,
            onTap: () => _iniciarAcaoComCanteiro(context, 'diagnostico'),
            isLast: false,
          ),

          // --- FASE 3: A CORREÇÃO (ATALHO) ---
          _TimelineItem(
            fase: 3,
            titulo: 'Calculadora de Calagem',
            descricao:
                'Corrija a acidez (pH). Sem isso, a planta não consegue comer.',
            corIcone: Colors.blueGrey,
            icone: Icons.landscape,
            onTap: () => _iniciarAcaoComCanteiro(context, 'calagem'),
            isLast: false,
          ),

          // --- FASE 4: NUTRIÇÃO (EM BREVE) ---
          const _TimelineItem(
            fase: 4,
            titulo: 'Adubação (Em Breve)',
            descricao: 'O "prato de comida" da planta. N-P-K na medida certa.',
            corIcone: Colors.orange,
            icone: Icons.eco,
            onTap: null,
            isLast: false,
            bloqueado: true,
          ),

          // --- FASE 5: COLHEITA (EM BREVE) ---
          const _TimelineItem(
            fase: 5,
            titulo: 'Colheita & Venda',
            descricao: 'Registre sua produção e anuncie no marketplace.',
            corIcone: Colors.purple,
            icone: Icons.shopping_basket,
            onTap: null,
            isLast: true,
            bloqueado: true,
          ),
        ],
      ),
    );
  }
}

// --- COMPONENTES VISUAIS (Header e TimelineItem) ---

class _HeaderBoasVindas extends StatelessWidget {
  const _HeaderBoasVindas();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade800, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 40),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Siga a Trilha!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 5),
                Text('Complete as fases para garantir uma colheita produtiva.',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final int fase;
  final String titulo;
  final String descricao;
  final IconData icone;
  final Color corIcone;
  final VoidCallback? onTap;
  final bool isLast;
  final bool bloqueado;

  const _TimelineItem({
    required this.fase,
    required this.titulo,
    required this.descricao,
    required this.icone,
    required this.corIcone,
    required this.onTap,
    this.isLast = false,
    this.bloqueado = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: bloqueado ? Colors.grey[300] : corIcone,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    const BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2))
                  ],
                ),
                child: Center(
                  child: Text(
                    fase.toString(),
                    style: TextStyle(
                        color: bloqueado ? Colors.grey : Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey[300],
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: InkWell(
                  onTap: bloqueado ? null : onTap,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: bloqueado
                                ? Colors.grey[100]
                                : corIcone.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icone,
                              color: bloqueado ? Colors.grey : corIcone,
                              size: 28),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titulo,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      bloqueado ? Colors.grey : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                descricao,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    height: 1.3),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          bloqueado
                              ? Icons.lock_outline
                              : Icons.arrow_forward_ios,
                          color: Colors.grey[400],
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
