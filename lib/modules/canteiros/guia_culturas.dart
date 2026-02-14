// lib/modules/canteiros/guia_culturas.dart
//
// Guia “completo” (bem parrudo) pra:
// - TelaPlanejamentoCanteiro (calendarioRegional, buscarCulturas, getCulturaInfo)
// - TelaDetalhesCanteiro (guiaCompleto: Map com todos os detalhes)

class CulturaInfo {
  final String nome;
  final String categoria;
  final int cicloDias;

  /// Distância entre linhas (m)
  final double espacamentoLinhaM;

  /// Distância entre plantas (m)
  final double espacamentoPlantaM;

  // Extras (pra detalhes e futuras telas)
  final double? profundidadeCm;
  final String? luminosidade;
  final String? irrigacao;
  final String? adubacao;
  final String? pragas;
  final String? observacoes;
  
  // ✅ Adicionado as propriedades de consórcio / alelopatia
  final List<String> companheiras;
  final List<String> evitar;

  const CulturaInfo({
    required this.nome,
    required this.categoria,
    required this.cicloDias,
    required this.espacamentoLinhaM,
    required this.espacamentoPlantaM,
    this.profundidadeCm,
    this.luminosidade,
    this.irrigacao,
    this.adubacao,
    this.pragas,
    this.observacoes,
    this.companheiras = const [], // Valor padrão vazio
    this.evitar = const [],       // Valor padrão vazio
  });

  /// Estimativa simples: área / (espacamentoLinha * espacamentoPlanta)
  int estimarQtdPlantasPorArea(double areaM2) {
    if (areaM2 <= 0) return 0;
    final areaPorPlanta = espacamentoLinhaM * espacamentoPlantaM;
    if (areaPorPlanta <= 0) return 0;
    final qtd = (areaM2 / areaPorPlanta).floor();
    return qtd < 0 ? 0 : qtd;
  }

  factory CulturaInfo.fromMap(String nome, Map<String, dynamic> m) {
    double _d(dynamic v, double def) {
      if (v == null) return def;
      if (v is num) return v.toDouble();
      final s = v.toString().trim().replaceAll(',', '.');
      return double.tryParse(s) ?? def;
    }

    int _i(dynamic v, int def) {
      if (v == null) return def;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? def;
    }

    List<String> _list(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return [];
    }

    return CulturaInfo(
      nome: nome,
      categoria: (m['categoria'] ?? 'Hortaliça').toString(),
      cicloDias: _i(m['ciclo_dias'], 60),
      espacamentoLinhaM: _d(m['espacamento_linha_m'], 0.30),
      espacamentoPlantaM: _d(m['espacamento_planta_m'], 0.30),
      profundidadeCm: m['profundidade_cm'] == null ? null : _d(m['profundidade_cm'], 0),
      luminosidade: m['luminosidade']?.toString(),
      irrigacao: m['irrigacao']?.toString(),
      adubacao: m['adubacao']?.toString(),
      pragas: m['pragas']?.toString(),
      observacoes: m['observacoes']?.toString(),
      companheiras: _list(m['companheiras']), // ✅ Carregando do mapa
      evitar: _list(m['evitar']),             // ✅ Carregando do mapa
    );
  }
}

/// Estrutura: nomeDaCultura -> mapa de detalhes.
final Map<String, Map<String, dynamic>> guiaCompleto = {
  'Alface': {
    'categoria': 'Folhosa',
    'ciclo_dias': 45,
    'espacamento_linha_m': 0.30,
    'espacamento_planta_m': 0.25,
    'profundidade_cm': 0.5,
    'luminosidade': 'Sol pleno a meia sombra',
    'irrigacao': 'Frequente, manter solo úmido sem encharcar',
    'adubacao': 'Rico em matéria orgânica; reforço leve a cada 15 dias',
    'pragas': 'Pulgões, lesmas, lagartas',
    'observacoes': 'Prefere clima ameno. No calor forte, pode pendoar (subir flor).',
    'companheiras': ['Alho', 'Alho poró', 'Batata', 'Cebola', 'Cenoura', 'Rabanete'],
    'evitar': ['Beterraba', 'Couve', 'Nabo'],
  },
  'Rúcula': {
    'categoria': 'Folhosa',
    'ciclo_dias': 35,
    'espacamento_linha_m': 0.25,
    'espacamento_planta_m': 0.15,
    'profundidade_cm': 0.5,
    'luminosidade': 'Sol pleno',
    'irrigacao': 'Regular, sem encharcar',
    'adubacao': 'Composto + cobertura leve',
    'pragas': 'Pulgões, vaquinhas, lagartas',
    'observacoes': 'Cresce rápido. Colheita pode ser por corte.',
    'companheiras': ['Alho', 'Alho poró', 'Cebola', 'Espinafre'],
    'evitar': ['Abóbora', 'Cenoura', 'Feijão', 'Melão', 'Pepino', 'Tomate'],
  },
  'Couve': {
    'categoria': 'Folhosa',
    'ciclo_dias': 90,
    'espacamento_linha_m': 0.70,
    'espacamento_planta_m': 0.50,
    'profundidade_cm': 1.0,
    'luminosidade': 'Sol pleno',
    'irrigacao': 'Regular',
    'adubacao': 'Responde bem a nitrogênio (sem exagero)',
    'pragas': 'Lagarta da couve, pulgões',
    'observacoes': 'Colheita contínua por folhas.',
    'companheiras': ['Alho', 'Alho poró', 'Cebola', 'Espinafre'],
    'evitar': ['Abóbora', 'Cenoura', 'Feijão', 'Melão', 'Pepino', 'Tomate'],
  },
  'Espinafre': {
    'categoria': 'Folhosa',
    'ciclo_dias': 45,
    'espacamento_linha_m': 0.25,
    'espacamento_planta_m': 0.15,
    'profundidade_cm': 1.0,
    'luminosidade': 'Sol pleno a meia sombra',
    'irrigacao': 'Regular',
    'adubacao': 'Composto + cobertura leve',
    'pragas': 'Pulgões, lesmas',
    'observacoes': 'Gosta de clima ameno.',
    'companheiras': ['Couve', 'Rúcula', 'Repolho', 'Brócolis', 'Pepino', 'Abobrinha'],
    'evitar': [],
  },
  'Repolho': {
    'categoria': 'Brássica',
    'ciclo_dias': 110,
    'espacamento_linha_m': 0.60,
    'espacamento_planta_m': 0.50,
    'profundidade_cm': 1.0,
    'luminosidade': 'Sol pleno',
    'irrigacao': 'Regular',
    'adubacao': 'Boa base orgânica + cobertura no pegamento',
    'pragas': 'Lagartas, pulgões',
    'observacoes': 'Clima ameno ajuda a formar cabeças melhores.',
    'companheiras': ['Alho', 'Alho poró', 'Cebola', 'Espinafre'],
    'evitar': ['Abóbora', 'Cenoura', 'Feijão', 'Melão', 'Pepino', 'Tomate'],
  },
  'Brócolis': {
    'categoria': 'Brássica',
    'ciclo_dias': 90,
    'espacamento_linha_m': 0.70,
    'espacamento_planta_m': 0.50,
    'profundidade_cm': 1.0,
    'luminosidade': 'Sol pleno',
    'irrigacao': 'Regular',
    'adubacao': 'Composto + reforço leve (K/Ca ajuda)',
    'pragas': 'Lagartas, pulgões',
    'observacoes': 'Prefere clima ameno.',
    'companheiras': ['Alho', 'Alho poró', 'Cebola', 'Espinafre'],
    'evitar': ['Abóbora', 'Cenoura', 'Feijão', 'Melão', 'Pepino', 'Tomate'],
  },
  'Couve-flor': {
    'categoria': 'Brássica',
    'ciclo_dias': 110,
    'espacamento_linha_m': 0.70,
    'espacamento_planta_m': 0.60,
    'profundidade_cm': 1.0,
    'luminosidade': 'Sol pleno',
    'irrigacao': 'Regular',
    'adubacao': 'Rico em matéria orgânica',
    'pragas': 'Lagartas, pulgões',
    'observacoes': 'Exige mais regularidade de água.',
    'companheiras': ['Alho', 'Alho poró', 'Cebola', 'Espinafre'],
    'evitar': ['Abóbora', 'Cenoura', 'Feijão', 'Melão', 'Pepino', 'Tomate'],
  },
  'Cebolinha': {
    'categoria': 'Temperos',
    'ciclo_dias': 80,
    'espacamento_linha_m': 0.25,
    'espacamento_planta_m': 0.10,
    'profundidade_cm': 1.0,
    'luminosidade': 'Sol pleno a meia sombra',
    'irrigacao': 'Regular',
    'adubacao': 'Composto + cobertura mensal',
    'pragas': 'Trips',
    'observacoes': 'Pode ser replantada por touceira.',
    'companheiras': ['Couve', 'Repolho', 'Brócolis', 'Tomate', 'Alface', 'Pepino'],
    'evitar': ['Ervilha', 'Feijão', 'Vagem'],
  },
  'Salsinha': {
    'categoria': 'Temperos',
    'ciclo_dias': 90,
    'espacamento_linha_m': 0.25,
    'espacamento_planta_m': 0.15,
    'profundidade_cm': 1.0,
    'luminosidade': 'Sol pleno a meia sombra',
    'irrigacao': 'Regular',
    'adubacao': 'Composto + cobertura leve',
    'pragas': 'Pulgões',
    'observacoes': 'Germinação pode ser lenta.',
    'companheiras': ['Milho', 'Tomate'],
    'evitar': ['Cenoura', 'Coentro'],
  },
  'Coentro': {
    'categoria': 'Temperos',
    'ciclo_dias': 40,
    'espacamento_linha_m': 0.25,
    'espacamento_planta_m': 0.10,
    'profundidade_cm': 1.0,
    'luminosidade': 'Sol pleno',
    'irrigacao': 'Regular',
    'adubacao': 'Leve',
    'pragas': 'Pulgões',
    'observacoes': 'No calor, pendoa rápido.',
    'companheiras': ['Milho', 'Tomate'],
    'evitar': ['Cenoura', 'Salsinha'],
  },
  'Manjericão': {
    'categoria': 'Temperos',
    'ciclo_dias': 70,
    'espacamento_linha_m': 0.40,
    'espacamento_planta_m': 0.35,
    'profundidade_cm': 0.5,
    'luminosidade': 'Sol pleno',
    'irrigacao': 'Regular',
    'adubacao': 'Composto + cobertura leve',
    'pragas': 'Pulgões',
    'observacoes': 'Podas frequentes aumentam produção.',
    'companheiras': ['Tomate', 'Pimentão'],
    'evitar': ['Ruda'],
  },
  'Hortelã': {
    'categoria': 'Temperos',
    'ciclo_dias': 60,
    'espacamento_linha_m': 0.40,
    'espacamento_planta_m': 0.30,
    'profundidade_cm': 0.5,
    'luminosidade': 'Meia sombra a sol',
    'irrigacao': 'Gosta de umidade',
    'adubacao': 'Composto',
    'pragas': 'Pulgões',
    'observacoes': 'Se espalha rápido (controlar).',
    'companheiras': ['Couve', 'Tomate'],
    'evitar': [],
  },
  'Tomate': {
    'categoria': 'Frutífera',
    'ciclo_dias': 110,
    'espacamento_linha_m': 1.00,
    'espacamento_planta_m': 0.60,
    'profundidade_cm': 1.0,
    'luminosidade': 'Sol pleno',
    'irrigacao': 'Regular (evitar molhar folhas)',
    'adubacao': 'Mais exigente: composto + reforços (K/Ca)',
    'pragas': 'Traça, mosca-branca, requeima',
    'observacoes': 'Tutoramento ajuda muito. Ventilação evita fungos.',
    'companheiras': ['Abóbora', 'Melão', 'Pepino', 'Alho', 'Cebola', 'Manjericão'],
    'evitar': ['Batata', 'Berinjela', 'Pimentão', 'Pimenta', 'Jiló'],
  },
  'Pimentão': {
    'categoria': 'Frutífera',
    'ciclo_dias': 120,
    'espacamento_linha_m': 0.80,
    'espacamento_planta_m': 0.50,
    'profundidade_cm': 1.0,
    'luminosidade': 'Sol pleno',
    'irrigacao': 'Regular',
    'adubacao': 'Composto + reforço na floração',
    'pragas': 'Pulgões, trips, ácaros',
    'observacoes': 'Prefere calor moderado.',
    'companheiras': ['Abóbora', 'Melão', 'Pepino', 'Alho', 'Cebola', 'Manjericão'],
    'evitar': ['Batata', 'Berinjela', 'Tomate', 'Pimenta', 'Jiló'],
  },
  'Berinjela': {
    'categoria': 'Frutífera',
    'ciclo_dias': 120,
    'espacamento_linha_m': 1.00,
    'espacamento_planta_m': 0.70,
    'profundidade_cm': 1.0,
    'luminosidade': 'Sol pleno',
    'irrigacao': 'Regular',
    'adubacao': 'Boa base orgânica',
    'pragas': 'Pulgões, brocas',
    'observacoes': 'Calor ajuda. Tutoramento melhora.',
    'companheiras': ['Abóbora', 'Melão', 'Pepino', 'Alho', 'Cebola'],
    'evitar': ['Batata', 'Tomate', 'Pimentão', 'Pimenta', 'Jiló'],
  },
  'Pepino': {
    'categoria': 'Cucurbitácea',
    'ciclo_dias': 70,
    'espacamento_linha_m': 1.20,
    'espacamento_planta_m': 0.50,
    'profundidade_cm': 2.0,
    'luminosidade': 'Sol pleno',
    'irrigacao': 'Frequente',
    'adubacao': 'Composto + reforço no pegamento',
    'pragas': 'Oídio, pulgões',
    'observacoes': 'Treliça ajuda muito e economiza espaço.',
    'companheiras': ['Alho', 'Alho poró', 'Cebola', 'Espinafre'],
    'evitar': ['Beterraba', 'Milho', 'Abóbora', 'Melancia', 'Melão'],
  },
  'Abobrinha': {
    'categoria': 'Cucurbitácea',
    'ciclo_dias': 80,
    'espacamento_linha_m': 1.50,
    'espacamento_planta_m': 1.00,
    'profundidade_cm': 2.0,
    'luminosidade': 'Sol pleno',
    'irrigacao': 'Regular',
    'adubacao': 'Boa base orgânica',
    'pragas': 'Oídio, brocas',
    'observacoes': 'Ocupa espaço. Melhor em canteiro maior.',
    'companheiras': ['Alho', 'Alho poró', 'Cebola', 'Espinafre', 'Milho', 'Feijão'],
    'evitar': ['Beterraba', 'Abóbora', 'Melancia', 'Melão'],
  },
  'Cenoura': {
    'categoria': 'Raiz',
    'ciclo_dias': 90,
    'espacamento_linha_m': 0.25,
    'espacamento_planta_m': 0.07,
    'profundidade_cm': 1.0,
    'luminosidade': 'Sol pleno',
    'irrigacao': 'Regular',
    'adubacao': 'Solo fofo e bem curtido (evitar esterco fresco)',
    'pragas': 'Mosca-da-cenoura',
    'observacoes': 'Solo muito pesado entorta a raiz.',
    'companheiras': ['Milho', 'Alface', 'Cebola', 'Alho'],
    'evitar': ['Coentro', 'Salsinha'],
  },
  'Beterraba': {
    'categoria': 'Raiz',
    'ciclo_dias': 75,
    'espacamento_linha_m': 0.30,
    'espacamento_planta_m': 0.10,
    'profundidade_cm': 1.5,
    'luminosidade': 'Sol pleno',
    'irrigacao': 'Regular',
    'adubacao': 'Composto + leve reforço',
    'pragas': 'Pulgões',
    'observacoes': 'Clima ameno ajuda.',
    'companheiras': ['Cebola', 'Couve-rábano', 'Alho'],
    'evitar': ['Alface', 'Tomate', 'Feijão'],
  },
  'Quiabo': {
    'categoria': 'Frutífera',
    'ciclo_dias': 110,
    'espacamento_linha_m': 1.00,
    'espacamento_planta_m': 0.50,
    'profundidade_cm': 2.0,
    'luminosidade': 'Sol pleno',
    'irrigacao': 'Regular',
    'adubacao': 'Composto',
    'pragas': 'Pulgões',
    'observacoes': 'Gosta de calor.',
    'companheiras': ['Melancia', 'Abóbora', 'Batata doce'],
    'evitar': [],
  },
  'Milho verde': {
    'categoria': 'Grão',
    'ciclo_dias': 100,
    'espacamento_linha_m': 0.80,
    'espacamento_planta_m': 0.25,
    'profundidade_cm': 3.0,
    'luminosidade': 'Sol pleno',
    'irrigacao': 'Regular',
    'adubacao': 'Exige N (matéria orgânica ajuda)',
    'pragas': 'Lagarta do cartucho',
    'observacoes': 'Plantio em bloco melhora polinização.',
    'companheiras': ['Feijão', 'Abóbora', 'Pepino', 'Melancia', 'Vagem'],
    'evitar': ['Tomate'],
  },
  'Feijão vagem': {
    'categoria': 'Leguminosa',
    'ciclo_dias': 70,
    'espacamento_linha_m': 0.50,
    'espacamento_planta_m': 0.15,
    'profundidade_cm': 3.0,
    'luminosidade': 'Sol pleno',
    'irrigacao': 'Regular',
    'adubacao': 'Boa base orgânica',
    'pragas': 'Pulgões, vaquinhas',
    'observacoes': 'Se trepador, use suporte.',
    'companheiras': ['Mandioca', 'Milho', 'Abóbora'],
    'evitar': ['Cebola', 'Alho', 'Alho-poró'],
  },
};

final Map<String, Map<String, List<String>>> calendarioRegional = {
  'Norte': {
    'Janeiro': ['Quiabo', 'Pepino', 'Abobrinha', 'Coentro', 'Cebolinha'],
    'Fevereiro': ['Quiabo', 'Pepino', 'Abobrinha', 'Coentro', 'Cebolinha'],
    'Março': ['Tomate', 'Pimentão', 'Pepino', 'Couve'],
    'Abril': ['Couve', 'Repolho', 'Brócolis', 'Cebolinha'],
    'Maio': ['Repolho', 'Brócolis', 'Couve-flor', 'Cenoura', 'Beterraba'],
    'Junho': ['Repolho', 'Brócolis', 'Cenoura', 'Beterraba', 'Alface'],
    'Julho': ['Alface', 'Rúcula', 'Couve', 'Cebolinha', 'Salsinha'],
    'Agosto': ['Alface', 'Rúcula', 'Couve', 'Tomate', 'Pimentão'],
    'Setembro': ['Tomate', 'Pimentão', 'Berinjela', 'Pepino'],
    'Outubro': ['Pepino', 'Abobrinha', 'Quiabo', 'Milho verde'],
    'Novembro': ['Milho verde', 'Feijão vagem', 'Quiabo', 'Coentro'],
    'Dezembro': ['Quiabo', 'Pepino', 'Abobrinha', 'Coentro', 'Cebolinha'],
  },
  'Nordeste': {
    'Janeiro': ['Quiabo', 'Pepino', 'Abobrinha', 'Coentro'],
    'Fevereiro': ['Quiabo', 'Pepino', 'Abobrinha', 'Coentro'],
    'Março': ['Tomate', 'Pimentão', 'Berinjela', 'Couve'],
    'Abril': ['Couve', 'Repolho', 'Brócolis', 'Cebolinha'],
    'Maio': ['Repolho', 'Brócolis', 'Couve-flor', 'Cenoura'],
    'Junho': ['Alface', 'Rúcula', 'Couve', 'Beterraba'],
    'Julho': ['Alface', 'Rúcula', 'Espinafre', 'Salsinha'],
    'Agosto': ['Tomate', 'Pimentão', 'Pepino', 'Cebolinha'],
    'Setembro': ['Tomate', 'Pimentão', 'Berinjela', 'Pepino'],
    'Outubro': ['Pepino', 'Abobrinha', 'Quiabo', 'Milho verde'],
    'Novembro': ['Milho verde', 'Feijão vagem', 'Quiabo', 'Coentro'],
    'Dezembro': ['Quiabo', 'Pepino', 'Abobrinha', 'Coentro'],
  },
  'Centro-Oeste': {
    'Janeiro': ['Quiabo', 'Pepino', 'Abobrinha', 'Coentro'],
    'Fevereiro': ['Quiabo', 'Pepino', 'Abobrinha', 'Coentro'],
    'Março': ['Tomate', 'Pimentão', 'Couve'],
    'Abril': ['Couve', 'Repolho', 'Brócolis', 'Cebolinha'],
    'Maio': ['Repolho', 'Brócolis', 'Cenoura', 'Beterraba'],
    'Junho': ['Alface', 'Rúcula', 'Espinafre', 'Salsinha'],
    'Julho': ['Alface', 'Rúcula', 'Repolho', 'Brócolis'],
    'Agosto': ['Alface', 'Rúcula', 'Tomate', 'Pimentão'],
    'Setembro': ['Tomate', 'Pimentão', 'Berinjela', 'Pepino'],
    'Outubro': ['Pepino', 'Abobrinha', 'Milho verde'],
    'Novembro': ['Milho verde', 'Feijão vagem', 'Quiabo'],
    'Dezembro': ['Quiabo', 'Pepino', 'Abobrinha', 'Coentro'],
  },
  'Sudeste': {
    'Janeiro': ['Alface', 'Rúcula', 'Cebolinha', 'Coentro', 'Pepino'],
    'Fevereiro': ['Alface', 'Rúcula', 'Cebolinha', 'Pepino', 'Abobrinha'],
    'Março': ['Couve', 'Repolho', 'Brócolis', 'Cenoura', 'Beterraba'],
    'Abril': ['Repolho', 'Brócolis', 'Couve-flor', 'Cenoura', 'Beterraba'],
    'Maio': ['Alface', 'Rúcula', 'Espinafre', 'Couve', 'Salsinha'],
    'Junho': ['Alface', 'Rúcula', 'Repolho', 'Brócolis', 'Couve-flor'],
    'Julho': ['Alface', 'Rúcula', 'Repolho', 'Brócolis', 'Cenoura'],
    'Agosto': ['Tomate', 'Pimentão', 'Berinjela', 'Cebolinha'],
    'Setembro': ['Tomate', 'Pimentão', 'Pepino', 'Feijão vagem'],
    'Outubro': ['Pepino', 'Abobrinha', 'Milho verde', 'Quiabo'],
    'Novembro': ['Milho verde', 'Feijão vagem', 'Quiabo', 'Coentro'],
    'Dezembro': ['Alface', 'Rúcula', 'Cebolinha', 'Pepino', 'Quiabo'],
  },
  'Sul': {
    'Janeiro': ['Alface', 'Rúcula', 'Cebolinha', 'Pepino'],
    'Fevereiro': ['Alface', 'Rúcula', 'Pepino', 'Abobrinha'],
    'Março': ['Couve', 'Repolho', 'Brócolis', 'Cenoura', 'Beterraba'],
    'Abril': ['Repolho', 'Brócolis', 'Couve-flor', 'Cenoura'],
    'Maio': ['Repolho', 'Brócolis', 'Alface', 'Rúcula', 'Espinafre'],
    'Junho': ['Alface', 'Rúcula', 'Espinafre', 'Couve'],
    'Julho': ['Alface', 'Rúcula', 'Repolho', 'Brócolis'],
    'Agosto': ['Alface', 'Rúcula', 'Cenoura', 'Beterraba'],
    'Setembro': ['Tomate', 'Pimentão', 'Cebolinha'],
    'Outubro': ['Tomate', 'Pimentão', 'Pepino', 'Feijão vagem'],
    'Novembro': ['Pepino', 'Abobrinha', 'Milho verde'],
    'Dezembro': ['Alface', 'Rúcula', 'Pepino', 'Abobrinha'],
  },
};

List<String> culturasPorRegiaoMes(String regiao, String mes) {
  final m = calendarioRegional[regiao];
  if (m == null) return [];
  final list = m[mes] ?? [];
  final seen = <String>{};
  final out = <String>[];
  for (final c in list) {
    if (seen.add(c)) out.add(c);
  }
  return out;
}

CulturaInfo? getCulturaInfo(String nome) {
  final resolved = _resolveNomeCultura(nome);
  if (resolved == null) return null;
  final data = guiaCompleto[resolved];
  if (data == null) return null;
  return CulturaInfo.fromMap(resolved, data);
}

List<String> buscarCulturas(String query) {
  final q = _norm(query);
  final all = guiaCompleto.keys.toList()..sort((a, b) => a.compareTo(b));

  if (q.isEmpty) return all;

  final matches = <String>[];
  for (final nome in all) {
    final n = _norm(nome);
    if (n.contains(q)) matches.add(nome);
  }
  return matches;
}

String? _resolveNomeCultura(String nome) {
  final alvo = _norm(nome);
  if (alvo.isEmpty) return null;

  for (final k in guiaCompleto.keys) {
    if (_norm(k) == alvo) return k;
  }

  for (final k in guiaCompleto.keys) {
    if (_norm(k).contains(alvo)) return k;
  }

  return null;
}

String _norm(String s) {
  var t = s.trim().toLowerCase();
  t = t.replaceAll(RegExp(r'[áàâãä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòôõö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll(RegExp(r'[ç]'), 'c');
  t = t.replaceAll(RegExp(r'\s+'), ' ');
  return t;
}