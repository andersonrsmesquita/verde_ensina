import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase/firebase_paths.dart';

class DiarioRepository {
  final String tenantId;

  DiarioRepository(this.tenantId);

  Stream<QuerySnapshot<Map<String, dynamic>>> watchHistorico({String? canteiroId}) {
    Query<Map<String, dynamic>> q = FirebasePaths.historicoManejoCol(tenantId);
    if (canteiroId != null && canteiroId.isNotEmpty) {
      q = q.where('canteiro_id', isEqualTo: canteiroId);
    }
    return q.orderBy('data', descending: true).limit(100).snapshots();
  }

  Future<void> adicionarManejo(Map<String, dynamic> dados) async {
    final docRef = FirebasePaths.historicoManejoCol(tenantId).doc();
    // Adiciona timestamps automáticos se não vierem
    dados['data_criacao'] ??= FieldValue.serverTimestamp();
    dados['ativo'] = true;
    
    // Sanitização básica (pode ser expandida)
    final safeData = dados.map((key, value) {
      if (value is double && (value.isNaN || value.isInfinite)) return MapEntry(key, 0.0);
      return MapEntry(key, value);
    });

    await docRef.set(safeData);
  }

  Future<void> toggleConcluido(String docId, bool atual) async {
    await FirebasePaths.historicoManejoCol(tenantId).doc(docId).update({
      'concluido': !atual,
      'data_atualizacao': FieldValue.serverTimestamp(),
    });
  }
}