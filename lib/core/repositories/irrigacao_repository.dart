import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase/firebase_paths.dart';

class IrrigacaoRepository {
  final String tenantId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  IrrigacaoRepository(this.tenantId);

  // Histórico
  Stream<QuerySnapshot<Map<String, dynamic>>> watchHistorico() {
    return FirebasePaths.historicoManejoCol(tenantId)
        .where('tipo_manejo', isEqualTo: 'Irrigação')
        .orderBy('data', descending: true)
        .limit(50)
        .snapshots();
  }

  // Canteiros Ativos
  Stream<QuerySnapshot<Map<String, dynamic>>> watchCanteiros() {
    return FirebasePaths.canteirosCol(tenantId)
        .where('ativo', isEqualTo: true)
        .orderBy('nome')
        .snapshots();
  }

  // Busca Custo da Água nas Configurações
  Future<double> getCustoAguaUsuario(String uid) async {
    try {
      final doc = await _db.collection('configuracoes_usuario').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final val = doc.data()!['custo_padrao_agua'];
        if (val is num) return val.toDouble();
        if (val is String)
          return double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
      }
    } catch (e) {
      print('Erro config: $e');
    }
    return 0.0;
  }

  // Salvar Rega (Suporta Lote)
  Future<void> registrarRegaEmLote({
    required String uidUsuario,
    required List<Map<String, dynamic>> canteirosSelecionados,
    required int tempoMinutos,
    required String metodo,
    required double custoAguaM3,
    required double volumeTotalLitros,
    String? obs,
  }) async {
    final batch = _db.batch();
    final docRef = FirebasePaths.historicoManejoCol(tenantId).doc();

    // Calcula custo total baseado no volume
    final custoTotal = volumeTotalLitros * (custoAguaM3 / 1000);

    // Nomes para exibição
    final nomes = canteirosSelecionados.map((c) => c['nome']).join(', ');

    final payload = {
      'canteiro_id': 'LOTE', // Indica que foi múltiplo
      'canteiros_ids': canteirosSelecionados.map((c) => c['id']).toList(),
      'canteiro_nome': canteirosSelecionados.length > 1
          ? '${canteirosSelecionados.length} Locais'
          : nomes,
      'canteiros_detalhe': nomes,
      'uid_usuario': uidUsuario,
      'tipo_manejo': 'Irrigação',
      'produto': 'Água ($metodo)',
      'detalhes': '$tempoMinutos min via $metodo. ${obs ?? ''}',
      'volume_l': volumeTotalLitros,
      'custo_estimado': custoTotal,
      'tempo_min': tempoMinutos,
      'metodo': metodo,
      'data': FieldValue.serverTimestamp(),
      'concluido': true,
      'origem': 'modulo_irrigacao_v2',
    };

    batch.set(docRef, payload);
    await batch.commit();
  }
}
