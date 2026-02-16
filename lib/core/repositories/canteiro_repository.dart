import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase/firebase_paths.dart';

import 'firestore_writer.dart';

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
    final col = FirebasePaths.canteirosCol(tenantId)
        as CollectionReference<Map<String, dynamic>>;

    // Blindagem: nunca muta o map recebido (evita efeito colateral na UI)
    final data = Map<String, dynamic>.from(payload);

    // Defaults seguros
    data['ativo'] = (data['ativo'] ?? true) == true;
    final status = (data['status'] ?? '').toString().trim();
    if (status.isEmpty) data['status'] = 'livre';

    if (docId == null) {
      // Compat: mantém campos antigos e já cria os novos
      await FirestoreWriter.add(
        col,
        data,
        legacyCreatedField: 'data_criacao',
        legacyUpdatedField: 'data_atualizacao',
      );
    } else {
      final ref = col.doc(docId);
      await FirestoreWriter.update(
        ref,
        data,
        legacyUpdatedField: 'data_atualizacao',
      );
    }
  }

  Future<void> alternarStatusAtivo(String docId, bool ativoAtual) async {
    final ref = (FirebasePaths.canteirosCol(tenantId)
            as CollectionReference<Map<String, dynamic>>)
        .doc(docId);

    await FirestoreWriter.update(
      ref,
      {
        'ativo': !ativoAtual,
      },
      legacyUpdatedField: 'data_atualizacao',
    );
  }

  Future<void> atualizarStatus(String docId, String status) async {
    final ref = (FirebasePaths.canteirosCol(tenantId)
            as CollectionReference<Map<String, dynamic>>)
        .doc(docId);

    await FirestoreWriter.update(
      ref,
      {
        'status': status,
      },
      legacyUpdatedField: 'data_atualizacao',
    );
  }

  Future<void> duplicar(
      {required Map<String, dynamic> data, required String novoNome}) async {
    final payload = Map<String, dynamic>.from(data);
    payload['nome'] = novoNome;
    payload['nome_lower'] = novoNome.toLowerCase();
    // Compat + padrão novo
    payload['data_criacao'] = FieldValue.serverTimestamp();
    payload['createdAt'] = FieldValue.serverTimestamp();
    payload['updatedAt'] = FieldValue.serverTimestamp();
    payload.remove('data_atualizacao');
    payload
        .remove('data_criacao'); // será recolocado via writer (evita duplicar)
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

    final col = FirebasePaths.canteirosCol(tenantId)
        as CollectionReference<Map<String, dynamic>>;

    await FirestoreWriter.add(
      col,
      payload,
      legacyCreatedField: 'data_criacao',
      legacyUpdatedField: 'data_atualizacao',
    );
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
