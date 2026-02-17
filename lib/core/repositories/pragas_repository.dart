import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase/firebase_paths.dart';
import '../models/praga_model.dart';

class PragasRepository {
  // Adiciona uma nova ocorrência de praga
  Future<void> adicionarPraga(String tenantId, PragaModel praga) async {
    await FirebasePaths.pragasCol(tenantId).add(praga.toMap());
  }

  // Marca uma praga como resolvida/controlada
  Future<void> resolverPraga(String tenantId, String pragaId, String solucaoUsada) async {
    await FirebasePaths.pragasCol(tenantId).doc(pragaId).update({
      'status': 'controlada',
      'observacoes': solucaoUsada,
      'dataResolucao': FieldValue.serverTimestamp(),
    });
  }

  // Busca pragas ativas (para o dashboard)
  Stream<List<PragaModel>> getPragasAtivas(String tenantId) {
    return FirebasePaths.pragasCol(tenantId)
        .where('status', isEqualTo: 'ativa')
        .orderBy('dataIdentificacao', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PragaModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }
  
  // Busca histórico completo
  Stream<List<PragaModel>> getHistorico(String tenantId) {
    return FirebasePaths.pragasCol(tenantId)
        .orderBy('dataIdentificacao', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PragaModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }
}