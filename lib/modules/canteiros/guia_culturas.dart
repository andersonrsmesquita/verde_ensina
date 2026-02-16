// FILE: lib/modules/canteiros/guia_culturas.dart

class CulturaInfo {
  final String nome;
  final String categoria;
  final String icone; // ✅ Novo campo para o ícone visual
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

  // Consórcio / alelopatia
  final List<String> companheiras;
  final List<String> evitar;

  const CulturaInfo({
    required this.nome,
    required this.categoria,
    required this.icone, // ✅ Inserido no construtor
    required this.cicloDias,
    required this.espacamentoLinhaM,
    required this.espacamentoPlantaM,
    this.profundidadeCm,
    this.luminosidade,
    this.irrigacao,
    this.adubacao,
    this.pragas,
    this.observacoes,
    this.companheiras = const [],
    this.evitar = const [],
  });

  double get areaPorPlantaM2 => espacamentoLinhaM * espacamentoPlantaM;

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
      if (v is List) {
        return v
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList();
      }
      return const [];
    }

    return CulturaInfo(
      nome: nome,
      categoria: (m['categoria'] ?? 'Hortaliça').toString(),
      icone: (m['icone'] ?? '🌱').toString(), // ✅ Lendo o ícone do Map
      cicloDias: _i(m['ciclo_dias'], 60),
      espacamentoLinhaM: _d(m['espacamento_linha_m'], 0.30),
      espacamentoPlantaM: _d(m['espacamento_planta_m'], 0.30),
      profundidadeCm:
          m['profundidade_cm'] == null ? null : _d(m['profundidade_cm'], 0),
      luminosidade: m['luminosidade']?.toString(),
      irrigacao: m['irrigacao']?.toString(),
      adubacao: m['adubacao']?.toString(),
      pragas: m['pragas']?.toString(),
      observacoes: m['observacoes']?.toString(),
      companheiras: _list(m['companheiras']),
      evitar: _list(m['evitar']),
    );
  }
}

/// Estrutura: nomeDaCultura -> mapa de detalhes.
final Map<String, Map<String, dynamic>> guiaCompleto = {
  'Alface': {
    'categoria': 'Folhosa',
    'icone': '🥬',
    'ciclo_dias': 45,
    'espacamento_linha_m': 0.30,
    'espacamento_planta_m': 0.25,
    'profundidade_cm': 0.5,
    'luminosidade': 'Sol pleno a meia sombra',
    'irrigacao': 'Frequente, manter solo úmido sem encharcar',
    'adubacao': 'Rico em matéria orgânica; reforço leve a cada 15 dias',
    'pragas': 'Pulgões, lesmas, lagartas',
    'observacoes':
        'Prefere clima ameno. No calor forte, pode pendoar (subir flor).',
    'companheiras': [
      'Alho',
      'Alho poró',
      'Batata',
      'Cebola',
      'Cenoura',
      'Rabanete'
    ],
    'evitar': ['Beterraba', 'Couve', 'Nabo'],
  },
  'Rúcula': {
    'categoria': 'Folhosa',
    'icone': '🌿',
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
    'icone': '🥬',
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
    'icone': '🍃',
    'ciclo_dias': 45,
    'espacamento_linha_m': 0.25,
    'espacamento_planta_m': 0.15,
    'profundidade_cm': 1.0,
    'luminosidade': 'Sol pleno a meia sombra',
    'irrigacao': 'Regular',
    'adubacao': 'Composto + cobertura leve',
    'pragas': 'Pulgões, lesmas',
    'observacoes': 'Gosta de clima ameno.',
    'companheiras': [
      'Couve',
      'Rúcula',
      'Repolho',
      'Brócolis',
      'Pepino',
      'Abobrinha'
    ],
    'evitar': [],
  },
  'Repolho': {
    'categoria': 'Brássica',
    'icone': '🥬',
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
    'icone': '🥦',
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
    'icone':
        '🥦', // Couve-flor não tem emoji nativo exato, brócolis atende visualmente
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
    'icone': '🧅', // Representação mais próxima para a família das cebolas
    'ciclo_dias': 80,
    'espacamento_linha_m': 0.25,
    'espacamento_planta_m': 0.10,
    'profundidade_cm': 1.0,
    'luminosidade': 'Sol pleno a meia sombra',
    'irrigacao': 'Regular',
    'adubacao': 'Composto + cobertura mensal',
    'pragas': 'Trips',
    'observacoes': 'Pode ser replantada por touceira.',
    'companheiras': [
      'Couve',
      'Repolho',
      'Brócolis',
      'Tomate',
      'Alface',
      'Pepino'
    ],
    'evitar': ['Ervilha', 'Feijão', 'Vagem'],
  },
  'Salsinha': {
    'categoria': 'Temperos',
    'icone': '🌿',
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
    'icone': '🌿',
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
    'icone': '🪴',
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
    'icone': '🍃',
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
    'icone': '🍅',
    'ciclo_dias': 110,
    'espacamento_linha_m': 1.00,
    'espacamento_planta_m': 0.60,
    'profundidade_cm': 1.0,
    'luminosidade': 'Sol pleno',
    'irrigacao': 'Regular (evitar molhar folhas)',
    'adubacao': 'Mais exigente: composto + reforços (K/Ca)',
    'pragas': 'Traça, mosca-branca, requeima',
    'observacoes': 'Tutoramento ajuda muito. Ventilação evita fungos.',
    'companheiras': [
      'Abóbora',
      'Melão',
      'Pepino',
      'Alho',
      'Cebola',
      'Manjericão'
    ],
    'evitar': ['Batata', 'Berinjela', 'Pimentão', 'Pimenta', 'Jiló'],
  },
  'Pimentão': {
    'categoria': 'Frutífera',
    'icone': '🫑',
    'ciclo_dias': 120,
    'espacamento_linha_m': 0.80,
    'espacamento_planta_m': 0.50,
    'profundidade_cm': 1.0,
    'luminosidade': 'Sol pleno',
    'irrigacao': 'Regular',
    'adubacao': 'Composto + reforço na floração',
    'pragas': 'Pulgões, trips, ácaros',
    'observacoes': 'Prefere calor moderado.',
    'companheiras': [
      'Abóbora',
      'Melão',
      'Pepino',
      'Alho',
      'Cebola',
      'Manjericão'
    ],
    'evitar': ['Batata', 'Berinjela', 'Tomate', 'Pimenta', 'Jiló'],
  },
  'Berinjela': {
    'categoria': 'Frutífera',
    'icone': '🍆',
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
    'icone': '🥒',
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
    'icone': '🥒',
    'ciclo_dias': 80,
    'espacamento_linha_m': 1.50,
    'espacamento_planta_m': 1.00,
    'profundidade_cm': 2.0,
    'luminosidade': 'Sol pleno',
    'irrigacao': 'Regular',
    'adubacao': 'Boa base orgânica',
    'pragas': 'Oídio, brocas',
    'observacoes': 'Ocupa espaço. Melhor em canteiro maior.',
    'companheiras': [
      'Alho',
      'Alho poró',
      'Cebola',
      'Espinafre',
      'Milho',
      'Feijão'
    ],
    'evitar': ['Beterraba', 'Abóbora', 'Melancia', 'Melão'],
  },
  'Cenoura': {
    'categoria': 'Raiz',
    'icone': '🥕',
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
    'icone': '🧅', // Usando cebola roxa como representação visual
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
    'icone': '🌶️',
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
    'icone': '🌽',
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
    'icone': '🫘',
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

// ======================================================================
// Calendário regional
// ======================================================================
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
  if (m == null) return const [];
  final list = m[mes] ?? const [];
  final seen = <String>{};
  final out = <String>[];
  for (final c in list) {
    if (seen.add(c)) out.add(c);
  }
  return out;
}

// ======================================================================
// Funções usadas pela TelaGuiaCulturas
// ======================================================================

List<String> listarCategorias() {
  final set = <String>{};
  for (final e in guiaCompleto.entries) {
    final cat = (e.value['categoria'] ?? '').toString().trim();
    if (cat.isNotEmpty) set.add(cat);
  }
  final out = set.toList()..sort((a, b) => a.compareTo(b));
  return out;
}

List<String> buscarCulturas(String query, {String? categoria}) {
  final q = _norm(query);

  final catNorm = _norm((categoria ?? '').trim());
  final all = guiaCompleto.keys.toList()..sort((a, b) => a.compareTo(b));

  final matches = <String>[];

  for (final nome in all) {
    // filtro categoria
    if (catNorm.isNotEmpty) {
      final m = guiaCompleto[nome];
      final cat = _norm((m?['categoria'] ?? '').toString());
      if (cat != catNorm) continue;
    }

    // filtro texto
    if (q.isEmpty) {
      matches.add(nome);
    } else {
      final n = _norm(nome);
      if (n.contains(q)) matches.add(nome);
    }
  }

  return matches;
}

CulturaInfo? getCulturaInfo(String nome) {
  final resolved = _resolveNomeCultura(nome);
  if (resolved == null) return null;
  final data = guiaCompleto[resolved];
  if (data == null) return null;
  return CulturaInfo.fromMap(resolved, data);
}

// ======================================================================
// Adapter “GuiaCulturas.dados” (compat com TelaPlanejamentoConsumo)
// ======================================================================

class GuiaCulturas {
  static final Map<String, Map<String, dynamic>> dados = _buildDados();

  static Map<String, Map<String, dynamic>> _buildDados() {
    final out = <String, Map<String, dynamic>>{};

    for (final entry in guiaCompleto.entries) {
      final nome = entry.key;
      final m = entry.value;

      final categoria = (m['categoria'] ?? 'Geral').toString();
      final icone =
          (m['icone'] ?? '🌱').toString(); // ✅ Exportando ícone no Adapter
      final ciclo = _asInt(m['ciclo_dias'], 60);

      final espLinha = _asDouble(m['espacamento_linha_m'], 0.30);
      final espPlanta = _asDouble(m['espacamento_planta_m'], 0.30);
      final espaco =
          (espLinha > 0 && espPlanta > 0) ? (espLinha * espPlanta) : 0.5;

      final yieldVal = _asDouble(m['yield'], 1.0);
      final unit = (m['unit'] ?? _defaultUnit(categoria)).toString();

      final evitar = _asStringList(m['evitar']);
      final par = _asStringList(m['companheiras']);

      out[nome] = <String, dynamic>{
        'yield': yieldVal <= 0 ? 1.0 : yieldVal,
        'unit': unit.isEmpty ? 'un' : unit,
        'espaco': espaco <= 0 ? 0.5 : espaco,
        'cicloDias': ciclo <= 0 ? 60 : ciclo,
        'evitar': evitar,
        'par': par,
        'cat': categoria,
        'icone': icone, // ✅ Disponível para a TelaPlanejamento usar
      };
    }

    return out;
  }

  static String _defaultUnit(String categoria) {
    final c = _norm(categoria);
    if (c.contains('tempero')) return 'maço';
    if (c.contains('folh')) return 'un';
    if (c.contains('brassic')) return 'un';
    if (c.contains('raiz')) return 'kg';
    if (c.contains('frut')) return 'kg';
    if (c.contains('cucur')) return 'kg';
    if (c.contains('grao')) return 'un';
    if (c.contains('legumin')) return 'un';
    return 'un';
  }
}

// ======================================================================
// Normalização e resolve
// ======================================================================

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
  t = t
      .replaceAll(RegExp(r'[áàâãä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòôõö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll(RegExp(r'[ç]'), 'c');
  t = t.replaceAll(RegExp(r'\s+'), ' ');
  return t;
}

double _asDouble(dynamic v, double def) {
  if (v == null) return def;
  if (v is num) return v.toDouble();
  final s = v.toString().trim().replaceAll(',', '.');
  return double.tryParse(s) ?? def;
}

int _asInt(dynamic v, int def) {
  if (v == null) return def;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim()) ?? def;
}

List<String> _asStringList(dynamic v) {
  if (v is List) {
    return v
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }
  return const [];
}
