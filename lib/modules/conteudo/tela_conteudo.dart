import 'package:flutter/material.dart';

// Seus imports de UI
import '../../core/ui/app_ui.dart';

class TelaConteudo extends StatelessWidget {
  const TelaConteudo({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: cs.surface, // Cor de fundo do tema
        appBar: AppBar(
          title: Text(
            'Conteúdo & Receitas',
            style: txt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: cs.primary,
            labelColor: cs.primary,
            unselectedLabelColor: cs.onSurfaceVariant,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(
                  text: 'Dicas de Cultivo',
                  icon: Icon(Icons.lightbulb_outline)),
              Tab(text: 'Receitas da Roça', icon: Icon(Icons.restaurant_menu)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AbaDicas(),
            _AbaReceitas(),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ABA 1: DICAS TÉCNICAS (Layout de Artigos)
// ============================================================================
class _AbaDicas extends StatelessWidget {
  const _AbaDicas();

  @override
  Widget build(BuildContext context) {
    // Mock de dados (Simulando o Firestore)
    final dicas = [
      ConteudoModel(
        titulo: 'Como identificar falta de Nitrogênio?',
        resumo:
            'Folhas amareladas podem ser um sinal. Veja como corrigir rápido.',
        categoria: 'Nutrição',
        icon: Icons.science,
        cor: Colors.blue,
        tempoLeitura: '3 min',
      ),
      ConteudoModel(
        titulo: 'Calendário de Poda: Tomate e Pimentão',
        resumo: 'A época certa para podar e aumentar sua produtividade.',
        categoria: 'Manejo',
        icon: Icons.content_cut,
        cor: Colors.orange,
        tempoLeitura: '5 min',
      ),
      ConteudoModel(
        titulo: 'Irrigação: Gotejamento ou Aspersão?',
        resumo: 'Descubra qual sistema economiza mais água no seu canteiro.',
        categoria: 'Irrigação',
        icon: Icons.water_drop,
        cor: Colors.cyan,
        tempoLeitura: '4 min',
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: dicas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _ContentCard(item: dicas[index]);
      },
    );
  }
}

// ============================================================================
// ABA 2: RECEITAS (Layout de Culinária)
// ============================================================================
class _AbaReceitas extends StatelessWidget {
  const _AbaReceitas();

  @override
  Widget build(BuildContext context) {
    final receitas = [
      ConteudoModel(
        titulo: 'Molho de Tomate Rústico',
        resumo: 'Aproveite a colheita excessiva de tomates com essa receita.',
        categoria: 'Conserva',
        icon: Icons.soup_kitchen,
        cor: Colors.red,
        tempoLeitura: '40 min', // Tempo de preparo
      ),
      ConteudoModel(
        titulo: 'Chips de Batata Doce Assada',
        resumo: 'Snack saudável e crocante direto da terra para o forno.',
        categoria: 'Lanche',
        icon: Icons.cookie,
        cor: Colors.amber,
        tempoLeitura: '25 min',
      ),
      ConteudoModel(
        titulo: 'Pesto de Manjericão Fresco',
        resumo: 'O clássico italiano com o manjericão da sua horta.',
        categoria: 'Molhos',
        icon: Icons.eco,
        cor: Colors.green,
        tempoLeitura: '10 min',
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: receitas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _ContentCard(item: receitas[index], isRecipe: true);
      },
    );
  }
}

// ============================================================================
// WIDGETS AUXILIARES E MODELOS
// ============================================================================

/// Modelo simples para organizar os dados antes de vir do Firebase
class ConteudoModel {
  final String titulo;
  final String resumo;
  final String categoria;
  final String tempoLeitura;
  final IconData icon;
  final Color cor;

  ConteudoModel({
    required this.titulo,
    required this.resumo,
    required this.categoria,
    required this.tempoLeitura,
    required this.icon,
    required this.cor,
  });
}

/// O Card visualmente rico
class _ContentCard extends StatelessWidget {
  final ConteudoModel item;
  final bool isRecipe;

  const _ContentCard({required this.item, this.isRecipe = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Navegação para detalhes (placeholder)
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _TelaDetalheConteudo(item: item),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícone/Imagem do Conteúdo
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: item.cor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.cor, size: 30),
                ),
                const SizedBox(width: 16),

                // Textos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tag de Categoria
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.categoria.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Título
                      Text(
                        item.titulo,
                        style: txt.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Resumo
                      Text(
                        item.resumo,
                        style:
                            txt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),

                      // Rodapé (Tempo e Ação)
                      Row(
                        children: [
                          Icon(isRecipe ? Icons.timer_outlined : Icons.schedule,
                              size: 14, color: cs.outline),
                          const SizedBox(width: 4),
                          Text(
                            item.tempoLeitura,
                            style: TextStyle(fontSize: 12, color: cs.outline),
                          ),
                          const Spacer(),
                          Text(
                            'Ler mais',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward,
                              size: 14, color: cs.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Tela de Leitura (Placeholder Detalhado)
class _TelaDetalheConteudo extends StatelessWidget {
  final ConteudoModel item;

  const _TelaDetalheConteudo({required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(item.categoria)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(item.icon, size: 80, color: item.cor),
            const SizedBox(height: 24),
            Text(
              item.titulo,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Aqui virá o conteúdo completo do Firestore, podendo ser texto rico, vídeo ou lista de ingredientes.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
