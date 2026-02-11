class BaseAgronomica {
  // --- CONSTANTES PARA CANTEIROS (g/m²) ---
  // Fontes: Páginas 30 e 31 do e-book Organo15
  static const double DOSE_PADRAO_CALCARIO_M2 = 200.0;
  static const double DOSE_PADRAO_TERMOFOSFATO_M2 = 150.0;
  static const double DOSE_PADRAO_GESSO_M2 = 200.0; //

  // Doses de Adubo Orgânico para Canteiros (g/m²)
  static const double DOSE_ESTERCO_BOVINO_M2 = 3000.0; // 3kg
  static const double DOSE_ESTERCO_GALINHA_M2 = 1000.0; // 1kg
  static const double DOSE_BOKASHI_M2 = 1000.0; // 1kg
  static const double DOSE_MAMONA_M2 = 300.0; // 300g

  // --- CONSTANTES PARA VASOS (g/Litro de Mistura Final) ---
  // Fonte: Página 64 do e-book Organo15
  static const double DOSE_CALCARIO_POR_LITRO_MISTURA = 2.0;
  static const double DOSE_TERMOFOSFATO_POR_LITRO_MISTURA = 10.0;

  /// Calcula adubação para CANTEIROS (Solo)
  /// Retorna um Map com as quantidades em Gramas (g)
  static Map<String, double> calcularAdubacaoCanteiro({
    required double areaM2,
    required bool isSoloArgiloso, // Se argiloso, +25% calcário e fosfato
    required String
        tipoAduboOrganico, // 'bovino', 'galinha', 'bokashi', 'mamona'
  }) {
    // Fator de Ajuste do Solo
    double fatorSolo = isSoloArgiloso ? 1.25 : 1.0;

    // Cálculos
    double calcario = (DOSE_PADRAO_CALCARIO_M2 * areaM2) * fatorSolo;
    double termofosfato = (DOSE_PADRAO_TERMOFOSFATO_M2 * areaM2) * fatorSolo;
    double gesso = DOSE_PADRAO_GESSO_M2 * areaM2; // Gessagem é fixa por m²

    double aduboOrganico = 0;

    switch (tipoAduboOrganico) {
      case 'galinha':
        aduboOrganico = DOSE_ESTERCO_GALINHA_M2 * areaM2;
        break;
      case 'bokashi':
        aduboOrganico = DOSE_BOKASHI_M2 * areaM2;
        break;
      case 'mamona':
        aduboOrganico = DOSE_MAMONA_M2 * areaM2;
        break;
      case 'bovino':
      default: // Composto Orgânico usa a mesma base do bovino
        aduboOrganico = DOSE_ESTERCO_BOVINO_M2 * areaM2;
        break;
    }

    return {
      "calcario": calcario,
      "termofosfato": termofosfato,
      "adubo_organico": aduboOrganico,
      "gesso": gesso,
    };
  }

  /// Calcula receita de substrato para VASOS
  /// Baseado nas proporções das páginas 62 e 63
  /// Retorna Map com Litros (substrato/adubo) e Gramas (minerais)
  static Map<String, double> calcularMisturaVaso({
    required double volumeVasoLitros,
    required String tipoAdubo,
  }) {
    double partesTerra = 0;
    double partesAdubo = 0;
    double totalPartes = 0;

    // Definição das proporções
    if (tipoAdubo == 'bovino' || tipoAdubo == 'composto') {
      // Proporção 1:1
      partesTerra = 1;
      partesAdubo = 1;
    } else if (tipoAdubo == 'galinha' || tipoAdubo == 'bokashi') {
      // Proporção 3:1
      partesTerra = 3;
      partesAdubo = 1;
    } else if (tipoAdubo == 'mamona') {
      // Proporção 9:1
      partesTerra = 9;
      partesAdubo = 1;
    }

    totalPartes = partesTerra + partesAdubo;

    // Regra de três para descobrir quanto vai de cada no volume do vaso
    double litrosTerra = (volumeVasoLitros * partesTerra) / totalPartes;
    double litrosAdubo = (volumeVasoLitros * partesAdubo) / totalPartes;

    // Minerais são calculados sobre o VOLUME TOTAL da mistura
    double gramasCalcario = DOSE_CALCARIO_POR_LITRO_MISTURA * volumeVasoLitros;
    double gramasTermofosfato =
        DOSE_TERMOFOSFATO_POR_LITRO_MISTURA * volumeVasoLitros;

    return {
      "terra_litros": litrosTerra,
      "adubo_litros": litrosAdubo,
      "calcario_gramas": gramasCalcario,
      "termofosfato_gramas": gramasTermofosfato
    };
  }
}
