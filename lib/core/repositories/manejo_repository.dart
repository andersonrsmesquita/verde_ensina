import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firebase_paths.dart';
import 'firestore_writer.dart';

class ManejoRepository {
  final FirebaseFirestore _fs;
  ManejoRepository({FirebaseFirestore? fs})
      : _fs = fs ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _tenantCol(String tenantId) =>
      FirebasePaths.tenantSubCol(tenantId, 'historico_manejo');

  /// Cria um registro de manejo no escopo do tenant.
  Future<String> criarManejo({
    required String tenantId,
    required String uidUsuario,
    required String canteiroId,
    required String tipoManejo,
    required String produto,
    String detalhes = '',
    String origem = 'manual',
    double quantidadeG = 0,
    bool concluido = false,
    DateTime? dataColheitaPrevista,
  }) async {
    if (tenantId.trim().isEmpty) {
      throw ArgumentError('tenantId vazio');
    }
    if (uidUsuario.trim().isEmpty) {
      throw ArgumentError('uidUsuario vazio');
    }
    if (canteiroId.trim().isEmpty) {
      throw ArgumentError('canteiroId vazio');
    }

    final ref = _tenantCol(tenantId).doc();

    final payload = <String, dynamic>{
      'canteiro_id': canteiroId,
      'uid_usuario': uidUsuario, // mantém como "criado por"
      'tipo_manejo': tipoManejo,
      'produto': produto,
      'detalhes': detalhes,
      'origem': origem,
      'data': FieldValue.serverTimestamp(),
      'quantidade_g': quantidadeG,
      'concluido': concluido,
      'data_colheita_prevista': dataColheitaPrevista != null
          ? Timestamp.fromDate(dataColheitaPrevista)
          : null,
    };
    await FirestoreWriter.create(ref, payload);

    return ref.id;
  }
}
