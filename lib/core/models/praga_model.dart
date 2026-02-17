import 'package:cloud_firestore/cloud_firestore.dart';

class PragaModel {
  final String? id;
  final String nome; // Ex: Pulgão, Lagarta
  final String canteiroId; // Onde está o problema?
  final String canteiroNome; // Para facilitar a exibição na lista
  final String intensidade; // Leve, Média, Alta (Infestação)
  final DateTime dataIdentificacao;
  final String? fotoUrl; // Opcional
  final String status; // 'ativa' | 'controlada'
  final String? observacoes; // Qual veneno/orgânico usou?

  PragaModel({
    this.id,
    required this.nome,
    required this.canteiroId,
    required this.canteiroNome,
    required this.intensidade,
    required this.dataIdentificacao,
    this.fotoUrl,
    this.status = 'ativa',
    this.observacoes,
  });

  factory PragaModel.fromMap(Map<String, dynamic> map, String docId) {
    return PragaModel(
      id: docId,
      nome: map['nome'] ?? '',
      canteiroId: map['canteiroId'] ?? '',
      canteiroNome: map['canteiroNome'] ?? 'Canteiro Desconhecido',
      intensidade: map['intensidade'] ?? 'Leve',
      dataIdentificacao:
          (map['dataIdentificacao'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fotoUrl: map['fotoUrl'],
      status: map['status'] ?? 'ativa',
      observacoes: map['observacoes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'canteiroId': canteiroId,
      'canteiroNome': canteiroNome,
      'intensidade': intensidade,
      'dataIdentificacao': Timestamp.fromDate(dataIdentificacao),
      'fotoUrl': fotoUrl,
      'status': status,
      'observacoes': observacoes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
