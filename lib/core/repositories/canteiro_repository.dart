import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase/firebase_paths.dart';

class CanteiroRepository {
  final String tenantId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CanteiroRepository(this.tenantId);

  // Busca os canteiros BRUTOS (sem filtros).
  // O app vai filtrar localmente para evitar erros de Índice no Firebase.
  Query<Map<String, dynamic>> queryCanteiros() {
    return FirebasePaths.canteirosCol(tenantId);
  }

  Future<void> salvarLocal(
      {String? docId, required Map<String, dynamic> payload}) async {
    if (docId == null) {
      payload['data_criacao'] = FieldValue.serverTimestamp();
      payload['ativo'] = true;
      if (payload['status'] == null || payload['status']!.isEmpty) {
        payload['status'] = 'livre';
      }
      await FirebasePaths.canteirosCol(tenantId).add(payload);
    } else {
      payload['data_atualizacao'] = FieldValue.serverTimestamp();
      await FirebasePaths.canteirosCol(tenantId).doc(docId).update(payload);
    }
  }

  Future<void> alternarStatusAtivo(String docId, bool ativoAtual) async {
    await FirebasePaths.canteirosCol(tenantId).doc(docId).update({
      'ativo': !ativoAtual,
      'data_atualizacao': FieldValue.serverTimestamp(),
    });
  }

  Future<void> atualizarStatus(String docId, String status) async {
    await FirebasePaths.canteirosCol(tenantId).doc(docId).update({
      'status': status,
      'data_atualizacao': FieldValue.serverTimestamp(),
    });
  }

  Future<void> duplicar(
      {required Map<String, dynamic> data, required String novoNome}) async {
    final payload = Map<String, dynamic>.from(data);
    payload['nome'] = novoNome;
    payload['nome_lower'] = novoNome.toLowerCase();
    payload['data_criacao'] = FieldValue.serverTimestamp();
    payload.remove('data_atualizacao');
    payload['status'] = 'livre';
    payload.remove('agg_ciclo_id');
    payload.remove('agg_ciclo_inicio');
    payload.remove('agg_ciclo_produtos');
    payload.remove('agg_ciclo_mapa');
    payload['agg_ciclo_concluido'] = false;
    payload['agg_total_custo'] = 0.0;
    payload['agg_total_receita'] = 0.0;
    payload['agg_ciclo_custo'] = 0.0;
    payload['agg_ciclo_receita'] = 0.0;

    await FirebasePaths.canteirosCol(tenantId).add(payload);
  }

  Future<void> excluirDefinitivoCascade(String uid, String canteiroId) async {
    final batch = _db.batch();

    final historicoSnap = await FirebasePaths.historicoManejoCol(tenantId)
        .where('canteiro_id', isEqualTo: canteiroId)
        .where('uid_usuario', isEqualTo: uid)
        .get();

    for (var doc in historicoSnap.docs) {
      batch.delete(doc.reference);
    }

    final canteiroRef = FirebasePaths.canteirosCol(tenantId).doc(canteiroId);
    batch.delete(canteiroRef);

    await batch.commit();
  }
}
