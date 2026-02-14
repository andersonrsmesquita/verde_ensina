import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/firebase/firebase_paths.dart';
import '../../core/session/session_scope.dart';

import '../../core/ui/app_ui.dart';
import '../../core/repositories/user_profile_repository.dart';

// Telas
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

  void _setAba(int index) {
    if (index == _indiceAtual) return;
    setState(() => _indiceAtual = index);
  }

  void _push(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // AppBar premium: sempre coerente com o tema, sem “cor jogada”.
    // A diferença entre abas fica no título e ações, não em cor estranha.
    switch (_indiceAtual) {
      case 0:
        return AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          title: Row(
            children: [
              Icon(Icons.eco, color: cs.primary),
              const SizedBox(width: 10),
              const Text(
                'Verde Ensina',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          actions: [
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
            const SizedBox(width: 4),
          ],
        );

      case 1:
        return AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: true,
          title: const Text(
            'Trilha do Cultivo',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        );

      default:
        return AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          title: const Text(
            'Meu Perfil',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        );
    }
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(top: BorderSide(color: cs.outlineVariant)),
          ),
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
}

// ============================================================================
// ABA 1: INÍCIO (DASHBOARD) — premium: responsivo, limpo, sem “boxDecoration” repetida
// ============================================================================
class _AbaInicioDashboard extends StatelessWidget {
  const _AbaInicioDashboard();

  Future<_CanteiroPickResult?> _abrirSheetCanteiros(
    BuildContext context, {
    required String titulo,
    required String subtitulo,
    required String uid,
    required String tenantId,
  }) async {
    return showModalBottomSheet<_CanteiroPickResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SheetSelecionarCanteiro(
        tenantId: tenantId,
        uid: uid,
        titulo: titulo,
        subtitulo: subtitulo,
      ),
    );
  }

  Future<void> _abrirPlanejamentoPorCanteiro(BuildContext context) async {
    final appSession = SessionScope.of(context).session;
    if (appSession == null) {
      AppMessenger.warn('Você precisa estar logado e com um espaço (tenant) selecionado.');
      return;
    }

    final result = await _abrirSheetCanteiros(
      context,
      uid: appSession.uid,
      tenantId: appSession.tenantId,
      titulo: 'Planejamento por Canteiro',
      subtitulo: 'Selecione o canteiro para calcular o plantio certinho.',
    );

    if (!context.mounted || result == null) return;

    if (result.cadastrarNovo) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const TelaCanteiros()));
      return;
    }

    final id = result.canteiroId;
    if (id == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => TelaPlanejamentoCanteiro(canteiroIdOrigem: id)),
    );
  }

  Future<void> _abrirDiagnostico(BuildContext context) async {
    final appSession = SessionScope.of(context).session;
    if (appSession == null) {
      AppMessenger.warn('Você precisa estar logado e com um espaço (tenant) selecionado.');
      return;
    }

    final result = await _abrirSheetCanteiros(
      context,
      uid: appSession.uid,
      tenantId: appSession.tenantId,
      titulo: 'Diagnóstico do Solo',
      subtitulo: 'Escolha o canteiro para analisar o solo.',
    );

    if (!context.mounted || result == null) return;

    if (result.cadastrarNovo) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const TelaCanteiros()));
      return;
    }

    final id = result.canteiroId;
    if (id == null) return;

    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TelaDiagnostico(canteiroIdOrigem: id)));
  }

  Future<void> _abrirCalagem(BuildContext context) async {
    final appSession = SessionScope.of(context).session;
    if (appSession == null) {
      AppMessenger.warn('Você precisa estar logado e com um espaço (tenant) selecionado.');
      return;
    }

    final result = await _abrirSheetCanteiros(
      context,
      uid: appSession.uid,
      tenantId: appSession.tenantId,
      titulo: 'Calagem',
      subtitulo: 'Escolha o canteiro para calcular a correção.',
    );

    if (!context.mounted || result == null) return;

    if (result.cadastrarNovo) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const TelaCanteiros()));
      return;
    }

    final id = result.canteiroId;
    if (id == null) return;

    Navigator.push(context,
        MaterialPageRoute(builder: (_) => TelaCalagem(canteiroIdOrigem: id)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;

        return LayoutBuilder(
          builder: (context, c) {
            final maxW = c.maxWidth;
            final contentMax =
                maxW >= 1200 ? 1100.0 : (maxW >= 980 ? 960.0 : maxW);

            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMax),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeaderBlock(
                          title: user == null ? 'Olá! 👋' : 'Olá, Produtor! 👋',
                          subtitle: user == null
                              ? 'Faça login para ver sua visão geral.'
                              : 'Visão geral da sua produção.',
                        ),
                        const SizedBox(height: 14),
                        _SectionTitle('Ações rápidas'),
                        const SizedBox(height: 10),
                        _QuickActionsRow(
                          onPlanejar: () =>
                              _abrirPlanejamentoPorCanteiro(context),
                          onCanteiros: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TelaCanteiros()),
                          ),
                          onDiario: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TelaDiarioManejo()),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (user != null && SessionScope.of(context).session != null) ...[
                          _SectionTitle('Resumo'),
                          const SizedBox(height: 10),
                          _ResumoDashboard(
                            tenantId: SessionScope.of(context).session!.tenantId,
                            uid: user.uid,
                          ),
                          const SizedBox(height: 18),
                        ],
                        _SectionTitle('Módulos'),
                        const SizedBox(height: 10),
                        _ModulesGrid(
                          onPlanejamentoGeral: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const TelaPlanejamentoConsumo()),
                          ),
                          onPlanejamentoCanteiro: () =>
                              _abrirPlanejamentoPorCanteiro(context),
                          onCanteiros: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TelaCanteiros()),
                          ),
                          onDiagnostico: () => _abrirDiagnostico(context),
                          onCalagem: () => _abrirCalagem(context),
                          onAdubacao: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TelaAdubacaoOrgano15()),
                          ),
                          onDiario: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TelaDiarioManejo()),
                          ),
                          onConteudo: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TelaConteudo()),
                          ),
                          onAlertas: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TelaAlertas()),
                          ),
                          onPragas: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TelaPragas()),
                          ),
                          onIrrigacao: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TelaIrrigacao()),
                          ),
                          onFinanceiro: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TelaFinanceiro()),
                          ),
                          onMercado: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TelaMercado()),
                          ),
                          onConfiguracoes: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TelaConfiguracoes()),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (user == null)
                          _InfoBanner(
                            icon: Icons.lock_outline,
                            title: 'Você está desconectado',
                            message:
                                'Algumas ações exigem login (ex: diagnóstico, calagem, planejamento por canteiro).',
                            color: cs.tertiary,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  final String title;
  final String subtitle;

  const _HeaderBlock({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: t.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Text(text,
        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900));
  }
}

// Ações rápidas premium: card simples, coerente com tema, sem “decoração duplicada”
class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onPlanejar;
  final VoidCallback onCanteiros;
  final VoidCallback onDiario;

  const _QuickActionsRow({
    required this.onPlanejar,
    required this.onCanteiros,
    required this.onDiario,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final bool three = w >= 900;
        final bool two = w >= 560;

        final tileW = three
            ? (w - 24) / 3
            : two
                ? (w - 12) / 2
                : w;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: tileW,
              child: _ActionCard(
                icon: Icons.auto_awesome,
                title: 'Planejar\npor canteiro',
                onTap: onPlanejar,
              ),
            ),
            SizedBox(
              width: tileW,
              child: _ActionCard(
                icon: Icons.grid_on,
                title: 'Meus\ncanteiros',
                onTap: onCanteiros,
              ),
            ),
            SizedBox(
              width: tileW,
              child: _ActionCard(
                icon: Icons.menu_book,
                title: 'Diário\nde manejo',
                onTap: onDiario,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  const _InfoBanner({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: color.withOpacity(0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          t.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(message,
                      style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Grid de módulos premium: estrutura por lista, sem repetição
class _ModulesGrid extends StatelessWidget {
  final VoidCallback onPlanejamentoGeral;
  final VoidCallback onPlanejamentoCanteiro;
  final VoidCallback onCanteiros;
  final VoidCallback onDiagnostico;
  final VoidCallback onCalagem;
  final VoidCallback onAdubacao;
  final VoidCallback onDiario;
  final VoidCallback onConteudo;
  final VoidCallback onAlertas;
  final VoidCallback onPragas;
  final VoidCallback onIrrigacao;
  final VoidCallback onFinanceiro;
  final VoidCallback onMercado;
  final VoidCallback onConfiguracoes;

  const _ModulesGrid({
    required this.onPlanejamentoGeral,
    required this.onPlanejamentoCanteiro,
    required this.onCanteiros,
    required this.onDiagnostico,
    required this.onCalagem,
    required this.onAdubacao,
    required this.onDiario,
    required this.onConteudo,
    required this.onAlertas,
    required this.onPragas,
    required this.onIrrigacao,
    required this.onFinanceiro,
    required this.onMercado,
    required this.onConfiguracoes,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_ModuleItem>[
      _ModuleItem(
        title: 'Planejamento',
        subtitle: 'Geral (consumo)',
        icon: Icons.calculate,
        onTap: onPlanejamentoGeral,
      ),
      _ModuleItem(
        title: 'Planejar por Canteiro',
        subtitle: 'Linhas e quantidades',
        icon: Icons.auto_awesome,
        onTap: onPlanejamentoCanteiro,
      ),
      _ModuleItem(
        title: 'Canteiros',
        subtitle: 'Minha área',
        icon: Icons.grid_on,
        onTap: onCanteiros,
      ),
      _ModuleItem(
        title: 'Diagnóstico do Solo',
        subtitle: 'Analisar canteiro',
        icon: Icons.science,
        onTap: onDiagnostico,
      ),
      _ModuleItem(
        title: 'Calagem',
        subtitle: 'Correção de acidez',
        icon: Icons.landscape,
        onTap: onCalagem,
      ),
      _ModuleItem(
        title: 'Adubação',
        subtitle: 'Organo15',
        icon: Icons.eco,
        onTap: onAdubacao,
      ),
      _ModuleItem(
        title: 'Diário de Manejo',
        subtitle: 'Rotina do produtor',
        icon: Icons.menu_book,
        onTap: onDiario,
      ),
      _ModuleItem(
        title: 'Dicas & Receitas',
        subtitle: 'Curadoria + comunidade',
        icon: Icons.restaurant,
        onTap: onConteudo,
      ),
      _ModuleItem(
        title: 'Alertas/Agenda',
        subtitle: 'Lembretes',
        icon: Icons.notifications_active,
        onTap: onAlertas,
      ),
      _ModuleItem(
        title: 'Pragas & Doenças',
        subtitle: 'Base de conhecimento',
        icon: Icons.bug_report,
        onTap: onPragas,
      ),
      _ModuleItem(
        title: 'Irrigação',
        subtitle: 'Regras + histórico',
        icon: Icons.water_drop,
        onTap: onIrrigacao,
      ),
      _ModuleItem(
        title: 'Financeiro',
        subtitle: 'Custos e lucro',
        icon: Icons.attach_money,
        onTap: onFinanceiro,
      ),
      _ModuleItem(
        title: 'Mercado',
        subtitle: 'Compra/Venda (futuro)',
        icon: Icons.storefront,
        onTap: onMercado,
      ),
      _ModuleItem(
        title: 'Configurações',
        subtitle: 'Preferências',
        icon: Icons.settings,
        onTap: onConfiguracoes,
      ),
    ];

    return GridView.extent(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      maxCrossAxisExtent: 360,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: items.map((m) => _ModuleCard(m)).toList(),
    );
  }
}

class _ModuleItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ModuleItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}

class _ModuleCard extends StatelessWidget {
  final _ModuleItem item;
  const _ModuleCard(this.item);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, color: cs.primary),
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                item.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumoDashboard extends StatelessWidget {
  final String tenantId;
  final String? uid;
  const _ResumoDashboard({required this.tenantId, this.uid});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final canteirosStream = FirebasePaths.canteirosCol(tenantId)
        .where('ativo', isEqualTo: true)
        .snapshots();

    final ultManejoStream = FirebasePaths.historicoManejoCol(tenantId)
        .orderBy('data', descending: true)
        .limit(1)
        .snapshots();

    return Row(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: canteirosStream,
            builder: (context, snap) {
              final waiting = snap.connectionState == ConnectionState.waiting;
              final hasErr = snap.hasError;

              final qtd =
                  (!waiting && !hasErr) ? (snap.data?.docs.length ?? 0) : null;

              return _MetricCard(
                icon: Icons.grid_on,
                title: 'Canteiros ativos',
                value: qtd == null ? '—' : qtd.toString(),
                tone: cs.primary,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: ultManejoStream,
            builder: (context, snap) {
              final waiting = snap.connectionState == ConnectionState.waiting;
              final hasErr = snap.hasError;

              String value = '—';

              if (!waiting &&
                  !hasErr &&
                  snap.hasData &&
                  snap.data!.docs.isNotEmpty) {
                final raw = snap.data!.docs.first.data();
                final data =
                    (raw is Map<String, dynamic>) ? raw : <String, dynamic>{};
                value = (data['tipo_manejo'] ?? 'Manejo').toString();
              }

              return _MetricCard(
                icon: Icons.history,
                title: 'Último manejo',
                value: value,
                tone: cs.secondary,
                smallValue: true,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color tone;
  final bool smallValue;

  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.tone,
    this.smallValue = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tone.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: tone),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (smallValue ? t.bodyMedium : t.titleLarge)
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ABA 2: JORNADA — mantida, mas com layout mais consistente com tema
// ============================================================================
class _AbaJornadaTrilha extends StatelessWidget {
  const _AbaJornadaTrilha();

  Future<void> _iniciarAcaoComCanteiro(
      BuildContext context, String acao) async {
    final appSession = SessionScope.of(context).session;
    if (appSession == null) {
      AppMessenger.warn('Você precisa estar logado e com um espaço (tenant) selecionado.');
      return;
    }

    final result = await showModalBottomSheet<_CanteiroPickResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SheetSelecionarCanteiro(
        tenantId: appSession.tenantId,
        uid: appSession.uid,
        titulo: 'Para qual canteiro?',
        subtitulo: 'Escolha o canteiro onde você quer executar essa etapa.',
      ),
    );

    if (!context.mounted || result == null) return;

    if (result.cadastrarNovo) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const TelaCanteiros()));
      return;
    }

    final canteiroId = result.canteiroId;
    if (canteiroId == null) return;

    if (acao == 'planejamento_canteiro') {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                TelaPlanejamentoCanteiro(canteiroIdOrigem: canteiroId)),
      );
    } else if (acao == 'diagnostico') {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TelaDiagnostico(canteiroIdOrigem: canteiroId)),
      );
    } else if (acao == 'calagem') {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TelaCalagem(canteiroIdOrigem: canteiroId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth;
        final contentMax = maxW >= 1200 ? 1100.0 : (maxW >= 980 ? 960.0 : maxW);

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMax),
                child: Card(
                  elevation: 0,
                  color: cs.primaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome,
                            color: cs.onPrimaryContainer, size: 38),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Siga o Passo a Passo',
                                style: TextStyle(
                                  color: cs.onPrimaryContainer,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Complete as fases para colher mais.',
                                style: TextStyle(
                                    color:
                                        cs.onPrimaryContainer.withOpacity(0.8)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMax),
                child: Column(
                  children: [
                    _TimelineItem(
                      fase: 1,
                      titulo: 'Planejamento (por canteiro)',
                      descricao: 'Quantidade e linhas',
                      icone: Icons.auto_awesome,
                      corIcone: cs.primary,
                      onTap: () => _iniciarAcaoComCanteiro(
                          context, 'planejamento_canteiro'),
                    ),
                    _TimelineItem(
                      fase: 2,
                      titulo: 'Planejamento (geral)',
                      descricao: 'O que plantar?',
                      icone: Icons.calculate,
                      corIcone: cs.primary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TelaPlanejamentoConsumo()),
                      ),
                    ),
                    _TimelineItem(
                      fase: 3,
                      titulo: 'Meus Canteiros',
                      descricao: 'Organize sua área.',
                      icone: Icons.grid_on,
                      corIcone: cs.primary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TelaCanteiros()),
                      ),
                    ),
                    _TimelineItem(
                      fase: 4,
                      titulo: 'Diagnóstico',
                      descricao: 'Analise o solo.',
                      icone: Icons.science,
                      corIcone: cs.primary,
                      onTap: () =>
                          _iniciarAcaoComCanteiro(context, 'diagnostico'),
                    ),
                    _TimelineItem(
                      fase: 5,
                      titulo: 'Calagem',
                      descricao: 'Corrija a acidez.',
                      icone: Icons.landscape,
                      corIcone: cs.primary,
                      onTap: () => _iniciarAcaoComCanteiro(context, 'calagem'),
                    ),
                    _TimelineItem(
                      fase: 6,
                      titulo: 'Adubação',
                      descricao: 'Nutrição Organo15.',
                      icone: Icons.eco,
                      corIcone: cs.primary,
                      bloqueado: false,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TelaAdubacaoOrgano15()),
                      ),
                    ),
                    const _TimelineItem(
                      fase: 7,
                      titulo: 'Colheita',
                      descricao: 'Venda (Em breve).',
                      icone: Icons.shopping_basket,
                      corIcone: Colors.grey,
                      isLast: true,
                      bloqueado: true,
                      onTap: null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// RESULTADO DO SHEET
// ============================================================================
class _CanteiroPickResult {
  final String? canteiroId;
  final bool cadastrarNovo;

  const _CanteiroPickResult.selecionar(this.canteiroId) : cadastrarNovo = false;
  const _CanteiroPickResult.cadastrar()
      : canteiroId = null,
        cadastrarNovo = true;
}

// ============================================================================
// SHEET SELECIONAR CANTEIRO — premium e estável
// ============================================================================
class _SheetSelecionarCanteiro extends StatefulWidget {
  final String tenantId;
  final String uid;
  final String titulo;
  final String subtitulo;

  const _SheetSelecionarCanteiro({
    required this.tenantId,
    required this.uid,
    required this.titulo,
    required this.subtitulo,
  });

  @override
  State<_SheetSelecionarCanteiro> createState() =>
      _SheetSelecionarCanteiroState();
}

class _SheetSelecionarCanteiroState extends State<_SheetSelecionarCanteiro> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final stream = FirebasePaths.canteirosCol(widget.tenantId)
        .where('ativo', isEqualTo: true)
        .snapshots();

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, controller) {
        return Material(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.titulo,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppButtons.outlinedIcon(
                      icon: const Icon(Icons.add),
                      label: const Text('Novo'),
                      onPressed: () => Navigator.pop(
                        context,
                        const _CanteiroPickResult.cadastrar(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(widget.subtitulo,
                    style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) =>
                      setState(() => _busca = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Buscar canteiro...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: cs.primary, width: 1.4),
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

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Erro ao carregar canteiros.',
                            style: TextStyle(color: cs.error),
                          ),
                        );
                      }

                      final docsAll = snapshot.data?.docs ?? [];
                      if (docsAll.isEmpty) {
                        return Column(
                          children: [
                            Card(
                              elevation: 0,
                              color: cs.tertiaryContainer,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: cs.outlineVariant),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: cs.onTertiaryContainer),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Você ainda não tem canteiros ativos. Cadastre um para continuar.',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: cs.onTertiaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: AppButtons.elevatedIcon(
                                icon: const Icon(Icons.grid_on),
                                label: const Text('Cadastrar Canteiro'),
                                onPressed: () => Navigator.pop(
                                  context,
                                  const _CanteiroPickResult.cadastrar(),
                                ),
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
                        final raw = d.data();
                        final data = (raw is Map<String, dynamic>)
                            ? raw
                            : <String, dynamic>{};
                        final nome = ((data['nome'] ?? 'Canteiro').toString())
                            .toLowerCase();
                        if (_busca.isEmpty) return true;
                        return nome.contains(_busca);
                      }).toList()
                        ..sort((a, b) {
                          final da = (a.data() is Map<String, dynamic>)
                              ? a.data() as Map<String, dynamic>
                              : {};
                          final db = (b.data() is Map<String, dynamic>)
                              ? b.data() as Map<String, dynamic>
                              : {};
                          final na =
                              (da['nome'] ?? '').toString().toLowerCase();
                          final nb =
                              (db['nome'] ?? '').toString().toLowerCase();
                          return na.compareTo(nb);
                        });

                      return ListView.separated(
                        controller: controller,
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: cs.outlineVariant),
                        itemBuilder: (context, index) {
                          final doc = docs[index] as QueryDocumentSnapshot;
                          final raw = doc.data();
                          final data = (raw is Map<String, dynamic>)
                              ? raw
                              : <String, dynamic>{};

                          final nome = (data['nome'] ?? 'Canteiro').toString();

                          final area = data['area_m2'];
                          double areaM2 = 0;
                          if (area is num) areaM2 = area.toDouble();
                          if (area is String) {
                            areaM2 =
                                double.tryParse(area.replaceAll(',', '.')) ?? 0;
                          }

                          return ListTile(
                            leading: Icon(Icons.grid_on, color: cs.primary),
                            title: Text(
                              nome,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle:
                                Text('Área: ${areaM2.toStringAsFixed(2)} m²'),
                            trailing: Icon(Icons.chevron_right,
                                color: cs.onSurfaceVariant),
                            onTap: () => Navigator.pop(
                              context,
                              _CanteiroPickResult.selecionar(doc.id),
                            ),
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
      },
    );
  }
}

// ============================================================================
// PERFIL — premium (mais reativo, sem “peguei user uma vez e pronto”)
// ============================================================================
class AbaPerfilPage extends StatelessWidget {
  const AbaPerfilPage({super.key});

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
      AppMessenger.success('Você saiu da conta.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final repo = UserProfileRepository();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        final user = snap.data;

        if (user == null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            child: Card(
              elevation: 0,
              color: cs.tertiaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cs.outlineVariant),
              ),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Você está desconectado. Faça login para acessar o perfil.',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            StreamBuilder(
              stream: repo.watch(user.uid),
              builder: (context, snapshot) {
                final raw = snapshot.data?.data();
                final data =
                    (raw is Map<String, dynamic>) ? raw : <String, dynamic>{};
                final displayName =
                    (data['displayName'] ?? '').toString().trim();
                final plan = (data['plan'] ?? 'free').toString();

                final titulo = displayName.isNotEmpty
                    ? displayName
                    : (user.email ?? 'Produtor');
                final subtitulo = 'Plano: ${plan.toUpperCase()}';

                return Card(
                  elevation: 0,
                  color: cs.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: cs.primary.withOpacity(0.12),
                          child: Text(
                            titulo.isNotEmpty ? titulo[0].toUpperCase() : 'U',
                            style: TextStyle(
                              fontSize: 26,
                              color: cs.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titulo,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                subtitulo,
                                style: TextStyle(
                                    color: cs.onSurfaceVariant, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _ProfileSection(
              title: 'Conta',
              children: [
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Ajuda & Suporte'),
                  onTap: () => AppMessenger.info('Suporte: em breve 😉'),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacidade'),
                  onTap: () => AppMessenger.info('Privacidade: em breve'),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Configurações'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TelaConfiguracoes()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ProfileSection(
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
      },
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ProfileSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          ...children,
        ],
      ),
    );
  }
}

// ============================================================================
// Timeline Item — refinado (usa tema, sem card “old school”)
// ============================================================================
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
    final cs = Theme.of(context).colorScheme;

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
                  color: bloqueado ? cs.surfaceContainerHighest : corIcone,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.surface, width: 2),
                ),
                child: Center(
                  child: Text(
                    fase.toString(),
                    style: TextStyle(
                      color: bloqueado ? cs.onSurfaceVariant : Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: cs.outlineVariant,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                elevation: 0,
                color: cs.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                child: InkWell(
                  onTap: bloqueado ? null : onTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: bloqueado
                                ? cs.surface
                                : corIcone.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            icone,
                            color: bloqueado ? cs.onSurfaceVariant : corIcone,
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: bloqueado
                                      ? cs.onSurfaceVariant
                                      : cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                descricao,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          bloqueado ? Icons.lock_outline : Icons.chevron_right,
                          color: cs.onSurfaceVariant,
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
