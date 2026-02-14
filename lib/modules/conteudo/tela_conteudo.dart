import 'package:flutter/material.dart';

class TelaConteudo extends StatelessWidget {
  const TelaConteudo({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dicas & Receitas'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.lightbulb_outline), text: 'Dicas'),
              Tab(icon: Icon(Icons.restaurant_menu), text: 'Receitas'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ListaPlaceholder(texto: 'Dicas práticas (em breve)'),
            _ListaPlaceholder(texto: 'Receitas e conteúdos (em breve)'),
          ],
        ),
      ),
    );
  }
}

class _ListaPlaceholder extends StatelessWidget {
  final String texto;
  const _ListaPlaceholder({required this.texto});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.article_outlined),
            title: Text('$texto #${i + 1}'),
            subtitle: const Text('Depois a gente puxa do Firestore sem mexer na UI.'),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }
}
