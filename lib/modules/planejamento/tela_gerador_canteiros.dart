import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/ui/app_ui.dart';
import '../../core/firebase/firebase_paths.dart';
import '../../core/session/session_scope.dart';
import '../../core/session/app_session.dart';

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
  bool _processando = true; // Loading inicial para evitar travamento na UI
  String? _erroProcessamento;

  @override
  void initState() {
    super.initState();
    // Executa após o build para não travar a animação de entrada
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
  // Inteligência de Agrupamento
  // ===========================================================================
  void _processarInteligencia() async {
    try {
      setState(() => _processando = true);

      // Simula um delay mínimo para a UI respirar se a lista for gigante
      await Future.delayed(const Duration(milliseconds: 300));

      final fila = List<Map<String, dynamic>>.from(widget.itensPlanejados);

      // Ordena por área (maior para menor) para otimizar espaço
      fila.sort((a, b) => _asDouble(b['area']).compareTo(_asDouble(a['area'])));

      final canteiros = <Map<String, dynamic>>[];

      while (fila.isNotEmpty) {
        final mestre = fila.removeAt(0);

        final canteiro = <String, dynamic>{
          'nome': 'Canteiro de ${_nomePlanta(mestre)}',
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

        // Mantém na fila apenas o que sobrou (incompatível com o canteiro atual)
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
    } catch (e, s) {
      debugPrint('Erro na IA: $e $s');
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

    // 1. O canteiro já tem alguém que odeia a candidata?
    if (evitarDoCanteiro.contains(nomeCandidata)) return false;

    // 2. A candidata odeia alguém que já está no canteiro?
    final inimigosCandidata = _listaString(candidata['evitar']);
    final plantasNoCanteiro = canteiro['plantas'] as List;

    for (var p in plantasNoCanteiro) {
      if (inimigosCandidata.contains(_nomePlanta(p))) return false;
    }

    return true;
  }

  void _atualizarNomeAuto(Map<String, dynamic> canteiro) {
    final plantas = canteiro['plantas'] as List;
    final nomes = plantas
        .map((p) => _nomePlanta(p))
        .toSet()
        .toList(); // toSet remove duplicatas no nome

    if (nomes.length > 1) {
      final principal = nomes.first;
      final qtdExtras = nomes.length - 1;
      canteiro['nome'] = 'Consórcio: $principal + $qtdExtras cultura(s)';
    }
  }

  Future<void> _editarNome(int index) async {
    final controller =
        TextEditingController(text: _canteirosSugeridos[index]['nome']);
    final novo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renomear Canteiro'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ex: Canteiro da Frente'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Salvar')),
        ],
      ),
    );
    if (novo != null && novo.isNotEmpty) {
      setState(() => _canteirosSugeridos[index]['nome'] = novo);
    }
  }

  // ===========================================================================
  // Persistência
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
        // Proteção contra NaN
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
          'largura': 1.0, // Padrão
          'comprimento':
              double.parse(areaSafe.toStringAsFixed(2)), // Padrão linear
          'ativo': true,
          'status': 'ocupado',
          'culturas': culturasLista,
          'mudas_totais': mudasTotais,
          'data_criacao': FieldValue.serverTimestamp(),
          'origem': 'ia_generator',
        };

        batch.set(canteiroRef, _sanitizeMap(canteiroPayload));

        // Cria o histórico de "Plantio Inicial"
        final histRef =
            FirebasePaths.historicoManejoCol(appSession.tenantId).doc();

        // Detalhes bonitos para o histórico
        final detalhesBuffer = StringBuffer('Plantio Automático:\n');
        for (var p in plantas) {
          detalhesBuffer
              .writeln('• ${_nomePlanta(p)}: ${_asInt(p['mudas'])} mudas');
        }

        batch.set(
            histRef,
            _sanitizeMap({
              'canteiro_id': canteiroRef.id,
              'uid_usuario': appSession.uid,
              'tipo_manejo': 'Plantio',
              'produto': culturasLista.join(', '), // Resumo das plantas
              'detalhes': detalhesBuffer.toString(),
              'data': FieldValue.serverTimestamp(),
              'concluido': true,
            }));
      }

      await batch.commit();

      if (!mounted) return;
      Navigator.of(context)
          .popUntil((route) => route.isFirst); // Volta pra Home
      AppMessenger.success(
          'Sucesso! ${_canteirosSugeridos.length} canteiros criados.');
    } catch (e, s) {
      debugPrint('Erro ao salvar: $e $s');
      AppMessenger.error('Erro ao salvar canteiros. Tente novamente.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Estado de Carregamento
    if (_processando) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                  'A inteligência artificial está organizando seus canteiros...'),
            ],
          ),
        ),
      );
    }

    // Estado de Erro na Lógica
    if (_erroProcessamento != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(_erroProcessamento!, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                AppButtons.outlinedIcon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Voltar'),
                )
              ],
            ),
          ),
        ),
      );
    }

    // Tela Principal
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plano de Canteiros'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recalcular',
            onPressed: _salvando ? null : _processarInteligencia,
          ),
        ],
      ),
      body: _canteirosSugeridos.isEmpty
          ? const Center(child: Text('Nenhum item compatível para organizar.'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AppButtons.elevatedIcon(
            onPressed: _salvando ? null : _criarTodosCanteiros,
            // ✅ CORRIGIDO: Ícone done_all (minúsculo)
            icon: _salvando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.done_all),
            label: Text(_salvando ? 'SALVANDO...' : 'CONFIRMAR E PLANTAR TUDO'),
          ),
        ),
      ),
    );
  }

  // Sanitizador: Garante que nada vá como NaN/Null para o Firestore
  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> map) {
    return map.map((k, v) {
      if (v is double && (v.isNaN || v.isInfinite)) return MapEntry(k, 0.0);
      if (v == null) return MapEntry(k, ""); // Null safety básico
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

    // Helpers de exibição
    double area = 0.0;
    try {
      area = double.parse(sugestao['areaTotal'].toString());
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias, // Arredondamento perfeito
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        backgroundColor: cs.surfaceContainerHighest.withOpacity(0.3),
        shape: const Border(), // Remove bordas internas do ExpansionTile
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Text('#$index',
              style: TextStyle(
                  color: cs.onPrimaryContainer, fontWeight: FontWeight.bold)),
        ),
        title: Text(
          sugestao['nome'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${area.toStringAsFixed(2)} m² • ${plantas.length} culturas',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: onRename,
          tooltip: 'Renomear',
        ),
        children: [
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('COMPOSIÇÃO:',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.primary, fontWeight: FontWeight.bold)),
                ),
                ...plantas.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.subdirectory_arrow_right,
                              size: 16, color: cs.outline),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(p['planta'].toString(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('${p['mudas']} mudas',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSecondaryContainer)),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          )
        ],
      ),
    );
  }
}
