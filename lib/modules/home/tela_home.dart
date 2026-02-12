import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Imports das suas telas funcionais
import '../canteiros/tela_canteiros.dart';
import '../solo/tela_diagnostico.dart';
import '../calculadoras/tela_calagem.dart';
import '../planejamento/tela_planejamento_consumo.dart';
import '../adubacao/tela_adubacao_organo15.dart';

class TelaHome extends StatefulWidget {
  const TelaHome({super.key});

  @override
  State<TelaHome> createState() => _TelaHomeState();
}

class _TelaHomeState extends State<TelaHome> {
  int _indiceAtual = 0; // 0: Início, 1: Jornada, 2: Perfil

  late final List<Widget> _telas;

  @override
  void initState() {
    super.initState();

    // IMPORTANTE: sem const aqui porque passamos callback (limpa o hack do findAncestor)
    _telas = [
      _AbaInicioDashboard(onIrParaJornada: () => _aoClicarNaBarra(1)),
      const _AbaJornadaTrilha(),
      const _AbaPerfil(),
    ];
  }

  void _aoClicarNaBarra(int index) {
    if (index == _indiceAtual) return;
    setState(() => _indiceAtual = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack = mantém estado/scroll/streams das abas (UX e performance)
      body: IndexedStack(
        index: _indiceAtual,
        children: _telas,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _indiceAtual,
          onTap: _aoClicarNaBarra,
          backgroundColor: Colors.white,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: 'Início',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map),
              label: 'Jornada',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Perfil',
            ),
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
  final VoidCallback onIrParaJornada;
  const _AbaInicioDashboard({required this.onIrParaJornada});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Row(
          children: [
            Icon(Icons.eco, color: Colors.white),
            SizedBox(width: 10),
            Text(
              'Verde Ensina',
              style: TextStyle(fontWeight: FontWeight.bold),
            )
          ],
        ),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Notificações',
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notificações: em breve 😉'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Olá, Produtor! 👋',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Text(
              'Visão geral da sua produção.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // Card Atalho para Jornada
            InkWell(
              onTap: onIrParaJornada,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primary.withOpacity(0.95),
                      primary.withOpacity(0.75)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Continuar Jornada',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Acessar Trilha de Plantio',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.arrow_forward, color: Colors.white),
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),
            const Text(
              'Gestão & Serviços',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Financeiro: em breve 💸')),
                    );
                  },
                ),
                _CardMenuGrande(
                  titulo: 'Mercado',
                  subtitulo: 'Compra/Venda',
                  icone: Icons.storefront,
                  cor: Colors.purple,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mercado: em breve 🛒')),
                    );
                  },
                ),
                _CardMenuGrande(
                  titulo: 'Adubação',
                  subtitulo: 'Calculadora',
                  icone: Icons.eco,
                  cor: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TelaAdubacaoOrgano15()),
                    );
                  },
                ),
                _CardMenuGrande(
                  titulo: 'Configurações',
                  icone: Icons.settings,
                  cor: Colors.grey,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Configurações: em breve ⚙️')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ABA 2: JORNADA
// ============================================================================
class _AbaJornadaTrilha extends StatelessWidget {
  const _AbaJornadaTrilha();

  void _iniciarAcaoComCanteiro(BuildContext context, String acao) {
    final user = FirebaseAuth.instance.currentUser;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Para qual canteiro?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Escolha o canteiro onde você quer executar essa etapa.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
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
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade100),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.orange),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Você ainda não tem canteiros ativos. Cadastre um para continuar.',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.grid_on),
                              label: const Text('Cadastrar Canteiro'),
                              onPressed: () {
                                Navigator.pop(ctx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const TelaCanteiros()),
                                );
                              },
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Fechar'),
                          )
                        ],
                      );
                    }

                    final docs = snapshot.data!.docs.toList()
                      ..sort((a, b) {
                        final na = (a['nome'] ?? '').toString().toLowerCase();
                        final nb = (b['nome'] ?? '').toString().toLowerCase();
                        return na.compareTo(nb);
                      });

                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final nome = (doc['nome'] ?? 'Canteiro').toString();

                        return ListTile(
                          leading:
                              const Icon(Icons.grid_on, color: Colors.green),
                          title: Text(
                            nome,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.pop(ctx);

                            if (acao == 'diagnostico') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TelaDiagnostico(canteiroIdOrigem: doc.id),
                                ),
                              );
                            } else if (acao == 'calagem') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TelaCalagem(canteiroIdOrigem: doc.id),
                                ),
                              );
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Trilha do Cultivo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
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
                colors: [primary.withOpacity(0.95), primary.withOpacity(0.75)],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 40),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Siga o Passo a Passo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Complete as fases para colher mais.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 25),

          _TimelineItem(
            fase: 0,
            titulo: 'Planejamento',
            descricao: 'O que plantar?',
            icone: Icons.calculate,
            corIcone: Colors.blue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const TelaPlanejamentoConsumo()),
            ),
          ),
          _TimelineItem(
            fase: 1,
            titulo: 'Meus Canteiros',
            descricao: 'Organize sua área.',
            icone: Icons.grid_on,
            corIcone: Colors.green,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TelaCanteiros()),
            ),
          ),
          _TimelineItem(
            fase: 2,
            titulo: 'Diagnóstico',
            descricao: 'Analise o solo.',
            icone: Icons.science,
            corIcone: Colors.brown,
            onTap: () => _iniciarAcaoComCanteiro(context, 'diagnostico'),
          ),
          _TimelineItem(
            fase: 3,
            titulo: 'Calagem',
            descricao: 'Corrija a acidez.',
            icone: Icons.landscape,
            corIcone: Colors.blueGrey,
            onTap: () => _iniciarAcaoComCanteiro(context, 'calagem'),
          ),
          _TimelineItem(
            fase: 4,
            titulo: 'Adubação',
            descricao: 'Nutrição Organo15.',
            icone: Icons.eco,
            corIcone: Colors.orange,
            bloqueado: false,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TelaAdubacaoOrgano15()),
            ),
          ),
          const _TimelineItem(
            fase: 5,
            titulo: 'Colheita',
            descricao: 'Venda (Em breve).',
            icone: Icons.shopping_basket,
            corIcone: Colors.purple,
            isLast: true,
            bloqueado: true,
            onTap: null,
          ),
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

  Future<void> _confirmarLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair do app?'),
        content: const Text('Você será desconectado da sua conta.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

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
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.green.shade100,
                  child: Text(
                    user?.email?.isNotEmpty == true
                        ? user!.email![0].toUpperCase()
                        : 'U',
                    style:
                        TextStyle(fontSize: 40, color: Colors.green.shade800),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  user?.email ?? 'Produtor',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // Placeholder pro futuro modo "Família / Individual"
                Text(
                  'Modo: Individual (em breve: Família/Equipe)',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title:
                const Text('Sair do App', style: TextStyle(color: Colors.red)),
            onTap: () => _confirmarLogout(context),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGETS AUXILIARES
// ============================================================================
class _CardMenuGrande extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final IconData icone;
  final Color cor;
  final VoidCallback onTap;

  const _CardMenuGrande({
    required this.titulo,
    this.subtitulo,
    required this.icone,
    required this.cor,
    required this.onTap,
  });

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
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icone, color: cor, size: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (subtitulo != null)
                  Text(
                    subtitulo!,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
              ],
            )
          ],
        ),
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
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    fase.toString(),
                    style: TextStyle(
                      color: bloqueado ? Colors.grey : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
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
                          child: Icon(
                            icone,
                            color: bloqueado ? Colors.grey : corIcone,
                            size: 28,
                          ),
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
                                    fontSize: 12, color: Colors.grey[600]),
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
                        )
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
