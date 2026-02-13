/// BaseAgronomica
/// Núcleo do “cérebro” de cálculo (Organo15).
///
/// - CANTEIROS: doses em g/m²
/// - VASOS: doses em g/L de mistura final
///
/// Observação: este arquivo mantém compatibilidade com chamadas antigas
/// retornando Map<String, double>. Porém agora também oferece resultados tipados.
///
/// Fonte (conforme seu comentário):
/// - Canteiros: páginas 30 e 31 do e-book Organo15
/// - Vasos: página 64 do e-book Organo15
class BaseAgronomica {
  BaseAgronomica._(); // impede instância (core puro)

  // ---------------------------------------------------------------------------
  // CONSTANTES PARA CANTEIROS (g/m²)
  // ---------------------------------------------------------------------------
  static const double DOSE_PADRAO_CALCARIO_M2 = 200.0;
  static const double DOSE_PADRAO_TERMOFOSFATO_M2 = 150.0;
  static const double DOSE_PADRAO_GESSO_M2 = 200.0;

  // Doses de Adubo Orgânico para Canteiros (g/m²)
  static const double DOSE_ESTERCO_BOVINO_M2 = 3000.0; // 3 kg/m²
  static const double DOSE_ESTERCO_GALINHA_M2 = 1000.0; // 1 kg/m²
  static const double DOSE_BOKASHI_M2 = 1000.0; // 1 kg/m²
  static const double DOSE_MAMONA_M2 = 300.0; // 300 g/m²

  // Ajuste para solo argiloso (calcário + termofosfato)
  static const double FATOR_SOLO_ARGILOSO = 1.25;

  // ---------------------------------------------------------------------------
  // CONSTANTES PARA VASOS (g/Litro de mistura final)
  // ---------------------------------------------------------------------------
  static const double DOSE_CALCARIO_POR_LITRO_MISTURA = 2.0;
  static const double DOSE_TERMOFOSFATO_POR_LITRO_MISTURA = 10.0;

  // ---------------------------------------------------------------------------
  // API “premium”: enum para tipo de adubo (evita string errada)
  // ---------------------------------------------------------------------------
  static TipoAduboOrganico tipoFromKey(String key) {
    final k = key.trim().toLowerCase();

    // Normalizações comuns (usuário digita de todo jeito…)
    if (k.contains('bov')) return TipoAduboOrganico.bovino;
    if (k.contains('comp')) return TipoAduboOrganico.composto;
    if (k.contains('gali') || k.contains('avi'))
      return TipoAduboOrganico.galinha;
    if (k.contains('boka')) return TipoAduboOrganico.bokashi;
    if (k.contains('mamo')) return TipoAduboOrganico.mamona;

    // fallback padrão
    return TipoAduboOrganico.bovino;
  }

  // ---------------------------------------------------------------------------
  // Cálculo tipado (recomendado)
  // ---------------------------------------------------------------------------

  /// CANTEIRO (Solo)
  /// - areaM2: área do canteiro
  /// - isSoloArgiloso: se true, aplica +25% em calcário e termofosfato
  /// - tipoAduboOrganico: enum (preferível)
  /// - strict: se true, lança erro em entradas inválidas (<=0)
  static ResultadoAdubacaoCanteiro calcularAdubacaoCanteiroTyped({
    required double areaM2,
    required bool isSoloArgiloso,
    required TipoAduboOrganico tipoAduboOrganico,
    bool strict = false,
    bool incluirGesso = true,
  }) {
    final area = _sanitizePositive(areaM2, strict: strict);
    if (area == 0) {
      return const ResultadoAdubacaoCanteiro.zero();
    }

    final fatorSolo = isSoloArgiloso ? FATOR_SOLO_ARGILOSO : 1.0;

    final calcario = (DOSE_PADRAO_CALCARIO_M2 * area) * fatorSolo;
    final termofosfato = (DOSE_PADRAO_TERMOFOSFATO_M2 * area) * fatorSolo;

    final gesso = incluirGesso ? (DOSE_PADRAO_GESSO_M2 * area) : 0.0;

    final aduboOrganico = switch (tipoAduboOrganico) {
      TipoAduboOrganico.galinha => DOSE_ESTERCO_GALINHA_M2 * area,
      TipoAduboOrganico.bokashi => DOSE_BOKASHI_M2 * area,
      TipoAduboOrganico.mamona => DOSE_MAMONA_M2 * area,
      // composto cai na dose do bovino (mesma base)
      TipoAduboOrganico.bovino ||
      TipoAduboOrganico.composto => DOSE_ESTERCO_BOVINO_M2 * area,
    };

    return ResultadoAdubacaoCanteiro(
      calcario: _nonNeg(calcario),
      termofosfato: _nonNeg(termofosfato),
      aduboOrganico: _nonNeg(aduboOrganico),
      gesso: _nonNeg(gesso),
    );
  }

  /// VASO (mistura/substrato)
  /// - volumeVasoLitros: volume total do vaso (litros)
  /// - tipoAdubo: enum (preferível)
  /// - strict: se true, lança erro em entradas inválidas (<=0)
  static ResultadoMisturaVaso calcularMisturaVasoTyped({
    required double volumeVasoLitros,
    required TipoAduboOrganico tipoAdubo,
    bool strict = false,
  }) {
    final vol = _sanitizePositive(volumeVasoLitros, strict: strict);
    if (vol == 0) return const ResultadoMisturaVaso.zero();

    final (partesTerra, partesAdubo) = _proporcaoVaso(tipoAdubo);

    final totalPartes = partesTerra + partesAdubo;
    if (totalPartes <= 0) return const ResultadoMisturaVaso.zero();

    final litrosTerra = (vol * partesTerra) / totalPartes;
    final litrosAdubo = (vol * partesAdubo) / totalPartes;

    final gramasCalcario = DOSE_CALCARIO_POR_LITRO_MISTURA * vol;
    final gramasTermofosfato = DOSE_TERMOFOSFATO_POR_LITRO_MISTURA * vol;

    return ResultadoMisturaVaso(
      terraLitros: _nonNeg(litrosTerra),
      aduboLitros: _nonNeg(litrosAdubo),
      calcarioGramas: _nonNeg(gramasCalcario),
      termofosfatoGramas: _nonNeg(gramasTermofosfato),
    );
  }

  // ---------------------------------------------------------------------------
  // Compatibilidade (API antiga) — mantém seu app funcionando SEM mexer em nada
  // ---------------------------------------------------------------------------

  /// Mantido para compatibilidade: retorna Map com gramas (g)
  /// tipoAduboOrganico esperado: 'bovino', 'galinha', 'bokashi', 'mamona', 'composto'
  static Map<String, double> calcularAdubacaoCanteiro({
    required double areaM2,
    required bool isSoloArgiloso,
    required String tipoAduboOrganico,
    bool strict = false,
    bool incluirGesso = true,
  }) {
    final tipo = tipoFromKey(tipoAduboOrganico);
    return calcularAdubacaoCanteiroTyped(
      areaM2: areaM2,
      isSoloArgiloso: isSoloArgiloso,
      tipoAduboOrganico: tipo,
      strict: strict,
      incluirGesso: incluirGesso,
    ).toMap();
  }

  /// Mantido para compatibilidade: retorna Map com Litros e Gramas
  static Map<String, double> calcularMisturaVaso({
    required double volumeVasoLitros,
    required String tipoAdubo,
    bool strict = false,
  }) {
    final tipo = tipoFromKey(tipoAdubo);
    return calcularMisturaVasoTyped(
      volumeVasoLitros: volumeVasoLitros,
      tipoAdubo: tipo,
      strict: strict,
    ).toMap();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  static double _sanitizePositive(double value, {required bool strict}) {
    if (value.isNaN || value.isInfinite) {
      if (strict) {
        throw ArgumentError('Valor inválido: $value');
      }
      return 0.0;
    }
    if (value <= 0) {
      if (strict) {
        throw ArgumentError('Valor deve ser maior que zero: $value');
      }
      return 0.0;
    }
    return value;
  }

  static double _nonNeg(double v) => v < 0 ? 0.0 : v;

  /// Proporções de mistura para vasos:
  /// - bovino/composto: 1:1
  /// - galinha/bokashi: 3:1
  /// - mamona: 9:1
  static (double partesTerra, double partesAdubo) _proporcaoVaso(
    TipoAduboOrganico tipo,
  ) {
    return switch (tipo) {
      TipoAduboOrganico.bovino || TipoAduboOrganico.composto => (1.0, 1.0),
      TipoAduboOrganico.galinha || TipoAduboOrganico.bokashi => (3.0, 1.0),
      TipoAduboOrganico.mamona => (9.0, 1.0),
    };
  }
}

// -----------------------------------------------------------------------------
// Modelos de retorno tipados (premium)
// -----------------------------------------------------------------------------

enum TipoAduboOrganico { bovino, galinha, bokashi, mamona, composto }

extension TipoAduboOrganicoX on TipoAduboOrganico {
  String get key => switch (this) {
    TipoAduboOrganico.bovino => 'bovino',
    TipoAduboOrganico.galinha => 'galinha',
    TipoAduboOrganico.bokashi => 'bokashi',
    TipoAduboOrganico.mamona => 'mamona',
    TipoAduboOrganico.composto => 'composto',
  };

  String get label => switch (this) {
    TipoAduboOrganico.bovino => 'Esterco Bovino / Composto',
    TipoAduboOrganico.galinha => 'Esterco de Galinha',
    TipoAduboOrganico.bokashi => 'Bokashi',
    TipoAduboOrganico.mamona => 'Torta de Mamona',
    TipoAduboOrganico.composto => 'Composto Orgânico',
  };
}

class ResultadoAdubacaoCanteiro {
  final double calcario; // g
  final double termofosfato; // g
  final double aduboOrganico; // g
  final double gesso; // g

  const ResultadoAdubacaoCanteiro({
    required this.calcario,
    required this.termofosfato,
    required this.aduboOrganico,
    required this.gesso,
  });

  const ResultadoAdubacaoCanteiro.zero()
    : calcario = 0,
      termofosfato = 0,
      aduboOrganico = 0,
      gesso = 0;

  Map<String, double> toMap() => {
    'calcario': calcario,
    'termofosfato': termofosfato,
    'adubo_organico': aduboOrganico,
    'gesso': gesso,
  };
}

class ResultadoMisturaVaso {
  final double terraLitros; // L
  final double aduboLitros; // L
  final double calcarioGramas; // g
  final double termofosfatoGramas; // g

  const ResultadoMisturaVaso({
    required this.terraLitros,
    required this.aduboLitros,
    required this.calcarioGramas,
    required this.termofosfatoGramas,
  });

  const ResultadoMisturaVaso.zero()
    : terraLitros = 0,
      aduboLitros = 0,
      calcarioGramas = 0,
      termofosfatoGramas = 0;

  Map<String, double> toMap() => {
    'terra_litros': terraLitros,
    'adubo_litros': aduboLitros,
    'calcario_gramas': calcarioGramas,
    'termofosfato_gramas': termofosfatoGramas,
  };
}
