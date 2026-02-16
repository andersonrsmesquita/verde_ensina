// FILE: lib/modules/planejamento/tela_gerador_canteiros.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/ui/app_ui.dart';
import '../../core/firebase/firebase_paths.dart';
import '../../core/session/session_scope.dart';

class TelaGeradorCanteiros extends StatefulWidget {
  final List<Map<String, dynamic>> itensPlanejados;

  const TelaGeradorCanteiros({
    super.key,
    required this.itensPlanejados,
  });

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

  // ===========================================================================
  // Helpers robustos
  // ===========================================================================
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

  // ===========================================================================
  // Sanitizador Firestore (anti abort() / NaN / tipos bizarros)
  // ===========================================================================
  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> map) {
    final val = _sanitize(map, r'$');
    return (val as Map).cast<String, dynamic>();
  }

  dynamic _sanitize(dynamic value, String path) {
    if (value == null) return null;
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
      return d;
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

  // ===========================================================================
  // Inteligência de agrupamento
  // ===========================================================================
  bool _ehCompat(
      Map<String, dynamic> canteiro, Map<String, dynamic> candidata) {
    final nomeCandidata = _nomePlanta(candidata);
    final inimigosCandidata = _listaString(candidata['evitar']);

    final evitarDoCanteiro =
        List<String>.from(canteiro['evitar'] as List? ?? const []);
    if (evitarDoCanteiro.contains(nomeCandidata)) return false;

    final plantasNoCanteiro = List<Map<String, dynamic>>.from(
        canteiro['plantas'] as List? ?? const []);
    for (final p in plantasNoCanteiro) {
      final plantaNoCanteiro = _nomePlanta(p);
      if (inimigosCandidata.contains(plantaNoCanteiro)) return false;
    }

    return true;
  }

  int _scorePreferencia(
      Map<String, dynamic> canteiro, Map<String, dynamic> candidata) {
    final nomeCandidata = _nomePlanta(candidata);
    final parDoCanteiro =
        List<String>.from(canteiro['par'] as List? ?? const []);
    final parDaCandidata = _listaString(candidata['par']);
    int score = 0;

    if (parDoCanteiro.contains(nomeCandidata)) score += 2;

    final plantasNoCanteiro = List<Map<String, dynamic>>.from(
        canteiro['plantas'] as List? ?? const []);
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
        canteiro['plantas'] as List? ?? const []);
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

  // ===========================================================================
  // Totais
  // ===========================================================================
  int _totalMudas() {
    int total = 0;
    for (final c in _canteirosSugeridos) {
      final plantas =
          List<Map<String, dynamic>>.from(c['plantas'] as List? ?? const []);
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

  // ===========================================================================
  // Editar nome
  // ===========================================================================
  Future<void> _editarNome(int index) async {
    final atual =
        _asString(_canteirosSugeridos[index]['nome'], fallback: 'Canteiro');
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
          ),
          onSubmitted: (_) => Navigator.pop(ctx, controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (novo == null || novo.trim().isEmpty) return;

    setState(() => _canteirosSugeridos[index]['nome'] = novo.trim());
  }

  // ===========================================================================
  // Firestore Save (Plano de Manejo Integrado) 🔥
  // ===========================================================================
  Future<void> _criarTodosCanteiros() async {
    final appSession = SessionScope.of(context).session;
    if (appSession == null) {
      AppMessenger.error('Selecione um espaço (tenant) para salvar.');
      return;
    }

    if (_canteirosSugeridos.isEmpty) {
      AppMessenger.warn('Nada para salvar ainda.');
      return;
    }

    setState(() => _salvando = true);

    final fs = FirebaseFirestore.instance;
    final batch = fs.batch();
    final hoje = DateTime.now();

    try {
      for (final sugestao in _canteirosSugeridos) {
        final canteiroRef =
            FirebasePaths.canteirosCol(appSession.tenantId).doc();

        final area = _asDouble(sugestao['areaTotal']);
        const largura = 1.0;
        final comprimento = area > 0 ? (area / largura) : 1.0;

        final plantas = List<Map<String, dynamic>>.from(
            sugestao['plantas'] as List? ?? const []);

        final culturas = plantas.map((p) => _nomePlanta(p)).toList();
        final mudasTotais =
            plantas.fold<int>(0, (acc, p) => acc + _asInt(p['mudas']));

        // 🔥 Calcula o maior ciclo do canteiro para o manejo
        int maiorCicloDias = 0;
        for (final p in plantas) {
          // Assumindo que a Tela Planejamento passou a propriedade cicloDias ou pegamos um valor default 60
          int ciclo = _asInt(p['ciclo_dias']);
          if (ciclo == 0) ciclo = 60; // fallback se não encontrou o dado
          if (ciclo > maiorCicloDias) maiorCicloDias = ciclo;
        }
        int totalSemanas = (maiorCicloDias / 7).ceil();

        final canteiroPayload = <String, dynamic>{
          'uid_usuario': appSession.uid,
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

        // -------------------------------------------------------------------
        // 🔥 INÍCIO DO PLANO DE MANEJO (Fase 1, Fase 2 e Fase 3)
        // -------------------------------------------------------------------

        // Função auxiliar para criar tarefa no Batch
        void agendarTarefa(
            String tipoManejo, String detalhe, int diasAcrescentar) {
          final histRef =
              FirebasePaths.historicoManejoCol(appSession.tenantId).doc();
          final dataPrevista = hoje.add(Duration(days: diasAcrescentar));

          final historicoPayload = <String, dynamic>{
            'canteiro_id': canteiroRef.id,
            'uid_usuario': appSession.uid,
            'tipo_manejo': tipoManejo,
            'produto': culturas.join(' + '),
            'detalhes': detalhe,
            'origem': 'planejamento',
            'data_prevista': Timestamp.fromDate(
                dataPrevista), // Usamos data_prevista para agenda futura
            'data': null, // Fica nulo até o usuário concluir a tarefa real
            'concluido': false,
          };
          batch.set(histRef, _sanitizeMap(historicoPayload));
        }

        // --- FASE 1: PREPARO E PLANTIO (Início imediato: Dia 0) ---
        var detalhesPlantio = 'Plano de Plantio:\n';
        for (final p in plantas) {
          final nome = _nomePlanta(p);
          final mudas = _asInt(p['mudas']);
          detalhesPlantio += '- $nome: $mudas mudas\n';
        }
        agendarTarefa('Plantio', detalhesPlantio, 0);
        agendarTarefa('Adubação', 'Adubação de plantio (base orgânica)', 0);
        agendarTarefa(
            'Manejo', 'Cobertura com palhada', 0); // Opcional mas recomendado

        // --- FASE 2: CONDUÇÃO (Irrigação, Capina, Pulverização) ---
        // Vamos agendar tarefas semanais até o fim do maior ciclo do canteiro
        for (int semana = 1; semana <= totalSemanas; semana++) {
          int dias = semana * 7;
          agendarTarefa('Irrigação', 'Irrigação Semanal', dias);
          agendarTarefa('Manejo', 'Capina / Limpeza', dias);

          // A pulverização pode ser mais espaçada (ex: a cada 15 dias)
          if (semana % 2 == 0) {
            agendarTarefa('Pulverização',
                'Pulverização preventiva de biofertilizante', dias);
          }
        }

        // --- FASE 3: COLHEITA (Fim do Ciclo) ---
        // Aqui seria ideal gerar uma tarefa de colheita específica para cada planta de acordo com o seu próprio ciclo
        for (final p in plantas) {
          final nome = _nomePlanta(p);
          int ciclo = _asInt(p['ciclo_dias']);
          if (ciclo == 0) ciclo = 60; // fallback
          agendarTarefa('Colheita', 'Colheita prevista de: $nome', ciclo);
        }
      }

      await batch.commit();

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppMessenger.success(
            '✅ Canteiros e Plano de Manejo criados com sucesso!');
      });
    } catch (e) {
      AppMessenger.error('Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // ===========================================================================
  // UI (premium via Theme + AppUI)
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final appSession = SessionScope.of(context).session;
    if (appSession == null) {
      return const Scaffold(
        body:
            Center(child: Text('Selecione um espaço (tenant) para continuar.')),
      );
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Plano de Canteiros'),
            actions: [
              IconButton(
                tooltip: 'Reprocessar',
                onPressed: _salvando ? null : _processarInteligencia,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _canteirosSugeridos.isEmpty
              ? _EmptyState(onReprocessar: _processarInteligencia)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 92),
                  children: [
                    _SummaryCard(
                      qtd: _canteirosSugeridos.length,
                      areaTotal: _totalArea(),
                      mudasTotal: _totalMudas(),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(_canteirosSugeridos.length, (i) {
                      final c = _canteirosSugeridos[i];
                      final nome = _asString(c['nome'], fallback: 'Canteiro');
                      final area = _asDouble(c['areaTotal']);
                      const largura = 1.0;
                      final comprimento = area > 0 ? (area / largura) : 1.0;

                      final plantas = List<Map<String, dynamic>>.from(
                          c['plantas'] as List? ?? const []);
                      final mudas = plantas.fold<int>(
                          0, (acc, p) => acc + _asInt(p['mudas']));

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CanteiroCard(
                          index: i + 1,
                          nome: nome,
                          area: area,
                          largura: largura,
                          comprimento: comprimento,
                          culturasCount: plantas.length,
                          mudasTotal: mudas,
                          plantas: plantas,
                          onRename: _salvando ? null : () => _editarNome(i),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.info_outline, color: cs.primary),
                        title: const Text('Antes de salvar'),
                        subtitle: const Text(
                          'Dica: toque em “renomear” se quiser ajustar os nomes. '
                          'Depois é só aprovar e o app irá gerar a agenda de plantio e manutenção das Fases 1, 2 e 3 para você.',
                        ),
                      ),
                    ),
                  ],
                ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: AppButtons.elevatedIcon(
                fullWidth: true,
                loading: _salvando,
                onPressed: _salvando || _canteirosSugeridos.isEmpty
                    ? null
                    : _criarTodosCanteiros,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('APROVAR E GERAR PLANO DE MANEJO'),
              ),
            ),
          ),
        ),
        if (_salvando) ...[
          const ModalBarrier(dismissible: false, color: Colors.black26),
          Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Agendando tarefas de manejo...'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ===========================================================================
// Widgets “premium” sem decoração caseira (só Theme / Card / Chip)
// ===========================================================================
class _SummaryCard extends StatelessWidget {
  final int qtd;
  final double areaTotal;
  final int mudasTotal;

  const _SummaryCard({
    required this.qtd,
    required this.areaTotal,
    required this.mudasTotal,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.auto_awesome, color: cs.primary),
              title: const Text(
                'Sugestão Inteligente',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('A IA organizou seu consumo em $qtd canteiros.'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MiniKpi(
                    label: 'Área total',
                    value: '${areaTotal.toStringAsFixed(2)} m²',
                    icon: Icons.square_foot,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniKpi(
                    label: 'Mudas',
                    value: mudasTotal.toString(),
                    icon: Icons.grass,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniKpi extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniKpi({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(14),
        color: cs.surface,
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _CanteiroCard extends StatelessWidget {
  final int index;
  final String nome;
  final double area;
  final int culturasCount;
  final int mudasTotal;
  final double largura;
  final double comprimento;
  final List<Map<String, dynamic>> plantas;
  final VoidCallback? onRename;

  const _CanteiroCard({
    required this.index,
    required this.nome,
    required this.area,
    required this.culturasCount,
    required this.mudasTotal,
    required this.largura,
    required this.comprimento,
    required this.plantas,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ExpansionTile(
        title: Text(
          nome,
          style: const TextStyle(fontWeight: FontWeight.w800),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Canteiro #$index • ${area.toStringAsFixed(2)} m²',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: 'Renomear',
          onPressed: onRename,
          icon: const Icon(Icons.edit_outlined),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(icon: Icons.grass, label: '$mudasTotal mudas'),
              _InfoChip(icon: Icons.layers, label: '$culturasCount culturas'),
              _InfoChip(
                icon: Icons.straighten,
                label:
                    '${largura.toStringAsFixed(1)}m x ${comprimento.toStringAsFixed(1)}m',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Culturas neste canteiro',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: plantas.map((p) {
              final planta = (p['planta'] ?? 'Planta').toString();
              final mudas = (p['mudas'] ?? 0).toString();
              // Inserir o emoji caso tenha vindo da tela de planejamento
              final icone = (p['icone'] ?? '🌱').toString();
              return Chip(
                label: Text('$icone $planta ($mudas x)'),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onReprocessar;

  const _EmptyState({
    required this.onReprocessar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 44),
            const SizedBox(height: 12),
            const Text(
              'Nada para organizar ainda.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Volte ao planejamento, selecione as culturas e tente de novo.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            AppButtons.outlinedIcon(
              icon: const Icon(Icons.refresh),
              label: const Text('Reprocessar'),
              onPressed: onReprocessar,
            ),
          ],
        ),
      ),
    );
  }
}
