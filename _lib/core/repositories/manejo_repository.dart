import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_sanitizer.dart';

class ManejoRepository {
  final FirebaseFirestore _fs;
  ManejoRepository({FirebaseFirestore? fs})
      : _fs = fs ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _fs.collection('historico_manejo');

  Future<String> criarManejo({
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
    if (uidUsuario.trim().isEmpty) {
      throw ArgumentError('uidUsuario vazio');
    }
    if (canteiroId.trim().isEmpty) {
      throw ArgumentError('canteiroId vazio');
    }

    final ref = _col.doc();

    final payload = <String, dynamic>{
      'canteiro_id': canteiroId,
      'uid_usuario': uidUsuario,
      'tipo_manejo': tipoManejo,
      'produto': produto,
      'detalhes': detalhes,
      'origem': origem,
      'data': FieldValue.serverTimestamp(),
      'quantidade_g': quantidadeG,
      'concluido': concluido,
      'data_colheita_prevista':
          dataColheitaPrevista != null ? Timestamp.fromDate(dataColheitaPrevista) : null,
    };

    final safe = FirestoreSanitizer.sanitizeMap(payload);
    await ref.set(safe);

    return ref.id;
  }
}
