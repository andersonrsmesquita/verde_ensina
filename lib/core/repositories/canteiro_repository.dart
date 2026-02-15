import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase/firebase_paths.dart';

class CanteiroRepository {
  final String tenantId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CanteiroRepository(this.tenantId);

  // Busca os canteiros aplicando filtros
  Query<Map<String, dynamic>> queryCanteiros({
    required String filtroAtivo,
    required String filtroStatus,
    required String busca,
  }) {
    Query<Map<String, dynamic>> q = FirebasePaths.canteirosCol(tenantId);

    if (filtroAtivo == 'ativos') {
      q = q.where('ativo', isEqualTo: true);
    } else if (filtroAtivo == 'arquivados') {
      q = q.where('ativo', isEqualTo: false);
    }

    if (filtroStatus != 'todos') {
      q = q.where('status', isEqualTo: filtroStatus);
    }

    if (busca.trim().isNotEmpty) {
      final term = busca.trim().toLowerCase();
      q = q.orderBy('nome_lower').startAt([term]).endAt(['$term\uf8ff']);
    } else {
      q = q.orderBy('data_criacao', descending: true);
    }

    return q;
  }

  // Cria ou Atualiza um Lote/Vaso
  Future<void> salvarLocal({
    String? docId,
    required Map<String, dynamic> payload,
  }) async {
    if (docId == null) {
      payload['data_criacao'] = FieldValue.serverTimestamp();
      payload['ativo'] = true;
      payload['status'] = 'livre';
      await FirebasePaths.canteirosCol(tenantId).add(payload);
    } else {
      payload['data_atualizacao'] = FieldValue.serverTimestamp();
      await FirebasePaths.canteirosCol(tenantId).doc(docId).update(payload);
    }
  }

  // Arquiva ou Reativa
  Future<void> alternarStatusAtivo(String docId, bool ativoAtual) async {
    await FirebasePaths.canteirosCol(tenantId).doc(docId).update({
      'ativo': !ativoAtual,
      'data_atualizacao': FieldValue.serverTimestamp(),
    });
  }

  // Exclusão Permanente (Cascade Delete - Exclui o Lote e o Histórico dele)
  Future<void> excluirDefinitivoCascade(String uid, String canteiroId) async {
    final batch = _db.batch();

    // Apaga o histórico vinculado ao canteiro
    final historicoSnap = await FirebasePaths.historicoManejoCol(tenantId)
        .where('canteiro_id', isEqualTo: canteiroId)
        .where('uid_usuario', isEqualTo: uid)
        .get();

    for (var doc in historicoSnap.docs) {
      batch.delete(doc.reference);
    }

    // Apaga o canteiro
    final canteiroRef = FirebasePaths.canteirosCol(tenantId).doc(canteiroId);
    batch.delete(canteiroRef);

    await batch.commit();
  }
}
