import 'package:cloud_firestore/cloud_firestore.dart';

/// Padrão multi-tenant do VerdeEnsina Pro:
/// - Dados do app ficam SEMPRE dentro de: tenants/{tenantId}/...
/// - Usuários (identidade/login) ficam em: users/{uid}
/// - Membership fica em: tenants/{tenantId}/members/{uid}
class FirebasePaths {
  FirebasePaths._();

  static FirebaseFirestore get db => FirebaseFirestore.instance;

  // =========================
  // Tenancy
  // =========================
  static CollectionReference<Map<String, dynamic>> tenantsCol() =>
      db.collection('tenants');

  static DocumentReference<Map<String, dynamic>> tenantRef(String tenantId) =>
      tenantsCol().doc(tenantId);

  static CollectionReference<Map<String, dynamic>> tenantSubCol(
    String tenantId,
    String colName,
  ) =>
      tenantRef(tenantId).collection(colName);

  static DocumentReference<Map<String, dynamic>> memberRef(
    String tenantId,
    String uid,
  ) =>
      tenantRef(tenantId).collection('members').doc(uid);

  // =========================
  // Users
  // =========================
  static DocumentReference<Map<String, dynamic>> userRef(String uid) =>
      db.collection('users').doc(uid);

  // =========================
  // Core domain collections (por tenant)
  // =========================

  // Canteiros
  static CollectionReference<Map<String, dynamic>> canteirosCol(
    String tenantId,
  ) =>
      tenantRef(tenantId).collection('canteiros');

  static DocumentReference<Map<String, dynamic>> canteiroRef(
    String tenantId,
    String canteiroId,
  ) =>
      canteirosCol(tenantId).doc(canteiroId);

  // Histórico de manejo (2 opções)
  // A) por canteiro (mais granular)
  static CollectionReference<Map<String, dynamic>> canteiroHistoricoCol(
    String tenantId,
    String canteiroId,
  ) =>
      canteiroRef(tenantId, canteiroId).collection('historico_manejo');

  // B) geral do tenant (melhor pra dashboard/último manejo)
  static CollectionReference<Map<String, dynamic>> historicoManejoCol(
    String tenantId,
  ) =>
      tenantRef(tenantId).collection('historico_manejo');

  // Planejamentos (subcoleção por canteiro)
  static CollectionReference<Map<String, dynamic>> canteiroPlanejamentosCol(
    String tenantId,
    String canteiroId,
  ) =>
      canteiroRef(tenantId, canteiroId).collection('planejamentos');

  // Análises de solo (geral por tenant; compatível com seu código atual)
  static CollectionReference<Map<String, dynamic>> analisesSoloCol(
    String tenantId,
  ) =>
      tenantRef(tenantId).collection('analises_solo');

  // Módulos Técnicos
  static CollectionReference<Map<String, dynamic>> irrigacaoCol(
    String tenantId,
  ) =>
      tenantRef(tenantId).collection('irrigacao');

  static CollectionReference<Map<String, dynamic>> pragasCol(
    String tenantId,
  ) =>
      tenantRef(tenantId).collection('pragas');

  // =========================
  // Módulos ERP / Negócio
  // =========================

  // ESTOQUE DE INSUMOS (Sementes, Adubos, Defensivos)
  static CollectionReference<Map<String, dynamic>> estoqueInsumosCol(
    String tenantId,
  ) =>
      tenantRef(tenantId).collection('estoque_insumos');

  // ESTOQUE DE PRODUTOS COLHIDOS (O que está pronto para venda)
  static CollectionReference<Map<String, dynamic>> estoqueProdutosCol(
    String tenantId,
  ) =>
      tenantRef(tenantId).collection('estoque_produtos');

  // VENDAS / PEDIDOS
  static CollectionReference<Map<String, dynamic>> vendasCol(
    String tenantId,
  ) =>
      tenantRef(tenantId).collection('vendas');

  // CLIENTES (CRM)
  static CollectionReference<Map<String, dynamic>> clientesCol(
    String tenantId,
  ) =>
      tenantRef(tenantId).collection('clientes');

  // FINANCEIRO (Centraliza Contas a Pagar e Receber)
  static CollectionReference<Map<String, dynamic>> financeiroCol(
    String tenantId,
  ) =>
      tenantRef(tenantId).collection('financeiro');
}
