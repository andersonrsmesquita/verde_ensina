import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:verde_ensina/core/ui/app_messenger.dart';

// Imports das telas funcionais
import 'package:verde_ensina/modules/canteiros/tela_canteiros.dart';
import 'package:verde_ensina/modules/solo/tela_diagnostico.dart';
import 'package:verde_ensina/modules/calculadoras/tela_calagem.dart';
import 'package:verde_ensina/modules/planejamento/tela_planejamento_consumo.dart';
import 'package:verde_ensina/modules/adubacao/tela_adubacao_organo15.dart';

class TelaHome extends StatefulWidget {
  const TelaHome({super.key});

  @override
  State<TelaHome> createState() => _TelaHomeState();
}

class _TelaHomeState extends State<TelaHome> {
  int _indiceAtual = 0;

  void _snack(String msg, {Color? cor}) {
    AppMessenger.showSnack(msg, cor: cor);
  }

  void _setAba(int index) {
    if (index == _indiceAtual) return;
    setState(() => _indiceAtual = index);
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    switch (_indiceAtual) {
      case 0:
        return AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Row(
            children: [
              Icon(Icons.eco, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'Verde Ensina',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Notificações',
              icon: const Icon(Icons.notifications_none),
              onPressed: () => _snack('Notificações: em breve 😉'),
            ),
          ],
        );

      case 1:
        return AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'Trilha do Cultivo',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        );

      default:
        return AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          title: const Text(
            'Meu Perfil',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(context),
      body: IndexedStack(
        index: _indiceAtual,
        children: [
          _AbaInicioDashboard(
            onIrParaJornada: () => _setAba(1),
            onAviso: (msg) => _snack(msg),
          ),
          _AbaJornadaTrilha(onAviso: (msg) => _snack(msg)),
          _AbaPerfil(onAviso: (msg, {Color? cor}) => _snack(msg, cor: cor)),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _indiceAtual,
          onTap: _setAba,
          backgroundColor: Colors.white,
          selectedItemColor: primary,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: 'Início',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Jornada'),
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
// ABA 1: INÍCIO (DASHBOARD)
// ============================================================================
class _AbaInicioDashboard extends StatelessWidget {
  final VoidCallback onIrParaJornada;
  final void Function(String msg) onAviso;

  const _AbaInicioDashboard({
    required this.onIrParaJornada,
    required this.onAviso,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final primary = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user == null ? 'Olá! 👋' : 'Olá, Produtor! 👋',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user == null
                ? 'Faça login para ver sua visão geral.'
                : 'Visão geral da sua produção.',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 18),
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
                    primary.withOpacity(0.75),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
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
                        SizedBox(height: 6),
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
                      color: Colors.white.withOpacity(0.22),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (user != null) _ResumoDashboard(uid: user.uid),
          const SizedBox(height: 22),
          const Text(
            'Gestão & Serviços',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final cols = w >= 820 ? 3 : 2;

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: cols,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: cols == 3 ? 1.8 : 1.55,
                children: [
                  _CardMenuGrande(
                    titulo: 'Planejamento',
                    subtitulo: 'O que plantar?',
                    icone: Icons.calculate,
                    cor: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TelaPlanejamentoConsumo(),
                        ),
                      );
                    },
                  ),
                  _CardMenuGrande(
                    titulo: 'Canteiros',
                    subtitulo: 'Minha área',
                    icone: Icons.grid_on,
                    cor: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TelaCanteiros(),
                        ),
                      );
                    },
                  ),
                  _CardMenuGrande(
                    titulo: 'Adubação',
                    subtitulo: 'Organo15',
                    icone: Icons.eco,
                    cor: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TelaAdubacaoOrgano15(),
                        ),
                      );
                    },
                  ),
                  _CardMenuGrande(
                    titulo: 'Financeiro',
                    icone: Icons.attach_money,
                    cor: Colors.indigo,
                    onTap: () => onAviso('Financeiro: em breve 💸'),
                  ),
                  _CardMenuGrande(
                    titulo: 'Mercado',
                    subtitulo: 'Compra/Venda',
                    icone: Icons.storefront,
                    cor: Colors.purple,
                    onTap: () => onAviso('Mercado: em breve 🛒'),
                  ),
                  _CardMenuGrande(
                    titulo: 'Configurações',
                    icone: Icons.settings,
                    cor: Colors.grey,
                    onTap: () => onAviso('Configurações: em breve ⚙️'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ResumoDashboard extends StatelessWidget {
  final String uid;
  const _ResumoDashboard({required this.uid});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    final canteirosStream = FirebaseFirestore.instance
        .collection('canteiros')
        .where('uid_usuario', isEqualTo: uid)
        .where('ativo', isEqualTo: true)
        .snapshots();

    final ultManejoStream = FirebaseFirestore.instance
        .collection('historico_manejo')
        .where('uid_usuario', isEqualTo: uid)
        .orderBy('data', descending: true)
        .limit(1)
        .snapshots();

    return Row(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: canteirosStream,
            builder: (context, snap) {
              final qtd = snap.data?.docs.length ?? 0;
              return _MiniMetricCard(
                icon: Icons.grid_on,
                color: primary,
                title: 'Canteiros ativos',
                value: qtd.toString(),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: ultManejoStream,
            builder: (context, snap) {
              String value = '—';
              if (snap.hasData && snap.data!.docs.isNotEmpty) {
                final d = snap.data!.docs.first;
                value = (d['tipo_manejo'] ?? 'Manejo').toString();
              }
              return _MiniMetricCard(
                icon: Icons.history,
                color: Colors.blueGrey,
                title: 'Último manejo',
                value: value,
                isBigText: false,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MiniMetricCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final bool isBigText;

  const _MiniMetricCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    this.isBigText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isBigText ? 18 : 13,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ABA 2: JORNADA
// ============================================================================
class _AbaJornadaTrilha extends StatelessWidget {
  final void Function(String msg) onAviso;
  const _AbaJornadaTrilha({required this.onAviso});

  void _iniciarAcaoComCanteiro(BuildContext context, String acao) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      onAviso('Faça login para selecionar canteiro.');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SheetSelecionarCanteiro(
        uid: user.uid,
        titulo: 'Para qual canteiro?',
        subtitulo: 'Escolha o canteiro onde você quer executar essa etapa.',
        onCadastrar: () {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TelaCanteiros()),
          );
        },
        onSelecionar: (doc) {
          Navigator.pop(ctx);

          if (acao == 'diagnostico') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TelaDiagnostico(canteiroIdOrigem: doc.id),
              ),
            );
          } else if (acao == 'calagem') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TelaCalagem(canteiroIdOrigem: doc.id),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primary.withOpacity(0.95), primary.withOpacity(0.75)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 38),
              SizedBox(width: 14),
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
                    SizedBox(height: 4),
                    Text(
                      'Complete as fases para colher mais.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _TimelineItem(
          fase: 0,
          titulo: 'Planejamento',
          descricao: 'O que plantar?',
          icone: Icons.calculate,
          corIcone: Colors.blue,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TelaPlanejamentoConsumo()),
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
    );
  }
}

class _SheetSelecionarCanteiro extends StatefulWidget {
  final String uid;
  final String titulo;
  final String subtitulo;
  final VoidCallback onCadastrar;
  final void Function(QueryDocumentSnapshot doc) onSelecionar;

  const _SheetSelecionarCanteiro({
    required this.uid,
    required this.titulo,
    required this.subtitulo,
    required this.onCadastrar,
    required this.onSelecionar,
  });

  @override
  State<_SheetSelecionarCanteiro> createState() =>
      _SheetSelecionarCanteiroState();
}

class _SheetSelecionarCanteiroState extends State<_SheetSelecionarCanteiro> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('canteiros')
        .where('uid_usuario', isEqualTo: widget.uid)
        .where('ativo', isEqualTo: true)
        .snapshots();

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.titulo,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitulo,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) =>
                    setState(() => _busca = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Buscar canteiro...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: stream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docsAll = snapshot.data?.docs ?? [];
                    if (docsAll.isEmpty) {
                      return Column(
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
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.grid_on),
                              label: const Text('Cadastrar Canteiro'),
                              onPressed: widget.onCadastrar,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Fechar'),
                          ),
                        ],
                      );
                    }

                    final docs = docsAll.where((d) {
                      final nome =
                          ((d['nome'] ?? 'Canteiro').toString()).toLowerCase();
                      if (_busca.isEmpty) return true;
                      return nome.contains(_busca);
                    }).toList()
                      ..sort((a, b) {
                        final na = (a['nome'] ?? '').toString().toLowerCase();
                        final nb = (b['nome'] ?? '').toString().toLowerCase();
                        return na.compareTo(nb);
                      });

                    return ListView.separated(
                      controller: controller,
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final doc = docs[index] as QueryDocumentSnapshot;
                        final nome = (doc['nome'] ?? 'Canteiro').toString();
                        final area =
                            (doc.data() as Map<String, dynamic>)['area_m2'];

                        double areaM2 = 0;
                        if (area is num) areaM2 = area.toDouble();
                        if (area is String) areaM2 = double.tryParse(area) ?? 0;

                        return ListTile(
                          leading:
                              const Icon(Icons.grid_on, color: Colors.green),
                          title: Text(
                            nome,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle:
                              Text('Área: ${areaM2.toStringAsFixed(2)} m²'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => widget.onSelecionar(doc),
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

// ============================================================================
// ABA 3: PERFIL
// ============================================================================
class _AbaPerfil extends StatelessWidget {
  final void Function(String msg, {Color? cor}) onAviso;
  const _AbaPerfil({required this.onAviso});

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
      onAviso('Você saiu da conta.', cor: Colors.green);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: const [
          _InfoBox(
            icon: Icons.lock_outline,
            cor: Colors.orange,
            texto: 'Você está desconectado. Faça login para acessar o perfil.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.green.shade100,
                child: Text(
                  user.email?.isNotEmpty == true
                      ? user.email![0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    fontSize: 28,
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.email ?? 'Produtor',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Modo: Individual (em breve: Família/Equipe)',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _CardSection(
          title: 'Conta',
          children: [
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Ajuda & Suporte'),
              onTap: () => onAviso('Suporte: em breve 😉'),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacidade'),
              onTap: () => onAviso('Privacidade: em breve'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _CardSection(
          title: 'Sessão',
          children: [
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sair do App',
                  style: TextStyle(color: Colors.red)),
              onTap: () => _confirmarLogout(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _CardSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _CardSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...children,
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
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
                if (subtitulo != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitulo!,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                ],
              ],
            ),
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
                    ),
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
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: InkWell(
                  onTap: bloqueado ? null : onTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: bloqueado
                                ? Colors.grey[100]
                                : corIcone.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            icone,
                            color: bloqueado ? Colors.grey : corIcone,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
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

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final Color cor;
  final String texto;

  const _InfoBox({required this.icon, required this.cor, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: cor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                color: cor.withOpacity(0.90),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
