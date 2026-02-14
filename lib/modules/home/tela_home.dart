import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ✅ Caminhos corrigidos para o Core
import '../../core/firebase/firebase_paths.dart';
import '../../core/session/session_scope.dart';
import '../../core/session/app_session.dart';
import '../../core/ui/app_ui.dart';
import '../../core/repositories/user_profile_repository.dart';

// Seus imports de telas
import '../canteiros/tela_canteiros.dart';
import '../canteiros/tela_planejamento_canteiro.dart';
import '../solo/tela_diagnostico.dart';
import '../calculadoras/tela_calagem.dart';
import '../planejamento/tela_planejamento_consumo.dart';
import '../adubacao/tela_adubacao_organo15.dart';
import '../diario/tela_diario_manejo.dart';
import '../conteudo/tela_conteudo.dart';
import '../financeiro/tela_financeiro.dart';
import '../mercado/tela_mercado.dart';
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: _buildAppBar(context),
      body: IndexedStack(
        index: _indiceAtual,
        children: const [
          _AbaInicioDashboard(),
          _AbaJornadaTrilha(),
          AbaPerfilPage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
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
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

    Widget titleWidget = Text(
      'Verde Ensina',
      style: txt.titleLarge
          ?.copyWith(fontWeight: FontWeight.bold, color: cs.primary),
    );

    List<Widget> actions = [
      IconButton(
        tooltip: 'Alertas',
        icon: const Icon(Icons.notifications_none),
        onPressed: () => _push(context, const TelaAlertas()),
      ),
      IconButton(
        tooltip: 'Configurações',
        icon: const Icon(Icons.settings_outlined),
        onPressed: () => _push(context, const TelaConfiguracoes()),
      ),
      const SizedBox(width: 8),
    ];

    if (_indiceAtual == 0) {
      titleWidget = Row(
        children: [
          Icon(Icons.eco, color: cs.primary),
          const SizedBox(width: 8),
          Text('Verde Ensina',
              style: txt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      );
    } else if (_indiceAtual == 1) {
      titleWidget = Text('Trilha do Cultivo',
          style: txt.titleLarge?.copyWith(fontWeight: FontWeight.bold));
      actions = [];
    } else {
      titleWidget = Text('Meu Perfil',
          style: txt.titleLarge?.copyWith(fontWeight: FontWeight.bold));
      actions = [];
    }

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: _indiceAtual == 1,
      title: titleWidget,
      actions: actions,
    );
  }
}

class _AbaInicioDashboard extends StatelessWidget {
  const _AbaInicioDashboard();

  AppSession? _validarSessao(BuildContext context) {
    final appSession = SessionScope.sessionOf(context);
    if (appSession == null) {
      AppMessenger.warn('Selecione um espaço de trabalho para continuar.');
      return null;
    }
    return appSession;
  }

  Future<void> _navegarParaCanteiro(BuildContext context,
      Widget Function(String id) pageBuilder, String tituloSheet) async {
    final appSession = _validarSessao(context);
    if (appSession == null) return;

    final result = await showModalBottomSheet<_CanteiroPickResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SheetSelecionarCanteiro(
        tenantId: appSession.tenantId,
        uid: appSession.uid,
        titulo: tituloSheet,
      ),
    );

    if (!context.mounted || result == null) return;

    if (result.cadastrarNovo) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const TelaCanteiros()));
      return;
    }

    if (result.canteiroId != null) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => pageBuilder(result.canteiroId!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;
    final session = SessionScope.sessionOf(context);
    final user = FirebaseAuth.instance.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Olá, ${user?.displayName ?? "Produtor"}',
                style: txt.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold, color: cs.primary),
              ),
              Text(
                session?.tenantName != null
                    ? 'Espaço: ${session!.tenantName}'
                    : 'Bem-vindo de volta',
                style: txt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Text('Ações rápidas',
                  style:
                      txt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ActionCard(
                    icon: Icons.auto_awesome,
                    label: 'Planejar',
                    onTap: () => _navegarParaCanteiro(
                        context,
                        (id) => TelaPlanejamentoCanteiro(canteiroIdOrigem: id),
                        'Planejamento'),
                  ),
                  _ActionCard(
                    icon: Icons.grid_on,
                    label: 'Canteiros',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TelaCanteiros())),
                  ),
                  _ActionCard(
                    icon: Icons.menu_book,
                    label: 'Diário',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TelaDiarioManejo())),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (session != null) ...[
                Text('Resumo',
                    style:
                        txt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _ResumoDashboard(tenantId: session.tenantId),
                const SizedBox(height: 24),
              ],
              Text('Módulos',
                  style:
                      txt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _ModulesGrid(
                context: context,
                onNavegar: (page) => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => page)),
                onCanteiroAction: (pageBuilder, titulo) =>
                    _navegarParaCanteiro(context, pageBuilder, titulo),
              ),
              if (user == null) ...[
                const SizedBox(height: 24),
                Card(
                  color: cs.errorContainer,
                  child: ListTile(
                    leading: Icon(Icons.lock, color: cs.onErrorContainer),
                    title: Text('Modo Visitante',
                        style: TextStyle(
                            color: cs.onErrorContainer,
                            fontWeight: FontWeight.bold)),
                    subtitle: Text('Faça login para acessar todos os recursos.',
                        style: TextStyle(color: cs.onErrorContainer)),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

class _AbaJornadaTrilha extends StatelessWidget {
  const _AbaJornadaTrilha();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          elevation: 0,
          color: cs.primaryContainer,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
                backgroundColor: cs.primary,
                child: const Icon(Icons.alt_route, color: Colors.white)),
            title: Text('Trilha do Sucesso',
                style: txt.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
            subtitle: Text('Siga os passos para uma colheita produtiva.',
                style: TextStyle(color: cs.onPrimaryContainer)),
          ),
        ),
        const SizedBox(height: 24),
        _TimelineItem(1, 'Planejamento', 'Defina o que plantar.',
            Icons.calculate, cs.primary, () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const TelaPlanejamentoConsumo()));
        }),
        _TimelineItem(2, 'Preparar Canteiros', 'Organize sua área.',
            Icons.grid_on, cs.primary, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const TelaCanteiros()));
        }),
        _TimelineItem(3, 'Diagnóstico do Solo', 'Análise vital.', Icons.science,
            cs.primary, () {}),
        _TimelineItem(
            4, 'Correção & Adubação', 'Nutrição.', Icons.eco, cs.primary, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const TelaAdubacaoOrgano15()));
        }),
        _TimelineItem(5, 'Plantio & Manejo', 'Mão na massa.', Icons.agriculture,
            cs.secondary, () {},
            isLast: true),
      ],
    );
  }
}

class AbaPerfilPage extends StatelessWidget {
  const AbaPerfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final repo = UserProfileRepository();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_circle_outlined,
                size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Você não está logado.'),
            const SizedBox(height: 16),
            AppButtons.elevatedIcon(
              label: const Text('Fazer Login'),
              icon: const Icon(Icons.login),
              onPressed: () => SessionScope.of(context).signOut(),
            )
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        StreamBuilder(
          stream: repo.watch(user.uid),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
            final nome = data['displayName'] ?? user.email ?? 'Produtor';

            return Card(
              elevation: 0,
              color: cs.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      child: Text(nome.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nome.toString(),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          Text(
                              'Plano: ${(data['plan'] ?? 'Free').toString().toUpperCase()}',
                              style: TextStyle(color: cs.primary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Configurações'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const TelaConfiguracoes())),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: const Text('Ajuda e Suporte'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => AppMessenger.info('Em breve'),
        ),
        const Divider(),
        const SizedBox(height: 24),
        AppButtons.outlinedIcon(
          label: const Text('Sair da Conta'),
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await SessionScope.of(context).signOut();
          },
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCard(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 100,
      child: Card(
        elevation: 0,
        color: cs.surfaceContainerHighest,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: cs.primary, size: 28),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModulesGrid extends StatelessWidget {
  final BuildContext context;
  final Function(Widget) onNavegar;
  final Function(Widget Function(String), String) onCanteiroAction;

  const _ModulesGrid(
      {required this.context,
      required this.onNavegar,
      required this.onCanteiroAction});

  @override
  Widget build(BuildContext context) {
    final modules = [
      {
        'icon': Icons.calculate,
        'label': 'Planejamento Geral',
        'action': () => onNavegar(const TelaPlanejamentoConsumo())
      },
      {
        'icon': Icons.auto_awesome,
        'label': 'Por Canteiro',
        'action': () => onCanteiroAction(
            (id) => TelaPlanejamentoCanteiro(canteiroIdOrigem: id),
            'Planejamento')
      },
      {
        'icon': Icons.science,
        'label': 'Diagnóstico',
        'action': () => onCanteiroAction(
            (id) => TelaDiagnostico(canteiroIdOrigem: id), 'Diagnóstico')
      },
      {
        'icon': Icons.landscape,
        'label': 'Calagem',
        'action': () => onCanteiroAction(
            (id) => TelaCalagem(canteiroIdOrigem: id), 'Calagem')
      },
      {
        'icon': Icons.eco,
        'label': 'Adubação',
        'action': () => onNavegar(const TelaAdubacaoOrgano15())
      },
      {
        'icon': Icons.water_drop,
        'label': 'Irrigação',
        'action': () => onNavegar(const TelaIrrigacao())
      },
      {
        'icon': Icons.bug_report,
        'label': 'Pragas',
        'action': () => onNavegar(const TelaPragas())
      },
      {
        'icon': Icons.attach_money,
        'label': 'Financeiro',
        'action': () => onNavegar(const TelaFinanceiro())
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: modules.length,
      itemBuilder: (ctx, i) {
        final m = modules[i];
        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: m['action'] as VoidCallback,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(m['icon'] as IconData,
                      color: Theme.of(context).colorScheme.primary),
                  Text(
                    m['label'] as String,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ResumoDashboard extends StatelessWidget {
  final String tenantId;
  const _ResumoDashboard({required this.tenantId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebasePaths.canteirosCol(tenantId)
                .where('ativo', isEqualTo: true)
                .snapshots(),
            builder: (context, snap) => _MetricCard(
              label: 'Canteiros',
              value: snap.hasData ? '${snap.data!.docs.length}' : '...',
              icon: Icons.grid_on,
              color: cs.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebasePaths.historicoManejoCol(tenantId)
                .orderBy('data', descending: true)
                .limit(1)
                .snapshots(),
            builder: (context, snap) {
              String txt = '-';
              if (snap.hasData && snap.data!.docs.isNotEmpty) {
                final data =
                    snap.data!.docs.first.data() as Map<String, dynamic>;
                txt = data['tipo_manejo'] ?? 'Manejo';
              }
              return _MetricCard(
                label: 'Último Manejo',
                value: txt,
                icon: Icons.history,
                color: cs.secondary,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          side: BorderSide(color: color.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(12)),
      color: color.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color),
                overflow: TextOverflow.ellipsis),
            Text(label,
                style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final int step;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isLast;

  const _TimelineItem(
      this.step, this.title, this.subtitle, this.icon, this.color, this.onTap,
      {this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Center(
                    child: Text('$step',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
              ),
              if (!isLast)
                Expanded(
                    child: Container(width: 2, color: color.withOpacity(0.3))),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(subtitle,
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 16),
                    ],
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

class _CanteiroPickResult {
  final String? canteiroId;
  final bool cadastrarNovo;
  const _CanteiroPickResult.selecionar(this.canteiroId) : cadastrarNovo = false;
  const _CanteiroPickResult.cadastrar()
      : canteiroId = null,
        cadastrarNovo = true;
}

class _SheetSelecionarCanteiro extends StatefulWidget {
  final String tenantId;
  final String uid;
  final String titulo;

  const _SheetSelecionarCanteiro(
      {required this.tenantId, required this.uid, required this.titulo});

  @override
  State<_SheetSelecionarCanteiro> createState() =>
      _SheetSelecionarCanteiroState();
}

class _SheetSelecionarCanteiroState extends State<_SheetSelecionarCanteiro> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: cs.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text(widget.titulo,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar canteiro...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12))),
                  filled: true,
                ),
                onChanged: (v) => setState(() => _busca = v.toLowerCase()),
              ),
              const SizedBox(height: 16),
              AppButtons.elevatedIcon(
                label: const Text('Cadastrar Novo Canteiro'),
                icon: const Icon(Icons.add),
                onPressed: () => Navigator.pop(
                    context, const _CanteiroPickResult.cadastrar()),
              ),
              const SizedBox(height: 16),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebasePaths.canteirosCol(widget.tenantId)
                      .where('ativo', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError)
                      return const Center(child: Text('Erro ao carregar'));
                    if (!snap.hasData)
                      return const Center(child: CircularProgressIndicator());

                    final docs = snap.data!.docs.where((d) {
                      final n = (d['nome'] ?? '').toString().toLowerCase();
                      return _busca.isEmpty || n.contains(_busca);
                    }).toList();

                    if (docs.isEmpty)
                      return const Center(
                          child: Text('Nenhum canteiro encontrado.'));

                    return ListView.separated(
                      controller: controller,
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final data = docs[i].data() as Map<String, dynamic>;
                        return ListTile(
                          title: Text(data['nome'] ?? 'Canteiro',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${data['area_m2'] ?? 0} m²'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(context,
                              _CanteiroPickResult.selecionar(docs[i].id)),
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
