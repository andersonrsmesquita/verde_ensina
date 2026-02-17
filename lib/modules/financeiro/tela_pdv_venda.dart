// FILE: lib/modules/financeiro/tela_pdv_venda.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/erp_models.dart';
import '../../core/repositories/vendas_repository.dart';
import '../../core/session/session_scope.dart';
import '../../core/ui/app_ui.dart';

class TelaPdvVenda extends StatefulWidget {
  const TelaPdvVenda({super.key});

  @override
  State<TelaPdvVenda> createState() => _TelaPdvVendaState();
}

class _TelaPdvVendaState extends State<TelaPdvVenda> {
  // Estado do Carrinho
  final List<ItemVenda> _carrinho = [];
  final _clienteController = TextEditingController();

  // Estado do Item sendo adicionado
  ProdutoEstoque? _produtoSelecionado;
  final _qtdController = TextEditingController();
  final _precoVendaController = TextEditingController();

  bool _processando = false;

  void _adicionarAoCarrinho() {
    if (_produtoSelecionado == null) return;
    final qtd = double.tryParse(_qtdController.text.replaceAll(',', '.')) ?? 0;
    final preco =
        double.tryParse(_precoVendaController.text.replaceAll(',', '.')) ?? 0;

    if (qtd <= 0 || preco <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Quantidade e Preço devem ser maiores que zero.")));
      return;
    }

    if (qtd > _produtoSelecionado!.quantidadeAtual) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "Estoque insuficiente! Máx: ${_produtoSelecionado!.quantidadeAtual}")));
      return;
    }

    setState(() {
      _carrinho.add(ItemVenda(
        produtoId: _produtoSelecionado!.id,
        nomeProduto: _produtoSelecionado!.nome,
        quantidade: qtd,
        precoUnitarioVenda: preco,
        custoUnitario: _produtoSelecionado!.custoMedioUnitario,
      ));
      // Reset campos
      _produtoSelecionado = null;
      _qtdController.clear();
      _precoVendaController.clear();
    });
  }

  double get _totalVenda =>
      _carrinho.fold(0, (sum, item) => sum + item.subtotal);
  double get _lucroEstimado =>
      _carrinho.fold(0, (sum, item) => sum + item.lucroBruto);

  Future<void> _finalizarVenda(VendasRepository repo) async {
    if (_carrinho.isEmpty || _clienteController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Preencha o cliente e adicione itens.")));
      return;
    }

    setState(() => _processando = true);

    try {
      final venda = VendaModel(
        clienteNome: _clienteController.text,
        data: DateTime.now(),
        itens: _carrinho,
        valorTotal: _totalVenda,
        lucroTotalEstimado: _lucroEstimado,
        statusPagamento: 'pago', // Simplificado para este exemplo
      );

      await repo.realizarVenda(venda);

      if (!mounted) return;

      // Feedback de Sucesso Estilo ERP
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Text("Venda Registrada!")
          ]),
          content: Text(
              "Estoque atualizado.\nFinanceiro lançado.\n\nLucro desta venda: R\$ ${_lucroEstimado.toStringAsFixed(2)}"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // Fecha Dialog
                Navigator.pop(context); // Fecha Tela PDV
              },
              child: const Text("OK"),
            )
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context).session;
    if (session == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final repo = VendasRepository(session.tenantId);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Nova Venda (PDV)")),
      body: Column(
        children: [
          // 1. DADOS DO CLIENTE
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _clienteController,
              decoration: const InputDecoration(
                labelText: "Nome do Cliente",
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
          ),

          // 2. SELEÇÃO DE PRODUTOS (Conectado ao Estoque)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: cs.surfaceVariant.withOpacity(0.3),
            child: Column(
              children: [
                StreamBuilder<List<ProdutoEstoque>>(
                    stream: repo.getProdutosDisponiveis(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const LinearProgressIndicator();
                      final produtos = snapshot.data!;

                      return DropdownButtonFormField<ProdutoEstoque>(
                        value: _produtoSelecionado,
                        decoration: const InputDecoration(
                            labelText: "Selecionar Produto do Estoque",
                            border: OutlineInputBorder()),
                        items: produtos
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                      "${p.nome} (Disp: ${p.quantidadeAtual} ${p.unidade})"),
                                ))
                            .toList(),
                        onChanged: (p) =>
                            setState(() => _produtoSelecionado = p),
                      );
                    }),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _qtdController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: "Qtd",
                            suffixText: _produtoSelecionado?.unidade ?? 'un',
                            border: const OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _precoVendaController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: "Preço Unit. (R\$)",
                            prefixText: "R\$ ",
                            border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                        onPressed: _adicionarAoCarrinho,
                        icon: const Icon(Icons.add_shopping_cart))
                  ],
                ),
              ],
            ),
          ),

          // 3. LISTA DE ITENS (CARRINHO)
          Expanded(
            child: ListView.separated(
              itemCount: _carrinho.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final item = _carrinho[i];
                return ListTile(
                  title: Text(item.nomeProduto,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      "${item.quantidade} x R\$ ${item.precoUnitarioVenda.toStringAsFixed(2)}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("R\$ ${item.subtotal.toStringAsFixed(2)}",
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.red),
                        onPressed: () => setState(() => _carrinho.removeAt(i)),
                      )
                    ],
                  ),
                );
              },
            ),
          ),

          // 4. RODAPÉ DE TOTAIS E FINALIZAÇÃO
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("TOTAL A RECEBER:",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text("R\$ ${_totalVenda.toStringAsFixed(2)}",
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed:
                        _processando ? null : () => _finalizarVenda(repo),
                    icon: _processando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: Text(
                        _processando ? "PROCESSANDO..." : "FINALIZAR VENDA"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
