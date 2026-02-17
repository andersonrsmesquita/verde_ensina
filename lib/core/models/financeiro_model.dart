// FILE: lib/core/models/financeiro_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoTransacao { receita, despesa }

class FinanceiroTransacao {
  final String id;
  final String descricao;
  final double valor;
  final TipoTransacao tipo;
  final String categoria; // Ex: "Insumos", "Mão de Obra", "Venda", "Energia"
  final DateTime data;
  final String?
      canteiroId; // Opcional: para saber o custo específico de um lote
  final String? origemId; // Se veio do Diário de Manejo, guardamos o ID aqui

  FinanceiroTransacao({
    required this.id,
    required this.descricao,
    required this.valor,
    required this.tipo,
    required this.categoria,
    required this.data,
    this.canteiroId,
    this.origemId,
  });

  // Converte do Firestore para o App
  factory FinanceiroTransacao.fromMap(Map<String, dynamic> map, String docId) {
    return FinanceiroTransacao(
      id: docId,
      descricao: map['descricao'] ?? '',
      valor: (map['valor'] as num?)?.toDouble() ?? 0.0,
      tipo: (map['tipo'] == 'receita')
          ? TipoTransacao.receita
          : TipoTransacao.despesa,
      categoria: map['categoria'] ?? 'Geral',
      data: (map['data'] as Timestamp?)?.toDate() ?? DateTime.now(),
      canteiroId: map['canteiro_id'],
      origemId: map['origem_id'],
    );
  }

  // Converte do App para o Firestore
  Map<String, dynamic> toMap() {
    return {
      'descricao': descricao,
      'valor': valor,
      'tipo': tipo == TipoTransacao.receita ? 'receita' : 'despesa',
      'categoria': categoria,
      'data': Timestamp.fromDate(data),
      'canteiro_id': canteiroId,
      'origem_id': origemId,
    };
  }
}
