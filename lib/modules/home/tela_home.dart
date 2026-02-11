import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Imports das suas telas funcionais
import '../canteiros/tela_canteiros.dart';
import '../solo/tela_diagnostico.dart';
import '../calculadoras/tela_calagem.dart';
import '../planejamento/tela_planejamento_consumo.dart';
import '../adubacao/tela_adubacao_organo15.dart'; // <--- NOVO IMPORT

class TelaHome extends StatefulWidget {
  const TelaHome({super.key});

  @override
  State<TelaHome> createState() => _TelaHomeState();
}

class _TelaHomeState extends State<TelaHome> {
  int _indiceAtual = 0; // 0: Início, 1: Jornada, 2: Perfil

  // Lista das telas para cada aba
  final List<Widget> _telas = [
    const _AbaInicioDashboard(), // Dashboard Geral
    const _AbaJornadaTrilha(), // Sua Trilha de Plantio (Timeline)
    const _AbaPerfil(), // Perfil do Usuário
  ];

  void _aoClicarNaBarra(int index) {
    setState(() {
      _indiceAtual = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _telas[_indiceAtual],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _indiceAtual,
          onTap: _aoClicarNaBarra,
          backgroundColor: Colors.white,
          selectedItemColor: Theme.of(context).colorScheme.primary, // Verde
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_filled), label: 'Início'),
            BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Jornada'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ABA 1: INÍCIO (DASHBOARD GERAL)
// ============================================================================
class _AbaInicioDashboard extends StatelessWidget {
  const _AbaInicioDashboard();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(children: [
          const Icon(Icons.eco, color: Colors.white),
          const SizedBox(width: 10),
          const Text('Verde Ensina',
              style: TextStyle(fontWeight: FontWeight.bold))
        ]),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.notifications_none), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Olá, Produtor! 👋',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const Text('Visão geral da sua produção.',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 20),

            // Card Atalho para Jornada
            InkWell(
              onTap: () {
                final state = context.findAncestorStateOfType<_TelaHomeState>();
                state?._aoClicarNaBarra(1); // Vai para a aba Jornada
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Colors.green.shade700, Colors.green.shade500]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5))
                    ]),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Continuar Jornada',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                            SizedBox(height: 5),
                            Text('Acessar Trilha de Plantio',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                          ]),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle),
                      child:
                          const Icon(Icons.arrow_forward, color: Colors.white),
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),
            const Text('Gestão & Serviços',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.5,
              children: [
                _CardMenuGrande(
                    titulo: 'Financeiro',
                    icone: Icons.attach_money,
                    cor: Colors.blue,
                    onTap: () {}),
                _CardMenuGrande(
                    titulo: 'Mercado',
                    subtitulo: 'Compra/Venda',
                    icone: Icons.storefront,
                    cor: Colors.purple,
                    onTap: () {}),
                // ATUALIZAÇÃO: Atalho direto para Adubação
                _CardMenuGrande(
                    titulo: 'Adubação',
                    subtitulo: 'Calculadora',
                    icone: Icons.eco,
                    cor: Colors.orange,
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TelaAdubacaoOrgano15()));
                    }),
                _CardMenuGrande(
                    titulo: 'Configurações',
                    icone: Icons.settings,
                    cor: Colors.grey,
                    onTap: () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ABA 2: JORNADA (SUA TELA TRILHA MELHORADA)
// ============================================================================
class _AbaJornadaTrilha extends StatelessWidget {
  const _AbaJornadaTrilha();

  void _iniciarAcaoComCanteiro(BuildContext context, String acao) {
    final user = FirebaseAuth.instance.currentUser;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Para qual canteiro?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Flexible(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('canteiros')
                    .where('uid_usuario', isEqualTo: user?.uid)
                    .where('ativo', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const TelaCanteiros()));
                        },
                        child: const Text('Cadastrar Canteiro'));
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: snapshot.data!.docs.map((doc) {
                      return ListTile(
                        leading: const Icon(Icons.grid_on, color: Colors.green),
                        title: Text(doc['nome'],
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(ctx);
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
        title: const Text('Trilha do Cultivo',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading:
            false, // Sem seta de voltar aqui (use a barra inferior)
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header da Trilha
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.green.shade800, Colors.green.shade600]),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5))
              ],
            ),
            child: Row(children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 40),
              const SizedBox(width: 15),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                    Text('Siga o Passo a Passo',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text('Complete as fases para colher mais.',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ]))
            ]),
          ),
          const SizedBox(height: 25),

          // Itens da Timeline
          _TimelineItem(
              fase: 0,
              titulo: 'Planejamento',
              descricao: 'O que plantar?',
              icone: Icons.calculate,
              corIcone: Colors.blue,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TelaPlanejamentoConsumo()))),
          _TimelineItem(
              fase: 1,
              titulo: 'Meus Canteiros',
              descricao: 'Organize sua área.',
              icone: Icons.grid_on,
              corIcone: Colors.green,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TelaCanteiros()))),
          _TimelineItem(
              fase: 2,
              titulo: 'Diagnóstico',
              descricao: 'Analise o solo.',
              icone: Icons.science,
              corIcone: Colors.brown,
              onTap: () => _iniciarAcaoComCanteiro(context, 'diagnostico')),
          _TimelineItem(
              fase: 3,
              titulo: 'Calagem',
              descricao: 'Corrija a acidez.',
              icone: Icons.landscape,
              corIcone: Colors.blueGrey,
              onTap: () => _iniciarAcaoComCanteiro(context, 'calagem')),

          // ATUALIZAÇÃO: Fase 4 Desbloqueada
          _TimelineItem(
              fase: 4,
              titulo: 'Adubação',
              descricao: 'Nutrição Organo15.', // Texto atualizado
              icone: Icons.eco,
              corIcone: Colors.orange,
              bloqueado: false, // Desbloqueado!
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TelaAdubacaoOrgano15()));
              }),

          const _TimelineItem(
              fase: 5,
              titulo: 'Colheita',
              descricao: 'Venda (Em breve).',
              icone: Icons.shopping_basket,
              corIcone: Colors.purple,
              isLast: true,
              bloqueado: true,
              onTap: null),
        ],
      ),
    );
  }
}

// ============================================================================
// ABA 3: PERFIL
// ============================================================================
class _AbaPerfil extends StatelessWidget {
  const _AbaPerfil();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          title: const Text('Meu Perfil'),
          elevation: 0,
          foregroundColor: Colors.black,
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
              child: Column(children: [
            CircleAvatar(
                radius: 50,
                backgroundColor: Colors.green.shade100,
                child: Text(user?.email?[0].toUpperCase() ?? 'U',
                    style:
                        TextStyle(fontSize: 40, color: Colors.green.shade800))),
            const SizedBox(height: 15),
            Text(user?.email ?? 'Produtor',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ])),
          const SizedBox(height: 30),
          ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sair do App',
                  style: TextStyle(color: Colors.red)),
              onTap: () => FirebaseAuth.instance.signOut()),
        ],
      ),
    );
  }
}

// --- WIDGETS AUXILIARES ---

class _CardMenuGrande extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final IconData icone;
  final Color cor;
  final VoidCallback onTap;
  const _CardMenuGrande(
      {required this.titulo,
      this.subtitulo,
      required this.icone,
      required this.cor,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: cor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icone, color: cor, size: 24)),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                if (subtitulo != null)
                  Text(subtitulo!,
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ])
            ]),
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
  const _TimelineItem(
      {required this.fase,
      required this.titulo,
      required this.descricao,
      required this.icone,
      required this.corIcone,
      required this.onTap,
      this.isLast = false,
      this.bloqueado = false});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
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
                  ]),
              child: Center(
                  child: Text(fase.toString(),
                      style: TextStyle(
                          color: bloqueado ? Colors.grey : Colors.white,
                          fontWeight: FontWeight.bold)))),
          if (!isLast)
            Expanded(
                child: Container(
                    width: 2,
                    color: Colors.grey[300],
                    margin: const EdgeInsets.symmetric(vertical: 4))),
        ]),
        const SizedBox(width: 15),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(color: Colors.grey.shade200)),
                    child: InkWell(
                        onTap: bloqueado ? null : onTap,
                        borderRadius: BorderRadius.circular(15),
                        child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Row(children: [
                              Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                      color: bloqueado
                                          ? Colors.grey[100]
                                          : corIcone.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Icon(icone,
                                      color: bloqueado ? Colors.grey : corIcone,
                                      size: 28)),
                              const SizedBox(width: 15),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(titulo,
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: bloqueado
                                                ? Colors.grey
                                                : Colors.black87)),
                                    const SizedBox(height: 5),
                                    Text(descricao,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600]))
                                  ])),
                              Icon(
                                  bloqueado
                                      ? Icons.lock_outline
                                      : Icons.arrow_forward_ios,
                                  color: Colors.grey[400],
                                  size: 16)
                            ])))))),
      ]),
    );
  }
}
