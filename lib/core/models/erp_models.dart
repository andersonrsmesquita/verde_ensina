// FILE: lib/core/models/erp_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// 1. PRODUTO (O que você colheu e vai vender)
class ProdutoEstoque {
  final String id;
  final String nome; // Ex: Alface Americana
  final double quantidadeAtual;
  final String unidade; // kg, maço, caixa
  final double custoMedioUnitario; // Calculado automaticamente pelo manejo

  ProdutoEstoque(
      {required this.id,
      required this.nome,
      required this.quantidadeAtual,
      required this.unidade,
      required this.custoMedioUnitario});

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'quantidade': quantidadeAtual,
        'unidade': unidade,
        'custo_medio': custoMedioUnitario,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

// 2. ITEM DE VENDA (O carrinho de compras)
class ItemVenda {
  final String produtoId;
  final String nomeProduto;
  final double quantidade;
  final double precoUnitarioVenda;
  // Correção aqui: O comentário estava quebrando o código
  final double custoUnitario;

  ItemVenda({
    required this.produtoId,
    required this.nomeProduto,
    required this.quantidade,
    required this.precoUnitarioVenda,
    required this.custoUnitario,
  });

  double get subtotal => quantidade * precoUnitarioVenda;
  double get lucroBruto => (precoUnitarioVenda - custoUnitario) * quantidade;

  Map<String, dynamic> toMap() => {
        'produto_id': produtoId,
        'nome': nomeProduto,
        'qtd': quantidade,
        'preco_venda': precoUnitarioVenda,
        'custo_base': custoUnitario,
      };
}

// 3. VENDA (A transação completa)
class VendaModel {
  final String? id;
  final String clienteNome;
  final DateTime data;
  final List<ItemVenda> itens;
  final double valorTotal;
  final double lucroTotalEstimado;
  final String statusPagamento; // 'pendente', 'pago'

  VendaModel({
    this.id,
    required this.clienteNome,
    required this.data,
    required this.itens,
    required this.valorTotal,
    required this.lucroTotalEstimado,
    this.statusPagamento = 'pendente',
  });

  Map<String, dynamic> toMap() => {
        'cliente_nome': clienteNome,
        'data': Timestamp.fromDate(data),
        'itens': itens.map((i) => i.toMap()).toList(),
        'total': valorTotal,
        'lucro_estimado': lucroTotalEstimado,
        'status_pagamento': statusPagamento,
        'tipo': 'receita_venda'
      };
}
