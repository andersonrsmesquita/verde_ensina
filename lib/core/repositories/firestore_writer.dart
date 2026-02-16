import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_sanitizer.dart';

/// Camada de escrita *blindada* pro Firestore.
///
/// Objetivos (Patch #02):
/// - Sanitizar payloads (pega NaN/Infinity, tipos inválidos, chaves erradas)
/// - Padronizar timestamps (createdAt/updatedAt) SEM quebrar campos legados
/// - Entregar erros mais humanos (pra tela não virar “tela vermelha”)
class FirestoreWriter {
  FirestoreWriter._();

  /// Enrich de timestamps. Mantém compatibilidade com campos antigos.
  ///
  /// Exemplos de legado:
  /// - canteiros: data_criacao / data_atualizacao
  /// - padrão novo: createdAt / updatedAt
  static Map<String, dynamic> withTimestamps(
    Map<String, dynamic> input, {
    required bool isCreate,
    String createdField = 'createdAt',
    String updatedField = 'updatedAt',
    String? legacyCreatedField,
    String? legacyUpdatedField,
  }) {
    final out = Map<String, dynamic>.from(input);
    final now = FieldValue.serverTimestamp();

    if (isCreate) {
      out.putIfAbsent(createdField, () => now);
      out.putIfAbsent(updatedField, () => now);
      if (legacyCreatedField != null) {
        out.putIfAbsent(legacyCreatedField, () => now);
      }
      if (legacyUpdatedField != null) {
        out.putIfAbsent(legacyUpdatedField, () => now);
      }
    } else {
      out[updatedField] = now;
      if (legacyUpdatedField != null) {
        out[legacyUpdatedField] = now;
      }
    }
    return out;
  }

  /// Sanitiza (e falha com mensagem útil) antes de gravar.
  static Map<String, dynamic> sanitize(Map<String, dynamic> input) {
    return FirestoreSanitizer.sanitizeMap(input);
  }

  /// Escrita de create (add) com timestamps + sanitização.
  static Future<DocumentReference<Map<String, dynamic>>> add(
    CollectionReference<Map<String, dynamic>> col,
    Map<String, dynamic> payload, {
    String createdField = 'createdAt',
    String updatedField = 'updatedAt',
    String? legacyCreatedField,
    String? legacyUpdatedField,
  }) async {
    try {
      final enriched = withTimestamps(
        payload,
        isCreate: true,
        createdField: createdField,
        updatedField: updatedField,
        legacyCreatedField: legacyCreatedField,
        legacyUpdatedField: legacyUpdatedField,
      );
      final safe = sanitize(enriched);
      return await col.add(safe);
    } catch (e) {
      throw AppFriendlyException.from(e);
    }
  }

  /// Escrita de create (set) em um DocumentReference com timestamps + sanitização.
  ///
  /// Útil quando você quer controlar o ID do doc (ex: ref = col.doc()).
  static Future<void> create(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> payload, {
    String createdField = 'createdAt',
    String updatedField = 'updatedAt',
    String? legacyCreatedField,
    String? legacyUpdatedField,
  }) async {
    try {
      final enriched = withTimestamps(
        payload,
        isCreate: true,
        createdField: createdField,
        updatedField: updatedField,
        legacyCreatedField: legacyCreatedField,
        legacyUpdatedField: legacyUpdatedField,
      );
      final safe = sanitize(enriched);
      await ref.set(safe, SetOptions(merge: false));
    } catch (e) {
      throw AppFriendlyException.from(e);
    }
  }

  /// Delete blindado.
  static Future<void> delete(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      await ref.delete();
    } catch (e) {
      throw AppFriendlyException.from(e);
    }
  }

  /// Escrita de update com timestamps + sanitização.
  static Future<void> update(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> payload, {
    String updatedField = 'updatedAt',
    String? legacyUpdatedField,
  }) async {
    try {
      if (payload.isEmpty) return;
      final enriched = withTimestamps(
        payload,
        isCreate: false,
        updatedField: updatedField,
        legacyUpdatedField: legacyUpdatedField,
      );
      final safe = sanitize(enriched);
      await ref.update(safe);
    } catch (e) {
      throw AppFriendlyException.from(e);
    }
  }

  /// set(merge) com sanitização.
  static Future<void> set(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> payload, {
    bool merge = true,
  }) async {
    try {
      final safe = sanitize(payload);
      await ref.set(safe, SetOptions(merge: merge));
    } catch (e) {
      throw AppFriendlyException.from(e);
    }
  }
}

/// Exception já “pronta pra UI”.
class AppFriendlyException implements Exception {
  final String message;
  final Object? original;

  AppFriendlyException(this.message, {this.original});

  @override
  String toString() => message;

  static AppFriendlyException from(Object e) {
    // Firebase
    if (e is FirebaseException) {
      final code = e.code;
      switch (code) {
        case 'permission-denied':
          return AppFriendlyException(
            'Sem permissão pra gravar/ler esses dados. (permission-denied)',
            original: e,
          );
        case 'unavailable':
          return AppFriendlyException(
            'Firebase indisponível agora. Tenta de novo em instantes. (unavailable)',
            original: e,
          );
        case 'deadline-exceeded':
          return AppFriendlyException(
            'A operação demorou demais e foi cancelada. Tenta de novo. (deadline-exceeded)',
            original: e,
          );
        case 'not-found':
          return AppFriendlyException('Registro não encontrado. (not-found)',
              original: e);
        case 'already-exists':
          return AppFriendlyException(
              'Esse registro já existe. (already-exists)',
              original: e);
        case 'invalid-argument':
          return AppFriendlyException(
            'Dados inválidos pra salvar. Confere os campos e tenta de novo. (invalid-argument)',
            original: e,
          );
        default:
          return AppFriendlyException(
            e.message ?? 'Erro no Firebase ($code).',
            original: e,
          );
      }
    }

    // Sanitizer / ArgumentError etc
    if (e is ArgumentError) {
      return AppFriendlyException(e.message.toString(), original: e);
    }
    if (e is UnsupportedError) {
      return AppFriendlyException(
          e.message ?? 'Tipo não suportado para salvar.',
          original: e);
    }

    // Fallback
    return AppFriendlyException(e.toString(), original: e);
  }
}
