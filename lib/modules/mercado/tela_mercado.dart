import 'package:flutter/material.dart';

class TelaMercado extends StatefulWidget {
  const TelaMercado({super.key});

  @override
  State<TelaMercado> createState() => _TelaMercadoState();
}

class _TelaMercadoState extends State<TelaMercado> {
  final TextEditingController _searchCtrl = TextEditingController();

  final List<_MercadoCategoria> _categorias = const [
    _MercadoCategoria(id: 'sementes', nome: 'Sementes', icon: Icons.grass),
    _MercadoCategoria(id: 'mudas', nome: 'Mudas', icon: Icons.local_florist),
    _MercadoCategoria(id: 'adubos', nome: 'Adubos', icon: Icons.eco),
    _MercadoCategoria(
        id: 'irrigacao', nome: 'Irrigação', icon: Icons.water_drop),
    _MercadoCategoria(id: 'defensivos', nome: 'Pragas', icon: Icons.bug_report),
    _MercadoCategoria(
        id: 'ferramentas', nome: 'Ferramentas', icon: Icons.construction),
  ];

  // Produtos mock (depois você liga no Firestore)
  late final List<_MercadoProduto> _produtos = [
    _MercadoProduto(
      id: 'p1',
      nome: 'Semente de Alface Crespa',
      categoriaId: 'sementes',
      preco: 6.90,
      unidade: 'pacote',
      estoque: 42,
      destaque: true,
      descricao:
          'Germinação rápida. Ideal pra horta doméstica. Plantio o ano todo em clima ameno.',
      icon: Icons.grass,
      tags: const ['rápido', 'horta', 'folhosa'],
    ),
    _MercadoProduto(
      id: 'p2',
      nome: 'Muda de Manjericão',
      categoriaId: 'mudas',
      preco: 12.50,
      unidade: 'unidade',
      estoque: 18,
      destaque: true,
      descricao:
          'Aroma forte e crescimento fácil. Vai bem em vasos e canteiros.',
      icon: Icons.local_florist,
      tags: const ['tempero', 'vaso', 'fácil'],
    ),
    _MercadoProduto(
      id: 'p3',
      nome: 'Adubo Orgânico (Composto)',
      categoriaId: 'adubos',
      preco: 29.90,
      unidade: '5kg',
      estoque: 9,
      descricao:
          'Melhora a estrutura do solo e aumenta a vida microbiana. Excelente para hortaliças.',
      icon: Icons.eco,
      tags: const ['solo', 'nutrição'],
    ),
    _MercadoProduto(
      id: 'p4',
      nome: 'Fertilizante NPK 10-10-10',
      categoriaId: 'adubos',
      preco: 24.90,
      unidade: '1kg',
      estoque: 25,
      descricao:
          'Equilibrado para crescimento geral. Use com moderação e regue em seguida.',
      icon: Icons.eco,
      tags: const ['npk', 'crescimento'],
    ),
    _MercadoProduto(
      id: 'p5',
      nome: 'Kit Gotejamento (10m)',
      categoriaId: 'irrigacao',
      preco: 59.90,
      unidade: 'kit',
      estoque: 7,
      destaque: true,
      descricao:
          'Economiza água e mantém o solo úmido na medida. Ideal pra canteiros.',
      icon: Icons.water_drop,
      tags: const ['economia', 'gotejo'],
    ),
    _MercadoProduto(
      id: 'p6',
      nome: 'Pulverizador Manual (2L)',
      categoriaId: 'defensivos',
      preco: 39.90,
      unidade: 'unidade',
      estoque: 14,
      descricao:
          'Para caldas naturais, óleo de neem e aplicações leves. Fácil de usar.',
      icon: Icons.bug_report,
      tags: const ['neem', 'aplicação'],
    ),
    _MercadoProduto(
      id: 'p7',
      nome: 'Pá de Jardinagem',
      categoriaId: 'ferramentas',
      preco: 18.90,
      unidade: 'unidade',
      estoque: 33,
      descricao:
          'Boa pra transplante e manejo do solo em vasos e canteiros pequenos.',
      icon: Icons.construction,
      tags: const ['mão na massa'],
    ),
  ];

  String _categoriaSelecionada = 'sementes';

  // Carrinho: id -> qtd
  final Map<String, int> _cart = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int get _cartCount => _cart.values.fold(0, (a, b) => a + b);

  double get _cartTotal {
    double total = 0;
    for (final entry in _cart.entries) {
      final p = _produtos.firstWhere((e) => e.id == entry.key,
          orElse: () => _produtos.first);
      total += p.preco * entry.value;
    }
    return total;
  }

  String _brl(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  List<_MercadoProduto> get _filtrados {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _produtos.where((p) {
      final matchCat = p.categoriaId == _categoriaSelecionada;
      final matchSearch = q.isEmpty ||
          p.nome.toLowerCase().contains(q) ||
          p.tags.any((t) => t.toLowerCase().contains(q));
      return matchCat && matchSearch;
    }).toList();
  }

  void _setCategoria(String id) {
    setState(() {
      _categoriaSelecionada = id;
      _searchCtrl.clear();
    });
  }

  void _addToCart(_MercadoProduto p, {int qtd = 1}) {
    setState(() {
      final current = _cart[p.id] ?? 0;
      _cart[p.id] = current + qtd;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('🛒 Adicionado: ${p.nome} (+$qtd)'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Ver carrinho',
          onPressed: _openCart,
        ),
      ),
    );
  }

  void _removeFromCart(String productId) {
    setState(() {
      if (!_cart.containsKey(productId)) return;
      final current = _cart[productId]!;
      if (current <= 1) {
        _cart.remove(productId);
      } else {
        _cart[productId] = current - 1;
      }
    });
  }

  void _clearCart() {
    setState(() => _cart.clear());
  }

  void _openProduct(_MercadoProduto p) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        int qtd = 1;
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 6,
                bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor:
                            Theme.of(ctx).colorScheme.primary.withOpacity(0.12),
                        child: Icon(p.icon,
                            color: Theme.of(ctx).colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          p.nome,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        _brl(p.preco),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      p.descricao,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: p.tags
                        .map(
                          (t) => Chip(
                            label: Text(t),
                            backgroundColor: Colors.grey.shade100,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _MiniInfo(
                          label: 'Unidade',
                          value: p.unidade,
                          icon: Icons.inventory_2),
                      const SizedBox(width: 10),
                      _MiniInfo(
                        label: 'Estoque',
                        value: p.estoque > 0 ? '${p.estoque}' : 'Sem',
                        icon: Icons.warehouse,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      IconButton(
                        onPressed: qtd > 1 ? () => setModal(() => qtd--) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$qtd',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      IconButton(
                        onPressed: () => setModal(() => qtd++),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                      const Spacer(),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: p.estoque <= 0
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                  _addToCart(p, qtd: qtd);
                                },
                          icon: const Icon(Icons.add_shopping_cart),
                          label: Text('Adicionar (${_brl(p.preco * qtd)})'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openCart() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final items = _cart.entries.map((e) {
          final p = _produtos.firstWhere((x) => x.id == e.key);
          return (p: p, qtd: e.value);
        }).toList();

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 6,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('Carrinho',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _cart.isEmpty
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _clearCart();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                behavior: SnackBarBehavior.floating,
                                content: Text('🧹 Carrinho limpo.'),
                              ),
                            );
                          },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Limpar'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  child: Text(
                    'Seu carrinho tá vazio. Bora plantar alguma coisa? 😄',
                    style: TextStyle(color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...items.map((it) {
                  final subtotal = it.p.preco * it.qtd;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.12),
                          child: Icon(it.p.icon,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(it.p.nome,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Text(
                                '${_brl(it.p.preco)} • ${it.p.unidade}',
                                style: TextStyle(
                                    color: Colors.grey.shade700, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_brl(subtotal),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => _removeFromCart(it.p.id),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text('${it.qtd}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900)),
                                IconButton(
                                  onPressed: () => _addToCart(it.p, qtd: 1),
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              if (items.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      const Text('Total',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      const Spacer(),
                      Text(_brl(_cartTotal),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text(
                            '✅ Checkout (mock). Depois a gente liga no pagamento.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.payment),
                  label: const Text('Finalizar compra'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cat = _categorias.firstWhere((c) => c.id == _categoriaSelecionada);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Mercado'),
        actions: [
          IconButton(
            tooltip: 'Carrinho',
            onPressed: _openCart,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart_outlined),
                if (_cartCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$_cartCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                  radius: 22,
                  child: Icon(cat.icon, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Categoria: ${cat.nome}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Escolha itens pra sua horta e registre tudo no app.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Search
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar produtos (ex: alface, adubo, gotejo...)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Categories
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categorias.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final c = _categorias[i];
                final selected = c.id == _categoriaSelecionada;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => _setCategoria(c.id),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(c.icon, size: 18),
                      const SizedBox(width: 6),
                      Text(c.nome),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          // Destaques
          _Section(
            title: 'Destaques',
            child: _DestaquesRow(
              produtos: _produtos.where((p) => p.destaque).take(4).toList(),
              brl: _brl,
              onTap: _openProduct,
            ),
          ),

          const SizedBox(height: 14),

          // Grid
          _Section(
            title: 'Produtos',
            trailing: Text(
              '${_filtrados.length} itens',
              style: TextStyle(
                  color: Colors.grey.shade700, fontWeight: FontWeight.w800),
            ),
            child: _filtrados.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'Nada aqui com esse filtro. Tenta outra palavra.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filtrados.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    itemBuilder: (_, i) {
                      final p = _filtrados[i];
                      return _ProdutoCard(
                        produto: p,
                        brl: _brl,
                        onTap: () => _openProduct(p),
                        onAdd:
                            p.estoque <= 0 ? null : () => _addToCart(p, qtd: 1),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _cartCount == 0
          ? null
          : FloatingActionButton.extended(
              onPressed: _openCart,
              icon: const Icon(Icons.shopping_cart),
              label: Text('Carrinho • ${_brl(_cartTotal)}'),
            ),
    );
  }
}

// -------------------- UI Pieces --------------------
class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _Section({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16)),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ProdutoCard extends StatelessWidget {
  final _MercadoProduto produto;
  final String Function(double) brl;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  const _ProdutoCard({
    required this.produto,
    required this.brl,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semEstoque = produto.estoque <= 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                  child: Icon(produto.icon, color: theme.colorScheme.primary),
                ),
                const Spacer(),
                if (produto.destaque)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.25)),
                    ),
                    child: Text(
                      'Destaque',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              produto.nome,
              style: const TextStyle(fontWeight: FontWeight.w900),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              '${brl(produto.preco)} • ${produto.unidade}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    semEstoque ? 'Sem estoque' : 'Estoque: ${produto.estoque}',
                    style: TextStyle(
                      color:
                          semEstoque ? Colors.redAccent : Colors.grey.shade700,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onAdd,
                  icon:
                      Icon(semEstoque ? Icons.block : Icons.add_shopping_cart),
                  color: semEstoque ? Colors.grey : theme.colorScheme.primary,
                  tooltip: semEstoque ? 'Sem estoque' : 'Adicionar ao carrinho',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DestaquesRow extends StatelessWidget {
  final List<_MercadoProduto> produtos;
  final String Function(double) brl;
  final void Function(_MercadoProduto) onTap;

  const _DestaquesRow({
    required this.produtos,
    required this.brl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (produtos.isEmpty) {
      return Text('Sem destaques por enquanto.',
          style: TextStyle(color: Colors.grey.shade700));
    }

    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: produtos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final p = produtos[i];
          return InkWell(
            onTap: () => onTap(p),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 240,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.12),
                    child: Icon(p.icon,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.nome,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Text('${brl(p.preco)} • ${p.unidade}',
                            style: TextStyle(
                                color: Colors.grey.shade700, fontSize: 12)),
                        const Spacer(),
                        Wrap(
                          spacing: 6,
                          children: p.tags
                              .take(2)
                              .map((t) => Chip(label: Text(t)))
                              .toList(),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniInfo(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------- Models --------------------
class _MercadoCategoria {
  final String id;
  final String nome;
  final IconData icon;

  const _MercadoCategoria({
    required this.id,
    required this.nome,
    required this.icon,
  });
}

class _MercadoProduto {
  final String id;
  final String nome;
  final String categoriaId;
  final double preco;
  final String unidade;
  final int estoque;
  final bool destaque;
  final String descricao;
  final IconData icon;
  final List<String> tags;

  const _MercadoProduto({
    required this.id,
    required this.nome,
    required this.categoriaId,
    required this.preco,
    required this.unidade,
    required this.estoque,
    this.destaque = false,
    required this.descricao,
    required this.icon,
    this.tags = const [],
  });
}
