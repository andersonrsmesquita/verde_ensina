// FILE: lib/core/repositories/vendas_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase/firebase_paths.dart';
import '../models/erp_models.dart';

class VendasRepository {
  final String tenantId;
  VendasRepository(this.tenantId);

  // REALIZAR UMA VENDA INTEGRADA (Atomic Transaction)
  Future<void> realizarVenda(VendaModel venda) async {
    final db = FirebaseFirestore.instance;

    await db.runTransaction((transaction) async {
      // 1. Validar e Abater Estoque para CADA item
      for (var item in venda.itens) {
        final docRef =
            FirebasePaths.estoqueProdutosCol(tenantId).doc(item.produtoId);
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          throw Exception(
              "Produto ${item.nomeProduto} não encontrado no estoque!");
        }

        final estoqueAtual =
            (snapshot.data()?['quantidade'] as num?)?.toDouble() ?? 0;

        if (estoqueAtual < item.quantidade) {
          throw Exception(
              "Estoque insuficiente para ${item.nomeProduto}. Disponível: $estoqueAtual");
        }

        // Abate o estoque
        transaction.update(docRef, {
          'quantidade': estoqueAtual - item.quantidade,
        });
      }

      // 2. Criar o registro da Venda
      final vendaRef = FirebasePaths.vendasCol(tenantId).doc();
      transaction.set(vendaRef, venda.toMap());

      // 3. Lançar automaticamente no Financeiro (Contas a Receber/Caixa)
      final finRef = FirebasePaths.financeiroCol(tenantId).doc();
      transaction.set(finRef, {
        'descricao':
            'Venda #${vendaRef.id.substring(0, 5).toUpperCase()} - ${venda.clienteNome}',
        'valor': venda.valorTotal,
        'tipo': 'receita',
        'categoria': 'Vendas',
        'data': Timestamp.fromDate(venda.data),
        'origem_id': vendaRef.id, // Link para rastreabilidade (Auditabilidade)
        'status': venda.statusPagamento, // Pago ou A Receber
        'criado_em': FieldValue.serverTimestamp(),
      });
    });
  }

  // Buscar produtos disponíveis para venda (Dropdown)
  Stream<List<ProdutoEstoque>> getProdutosDisponiveis() {
    return FirebasePaths.estoqueProdutosCol(tenantId)
        .where('quantidade', isGreaterThan: 0)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              return ProdutoEstoque(
                id: doc.id,
                nome: d['nome'],
                quantidadeAtual: (d['quantidade'] as num).toDouble(),
                unidade: d['unidade'] ?? 'un',
                custoMedioUnitario:
                    (d['custo_medio'] as num?)?.toDouble() ?? 0.0,
              );
            }).toList());
  }
}
