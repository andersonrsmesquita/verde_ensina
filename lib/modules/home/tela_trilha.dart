import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../core/firebase/firebase_paths.dart';
import '../../core/session/session_scope.dart';
import '../../core/ui/app_ui.dart'; // Importa AppButtons, AppModuleCard, etc.

class TelaTrilha extends StatelessWidget {
  const TelaTrilha({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Trilha do Sucesso'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header Motivacional
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.primary.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.rocket_launch,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vamos começar!',
                        style: txt.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Siga os passos para uma colheita de sucesso.',
                        style: txt.bodyMedium
                            ?.copyWith(color: Colors.white.withOpacity(0.9)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Itens da Trilha
          _TrilhaItem(
            step: 1,
            title: 'Planejamento',
            desc: 'Defina o que plantar e calcule o consumo.',
            icon: Icons.edit_note,
            color: Colors.blue,
            onTap: () => context.push('/planejamento'),
          ),
          _TrilhaItem(
            step: 2,
            title: 'Meus Locais',
            desc: 'Cadastre vasos e canteiros.',
            icon: Icons.grid_view,
            color: Colors.green,
            onTap: () => context.push('/canteiros'),
          ),
          _TrilhaItem(
            step: 3,
            title: 'Diagnóstico',
            desc: 'Analise a saúde do seu solo.',
            icon: Icons.science,
            color: Colors.amber,
            onTap: () => _selecionarCanteiroParaAcao(context, 'diagnostico'),
          ),
          _TrilhaItem(
            step: 4,
            title: 'Correção (Calagem)',
            desc: 'Calcule o calcário necessário.',
            icon: Icons.landscape,
            color: Colors.brown,
            onTap: () => _selecionarCanteiroParaAcao(context, 'calagem'),
          ),
          _TrilhaItem(
            step: 5,
            title: 'Adubação Organo15',
            desc: 'Calculadora de misturas.',
            icon: Icons.eco,
            color: Colors.orange,
            onTap: () => context.push('/adubacao'),
          ),
          const _TrilhaItem(
            step: 6,
            title: 'Colheita & Venda',
            desc: 'Em breve: Gestão de produção.',
            icon: Icons.storefront,
            color: Colors.purple,
            isLocked: true,
            isLast: true,
          ),
        ],
      ),
    );
  }

  // Helper para abrir o modal de seleção
  void _selecionarCanteiroParaAcao(BuildContext context, String acao) {
    final session = SessionScope.of(context).session;
    if (session == null) {
      AppMessenger.warn('Faça login para continuar.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _CanteiroSelectionSheet(
        tenantId: session.tenantId,
        acao: acao,
      ),
    );
  }
}

// Widget encapsulado para o Item da Trilha (Design Limpo)
class _TrilhaItem extends StatelessWidget {
  final int step;
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isLast;
  final bool isLocked;

  const _TrilhaItem({
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
    final cs = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Coluna da Linha do Tempo
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isLocked ? cs.surfaceContainerHighest : cs.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isLocked ? Colors.transparent : color,
                    width: 2,
                  ),
                  boxShadow: isLocked
                      ? []
                      : [
                          BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3)),
                        ],
                ),
                child: Center(
                  child: Text(
                    '$step',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isLocked ? cs.onSurfaceVariant : color,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: cs.outlineVariant.withOpacity(0.5),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Card de Conteúdo
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Material(
                color: cs.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
                ),
                child: InkWell(
                  onTap: isLocked ? null : onTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isLocked
                                ? cs.surfaceContainerHighest
                                : color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icon,
                            color: isLocked ? cs.onSurfaceVariant : color,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: txt.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isLocked
                                      ? cs.onSurfaceVariant
                                      : cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                desc,
                                style: txt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isLocked)
                          Icon(Icons.chevron_right, color: cs.outline),
                        if (isLocked)
                          Icon(Icons.lock_outline, size: 18, color: cs.outline),
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

// Modal de Seleção de Canteiro (Limpo e Reutilizável)
class _CanteiroSelectionSheet extends StatefulWidget {
  final String tenantId;
  final String acao; // 'diagnostico' ou 'calagem'

  const _CanteiroSelectionSheet({required this.tenantId, required this.acao});

  @override
  State<_CanteiroSelectionSheet> createState() =>
      _CanteiroSelectionSheetState();
}

class _CanteiroSelectionSheetState extends State<_CanteiroSelectionSheet> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selecionar Local',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Onde você vai realizar esta ação?'),
          const SizedBox(height: 20),
          Flexible(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebasePaths.canteirosCol(widget.tenantId)
                  .where('ativo', isEqualTo: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(child: Text('Erro ao carregar locais.'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Column(
                    children: [
                      const Icon(Icons.warning_amber,
                          size: 48, color: Colors.orange),
                      const SizedBox(height: 16),
                      const Text('Nenhum local encontrado.'),
                      const SizedBox(height: 16),
                      AppButtons.elevatedIcon(
                        label: const Text('Criar Novo Canteiro'),
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/canteiros');
                        },
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        child: Icon(Icons.grid_on, color: cs.primary, size: 20),
                      ),
                      title: Text(data['nome'] ?? 'Canteiro',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${data['area_m2'] ?? 0} m²'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(context);
                        // Navegação limpa baseada na ação
                        if (widget.acao == 'diagnostico') {
                          context.push('/diagnostico/${docs[i].id}');
                        } else if (widget.acao == 'calagem') {
                          context.push('/calagem/${docs[i].id}');
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
    );
  }
}
