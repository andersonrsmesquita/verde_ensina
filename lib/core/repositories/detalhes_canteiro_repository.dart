import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase/firebase_paths.dart';

class DetalhesCanteiroRepository {
  final String tenantId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DetalhesCanteiroRepository(this.tenantId);

  Timestamp _nowTs() => Timestamp.now();

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    final s = v.toString().trim().replaceAll(',', '.');
    return double.tryParse(s) ?? 0.0;
  }

  // Escuta os dados do Canteiro em Tempo Real
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCanteiro(
      String canteiroId) {
    return FirebasePaths.canteiroRef(tenantId, canteiroId).snapshots();
  }

  // Escuta o Histórico do Canteiro
  Query<Map<String, dynamic>> queryHistorico(String canteiroId, String uid) {
    return _db
        .collection('tenants')
        .doc(tenantId)
        .collection('historico_manejo')
        .where('canteiro_id', isEqualTo: canteiroId)
        .where('uid_usuario', isEqualTo: uid)
        .orderBy('data', descending: true);
  }

  // Atualizar Status (Ocupado, Livre, Manutenção)
  Future<void> atualizarStatus(String canteiroId, String novoStatus) async {
    await FirebasePaths.canteiroRef(tenantId, canteiroId).update({
      'status': novoStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Editar Nome e Medidas
  Future<void> editarCanteiro(
      String canteiroId, Map<String, dynamic> dados) async {
    dados['updatedAt'] = FieldValue.serverTimestamp();
    await FirebasePaths.canteiroRef(tenantId, canteiroId).update(dados);
  }

  // Editar Texto do Histórico
  Future<void> editarTextoHistorico(
      String historicoId, String detalhes, String obs) async {
    await FirebasePaths.historicoManejoCol(tenantId).doc(historicoId).update({
      'detalhes': detalhes,
      'observacao_extra': obs,
    });
  }

  // Excluir Item do Histórico
  Future<void> excluirItemHistorico(String historicoId) async {
    await FirebasePaths.historicoManejoCol(tenantId).doc(historicoId).delete();
  }

  // Transação Premium: Irrigação
  Future<void> registrarIrrigacao({
    required String uid,
    required String canteiroId,
    required String metodo,
    required int tempo,
    required double chuva,
    required double custo,
  }) async {
    final canteiroRef = FirebasePaths.canteiroRef(tenantId, canteiroId);
    final histRef = FirebasePaths.historicoManejoCol(tenantId).doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(canteiroRef);
      if (!snap.exists) throw Exception('Lote não encontrado.');

      final c = snap.data() ?? {};
      final cicloAtivo = (c['status'] == 'ocupado') &&
          ((c['agg_ciclo_id'] ?? '').toString().isNotEmpty) &&
          (c['agg_ciclo_concluido'] != true);

      tx.set(histRef, {
        'canteiro_id': canteiroId,
        'uid_usuario': uid,
        'data': _nowTs(),
        'tipo_manejo': 'Irrigação',
        'produto': metodo,
        'detalhes': 'Duração: $tempo min | Chuva: ${chuva}mm',
        'custo': custo,
        'concluido': true,
      });

      tx.update(canteiroRef, {
        'agg_total_custo': _toDouble(c['agg_total_custo']) + custo,
        if (cicloAtivo)
          'agg_ciclo_custo': _toDouble(c['agg_ciclo_custo']) + custo,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Transação Premium: Plantio
  Future<void> registrarPlantio({
    required String uid,
    required String canteiroId,
    required Map<String, int> qtdPorPlanta,
    required String resumo,
    required String observacao,
    required double custo,
    required String produto,
  }) async {
    final canteiroRef = FirebasePaths.canteiroRef(tenantId, canteiroId);
    final plantioRef = FirebasePaths.historicoManejoCol(tenantId).doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(canteiroRef);
      if (!snap.exists) throw Exception('Lote não encontrado.');

      final canteiro = snap.data() ?? {};
      if (canteiro['status'] != 'livre')
        throw Exception('Lote Ocupado. Finalize a safra antes de plantar.');

      tx.set(plantioRef, {
        'canteiro_id': canteiroId,
        'uid_usuario': uid,
        'data': _nowTs(),
        'tipo_manejo': 'Plantio',
        'produto': produto,
        'detalhes': resumo,
        'observacao_extra': observacao,
        'concluido': false,
        'custo': custo,
        'mapa_plantio': qtdPorPlanta,
      });

      tx.update(canteiroRef, {
        'status': 'ocupado',
        'agg_total_custo': _toDouble(canteiro['agg_total_custo']) + custo,
        'agg_ciclo_custo': custo,
        'agg_ciclo_receita': 0.0,
        'agg_ciclo_id': plantioRef.id,
        'agg_ciclo_inicio': _nowTs(),
        'agg_ciclo_produtos': produto,
        'agg_ciclo_mapa': qtdPorPlanta,
        'agg_ciclo_concluido': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Transação Premium: Colheita
  Future<bool> registrarColheita({
    required String uid,
    required String canteiroId,
    required String idPlantioAtivo,
    required Map<String, int> colhidos,
    required String finalidade,
    required double receita,
    required String observacao,
  }) async {
    final plantioRef =
        FirebasePaths.historicoManejoCol(tenantId).doc(idPlantioAtivo);
    final canteiroRef = FirebasePaths.canteiroRef(tenantId, canteiroId);
    final colheitaRef = FirebasePaths.historicoManejoCol(tenantId).doc();
    bool cicloFinalizado = false;

    await _db.runTransaction((tx) async {
      final plantioSnap = await tx.get(plantioRef);
      if (!plantioSnap.exists) throw Exception('Plantio ativo não encontrado.');

      final data = plantioSnap.data() ?? {};
      Map<String, int> mapaRestante =
          Map<String, int>.from(data['mapa_plantio'] ?? {});

      colhidos.forEach((cultura, qtdColhida) {
        final atual = mapaRestante[cultura] ?? 0;
        final novo = atual - qtdColhida;
        if (novo <= 0)
          mapaRestante.remove(cultura);
        else
          mapaRestante[cultura] = novo;
      });

      final novoProduto = mapaRestante.keys.toList()..sort();
      cicloFinalizado = mapaRestante.isEmpty;

      tx.set(colheitaRef, {
        'canteiro_id': canteiroId,
        'uid_usuario': uid,
        'data': _nowTs(),
        'tipo_manejo': 'Colheita',
        'produto': colhidos.keys.join(' + '),
        'detalhes':
            'Colhido: ${colhidos.entries.map((e) => '${e.key} (${e.value} un)').join(' | ')}',
        'concluido': true,
        'finalidade': finalidade,
        if (finalidade == 'comercio') 'receita': receita,
        if (finalidade == 'consumo' && observacao.isNotEmpty)
          'observacao_extra': observacao,
      });

      tx.update(plantioRef, {
        'mapa_plantio': mapaRestante,
        'produto': novoProduto.join(' + '),
        if (cicloFinalizado) 'concluido': true,
      });

      final canteiroSnap = await tx.get(canteiroRef);
      final c = canteiroSnap.data() ?? {};

      final updates = <String, dynamic>{
        'agg_ciclo_mapa': mapaRestante,
        'agg_ciclo_produtos': novoProduto.join(' + '),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (finalidade == 'comercio') {
        updates['agg_total_receita'] =
            _toDouble(c['agg_total_receita']) + receita;
        updates['agg_ciclo_receita'] =
            _toDouble(c['agg_ciclo_receita']) + receita;
      }

      if (cicloFinalizado) {
        updates['status'] = 'livre';
        updates['agg_ciclo_concluido'] = true;
      }
      tx.update(canteiroRef, updates);
    });

    return cicloFinalizado; // Retorna true se a safra acabou e liberou o canteiro
  }

  // Transação Premium: Perda / Baixa
  Future<bool> registrarPerda({
    required String uid,
    required String canteiroId,
    required String idPlantioAtivo,
    required String cultura,
    required int qtdPerdida,
    required String motivo,
  }) async {
    final plantioRef =
        FirebasePaths.historicoManejoCol(tenantId).doc(idPlantioAtivo);
    final canteiroRef = FirebasePaths.canteiroRef(tenantId, canteiroId);
    final perdaRef = FirebasePaths.historicoManejoCol(tenantId).doc();
    bool cicloFinalizado = false;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(plantioRef);
      final data = snap.data() ?? {};
      Map<String, int> mapaAtual =
          Map<String, int>.from(data['mapa_plantio'] ?? {});

      final atual = mapaAtual[cultura] ?? 0;
      final novo = atual - qtdPerdida;
      if (novo <= 0)
        mapaAtual.remove(cultura);
      else
        mapaAtual[cultura] = novo;

      cicloFinalizado = mapaAtual.isEmpty;

      tx.set(perdaRef, {
        'canteiro_id': canteiroId,
        'uid_usuario': uid,
        'data': _nowTs(),
        'tipo_manejo': 'Perda',
        'produto': cultura,
        'detalhes': 'Baixa: $qtdPerdida un | Motivo: $motivo',
        'concluido': true,
      });

      tx.update(plantioRef,
          {'mapa_plantio': mapaAtual, if (cicloFinalizado) 'concluido': true});

      final updates = <String, dynamic>{
        'agg_ciclo_mapa': mapaAtual,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (cicloFinalizado) {
        updates['status'] = 'livre';
        updates['agg_ciclo_concluido'] = true;
      }
      tx.update(canteiroRef, updates);
    });

    return cicloFinalizado;
  }
}
