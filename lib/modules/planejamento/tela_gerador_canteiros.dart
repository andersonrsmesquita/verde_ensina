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
  bool _processando = true;
  String? _erroProcessamento;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processarInteligencia();
    });
  }

  // ===========================================================================
  // Helpers Robustos (Anti-Crash)
  // ===========================================================================
  double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) {
      if (v.isEmpty) return 0.0;
      return double.tryParse(v.replaceAll(',', '.').trim()) ?? 0.0;
    }
    return 0.0;
  }

  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.round();
    if (v is String) {
      if (v.isEmpty) return 0;
      final d = double.tryParse(v.replaceAll(',', '.').trim());
      return d != null ? d.round() : 0;
    }
    return 0;
  }

  String _nomePlanta(Map<String, dynamic> item) =>
      (item['planta'] ?? 'Cultura').toString();

  List<String> _listaString(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  // ===========================================================================
  // Inteligência de Agrupamento (Consórcio e Alelopatia)
  // ===========================================================================
  void _processarInteligencia() async {
    try {
      setState(() {
        _processando = true;
        _erroProcessamento = null;
      });

      await Future.delayed(
          const Duration(milliseconds: 500)); // UX de processamento

      final fila = List<Map<String, dynamic>>.from(widget.itensPlanejados);
      fila.sort((a, b) => _asDouble(b['area']).compareTo(_asDouble(a['area'])));

      final canteiros = <Map<String, dynamic>>[];

      while (fila.isNotEmpty) {
        final mestre = fila.removeAt(0);

        final canteiro = <String, dynamic>{
          'nome': 'Lote de ${_nomePlanta(mestre)}',
          'plantas': [mestre],
          'areaTotal': _asDouble(mestre['area']),
          'evitar': _listaString(mestre['evitar']),
          'par': _listaString(mestre['par']),
        };

        final sobrou = <Map<String, dynamic>>[];

        for (final candidata in fila) {
          if (_verificarCompatibilidade(canteiro, candidata)) {
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

        fila.clear();
        fila.addAll(sobrou);
        canteiros.add(canteiro);
      }

      if (mounted) {
        setState(() {
          _canteirosSugeridos = canteiros;
          _processando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erroProcessamento = 'Erro ao calcular consórcios: $e';
          _processando = false;
        });
      }
    }
  }

  bool _verificarCompatibilidade(
      Map<String, dynamic> canteiro, Map<String, dynamic> candidata) {
    final nomeCandidata = _nomePlanta(candidata);
    final evitarDoCanteiro = canteiro['evitar'] as List;

    if (evitarDoCanteiro.contains(nomeCandidata)) return false;

    final inimigosCandidata = _listaString(candidata['evitar']);
    final plantasNoCanteiro = canteiro['plantas'] as List;

    for (var p in plantasNoCanteiro) {
      if (inimigosCandidata.contains(_nomePlanta(p))) return false;
    }

    return true;
  }

  void _atualizarNomeAuto(Map<String, dynamic> canteiro) {
    final plantas = canteiro['plantas'] as List;
    final nomes = plantas.map((p) => _nomePlanta(p)).toSet().toList();

    if (nomes.length > 1) {
      final principal = nomes.first;
      final qtdExtras = nomes.length - 1;
      canteiro['nome'] = 'Consórcio: $principal + $qtdExtras cultura(s)';
    }
  }

  Future<void> _editarNome(int index) async {
    final controller =
        TextEditingController(text: _canteirosSugeridos[index]['nome']);
    final theme = Theme.of(context);

    final novo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusLg)),
        title: const Text('Renomear Lote',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Ex: Lote da Frente',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CANCELAR',
                  style: TextStyle(color: theme.colorScheme.outline))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary),
              child: const Text('SALVAR')),
        ],
      ),
    );
    if (novo != null && novo.isNotEmpty) {
      setState(() => _canteirosSugeridos[index]['nome'] = novo);
    }
  }

  // ===========================================================================
  // Persistência no Banco (Firebase)
  // ===========================================================================
  Future<void> _criarTodosCanteiros() async {
    final appSession = SessionScope.sessionOf(context);
    if (appSession == null) {
      AppMessenger.error('Sessão inválida. Faça login novamente.');
      return;
    }

    setState(() => _salvando = true);
    final batch = FirebaseFirestore.instance.batch();

    try {
      for (final sug in _canteirosSugeridos) {
        final canteiroRef =
            FirebasePaths.canteirosCol(appSession.tenantId).doc();

        final area = _asDouble(sug['areaTotal']);
        final areaSafe = area.isNaN || area.isInfinite ? 0.0 : area;

        final plantas = List<Map<String, dynamic>>.from(sug['plantas']);
        final culturasLista =
            plantas.map((p) => _nomePlanta(p)).toSet().toList();
        final mudasTotais =
            plantas.fold<int>(0, (acc, p) => acc + _asInt(p['mudas']));

        final canteiroPayload = {
          'uid_usuario': appSession.uid,
          'nome': sug['nome'],
          'area_m2': double.parse(areaSafe.toStringAsFixed(2)),
          'largura': 1.0,
          'comprimento': double.parse(areaSafe.toStringAsFixed(2)),
          'ativo': true,
          'status': 'ocupado',
          'culturas': culturasLista,
          'mudas_totais': mudasTotais,
          'data_criacao': FieldValue.serverTimestamp(),
          'origem': 'ia_generator_consorcio',
        };

        batch.set(canteiroRef, _sanitizeMap(canteiroPayload));

        // Cria o histórico de "Plantio" na linha do tempo
        final histRef =
            FirebasePaths.historicoManejoCol(appSession.tenantId).doc();

        final detalhesBuffer =
            StringBuffer('Plantio (Formação de Consórcio):\n');
        for (var p in plantas) {
          detalhesBuffer.writeln(
              '• ${_nomePlanta(p)}: ${_asInt(p['mudas'])} mudas (${_asDouble(p['area']).toStringAsFixed(1)}m²)');
        }

        batch.set(
            histRef,
            _sanitizeMap({
              'canteiro_id': canteiroRef.id,
              'canteiro_nome': sug['nome'],
              'uid_usuario': appSession.uid,
              'tipo_manejo': 'Plantio',
              'produto': culturasLista.join(', '),
              'detalhes': detalhesBuffer.toString(),
              'data': FieldValue.serverTimestamp(),
              'createdAt': FieldValue.serverTimestamp(),
              'concluido': true,
            }));
      }

      await batch.commit();

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      AppMessenger.success(
          'Sucesso! ${_canteirosSugeridos.length} Lotes gerados inteligentemente.');
    } catch (e) {
      AppMessenger.error('Erro ao salvar os lotes. Tente novamente.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_processando) {
      return Scaffold(
        backgroundColor: cs.surfaceContainerLowest,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppTokens.lg),
              Text(
                  'A inteligência agronômica está calculando os melhores consórcios...',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    if (_erroProcessamento != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erro de Cálculo')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: cs.error),
                const SizedBox(height: AppTokens.md),
                Text(_erroProcessamento!, textAlign: TextAlign.center),
                const SizedBox(height: AppTokens.xl),
                AppButtons.outlinedIcon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Voltar e revisar'),
                )
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Mapeamento Inteligente'),
        centerTitle: true,
        backgroundColor: cs.surface,
        foregroundColor: cs.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recalcular Lotes',
            onPressed: _salvando ? null : _processarInteligencia,
          ),
        ],
      ),
      body: _canteirosSugeridos.isEmpty
          ? const Center(child: Text('Nenhum item compatível para organizar.'))
          : Column(
              children: [
                _buildAgronomicInsightPanel(theme, cs),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        AppTokens.md, 0, AppTokens.md, AppTokens.xl * 3),
                    itemCount: _canteirosSugeridos.length,
                    itemBuilder: (context, i) {
                      final sug = _canteirosSugeridos[i];
                      return _CanteiroSugeridoCard(
                        index: i + 1,
                        sugestao: sug,
                        onRename: () => _editarNome(i),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(AppTokens.lg),
        decoration: BoxDecoration(
          color: cs.surface,
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: AppButtons.elevatedIcon(
          onPressed: _salvando ? null : _criarTodosCanteiros,
          icon: _salvando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.done_all),
          label: Text(_salvando ? 'CRIANDO LOTES...' : 'APROVAR E CRIAR LOTES'),
        ),
      ),
    );
  }

  // Painel Inteligente baseado no manual de Consórcio e Rotação
  Widget _buildAgronomicInsightPanel(ThemeData theme, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.all(AppTokens.md),
      padding: const EdgeInsets.all(AppTokens.md),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: cs.secondaryContainer),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates, color: cs.onSecondaryContainer),
          const SizedBox(width: AppTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Uso Eficiente da Terra (UET)',
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: cs.onSecondaryContainer,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Agrupamos suas plantas usando a técnica de Consórcio. Culturas aliadas compartilham o mesmo lote, reduzindo pragas e aumentando a produção por m²!',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSecondaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> map) {
    return map.map((k, v) {
      if (v is double && (v.isNaN || v.isInfinite)) return MapEntry(k, 0.0);
      if (v == null) return MapEntry(k, "");
      if (v is Map<String, dynamic>) return MapEntry(k, _sanitizeMap(v));
      return MapEntry(k, v);
    });
  }
}

class _CanteiroSugeridoCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> sugestao;
  final VoidCallback onRename;

  const _CanteiroSugeridoCard({
    required this.index,
    required this.sugestao,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final plantas = List<Map<String, dynamic>>.from(sugestao['plantas']);

    double area = 0.0;
    try {
      area = double.parse(sugestao['areaTotal'].toString());
    } catch (_) {}

    // Custo Operacional Fase 1: 0.25h / m² para preparar o lote, adubar e plantar
    final double custoMaoDeObra = area * 0.25;

    final isConsorcio = plantas.length > 1;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTokens.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
            color: isConsorcio ? cs.primary : cs.outlineVariant,
            width: isConsorcio ? 1.5 : 1.0),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      color: cs.surface,
      child: ExpansionTile(
        backgroundColor: Colors.transparent,
        shape: const Border(),
        leading: CircleAvatar(
          backgroundColor:
              isConsorcio ? cs.primary : cs.surfaceContainerHighest,
          child: Text('#$index',
              style: TextStyle(
                  color: isConsorcio ? cs.onPrimary : cs.onSurface,
                  fontWeight: FontWeight.bold)),
        ),
        title: Text(
          sugestao['nome'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.crop_free, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('${area.toStringAsFixed(1)} m²',
                    style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(width: 12),
                Icon(Icons.handyman, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('Fase 1: ${custoMaoDeObra.toStringAsFixed(1)}h',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
            if (isConsorcio) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('CONSÓRCIO INTELIGENTE',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer)),
              )
            ]
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.edit_outlined, color: cs.outline),
          onPressed: onRename,
          tooltip: 'Renomear',
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppTokens.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('COMPOSIÇÃO DO LOTE:',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.primary, fontWeight: FontWeight.bold)),
                const SizedBox(height: AppTokens.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: plantas.map((p) {
                    return Chip(
                      avatar: CircleAvatar(
                        backgroundColor: cs.secondary,
                        child: Text(
                          p['mudas'].toString(),
                          style: TextStyle(
                              fontSize: 10,
                              color: cs.onSecondary,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      label: Text(p['planta'].toString()),
                      backgroundColor: cs.secondaryContainer,
                      side: BorderSide.none,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
