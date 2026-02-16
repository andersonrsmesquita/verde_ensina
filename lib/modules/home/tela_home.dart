// FILE: lib/modules/home/tela_home.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ✅ Core Imports (Garantindo que nada falte)
import '../../core/firebase/firebase_paths.dart';
import '../../core/session/session_scope.dart';
import '../../core/ui/app_ui.dart';

// ✅ Todos os Módulos Importados
import '../canteiros/tela_canteiros.dart';
import '../canteiros/tela_planejamento_canteiro.dart'; // Classe TelaPlanejamentoCanteiro
import '../solo/tela_diagnostico.dart';
import '../calculadoras/tela_calagem.dart';
import '../planejamento/tela_planejamento_consumo.dart'; // Classe TelaPlanejamentoConsumo
import '../adubacao/tela_adubacao_organo15.dart';
import '../diario/tela_diario_manejo.dart';
import '../financeiro/tela_financeiro.dart';
import '../mercado/tela_mercado.dart';
import '../conteudo/tela_conteudo.dart';
import '../configuracoes/tela_configuracoes.dart';
import '../alertas/tela_alertas.dart';
import '../pragas/tela_pragas.dart';
import '../irrigacao/tela_irrigacao.dart';

class TelaHome extends StatefulWidget {
  const TelaHome({super.key});

  @override
  State<TelaHome> createState() => _TelaHomeState();
}

class _TelaHomeState extends State<TelaHome> {
  int _indiceAtual = 0;

  void _setAba(int index) => setState(() => _indiceAtual = index);

  void _push(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    // Proteção contra erro de tema
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest, // Fundo mais leve
      appBar: _buildAppBar(context),
      // IndexedStack preserva o estado das abas (não recarrega ao trocar)
      body: IndexedStack(
        index: _indiceAtual,
        children: const [
          _AbaInicioDashboard(), // Aba 0
          _AbaJornadaTrilha(), // Aba 1
          AbaPerfilPage(), // Aba 2
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
              top: BorderSide(color: cs.outlineVariant.withOpacity(0.3))),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _indiceAtual,
            onTap: _setAba,
            backgroundColor: cs.surface,
            selectedItemColor: cs.primary,
            unselectedItemColor: cs.onSurfaceVariant,
            type: BottomNavigationBarType.fixed,
            showUnselectedLabels: true,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label: 'Painel'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.map_outlined),
                  activeIcon: Icon(Icons.map),
                  label: 'Jornada'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

    Widget titleWidget;
    List<Widget> actions = [];

    if (_indiceAtual == 0) {
      titleWidget = Row(children: [
        Icon(Icons.eco, color: cs.primary),
        const SizedBox(width: 8),
        Text('Verde Ensina',
            style: txt.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ]);
      actions = [
        IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Alertas',
            onPressed: () => _push(context, const TelaAlertas())),
      ];
    } else if (_indiceAtual == 1) {
      titleWidget = Text('Trilha do Cultivo',
          style: txt.titleLarge?.copyWith(fontWeight: FontWeight.w900));
    } else {
      titleWidget = Text('Meu Perfil',
          style: txt.titleLarge?.copyWith(fontWeight: FontWeight.w900));
      actions = [
        IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configurações',
            onPressed: () => _push(context, const TelaConfiguracoes())),
      ];
    }

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor:
          cs.surfaceContainerLowest, // Combina com o fundo do Scaffold
      foregroundColor: cs.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0, // Evita mudança de cor ao rolar
      title: titleWidget,
      centerTitle: _indiceAtual != 0,
      actions:
          actions.isNotEmpty ? [...actions, const SizedBox(width: 8)] : null,
    );
  }
}

// ============================================================================
// ABA 1: DASHBOARD (Layout Seguro - Sem PageContainer aninhado)
// ============================================================================
class _AbaInicioDashboard extends StatelessWidget {
  const _AbaInicioDashboard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

    // Tratamento de segurança para Sessão
    final sessionScope = SessionScope.maybeOf(context);
    final session = sessionScope?.session;
    final user = FirebaseAuth.instance.currentUser;

    // Caso de usuário não logado ou erro de sessão
    if (user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_clock_outlined, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            const Text('Faça login para gerenciar sua produção.'),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: AppButtons.elevatedIcon(
                label: const Text('Entrar'),
                icon: const Icon(Icons.login),
                onPressed: () => sessionScope?.signOut(),
              ),
            ),
          ],
        ),
      );
    }

    // Layout principal com ScrollView seguro
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Cabeçalho de Status
            _DashboardHeader(
              userName: user.displayName ?? 'Produtor',
              tenantName: session?.tenantName,
              tenantId: session?.tenantId ?? '',
            ),

            const SizedBox(height: 24),

            // 2. Acesso Rápido (Operação Diária)
            SectionCard(
              title: 'Acesso Rápido',
              trailing: Icon(Icons.bolt, color: cs.tertiary),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickActionBtn(
                      label: 'Novo Plantio',
                      icon: Icons.add_circle_outline,
                      color: cs.primary,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TelaPlanejamentoConsumo())),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionBtn(
                      label: 'Diário',
                      icon: Icons.menu_book,
                      color: cs.secondary,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TelaDiarioManejo())),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionBtn(
                      label:
                          'Locais', // ✅ Modificado de "Canteiros" para "Locais"
                      icon: Icons.place_outlined, // ✅ Ícone mais abrangente
                      color: cs.tertiary,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TelaCanteiros())),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. Agronomia & Manejo
            Text('Agronomia & Manejo',
                style: txt.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),

            // Scroll Horizontal para Módulos Menores
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  _MiniModule(
                      label: 'Diagnóstico',
                      icon: Icons.science,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TelaDiagnostico(
                                  canteiroIdOrigem: '')))),
                  _MiniModule(
                      label: 'Calagem',
                      icon: Icons.landscape,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const TelaCalagem(canteiroIdOrigem: '')))),
                  _MiniModule(
                      label: 'Adubação',
                      icon: Icons.eco,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TelaAdubacaoOrgano15()))),
                  _MiniModule(
                      label: 'Irrigação',
                      icon: Icons.water_drop,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TelaIrrigacao()))),
                  _MiniModule(
                      label: 'Pragas',
                      icon: Icons.bug_report,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TelaPragas()))),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 4. Negócio & Mercado
            Text('Negócio & Mercado',
                style: txt.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),

            AppModuleCard(
              title: 'Gestão Financeira',
              subtitle: 'Fluxo de caixa, custos e lucros.',
              icon: Icons.attach_money,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TelaFinanceiro())),
            ),

            AppModuleCard(
              title: 'Mercado & Vendas',
              subtitle: 'Cotações, clientes e escoamento.',
              icon: Icons.storefront,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TelaMercado())),
            ),

            const SizedBox(height: 24),

            // 5. Conhecimento
            Text('Aprender & Transformar',
                style: txt.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),

            AppModuleCard(
              title: 'Conteúdo & Aulas',
              subtitle: 'Guias técnicos e vídeos educativos.',
              icon: Icons.school_outlined,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TelaConteudo())),
            ),

            AppModuleCard(
              title: 'Receitas & Processamento',
              subtitle: 'Agregue valor à sua colheita.',
              icon: Icons.soup_kitchen,
              onTap: () => AppMessenger.info('Em breve: Módulo de Receitas'),
            ),

            const SizedBox(height: 40), // Espaço extra no final
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGETS AUXILIARES
// ============================================================================

class _DashboardHeader extends StatelessWidget {
  final String userName;
  final String? tenantName;
  final String tenantId;

  const _DashboardHeader(
      {required this.userName,
      required this.tenantName,
      required this.tenantId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

    if (tenantId.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Olá, $userName',
                      style: txt.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text(tenantName ?? 'Sua Produção',
                      style:
                          txt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
              // ✅ Modificado: Contador agora diz "Locais"
              StreamBuilder<QuerySnapshot>(
                stream: FirebasePaths.canteirosCol(tenantId)
                    .where('ativo', isEqualTo: true)
                    .snapshots(),
                builder: (context, snap) {
                  final count = snap.hasData ? snap.data!.docs.length : 0;
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        Text('$count',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                color: cs.onPrimaryContainer)),
                        Text('Locais',
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionBtn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: color.withOpacity(0.1),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(icon, color: color, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }
}

class _MiniModule extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _MiniModule(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 85,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: cs.primary, size: 26),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ABAS SECUNDÁRIAS (Simples e Seguras)
// ============================================================================
class _AbaJornadaTrilha extends StatelessWidget {
  const _AbaJornadaTrilha();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          elevation: 0,
          color: cs.primaryContainer,
          child: const ListTile(
            contentPadding: EdgeInsets.all(16),
            leading: Icon(Icons.alt_route, size: 40),
            title: Text('Sua Jornada',
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Passo a passo para o sucesso da colheita.'),
          ),
        ),
        const SizedBox(height: 20),

        AppModuleCard(
          title: '1. O que vou plantar?',
          icon: Icons.shopping_basket_outlined,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const TelaPlanejamentoConsumo())),
        ),

        // ✅ Modificado de "Preparo" e TelaCanteiros para uma descrição melhor
        AppModuleCard(
            title: '2. Meus Locais (Onde vou plantar)',
            subtitle: 'Cadastre seus canteiros de solo ou vasos.',
            icon: Icons.place_outlined,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TelaCanteiros()))),

        AppModuleCard(
          title: '3. Mapa do Plantio',
          subtitle: 'Distribua as sementes/mudas no espaço.',
          icon: Icons.grid_on,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const TelaPlanejamentoCanteiro())),
        ),
      ],
    );
  }
}

class AbaPerfilPage extends StatelessWidget {
  const AbaPerfilPage({super.key});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("Não logado"));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ListTile(
          leading: CircleAvatar(child: Text(user.displayName?[0] ?? 'U')),
          title: Text(user.displayName ?? 'Usuário',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(user.email ?? ''),
        ),
        const Divider(),
        AppModuleCard(
            title: 'Configurações',
            icon: Icons.settings,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TelaConfiguracoes()))),
        const SizedBox(height: 20),
        AppButtons.outlinedIcon(
          label: const Text('Sair da Conta'),
          icon: const Icon(Icons.logout),
          onPressed: () => SessionScope.of(context).signOut(),
        )
      ],
    );
  }
}
