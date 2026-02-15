import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase/firebase_paths.dart';

class DiarioRepository {
  final String tenantId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DiarioRepository(this.tenantId);

  // 1. Busca bruta sem orderBy para evitar o bloqueio de Índice do Firebase
  Stream<QuerySnapshot> watchHistorico({String? canteiroId}) {
    Query q = FirebasePaths.historicoManejoCol(tenantId);

    if (canteiroId != null && canteiroId.isNotEmpty) {
      q = q.where('canteiro_id', isEqualTo: canteiroId);
    }

    return q.snapshots();
  }

  // 2. Adicionar um Novo Manejo
  Future<void> adicionarManejo(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    await FirebasePaths.historicoManejoCol(tenantId).add(data);
  }

  // 3. Marcar como Concluído / Pendente
  Future<void> toggleConcluido(String docId, bool atual) async {
    await FirebasePaths.historicoManejoCol(tenantId).doc(docId).update({
      'concluido': !atual,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // 4. Excluir Manejo
  Future<void> excluirManejo(String docId) async {
    await FirebasePaths.historicoManejoCol(tenantId).doc(docId).delete();
  }
}
