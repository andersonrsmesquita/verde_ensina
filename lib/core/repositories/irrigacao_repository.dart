import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase/firebase_paths.dart';

class IrrigacaoRepository {
  final String tenantId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  IrrigacaoRepository(this.tenantId);

  // Stream de canteiros ativos para o seletor
  Stream<QuerySnapshot<Map<String, dynamic>>> watchCanteiros() {
    return FirebasePaths.canteirosCol(tenantId)
        .where('ativo', isEqualTo: true)
        .orderBy('nome')
        .snapshots();
  }

  // Stream de histórico filtrado
  Stream<QuerySnapshot<Map<String, dynamic>>> watchHistorico() {
    return FirebasePaths.historicoManejoCol(tenantId)
        .where('tipo_manejo', isEqualTo: 'Irrigação')
        .orderBy('data', descending: true)
        .limit(50)
        .snapshots();
  }

  // Busca custo da água configurado no perfil do usuário
  Future<double> getCustoAguaUsuario(String uid) async {
    try {
      final doc = await _db.collection('configuracoes_usuario').doc(uid).get();
      if (doc.exists) {
        final val = doc.data()?['custo_padrao_agua'];
        if (val is num) return val.toDouble();
      }
    } catch (_) {}
    // De acordo com o manual, o custo padrão será R$ 6,00 por m³ [cite: 2935]
    return 6.00;
  }

  // Gravação em lote (SaaS Premium) corrigida para bater com a TelaIrrigacao
  Future<void> registrarRegaEmLote({
    required String uidUsuario,
    required List<Map<String, dynamic>> canteirosSelecionados,
    required int tempoMinutos,
    required String metodo,
    required double custoAguaM3,
    required double volumeTotalLitros,
    required String obs,
  }) async {
    final batch = _db.batch();

    // Extrai nomes e IDs para salvar no banco
    final nomes = canteirosSelecionados.map((l) => l['nome']).join(', ');
    final ids = canteirosSelecionados.map((l) => l['id']).toList();
    final agora = FieldValue.serverTimestamp();

    // 1. Cria o documento principal de histórico
    final docRef = FirebasePaths.historicoManejoCol(tenantId).doc();

    batch.set(docRef, {
      'canteiro_id': ids.length == 1 ? ids.first : 'LOTE',
      'canteiro_nome': ids.length > 1 ? '${ids.length} Locais' : nomes,
      'canteiros_detalhe': nomes,
      'uid_usuario': uidUsuario,
      'tipo_manejo': 'Irrigação',
      'produto': 'Água ($metodo)',
      'volume_l': volumeTotalLitros,
      // O custo é calculado convertendo o m³ para litros [cite: 3309]
      'custo_estimado': volumeTotalLitros * (custoAguaM3 / 1000),
      'tempo_min': tempoMinutos,
      'metodo': metodo,
      'obs': obs,
      'data': agora,
      'createdAt': agora,
      'concluido': true,
      'origem': 'assistente_irrigacao_pro',
    });

    // 2. Atualiza os dados dentro de CADA canteiro selecionado para manter o dashboard do usuário atualizado
    for (var c in canteirosSelecionados) {
      final canteiroRef = FirebasePaths.canteirosCol(tenantId).doc(c['id']);

      final area = c['area'] as double;
      // Calcula o volume individual (5 litros por metro quadrado)
      final volumeCanteiro = area * 5.0;

      batch.set(
          canteiroRef,
          {
            'updatedAt': agora,
            'totais_insumos.agua_litros': FieldValue.increment(volumeCanteiro),
            'ult_manejo': {
              'tipo': 'Irrigação',
              'hist_id': docRef.id,
              'resumo': '$metodo (${volumeCanteiro.toStringAsFixed(0)} L)',
              'atualizadoEm': agora,
            }
          },
          SetOptions(merge: true));
    }

    // 3. Salva tudo de uma vez no Firebase
    await batch.commit();
  }
}
