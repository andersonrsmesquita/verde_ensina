import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/ui/app_messenger.dart';

class TelaGeradorCanteiros extends StatefulWidget {
  final List<Map<String, dynamic>> itensPlanejados;

  const TelaGeradorCanteiros({super.key, required this.itensPlanejados});

  @override
  State<TelaGeradorCanteiros> createState() => _TelaGeradorCanteirosState();
}

class _TelaGeradorCanteirosState extends State<TelaGeradorCanteiros> {
  List<Map<String, dynamic>> _canteirosSugeridos = [];
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _processarInteligencia();
  }

  // ---------------------------
  // Helpers (robustos)
  // ---------------------------
  double _asDouble(dynamic v) {
    if (v == null) return 0.0;

    if (v is num) {
      final d = v.toDouble();
      if (d.isNaN || d.isInfinite) return 0.0;
      return d;
    }

    final s = v.toString().replaceAll(',', '.').trim();
    final d = double.tryParse(s) ?? 0.0;
    if (d.isNaN || d.isInfinite) return 0.0;
    return d;
  }

  int _asInt(dynamic v) {
    if (v == null) return 0;

    if (v is int) return v;

    if (v is double) {
      if (v.isNaN || v.isInfinite) return 0;
      return v.round();
    }

    if (v is num) return v.round();

    return int.tryParse(v.toString().trim()) ?? 0;
  }

  String _asString(dynamic v, {String fallback = ''}) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? fallback : s;
  }

  String _nomePlanta(Map<String, dynamic> item) =>
      _asString(item['planta'], fallback: 'Planta');

  List<String> _listaString(dynamic v) {
    if (v == null) return <String>[];
    if (v is List) {
      return v
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    return <String>[];
  }

  // ---------------------------
  // Sanitizador Firestore (anti “abort()” no Windows)
  // ---------------------------
  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> map) {
    final val = _sanitize(map, r'$');
    return (val as Map).cast<String, dynamic>();
  }

  dynamic _sanitize(dynamic value, String path) {
    if (value == null) return null;

    // tipos OK
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
      return d; // Firestore gosta de num como double
    }

    if (value is Timestamp ||
        value is GeoPoint ||
        value is FieldValue ||
        value is DocumentReference) {
      return value;
    }

    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is Enum) return value.name;

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
            'Firestore: chave não-String em $path -> "$k" (${k.runtimeType})',
          );
        }
        out[k] = _sanitize(entry.value, '$path.$k');
      }
      return out;
    }

    throw UnsupportedError(
      'Firestore: tipo NÃO suportado em $path -> ${value.runtimeType}. '
      'Converta antes de salvar.',
    );
  }

  // ---------------------------
  // Inteligência de Agrupamento
  // ---------------------------
  bool _ehCompat(
    Map<String, dynamic> canteiro,
    Map<String, dynamic> candidata,
  ) {
    final nomeCandidata = _nomePlanta(candidata);
    final inimigosCandidata = _listaString(candidata['evitar']);

    final evitarDoCanteiro = List<String>.from(
      canteiro['evitar'] as List? ?? const [],
    );
    if (evitarDoCanteiro.contains(nomeCandidata)) return false;

    final plantasNoCanteiro = List<Map<String, dynamic>>.from(
      canteiro['plantas'] as List? ?? const [],
    );
    for (final p in plantasNoCanteiro) {
      final plantaNoCanteiro = _nomePlanta(p);
      if (inimigosCandidata.contains(plantaNoCanteiro)) {
        return false;
      }
    }

    return true;
  }

  int _scorePreferencia(
    Map<String, dynamic> canteiro,
    Map<String, dynamic> candidata,
  ) {
    final nomeCandidata = _nomePlanta(candidata);

    final parDoCanteiro = List<String>.from(
      canteiro['par'] as List? ?? const [],
    );
    final parDaCandidata = _listaString(candidata['par']);

    int score = 0;

    if (parDoCanteiro.contains(nomeCandidata)) score += 2;

    final plantasNoCanteiro = List<Map<String, dynamic>>.from(
      canteiro['plantas'] as List? ?? const [],
    );
    for (final p in plantasNoCanteiro) {
      final nome = _nomePlanta(p);
      if (parDaCandidata.contains(nome)) {
        score += 2;
        break;
      }
    }

    final area = _asDouble(candidata['area']);
    if (area > 0 && area < 1.0) score += 1;

    return score;
  }

  void _atualizarNomeAuto(Map<String, dynamic> canteiro) {
    final plantas = List<Map<String, dynamic>>.from(
      canteiro['plantas'] as List? ?? const [],
    );
    final nomes = plantas.map(_nomePlanta).toList();

    if (nomes.isEmpty) {
      canteiro['nome'] = 'Canteiro';
      return;
    }
    if (nomes.length == 1) {
      canteiro['nome'] = 'Canteiro de ${nomes.first}';
      return;
    }

    final top2 = nomes.take(2).toList();
    final resto = nomes.length - 2;

    canteiro['nome'] = resto > 0
        ? 'Consórcio: ${top2.join(' + ')} +$resto'
        : 'Consórcio: ${top2.join(' + ')}';
  }

  void _processarInteligencia() {
    final fila = List<Map<String, dynamic>>.from(widget.itensPlanejados);

    fila.sort((a, b) => _asDouble(b['area']).compareTo(_asDouble(a['area'])));

    final canteiros = <Map<String, dynamic>>[];

    while (fila.isNotEmpty) {
      final mestre = fila.removeAt(0);

      final canteiro = <String, dynamic>{
        'nome': 'Canteiro de ${_nomePlanta(mestre)}',
        'plantas': [mestre],
        'areaTotal': _asDouble(mestre['area']),
        'evitar': List<String>.from(_listaString(mestre['evitar'])),
        'par': List<String>.from(_listaString(mestre['par'])),
      };

      final candidatasOrdenadas = List<Map<String, dynamic>>.from(fila)
        ..sort((a, b) {
          final sa = _scorePreferencia(canteiro, a);
          final sb = _scorePreferencia(canteiro, b);
          if (sb != sa) return sb.compareTo(sa);
          return _asDouble(b['area']).compareTo(_asDouble(a['area']));
        });

      final sobrou = <Map<String, dynamic>>[];

      for (final candidata in candidatasOrdenadas) {
        if (_ehCompat(canteiro, candidata)) {
          (canteiro['plantas'] as List).add(candidata);
          canteiro['areaTotal'] =
              _asDouble(canteiro['areaTotal']) + _asDouble(candidata['area']);

          (canteiro['evitar'] as List)
              .addAll(_listaString(candidata['evitar']));
          (canteiro['par'] as List).addAll(_listaString(candidata['par']));

          _atualizarNomeAuto(canteiro);
        } else {
          sobrou.add(candidata);
        }
      }

      fila
        ..clear()
        ..addAll(sobrou);

      canteiros.add(canteiro);
    }

    setState(() => _canteirosSugeridos = canteiros);
  }

  // ---------------------------
  // UI Actions
  // ---------------------------
  int _totalMudas() {
    int total = 0;
    for (final c in _canteirosSugeridos) {
      final plantas = List<Map<String, dynamic>>.from(
        c['plantas'] as List? ?? const [],
      );
      for (final p in plantas) {
        total += _asInt(p['mudas']);
      }
    }
    return total;
  }

  double _totalArea() {
    double total = 0;
    for (final c in _canteirosSugeridos) {
      total += _asDouble(c['areaTotal']);
    }
    return total;
  }

  Future<void> _editarNome(int index) async {
    final atual = _asString(
      _canteirosSugeridos[index]['nome'],
      fallback: 'Canteiro',
    );
    final controller = TextEditingController(text: atual);

    final novo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renomear canteiro'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'Ex: Canteiro Principal',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (novo == null) return;
    if (novo.trim().isEmpty) return;

    setState(() {
      _canteirosSugeridos[index]['nome'] = novo.trim();
    });
  }

  // ---------------------------
  // Firestore Save (batch + AppMessenger + popUntil)
  // ---------------------------
  Future<void> _criarTodosCanteiros() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      AppMessenger.error(
          'Você precisa estar logado para salvar o planejamento.');
      return;
    }

    setState(() => _salvando = true);

    final fs = FirebaseFirestore.instance;
    final batch = fs.batch();

    try {
      for (final sugestao in _canteirosSugeridos) {
        final canteiroRef = fs.collection('canteiros').doc();

        final area = _asDouble(sugestao['areaTotal']);
        const largura = 1.0;
        final comprimento = area > 0 ? (area / largura) : 1.0;

        final plantas = List<Map<String, dynamic>>.from(
          sugestao['plantas'] as List? ?? const [],
        );

        final culturas = plantas.map((p) => _nomePlanta(p)).toList();
        final mudasTotais =
            plantas.fold<int>(0, (acc, p) => acc + _asInt(p['mudas']));

        final canteiroPayload = <String, dynamic>{
          'uid_usuario': user.uid,
          'nome': _asString(sugestao['nome'], fallback: 'Canteiro'),
          'area_m2': double.parse(area.toStringAsFixed(2)),
          'largura': largura,
          'comprimento': double.parse(comprimento.toStringAsFixed(2)),
          'ativo': true,
          'status': 'ocupado',
          'culturas': culturas,
          'mudas_totais': mudasTotais,
          'plantas_planejadas': plantas.map((p) {
            return <String, dynamic>{
              'planta': _nomePlanta(p),
              'mudas': _asInt(p['mudas']),
              'area': _asDouble(p['area']),
              'evitar': _listaString(p['evitar']),
              'par': _listaString(p['par']),
            };
          }).toList(),
          'data_criacao': FieldValue.serverTimestamp(),
          'data_atualizacao': FieldValue.serverTimestamp(),
        };

        batch.set(canteiroRef, _sanitizeMap(canteiroPayload));

        final histRef = fs.collection('historico_manejo').doc();

        final nomes = <String>[];
        var detalhes = "Plantio Automático (Planejamento):\n";

        for (final p in plantas) {
          final nome = _nomePlanta(p);
          final mudas = _asInt(p['mudas']);
          nomes.add(nome);
          detalhes += "- $nome: $mudas mudas\n";
        }

        final historicoPayload = <String, dynamic>{
          'canteiro_id': canteiroRef.id,
          'uid_usuario': user.uid,
          'tipo_manejo': 'Plantio',
          'produto': nomes.join(' + '),
          'detalhes': detalhes,
          'origem': 'planejamento',
          'data': FieldValue.serverTimestamp(),
          'quantidade_g': 0,
          'concluido': false,
          'data_colheita_prevista': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 90)),
          ),
        };

        batch.set(histRef, _sanitizeMap(historicoPayload));
      }

      await batch.commit();

      if (!mounted) return;

      // Primeiro volta pra Home
      Navigator.of(context).popUntil((route) => route.isFirst);

      // Depois mostra a msg (sem depender do contexto da tela que acabou de morrer)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppMessenger.success('✅ Canteiros criados e plantados!');
      });
    } catch (e) {
      AppMessenger.error('Erro ao salvar planejamento: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // ---------------------------
  // UI
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text(
              'Plano de Canteiros',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: _canteirosSugeridos.isEmpty
              ? _EstadoVazio(onReprocessar: _processarInteligencia)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
                  children: [
                    _ResumoTopo(
                      qtd: _canteirosSugeridos.length,
                      areaTotal: _totalArea(),
                      mudasTotal: _totalMudas(),
                      primary: primary,
                    ),
                    const SizedBox(height: 14),
                    ...List.generate(_canteirosSugeridos.length, (i) {
                      final canteiro = _canteirosSugeridos[i];
                      final area = _asDouble(canteiro['areaTotal']);
                      const largura = 1.0;
                      final comprimento = area > 0 ? (area / largura) : 1.0;

                      final plantas = List<Map<String, dynamic>>.from(
                        canteiro['plantas'] as List? ?? const [],
                      );
                      final mudas = plantas.fold<int>(
                        0,
                        (acc, p) => acc + _asInt(p['mudas']),
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CardCanteiro(
                          nome:
                              _asString(canteiro['nome'], fallback: 'Canteiro'),
                          area: area,
                          culturasCount: plantas.length,
                          mudasTotal: mudas,
                          largura: largura,
                          comprimento: comprimento,
                          plantas: plantas,
                          onEditarNome: () => _editarNome(i),
                        ),
                      );
                    }),
                  ],
                ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 14,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _salvando || _canteirosSugeridos.isEmpty
                      ? null
                      : _criarTodosCanteiros,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: Colors.green.withOpacity(0.25),
                  ),
                  icon: const Icon(Icons.check_circle),
                  label: const Text(
                    'APROVAR E PLANTAR AGORA',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Overlay de loading
        IgnorePointer(
          ignoring: !_salvando,
          child: AnimatedOpacity(
            opacity: _salvando ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: Container(
              color: Colors.black.withOpacity(0.25),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 14),
                      Text('Salvando planejamento...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------
// Widgets Premium
// ---------------------------
class _ResumoTopo extends StatelessWidget {
  final int qtd;
  final double areaTotal;
  final int mudasTotal;
  final Color primary;

  const _ResumoTopo({
    required this.qtd,
    required this.areaTotal,
    required this.mudasTotal,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary.withOpacity(0.95), primary.withOpacity(0.75)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'Sugestão Inteligente',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'A IA organizou seu consumo em $qtd canteiros.',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Área total',
                  value: '${areaTotal.toStringAsFixed(2)} m²',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(label: 'Mudas', value: mudasTotal.toString()),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Dica: toque no lápis para renomear antes de salvar.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardCanteiro extends StatelessWidget {
  final String nome;
  final double area;
  final int culturasCount;
  final int mudasTotal;
  final double largura;
  final double comprimento;
  final List<Map<String, dynamic>> plantas;
  final VoidCallback onEditarNome;

  const _CardCanteiro({
    required this.nome,
    required this.area,
    required this.culturasCount,
    required this.mudasTotal,
    required this.largura,
    required this.comprimento,
    required this.plantas,
    required this.onEditarNome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Renomear',
                onPressed: onEditarNome,
                icon: Icon(Icons.edit, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ChipInfo(
                icon: Icons.square_foot,
                text: '${area.toStringAsFixed(1)} m²',
                color: Colors.blue,
              ),
              _ChipInfo(
                icon: Icons.grass,
                text: '$mudasTotal mudas',
                color: Colors.green,
              ),
              _ChipInfo(
                icon: Icons.layers,
                text: '$culturasCount culturas',
                color: Colors.deepPurple,
              ),
              _ChipInfo(
                icon: Icons.straighten,
                text:
                    '${largura.toStringAsFixed(1)}m x ${comprimento.toStringAsFixed(1)}m',
                color: Colors.blueGrey,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 18),
          const Text(
            'Culturas neste canteiro:',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: plantas.map((p) {
              final planta = (p['planta'] ?? 'Planta').toString();
              final mudas = (p['mudas'] ?? 0).toString();

              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  '$planta ($mudas x)',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ChipInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _ChipInfo({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoVazio extends StatelessWidget {
  final VoidCallback onReprocessar;
  const _EstadoVazio({required this.onReprocessar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 44, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            const Text(
              'Nada para organizar ainda.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Volte ao planejamento, selecione as culturas e tente de novo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onReprocessar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reprocessar'),
            ),
          ],
        ),
      ),
    );
  }
}
