import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FirestoreSanitizer {
  static Map<String, dynamic> sanitizeMap(Map<String, dynamic> map) {
    final v = _sanitize(map, r'$');
    return v as Map<String, dynamic>;
  }

  static dynamic _sanitize(dynamic value, String path) {
    if (value == null) return null;

    // Tipos OK
    if (value is String || value is bool || value is int) return value;

    if (value is double) {
      if (value.isNaN || value.isInfinite) {
        throw ArgumentError(
            'Firestore: double inválido em $path (NaN/Infinity).');
      }
      return value;
    }

    if (value is num) {
      final d = value.toDouble();
      if (d.isNaN || d.isInfinite) {
        throw ArgumentError('Firestore: num inválido em $path (NaN/Infinity).');
      }
      // mantém num como double pra Firestore ficar feliz
      return d;
    }

    if (value is Timestamp ||
        value is GeoPoint ||
        value is FieldValue ||
        value is DocumentReference) {
      return value;
    }

    // Conversões seguras
    if (value is DateTime) return Timestamp.fromDate(value);

    if (value is TimeOfDay) {
      final hh = value.hour.toString().padLeft(2, '0');
      final mm = value.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    if (value is Enum) return value.name;

    // Coleções
    if (value is List) {
      return value.asMap().entries.map((e) {
        return _sanitize(e.value, '$path[${e.key}]');
      }).toList();
    }

    if (value is Map) {
      final out = <String, dynamic>{};
      for (final entry in value.entries) {
        final k = entry.key;
        if (k is! String) {
          throw ArgumentError(
              'Firestore: chave não String em $path -> "$k" (${k.runtimeType})');
        }
        out[k] = _sanitize(entry.value, '$path.$k');
      }
      return out;
    }

    // Se cair aqui: ACHAMOS O VILÃO
    throw UnsupportedError(
      'Firestore: tipo NÃO suportado em $path -> ${value.runtimeType}. '
      'Converta para String/num/bool/Timestamp/Map/List antes de salvar.',
    );
  }
}
