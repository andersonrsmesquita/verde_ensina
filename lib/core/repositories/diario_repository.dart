import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase/firebase_paths.dart';

class DiarioRepository {
  final String tenantId;
  final FirebaseFirestore _db;

  DiarioRepository(
    this.tenantId, {
    FirebaseFirestore? db,
  }) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col {
    return FirebasePaths.historicoManejoCol(tenantId)
        as CollectionReference<Map<String, dynamic>>;
  }

  /// Padrão premium (igual TelaCanteiros):
  /// - Query BASE simples, ordenada por data.
  /// - Filtros por canteiro/status/busca ficam na tela (RAM),
  ///   pra não depender de índice composto.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchHistorico({
    String? canteiroId, // mantido por compatibilidade (filtramos na UI)
    int limit = 500,
  }) {
    final q = _col.orderBy('data', descending: true).limit(limit);
    return q.snapshots();
  }

  Future<void> adicionarManejo(Map<String, dynamic> payload) async {
    final ref = _col.doc();
    final now = FieldValue.serverTimestamp();

    final data = <String, dynamic>{
      'canteiro_id': payload['canteiro_id'],
      'canteiro_nome': payload['canteiro_nome'] ?? 'Canteiro',
      'tipo_manejo': payload['tipo_manejo'] ?? 'Manejo',
      'produto': payload['produto'] ?? '',
      'detalhes': payload['detalhes'] ?? '',
      'origem': payload['origem'] ?? 'manual',
      'concluido': payload['concluido'] ?? false,
      'uid_usuario': payload['uid_usuario'],
      'data': payload['data'] ?? now,
      'createdAt': payload['createdAt'] ?? now,
      'updatedAt': payload['updatedAt'] ?? now,
      if (payload.containsKey('quantidade_g'))
        'quantidade_g': payload['quantidade_g'],
      if (payload.containsKey('data_colheita_prevista'))
        'data_colheita_prevista': payload['data_colheita_prevista'],
    };

    if (data['canteiro_id'] == null ||
        (data['canteiro_id'].toString().trim().isEmpty)) {
      throw ArgumentError('canteiro_id é obrigatório');
    }
    if (data['uid_usuario'] == null ||
        (data['uid_usuario'].toString().trim().isEmpty)) {
      throw ArgumentError('uid_usuario é obrigatório');
    }

    await ref.set(data);
  }

  Future<void> excluirManejo(String id) async {
    await _col.doc(id).delete();
  }

  Future<void> toggleConcluido(String id, bool atual) async {
    await _col.doc(id).update({
      'concluido': !atual,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
