import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../solo/tela_diagnostico.dart';
import '../calculadoras/tela_calagem.dart';
import 'guia_culturas.dart';

class TelaDetalhesCanteiro extends StatefulWidget {
  final String canteiroId;
  const TelaDetalhesCanteiro({super.key, required this.canteiroId});

  @override
  State<TelaDetalhesCanteiro> createState() => _TelaDetalhesCanteiroState();
}

class _TelaDetalhesCanteiroState extends State<TelaDetalhesCanteiro> {
  final _nomeController = TextEditingController();
  final _compController = TextEditingController();
  final _largController = TextEditingController();

  final ScrollController _scroll = ScrollController();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  bool get _enableHardDelete => kDebugMode;
  String? get _uid => _auth.currentUser?.uid;
  bool get _isLogado => _uid != null;

  static const int _pageSize = 25;

  bool _loadingFirst = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  final List<QueryDocumentSnapshot> _docs = [];
  Object? _err;

  bool _aggInitChecked = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _compController.dispose();
    _largController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // -----------------------
  // Helpers
  // -----------------------
  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  void _snack(String msg, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }

  String _money(double v) => 'R\$ ${v.toStringAsFixed(2)}';

  String _fmtData(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$mi';
  }

  Widget _buildFirestoreError(Object? error) {
    final msg = (error ?? 'Erro desconhecido').toString();
    final low = msg.toLowerCase();
    final isIndex =
        low.contains('requires an index') || low.contains('create it here');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isIndex ? Colors.orange.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isIndex ? Colors.orange.shade200 : Colors.red.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isIndex
                ? '⚠️ Falta criar um índice no Firestore'
                : '❌ Erro no Firestore',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isIndex ? Colors.orange.shade900 : Colors.red.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isIndex
                ? 'Normal quando mistura WHERE + ORDER BY.\n'
                      'Abra o link do erro no console do Firebase e crie o índice sugerido.'
                : msg,
            style: TextStyle(
              color: isIndex ? Colors.orange.shade900 : Colors.red.shade900,
              fontSize: 12,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------
  // Finalidade
  // -----------------------
  String _labelFinalidade(String f) =>
      (f == 'comercio') ? 'Comércio' : 'Consumo';
  Color _corFinalidade(String f) =>
      (f == 'comercio') ? Colors.indigo : Colors.teal;

  // -----------------------
  // Map helpers
  // -----------------------
  Map<String, int> _intMapFromAny(dynamic mp) {
    if (mp is Map) {
      final out = <String, int>{};
      mp.forEach((k, v) {
        out[k.toString()] = _toInt(v);
      });
      return out;
    }
    return {};
  }

  Map<String, int> _extrairMapaDoDetalhe(String detalhes) {
    final out = <String, int>{};
    final lines = detalhes.split('\n');
    for (final ln in lines) {
      final s = ln.trim();
      if (!s.startsWith('-')) continue;
      final noDash = s.substring(1).trim();
      final parts = noDash.split(':');
      if (parts.length < 2) continue;
      final nome = parts[0].trim();
      final resto = parts.sublist(1).join(':').trim();
      final numMatch = RegExp(r'(\d+)').firstMatch(resto);
      if (numMatch == null) continue;
      final qtd = int.tryParse(numMatch.group(1) ?? '') ?? 0;
      if (nome.isNotEmpty && qtd > 0) out[nome] = qtd;
    }
    return out;
  }

  // -----------------------
  // Status + cores
  // -----------------------
  Color _getCorStatus(String status) {
    if (status == 'ocupado') return Colors.red.shade50;
    if (status == 'manutencao') return Colors.orange.shade50;
    return Colors.green.shade50;
  }

  Color _getCorAppBar(String status) {
    if (status == 'ocupado') return Colors.red.shade700;
    if (status == 'manutencao') return Colors.orange.shade800;
    return Theme.of(context).colorScheme.primary;
  }

  String _getTextoStatus(String status) {
    if (status == 'ocupado') return 'EM PRODUÇÃO';
    if (status == 'manutencao') return 'MANUTENÇÃO / DESCANSO';
    return 'LIVRE';
  }

  Future<void> _atualizarStatusCanteiro(String novoStatus) async {
    try {
      await _db.collection('canteiros').doc(widget.canteiroId).update({
        'status': novoStatus,
      });
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      _snack('❌ Falha ao atualizar status: $e', bg: Colors.red);
    }
  }

  // -----------------------
  // Navegação
  // -----------------------
  void _irParaDiagnostico() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaDiagnostico(canteiroIdOrigem: widget.canteiroId),
      ),
    ).then((_) {
      if (!mounted) return;
      // Atenção: se Diagnóstico gravar no histórico, ainda vamos ajustar aquela tela depois.
      _refreshHistorico();
    });
  }

  void _irParaCalagem() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaCalagem(canteiroIdOrigem: widget.canteiroId),
      ),
    ).then((_) {
      if (!mounted) return;
      // Atenção: se Calagem gravar custo no histórico, ainda vamos ajustar aquela tela depois.
      _refreshHistorico();
    });
  }

  // -----------------------
  // Agregados premium: inicializa campos se faltarem
  // -----------------------
  Future<void> _ensureAggFields(
    DocumentReference canteiroRef,
    Map<String, dynamic> d,
  ) async {
    if (_aggInitChecked) return;
    _aggInitChecked = true;

    final precisa =
        !(d.containsKey('agg_total_custo') &&
            d.containsKey('agg_total_receita') &&
            d.containsKey('agg_ciclo_custo') &&
            d.containsKey('agg_ciclo_receita') &&
            d.containsKey('agg_ciclo_concluido') &&
            d.containsKey('agg_ciclo_mapa'));

    if (!precisa) return;

    // Inicializa “zerado”. Pra canteiros antigos, você pode recalcular via menu DEV.
    try {
      await canteiroRef.update({
        'agg_total_custo': d['agg_total_custo'] ?? 0.0,
        'agg_total_receita': d['agg_total_receita'] ?? 0.0,
        'agg_ciclo_custo': d['agg_ciclo_custo'] ?? 0.0,
        'agg_ciclo_receita': d['agg_ciclo_receita'] ?? 0.0,
        'agg_ciclo_id': d['agg_ciclo_id'] ?? '',
        'agg_ciclo_inicio': d['agg_ciclo_inicio'],
        'agg_ciclo_produtos': d['agg_ciclo_produtos'] ?? '',
        'agg_ciclo_mapa': d['agg_ciclo_mapa'] ?? <String, int>{},
        'agg_ciclo_concluido': d['agg_ciclo_concluido'] ?? false,
      });
    } catch (_) {
      // sem spam de snack aqui
    }
  }

  // -----------------------
  // HISTÓRICO PAGINADO (mais leve, mais estável)
  // -----------------------
  Query _historicoQuery(String uid) {
    return _db
        .collection('historico_manejo')
        .where('canteiro_id', isEqualTo: widget.canteiroId)
        .where('uid_usuario', isEqualTo: uid)
        .orderBy('data', descending: true);
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore) return;
    if (!_scroll.hasClients) return;

    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _refreshHistorico() async {
    if (!_isLogado) return;

    setState(() {
      _loadingFirst = true;
      _loadingMore = false;
      _hasMore = true;
      _lastDoc = null;
      _docs.clear();
      _err = null;
    });

    await _loadMore();

    if (!mounted) return;
    setState(() => _loadingFirst = false);
  }

  Future<void> _loadMore() async {
    if (!_isLogado) return;
    if (_loadingMore || !_hasMore) return;

    setState(() {
      _loadingMore = true;
      _err = null;
    });

    try {
      Query q = _historicoQuery(_uid!).limit(_pageSize);
      if (_lastDoc != null) q = q.startAfterDocument(_lastDoc!);

      final snap = await q.get();

      if (snap.docs.isNotEmpty) {
        _lastDoc = snap.docs.last;
        _docs.addAll(snap.docs);
      }

      if (snap.docs.length < _pageSize) {
        _hasMore = false;
      }
    } catch (e) {
      _err = e;
    } finally {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  // -----------------------
  // DEV: recalcular agregados (1 vez) pra canteiros antigos
  // -----------------------
  Future<void> _recalcularAgregadosDev() async {
    if (!_isLogado) {
      _snack('⚠️ Faça login primeiro.', bg: Colors.orange);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Recalculando agregados...')),
          ],
        ),
      ),
    );

    try {
      final canteiroRef = _db.collection('canteiros').doc(widget.canteiroId);

      // lê tudo do histórico (DEV) - depois nunca mais precisa
      final all = await _historicoQuery(_uid!).get();

      double totalCusto = 0.0;
      double totalReceita = 0.0;

      // acha plantio ativo mais recente
      String cicloId = '';
      Timestamp? cicloInicio;
      String cicloProdutos = '';
      Map<String, int> cicloMapa = {};
      bool cicloConcluido = true;

      for (final doc in all.docs) {
        final d = (doc.data() as Map<String, dynamic>?) ?? {};
        final c = d['custo'];
        final r = d['receita'];
        if (c is num) totalCusto += c.toDouble();
        if (r is num) totalReceita += r.toDouble();
      }

      for (final doc in all.docs) {
        final d = (doc.data() as Map<String, dynamic>?) ?? {};
        if (d['tipo_manejo'] == 'Plantio' && d['concluido'] == false) {
          cicloId = doc.id;
          cicloConcluido = false;
          cicloProdutos = (d['produto'] ?? '').toString();
          cicloMapa = _intMapFromAny(d['mapa_plantio']);
          if (cicloMapa.isEmpty) {
            cicloMapa = _extrairMapaDoDetalhe((d['detalhes'] ?? '').toString());
          }
          final ts = d['data'];
          if (ts is Timestamp) cicloInicio = ts;
          break;
        }
      }

      // custo/receita do ciclo (aproximação: soma tudo desde o plantio ativo pra frente)
      double cicloCusto = 0.0;
      double cicloReceita = 0.0;
      if (!cicloConcluido && cicloId.isNotEmpty) {
        bool contando = false;
        for (final doc in all.docs) {
          if (doc.id == cicloId) contando = true;
          if (!contando) continue;

          final d = (doc.data() as Map<String, dynamic>?) ?? {};
          final c = d['custo'];
          final r = d['receita'];
          if (c is num) cicloCusto += c.toDouble();
          if (r is num) cicloReceita += r.toDouble();
        }
      }

      await canteiroRef.update({
        'agg_total_custo': totalCusto,
        'agg_total_receita': totalReceita,
        'agg_ciclo_custo': cicloCusto,
        'agg_ciclo_receita': cicloReceita,
        'agg_ciclo_id': cicloId,
        'agg_ciclo_inicio': cicloInicio,
        'agg_ciclo_produtos': cicloProdutos,
        'agg_ciclo_mapa': cicloMapa,
        'agg_ciclo_concluido': cicloConcluido,
      });

      if (!mounted) return;
      Navigator.pop(context);
      _snack('✅ Agregados recalculados (DEV).', bg: Colors.green);
      await _refreshHistorico();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _snack('❌ Falha ao recalcular: $e', bg: Colors.red);
    }
  }

  // -----------------------
  // Renomear
  // -----------------------
  void _editarNomeCanteiro(String nomeAtual) {
    final controller = TextEditingController(text: nomeAtual);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renomear'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nome',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final novoNome = controller.text.trim();
              if (novoNome.isEmpty) {
                _snack('⚠️ Informe um nome.', bg: Colors.orange);
                return;
              }
              try {
                await _db.collection('canteiros').doc(widget.canteiroId).update(
                  {'nome': novoNome},
                );
                if (!mounted) return;
                Navigator.pop(ctx);
              } catch (e) {
                _snack('❌ Falha ao renomear: $e', bg: Colors.red);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ).whenComplete(() => controller.dispose());
  }

  // -----------------------
  // IRRIGAÇÃO (premium: atualiza agregados no canteiro)
  // -----------------------
  void _mostrarDialogoIrrigacao() {
    if (!_isLogado) {
      _snack('⚠️ Você precisa estar logado.', bg: Colors.orange);
      return;
    }

    String metodo = 'Gotejamento';
    final tempoController = TextEditingController(text: '30');
    final chuvaController = TextEditingController(text: '0');
    final custoController = TextEditingController(text: '0.00');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.water_drop, color: Colors.blue, size: 28),
                  SizedBox(width: 10),
                  Text(
                    'Irrigação',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: chuvaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Chuva (mm)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.cloud),
                ),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: metodo,
                items: ['Manual', 'Gotejamento', 'Aspersão']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => metodo = v ?? metodo,
                decoration: const InputDecoration(
                  labelText: 'Sistema',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: tempoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tempo (min)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.timer),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: custoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Custo Operacional (R\$)',
                  hintText: 'Água, Luz...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final tempo = int.tryParse(tempoController.text) ?? 0;
                    final chuva =
                        double.tryParse(
                          chuvaController.text.replaceAll(',', '.'),
                        ) ??
                        0.0;
                    final custo =
                        double.tryParse(
                          custoController.text.replaceAll(',', '.'),
                        ) ??
                        0.0;

                    Navigator.pop(ctx);
                    await _salvarIrrigacaoPremium(metodo, tempo, chuva, custo);
                  },
                  child: const Text('SALVAR'),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      tempoController.dispose();
      chuvaController.dispose();
      custoController.dispose();
    });
  }

  Future<void> _salvarIrrigacaoPremium(
    String metodo,
    int tempo,
    double chuva,
    double custo,
  ) async {
    if (!_isLogado) return;

    final canteiroRef = _db.collection('canteiros').doc(widget.canteiroId);
    final histRef = _db.collection('historico_manejo').doc();

    try {
      await _db.runTransaction((tx) async {
        final canteiroSnap = await tx.get(canteiroRef);
        final c = (canteiroSnap.data() as Map<String, dynamic>?) ?? {};
        final cicloAtivo =
            (c['status'] == 'ocupado') &&
            ((c['agg_ciclo_id'] ?? '').toString().isNotEmpty) &&
            (c['agg_ciclo_concluido'] != true);

        tx.set(histRef, {
          'canteiro_id': widget.canteiroId,
          'uid_usuario': _uid,
          'data': FieldValue.serverTimestamp(),
          'tipo_manejo': 'Irrigação',
          'produto': metodo,
          'detalhes': 'Duração: $tempo min | Chuva: ${chuva}mm',
          'quantidade_g': 0,
          'custo': custo,
          'concluido': true,
        });

        tx.update(canteiroRef, {
          'agg_total_custo': FieldValue.increment(custo),
          if (cicloAtivo) 'agg_ciclo_custo': FieldValue.increment(custo),
        });
      });

      _snack('✅ Irrigação registrada.', bg: Colors.green);
      await _refreshHistorico();
    } catch (e) {
      _snack('❌ Falha ao salvar irrigação: $e', bg: Colors.red);
    }
  }

  // -----------------------
  // PLANTIO (premium: cria ciclo e reseta agregados do ciclo)
  // -----------------------
  void _mostrarDialogoPlantio(double cCanteiro, double lCanteiro) {
    if (!_isLogado) {
      _snack('⚠️ Você precisa estar logado.', bg: Colors.orange);
      return;
    }
    if (cCanteiro <= 0 || lCanteiro <= 0) {
      _snack(
        '⚠️ Medidas inválidas. Edite o canteiro e corrija as medidas.',
        bg: Colors.orange,
      );
      return;
    }

    final qtdPorPlanta = <String, int>{};
    const regiao = 'Sudeste';
    const mes = 'Fevereiro';
    final obsController = TextEditingController();
    final custoMudasController = TextEditingController(text: '0.00');

    final areaTotalCanteiro = cCanteiro * lCanteiro;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (contextModal, setModalState) {
          double areaOcupada = 0.0;

          qtdPorPlanta.forEach((planta, qtd) {
            final info =
                guiaCompleto[planta] ?? {'eLinha': 0.5, 'ePlanta': 0.5};
            final eLinha = (info['eLinha'] as num).toDouble();
            final ePlanta = (info['ePlanta'] as num).toDouble();
            areaOcupada += (qtd * (eLinha * ePlanta));
          });

          final percentualOcupado = (areaOcupada / areaTotalCanteiro).clamp(
            0.0,
            1.0,
          );
          final estourou = (areaTotalCanteiro - areaOcupada) < 0;

          void adicionarPlanta(String p) {
            final info = guiaCompleto[p] ?? {'eLinha': 0.5, 'ePlanta': 0.5};
            final eLinha = (info['eLinha'] as num).toDouble();
            final ePlanta = (info['ePlanta'] as num).toDouble();
            final areaUnit = (eLinha * ePlanta).clamp(0.0001, 999999.0);

            int qtdInicial = (areaTotalCanteiro / areaUnit).floor();
            if (qtdPorPlanta.isNotEmpty &&
                (areaTotalCanteiro - areaOcupada) > 0) {
              qtdInicial = ((areaTotalCanteiro - areaOcupada) / areaUnit)
                  .floor();
            }
            if (qtdInicial < 1) qtdInicial = 1;
            qtdPorPlanta[p] = qtdInicial;
          }

          final recomendadas = List<String>.from(
            calendarioRegional[regiao]?[mes] ?? const [],
          );

          final porCategoria = <String, List<String>>{};
          for (final p in recomendadas) {
            final cat = (guiaCompleto[p]?['cat'] ?? 'Outros').toString();
            porCategoria.putIfAbsent(cat, () => []);
            porCategoria[cat]!.add(p);
          }

          final outras =
              guiaCompleto.keys.where((c) => !recomendadas.contains(c)).toList()
                ..sort();
          final outrasPorCategoria = <String, List<String>>{};
          for (final p in outras) {
            final cat = (guiaCompleto[p]?['cat'] ?? 'Outros').toString();
            outrasPorCategoria.putIfAbsent(cat, () => []);
            outrasPorCategoria[cat]!.add(p);
          }

          Widget buildChip(String planta, bool isRecommended) {
            final isSel = qtdPorPlanta.containsKey(planta);
            return FilterChip(
              label: Text(planta),
              selected: isSel,
              checkmarkColor: Colors.white,
              selectedColor: isRecommended ? Colors.green : Colors.orange,
              backgroundColor: Colors.grey.shade100,
              labelStyle: TextStyle(
                fontSize: 11,
                color: isSel ? Colors.white : Colors.black87,
              ),
              onSelected: (v) {
                setModalState(() {
                  if (v) {
                    adicionarPlanta(planta);
                    if (!isRecommended)
                      _snack('⚠️ Atenção: Fora de época!', bg: Colors.orange);
                  } else {
                    qtdPorPlanta.remove(planta);
                  }
                });
              },
            );
          }

          return Container(
            height: MediaQuery.of(contextModal).size.height * 0.95,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Planejamento de Plantio',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                LinearProgressIndicator(
                  value: percentualOcupado,
                  color: estourou ? Colors.red : Colors.green,
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          color: Colors.green.shade50,
                          child: Text(
                            '✅ Recomendados:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                        ...porCategoria.entries.map(
                          (e) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 4,
                                ),
                                child: Text(
                                  e.key.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              Wrap(
                                spacing: 5,
                                children: e.value
                                    .map((p) => buildChip(p, true))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        Theme(
                          data: Theme.of(
                            contextModal,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            title: const Text(
                              '⚠️ Outras Culturas (Fora de Época)',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            children: [
                              ...outrasPorCategoria.entries.map(
                                (e) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 8,
                                        bottom: 4,
                                      ),
                                      child: Text(
                                        e.key.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade300,
                                        ),
                                      ),
                                    ),
                                    Wrap(
                                      spacing: 5,
                                      children: e.value
                                          .map((p) => buildChip(p, false))
                                          .toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (qtdPorPlanta.isNotEmpty) ...[
                          const Divider(),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Ajuste a Quantidade:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 10),
                                ...qtdPorPlanta.entries.map((entry) {
                                  return Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          entry.key,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => setModalState(() {
                                          if (entry.value > 1) {
                                            qtdPorPlanta[entry.key] =
                                                entry.value - 1;
                                          }
                                        }),
                                      ),
                                      Text(
                                        '${entry.value}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle,
                                          color: Colors.green,
                                        ),
                                        onPressed: () => setModalState(() {
                                          qtdPorPlanta[entry.key] =
                                              entry.value + 1;
                                        }),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: obsController,
                            decoration: const InputDecoration(
                              labelText: 'Observação do Plantio',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: custoMudasController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Custo de Mudas/Sementes (R\$)',
                              prefixIcon: Icon(Icons.monetization_on),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (qtdPorPlanta.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: estourou
                          ? null
                          : () async {
                              final custo =
                                  double.tryParse(
                                    custoMudasController.text.replaceAll(
                                      ',',
                                      '.',
                                    ),
                                  ) ??
                                  0.0;

                              try {
                                await _registrarPlantioPremium(
                                  qtdPorPlanta: qtdPorPlanta,
                                  regiao: regiao,
                                  mes: mes,
                                  observacao: obsController.text.trim(),
                                  custo: custo,
                                );

                                if (!mounted) return;
                                Navigator.pop(ctx);
                                _snack(
                                  '✅ Plantio registrado! Canteiro em PRODUÇÃO.',
                                  bg: Colors.green,
                                );
                                await _refreshHistorico();
                              } catch (e) {
                                _snack(
                                  '❌ Falha ao registrar plantio: $e',
                                  bg: Colors.red,
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: estourou
                            ? Colors.grey
                            : Theme.of(contextModal).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        estourou
                            ? 'FALTA ESPAÇO NO CANTEIRO'
                            : 'CONFIRMAR PLANTIO',
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      obsController.dispose();
      custoMudasController.dispose();
    });
  }

  Future<void> _registrarPlantioPremium({
    required Map<String, int> qtdPorPlanta,
    required String regiao,
    required String mes,
    required String observacao,
    required double custo,
  }) async {
    if (!_isLogado) throw Exception('Usuário não logado.');

    final canteiroRef = _db.collection('canteiros').doc(widget.canteiroId);
    final plantioRef = _db
        .collection('historico_manejo')
        .doc(); // já temos o ID do ciclo

    String resumo = "Plantio ($regiao/$mes):\n";
    final nomes = <String>[];

    qtdPorPlanta.forEach((planta, qtd) {
      nomes.add(planta);
      final ciclo = _toInt(guiaCompleto[planta]?['ciclo'] ?? 90);
      resumo += "- $planta: $qtd mudas ($ciclo dias)\n";
    });

    final produto = nomes.join(' + ');

    await _db.runTransaction((tx) async {
      final canteiroSnap = await tx.get(canteiroRef);
      if (!canteiroSnap.exists) throw Exception('Canteiro não encontrado.');

      final canteiro = (canteiroSnap.data() as Map<String, dynamic>?) ?? {};
      final status = (canteiro['status'] ?? 'livre').toString();

      if (status != 'livre') {
        throw Exception(
          'Canteiro não está livre. Finalize a safra antes de plantar de novo.',
        );
      }

      tx.set(plantioRef, {
        'canteiro_id': widget.canteiroId,
        'uid_usuario': _uid,
        'data': FieldValue.serverTimestamp(),
        'tipo_manejo': 'Plantio',
        'produto': produto,
        'detalhes': resumo,
        'observacao_extra': observacao,
        'quantidade_g': 0,
        'concluido': false,
        'custo': custo,
        'mapa_plantio': qtdPorPlanta,
      });

      tx.update(canteiroRef, {
        'status': 'ocupado',
        // totais
        'agg_total_custo': FieldValue.increment(custo),
        // ciclo
        'agg_ciclo_custo': custo,
        'agg_ciclo_receita': 0.0,
        'agg_ciclo_id': plantioRef.id,
        'agg_ciclo_inicio': FieldValue.serverTimestamp(),
        'agg_ciclo_produtos': produto,
        'agg_ciclo_mapa': qtdPorPlanta,
        'agg_ciclo_concluido': false,
      });
    });
  }

  // -----------------------
  // COLHEITA + PERDA (mantém seu fluxo, mas agora atualiza canteiro agregados)
  // -----------------------
  void _mostrarDialogoColheita({
    required String idPlantioAtivo,
    required Map<String, int> mapaPlantioAtual,
    required String finalidadeCanteiro,
  }) {
    final selecionados = <String, bool>{};
    final ctrlsQtd = <String, TextEditingController>{};
    final receitaCtrl = TextEditingController(text: '0.00');
    final obsCtrl = TextEditingController();

    final culturas = mapaPlantioAtual.keys.toList()..sort();
    for (final c in culturas) {
      selecionados[c] = false;
      ctrlsQtd[c] = TextEditingController();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (contextModal, setModalState) {
          bool temErro = false;

          String? validar(String cultura) {
            if (selecionados[cultura] != true) return null;
            final max = mapaPlantioAtual[cultura] ?? 0;
            final txt = ctrlsQtd[cultura]?.text.trim() ?? '';
            if (txt.isEmpty) return 'Informe a qtd';
            final qtd = int.tryParse(txt) ?? 0;
            if (qtd <= 0) return 'Qtd > 0';
            if (qtd > max) return 'Máx: $max';
            return null;
          }

          for (final c in culturas) {
            if (validar(c) != null) temErro = true;
          }

          return Container(
            height: MediaQuery.of(contextModal).size.height * 0.92,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(contextModal).viewInsets.bottom + 16,
              top: 18,
              left: 18,
              right: 18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.agriculture,
                      color: Colors.green,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Registrar Colheita',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setModalState(() {
                          for (final c in culturas) {
                            selecionados[c] = true;
                            ctrlsQtd[c]!.text = (mapaPlantioAtual[c] ?? 0)
                                .toString();
                          }
                        });
                      },
                      icon: const Icon(Icons.select_all),
                      label: const Text('Colher tudo'),
                    ),
                  ],
                ),
                Text(
                  'Finalidade: ${_labelFinalidade(finalidadeCanteiro)}',
                  style: TextStyle(
                    color: _corFinalidade(finalidadeCanteiro),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(),
                Expanded(
                  child: ListView(
                    children: [
                      ...culturas.map((cultura) {
                        final max = mapaPlantioAtual[cultura] ?? 0;
                        return Card(
                          elevation: 0,
                          color: Colors.grey.shade50,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: selecionados[cultura],
                                      onChanged: (v) => setModalState(
                                        () =>
                                            selecionados[cultura] = v ?? false,
                                      ),
                                      activeColor: Colors.green,
                                    ),
                                    Expanded(
                                      child: Text(
                                        cultura,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Chip(
                                      label: Text('Restante: $max'),
                                      backgroundColor: Colors.white,
                                    ),
                                  ],
                                ),
                                if (selecionados[cultura] == true)
                                  TextField(
                                    controller: ctrlsQtd[cultura],
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Qtd colhida',
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                      errorText: validar(cultura),
                                    ),
                                    onChanged: (_) => setModalState(() {}),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      if (finalidadeCanteiro == 'comercio') ...[
                        TextField(
                          controller: receitaCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Receita da venda (R\$)',
                            prefixIcon: Icon(Icons.monetization_on),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ] else ...[
                        TextField(
                          controller: obsCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Observação (opcional)',
                            prefixIcon: Icon(Icons.notes),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _mostrarDialogoPerda(
                            idPlantioAtivo: idPlantioAtivo,
                            mapaPlantioAtual: mapaPlantioAtual,
                          );
                        },
                        icon: const Icon(Icons.bug_report, color: Colors.red),
                        label: const Text('Registrar Perda / Estrago / Praga'),
                      ),
                      const SizedBox(height: 90),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: temErro
                          ? null
                          : () async {
                              final colhidos = <String, int>{};
                              for (final c in culturas) {
                                if (selecionados[c] == true) {
                                  final qtd =
                                      int.tryParse(ctrlsQtd[c]!.text.trim()) ??
                                      0;
                                  if (qtd > 0) colhidos[c] = qtd;
                                }
                              }

                              if (colhidos.isEmpty) {
                                Navigator.pop(ctx);
                                return;
                              }

                              final receita =
                                  double.tryParse(
                                    receitaCtrl.text.replaceAll(',', '.'),
                                  ) ??
                                  0.0;
                              final obs = obsCtrl.text.trim();

                              Navigator.pop(ctx);

                              await _processarColheitaTransacaoPremium(
                                idPlantioAtivo: idPlantioAtivo,
                                colhidos: colhidos,
                                finalidadeCanteiro: finalidadeCanteiro,
                                receita: (finalidadeCanteiro == 'comercio')
                                    ? receita
                                    : 0.0,
                                observacao: (finalidadeCanteiro == 'consumo')
                                    ? obs
                                    : '',
                              );

                              await _refreshHistorico();
                            },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('FINALIZAR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      for (final c in ctrlsQtd.values) {
        c.dispose();
      }
      receitaCtrl.dispose();
      obsCtrl.dispose();
    });
  }

  Future<void> _processarColheitaTransacaoPremium({
    required String idPlantioAtivo,
    required Map<String, int> colhidos,
    required String finalidadeCanteiro,
    required double receita,
    required String observacao,
  }) async {
    if (!_isLogado) {
      _snack('⚠️ Você precisa estar logado.', bg: Colors.orange);
      return;
    }

    final plantioRef = _db.collection('historico_manejo').doc(idPlantioAtivo);
    final canteiroRef = _db.collection('canteiros').doc(widget.canteiroId);
    final colheitaRef = _db.collection('historico_manejo').doc();

    try {
      bool cicloFinalizado = false;
      Map<String, int> mapaRestanteFinal = {};

      await _db.runTransaction((tx) async {
        final plantioSnap = await tx.get(plantioRef);
        if (!plantioSnap.exists)
          throw Exception('Plantio ativo não encontrado.');

        final data = (plantioSnap.data() as Map<String, dynamic>?) ?? {};
        if (data['concluido'] == true)
          throw Exception('Esse plantio já está concluído.');

        // mapa atual
        Map<String, int> mapaAtual = _intMapFromAny(data['mapa_plantio']);
        if (mapaAtual.isEmpty) {
          mapaAtual = _extrairMapaDoDetalhe(
            (data['detalhes'] ?? '').toString(),
          );
        }
        if (mapaAtual.isEmpty) {
          throw Exception(
            'Não consegui identificar quantidades. Garanta "mapa_plantio" no Plantio.',
          );
        }

        // baixa colheita
        final mapaRestante = Map<String, int>.from(mapaAtual);
        colhidos.forEach((cultura, qtdColhida) {
          final atual = mapaRestante[cultura] ?? 0;
          final novo = atual - qtdColhida;
          if (novo <= 0) {
            mapaRestante.remove(cultura);
          } else {
            mapaRestante[cultura] = novo;
          }
        });

        mapaRestanteFinal = mapaRestante;
        final novoProdutoList = mapaRestante.keys.toList()..sort();
        final novoProduto = novoProdutoList.join(' + ');

        cicloFinalizado = mapaRestante.isEmpty;

        // registra colheita
        tx.set(colheitaRef, {
          'canteiro_id': widget.canteiroId,
          'uid_usuario': _uid,
          'data': FieldValue.serverTimestamp(),
          'tipo_manejo': 'Colheita',
          'produto': colhidos.keys.join(' + '),
          'detalhes':
              'Colhido: ${colhidos.entries.map((e) => '${e.key} (${e.value} un)').join(' | ')}',
          'concluido': true,
          'finalidade': finalidadeCanteiro,
          'mapa_movimento': colhidos,
          if (finalidadeCanteiro == 'comercio') 'receita': receita,
          if (finalidadeCanteiro == 'consumo' && observacao.isNotEmpty)
            'observacao_extra': observacao,
        });

        // atualiza plantio ativo (saldo)
        tx.update(plantioRef, {
          'mapa_plantio': mapaRestante,
          'produto': novoProduto,
          if (cicloFinalizado) 'concluido': true,
          if (cicloFinalizado)
            'observacao_extra': 'Ciclo finalizado por colheita total.',
        });

        // atualiza canteiro agregados (premium)
        final updates = <String, dynamic>{
          'agg_ciclo_mapa': mapaRestante,
          'agg_ciclo_produtos': novoProduto,
          if (finalidadeCanteiro == 'comercio')
            'agg_total_receita': FieldValue.increment(receita),
          if (finalidadeCanteiro == 'comercio')
            'agg_ciclo_receita': FieldValue.increment(receita),
        };

        if (cicloFinalizado) {
          updates['status'] = 'livre';
          updates['agg_ciclo_concluido'] = true;
        }

        tx.update(canteiroRef, updates);
      });

      _snack(
        cicloFinalizado
            ? '✅ Colheita registrada. Canteiro liberado.'
            : '✅ Colheita parcial registrada. Saldo mantido.',
        bg: Colors.green,
      );

      setState(() {});
    } catch (e) {
      _snack('❌ Falha ao processar colheita: $e', bg: Colors.red);
    }
  }

  // -----------------------
  // PERDA (premium: atualiza ciclo no canteiro)
  // -----------------------
  void _mostrarDialogoPerda({
    required String idPlantioAtivo,
    required Map<String, int> mapaPlantioAtual,
  }) {
    final culturas = mapaPlantioAtual.keys.toList()..sort();
    if (culturas.isEmpty) {
      _snack('⚠️ Não há culturas ativas para dar baixa.', bg: Colors.orange);
      return;
    }

    String culturaSel = culturas.first;
    final qtdCtrl = TextEditingController();
    final motivoCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          top: 18,
          left: 18,
          right: 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bug_report, color: Colors.red, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Registrar Perda',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: culturaSel,
                items: culturas
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => culturaSel = v ?? culturaSel,
                decoration: const InputDecoration(
                  labelText: 'Cultura',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Restante atual: ${mapaPlantioAtual[culturaSel] ?? 0}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: qtdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Qtd perdida',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: motivoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Motivo',
                  hintText: 'Ex: praga, chuva, mela, formiga, queimou no sol…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final qtd = int.tryParse(qtdCtrl.text.trim()) ?? 0;
                    final max = mapaPlantioAtual[culturaSel] ?? 0;
                    final motivo = motivoCtrl.text.trim();

                    if (qtd <= 0) {
                      _snack(
                        '⚠️ Informe uma quantidade > 0.',
                        bg: Colors.orange,
                      );
                      return;
                    }
                    if (qtd > max) {
                      _snack(
                        '⚠️ Não pode baixar mais que o restante ($max).',
                        bg: Colors.orange,
                      );
                      return;
                    }
                    if (motivo.isEmpty) {
                      _snack('⚠️ Informe o motivo.', bg: Colors.orange);
                      return;
                    }

                    Navigator.pop(ctx);
                    await _processarPerdaTransacaoPremium(
                      idPlantioAtivo: idPlantioAtivo,
                      cultura: culturaSel,
                      qtdPerdida: qtd,
                      motivo: motivo,
                    );
                    await _refreshHistorico();
                  },
                  icon: const Icon(Icons.warning),
                  label: const Text('CONFIRMAR PERDA'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      qtdCtrl.dispose();
      motivoCtrl.dispose();
    });
  }

  Future<void> _processarPerdaTransacaoPremium({
    required String idPlantioAtivo,
    required String cultura,
    required int qtdPerdida,
    required String motivo,
  }) async {
    if (!_isLogado) {
      _snack('⚠️ Você precisa estar logado.', bg: Colors.orange);
      return;
    }

    final plantioRef = _db.collection('historico_manejo').doc(idPlantioAtivo);
    final canteiroRef = _db.collection('canteiros').doc(widget.canteiroId);
    final perdaRef = _db.collection('historico_manejo').doc();

    try {
      bool cicloFinalizado = false;

      await _db.runTransaction((tx) async {
        final snap = await tx.get(plantioRef);
        if (!snap.exists) throw Exception('Plantio ativo não encontrado.');

        final data = (snap.data() as Map<String, dynamic>?) ?? {};
        if (data['concluido'] == true)
          throw Exception('Esse plantio já está concluído.');

        Map<String, int> mapaAtual = _intMapFromAny(data['mapa_plantio']);
        if (mapaAtual.isEmpty) {
          mapaAtual = _extrairMapaDoDetalhe(
            (data['detalhes'] ?? '').toString(),
          );
        }
        if (mapaAtual.isEmpty) {
          throw Exception(
            'Não consegui identificar quantidades. Garanta "mapa_plantio" no Plantio.',
          );
        }

        final atual = mapaAtual[cultura] ?? 0;
        final novo = atual - qtdPerdida;
        if (novo <= 0) {
          mapaAtual.remove(cultura);
        } else {
          mapaAtual[cultura] = novo;
        }

        final novoProdutoList = mapaAtual.keys.toList()..sort();
        final novoProduto = novoProdutoList.join(' + ');
        cicloFinalizado = mapaAtual.isEmpty;

        tx.set(perdaRef, {
          'canteiro_id': widget.canteiroId,
          'uid_usuario': _uid,
          'data': FieldValue.serverTimestamp(),
          'tipo_manejo': 'Perda',
          'produto': cultura,
          'detalhes': 'Baixa: $qtdPerdida un | Motivo: $motivo',
          'concluido': true,
          'mapa_movimento': {cultura: qtdPerdida},
        });

        tx.update(plantioRef, {
          'mapa_plantio': mapaAtual,
          'produto': novoProduto,
          if (cicloFinalizado) 'concluido': true,
          if (cicloFinalizado)
            'observacao_extra':
                'Ciclo finalizado por perda total / baixa final.',
        });

        final updates = <String, dynamic>{
          'agg_ciclo_mapa': mapaAtual,
          'agg_ciclo_produtos': novoProduto,
        };

        if (cicloFinalizado) {
          updates['status'] = 'livre';
          updates['agg_ciclo_concluido'] = true;
        }

        tx.update(canteiroRef, updates);
      });

      _snack(
        cicloFinalizado
            ? '✅ Perda registrada. Canteiro liberado.'
            : '✅ Perda registrada. Saldo atualizado.',
        bg: cicloFinalizado ? Colors.green : Colors.orange,
      );

      setState(() {});
    } catch (e) {
      _snack('❌ Falha ao registrar perda: $e', bg: Colors.red);
    }
  }

  // -----------------------
  // Menu de operações
  // -----------------------
  void _mostrarOpcoesManejo(double c, double l, String statusAtual) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(20),
        height: 380,
        child: Column(
          children: [
            const Text(
              'Menu de Operações',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 15,
                crossAxisSpacing: 15,
                childAspectRatio: 1.4,
                children: [
                  _CardMenu(
                    icon: Icons.water_drop,
                    color: Colors.blue,
                    title: 'Irrigação',
                    subtitle: 'Regar',
                    onTap: () {
                      Navigator.pop(ctx);
                      _mostrarDialogoIrrigacao();
                    },
                  ),
                  _CardMenu(
                    icon: Icons.spa,
                    color: (statusAtual == 'livre')
                        ? Colors.green
                        : Colors.grey,
                    title: 'Novo Plantio',
                    subtitle: (statusAtual == 'livre')
                        ? 'Planejar'
                        : 'Bloqueado',
                    onTap: () {
                      Navigator.pop(ctx);
                      if (statusAtual != 'livre') {
                        _snack(
                          '⚠️ Finalize a safra (colheita/perda) antes de plantar de novo.',
                          bg: Colors.orange,
                        );
                        return;
                      }
                      _mostrarDialogoPlantio(c, l);
                    },
                  ),
                  _CardMenu(
                    icon: Icons.science,
                    color: Colors.brown,
                    title: 'Análise Solo',
                    subtitle: 'Registrar',
                    onTap: () {
                      Navigator.pop(ctx);
                      _irParaDiagnostico();
                    },
                  ),
                  _CardMenu(
                    icon: Icons.landscape,
                    color: Colors.orange,
                    title: 'Calagem',
                    subtitle: 'Calcular',
                    onTap: () {
                      Navigator.pop(ctx);
                      _irParaCalagem();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------
  // Dashboard premium: NÃO soma histórico, lê agregados do canteiro
  // -----------------------
  Widget _buildDashboard({
    required Map<String, dynamic> dadosCanteiro,
    required double area,
    required String status,
    required String finalidade,
  }) {
    final corFundo = _getCorStatus(status);
    final corTexto = (status == 'livre')
        ? Colors.green.shade900
        : (status == 'manutencao'
              ? Colors.orange.shade900
              : Colors.red.shade900);

    final textoStatus = _getTextoStatus(status);

    final totalCusto = _toDouble(dadosCanteiro['agg_total_custo']);
    final totalReceita = _toDouble(dadosCanteiro['agg_total_receita']);

    final cicloCusto = _toDouble(dadosCanteiro['agg_ciclo_custo']);
    final cicloReceita = _toDouble(dadosCanteiro['agg_ciclo_receita']);

    final cicloId = (dadosCanteiro['agg_ciclo_id'] ?? '').toString();
    final cicloConcluido =
        (dadosCanteiro['agg_ciclo_concluido'] ?? false) == true;
    final cicloInicio = dadosCanteiro['agg_ciclo_inicio'] is Timestamp
        ? dadosCanteiro['agg_ciclo_inicio'] as Timestamp
        : null;
    final cicloMapa = _intMapFromAny(dadosCanteiro['agg_ciclo_mapa']);
    final cicloProdutos = (dadosCanteiro['agg_ciclo_produtos'] ?? '')
        .toString();

    final temPlantioAtivo =
        (status == 'ocupado') && cicloId.isNotEmpty && !cicloConcluido;
    final culturasAtivas = cicloMapa.keys.toList()..sort();

    Widget financeCard() {
      if (finalidade != 'comercio') return const SizedBox.shrink();

      final lucroTotal = totalReceita - totalCusto;
      final lucroCiclo = cicloReceita - cicloCusto;

      return Container(
        margin: const EdgeInsets.fromLTRB(15, 12, 15, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance_wallet, size: 18),
                SizedBox(width: 8),
                Text(
                  'Financeiro',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Investido (Total)',
                    value: _money(totalCusto),
                    color: Colors.red,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Faturamento (Total)',
                    value: _money(totalReceita),
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Balanço (Total)',
                    value: _money(lucroTotal),
                    color: lucroTotal >= 0 ? Colors.blue : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Ciclo (Custo)',
                    value: _money(cicloCusto),
                    color: Colors.red,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Ciclo (Receita)',
                    value: _money(cicloReceita),
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Ciclo (Balanço)',
                    value: _money(lucroCiclo),
                    color: lucroCiclo >= 0 ? Colors.blue : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        financeCard(),
        Container(
          margin: const EdgeInsets.all(15),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: corFundo,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: corTexto.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 6),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(
                      textoStatus,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(color: corTexto),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      'Finalidade: ${_labelFinalidade(finalidade)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(color: _corFinalidade(finalidade)),
                  ),
                  const Spacer(),
                  if (temPlantioAtivo && cicloMapa.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () => _mostrarDialogoColheita(
                        idPlantioAtivo: cicloId,
                        mapaPlantioAtual: cicloMapa,
                        finalidadeCanteiro: finalidade,
                      ),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text(
                        'Colher',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${area.toStringAsFixed(1)} m²',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: corTexto,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Área total',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.build_circle,
                      color: status == 'manutencao'
                          ? Colors.orange
                          : (status == 'ocupado'
                                ? Colors.grey.withOpacity(0.35)
                                : Colors.grey),
                    ),
                    tooltip: 'Manutenção',
                    onPressed: status == 'ocupado'
                        ? () => _snack(
                            '❌ Canteiro em produção. Finalize a safra antes de manutenção.',
                            bg: Colors.red,
                          )
                        : () => _atualizarStatusCanteiro(
                            status == 'manutencao' ? 'livre' : 'manutencao',
                          ),
                  ),
                ],
              ),
              if (temPlantioAtivo) ...[
                const Divider(),
                Row(
                  children: [
                    const Text(
                      'Safra atual',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      cicloInicio == null
                          ? 'Início: —'
                          : 'Início: ${_fmtData(cicloInicio)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (cicloProdutos.isNotEmpty)
                  Text(
                    cicloProdutos,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: culturasAtivas.map((c) {
                    final rest = cicloMapa[c] ?? 0;
                    return Chip(
                      label: Text('$c: $rest'),
                      backgroundColor: Colors.white,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                if (cicloInicio != null) ...[
                  ...culturasAtivas.map((planta) {
                    final ciclo = _toInt(guiaCompleto[planta]?['ciclo'] ?? 90);
                    final diasPassados = DateTime.now()
                        .difference(cicloInicio!.toDate())
                        .inDays;
                    final progresso = (diasPassados / (ciclo <= 0 ? 1 : ciclo))
                        .clamp(0.0, 1.0);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$planta • ${diasPassados}d / ${ciclo}d',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progresso,
                              backgroundColor: Colors.white.withOpacity(0.55),
                              color: (progresso >= 1)
                                  ? Colors.green
                                  : Colors.orangeAccent,
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => _mostrarDialogoPerda(
                      idPlantioAtivo: cicloId,
                      mapaPlantioAtual: cicloMapa,
                    ),
                    icon: const Icon(Icons.bug_report, color: Colors.red),
                    label: const Text('Perda'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // -----------------------
  // Editar canteiro (com finalidade)
  // -----------------------
  void _mostrarDialogoEditarCanteiro(Map<String, dynamic> d) {
    _nomeController.text = (d['nome'] ?? '').toString();
    _compController.text = _toDouble(d['comprimento']).toString();
    _largController.text = _toDouble(d['largura']).toString();

    String finalidade = (d['finalidade'] ?? 'consumo').toString();
    if (finalidade != 'consumo' && finalidade != 'comercio')
      finalidade = 'consumo';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setLocalState) => AlertDialog(
          title: const Text('Editar Canteiro'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: finalidade,
                  items: const [
                    DropdownMenuItem(
                      value: 'consumo',
                      child: Text('Consumo (doméstico/familiar)'),
                    ),
                    DropdownMenuItem(
                      value: 'comercio',
                      child: Text('Comércio (venda/mercado)'),
                    ),
                  ],
                  onChanged: (v) =>
                      setLocalState(() => finalidade = v ?? finalidade),
                  decoration: const InputDecoration(
                    labelText: 'Finalidade',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _compController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Comprimento (m)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _largController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Largura (m)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nome = _nomeController.text.trim();
                final comp =
                    double.tryParse(
                      _compController.text.replaceAll(',', '.'),
                    ) ??
                    0.0;
                final larg =
                    double.tryParse(
                      _largController.text.replaceAll(',', '.'),
                    ) ??
                    0.0;

                if (nome.isEmpty || comp <= 0 || larg <= 0) {
                  _snack(
                    '⚠️ Preencha nome e medidas válidas.',
                    bg: Colors.orange,
                  );
                  return;
                }

                try {
                  await _db
                      .collection('canteiros')
                      .doc(widget.canteiroId)
                      .update({
                        'nome': nome,
                        'comprimento': comp,
                        'largura': larg,
                        'area_m2': comp * larg,
                        'finalidade': finalidade,
                      });

                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _snack('✅ Canteiro atualizado.', bg: Colors.green);
                } catch (e) {
                  _snack('❌ Falha ao salvar: $e', bg: Colors.red);
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _alternarStatus(bool ativoAtual) async {
    try {
      await _db.collection('canteiros').doc(widget.canteiroId).update({
        'ativo': !ativoAtual,
      });
      _snack(!ativoAtual ? '✅ Reativado.' : '✅ Arquivado.', bg: Colors.green);
    } catch (e) {
      _snack('❌ Falha ao alterar status: $e', bg: Colors.red);
    }
  }

  // -----------------------
  // HARD DELETE (DEV)
  // -----------------------
  Future<void> _hardDeleteCanteiroCascade() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Excluindo canteiro e histórico...')),
          ],
        ),
      ),
    );

    try {
      final db = _db;

      while (true) {
        Query q = db
            .collection('historico_manejo')
            .where('canteiro_id', isEqualTo: widget.canteiroId);
        if (_uid != null) q = q.where('uid_usuario', isEqualTo: _uid);
        final snap = await q.limit(400).get();
        if (snap.docs.isEmpty) break;

        final batch = db.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      await db.collection('canteiros').doc(widget.canteiroId).delete();

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);
      _snack(
        '✅ Excluído com sucesso (canteiro + histórico).',
        bg: Colors.green,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _snack('❌ Falha ao excluir: $e', bg: Colors.red);
    }
  }

  void _confirmarExclusaoCanteiro() {
    if (!_enableHardDelete) {
      _snack(
        '🚫 Excluir definitivo desativado em produção. Use Arquivar.',
        bg: Colors.orange,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir DEFINITIVO (DEV)?'),
        content: const Text(
          'Isso apaga o canteiro E todo o histórico dele.\n\n'
          'Use isso só em desenvolvimento pra “limpar” o banco.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _hardDeleteCanteiroCascade();
            },
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );
  }

  // Excluir item (DEV)
  void _confirmarExclusaoItem(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Registro?'),
        content: const Text('Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await _db.collection('historico_manejo').doc(id).delete();
                if (!mounted) return;
                Navigator.pop(ctx);
                _snack('✅ Registro excluído.', bg: Colors.green);
                await _refreshHistorico();
              } catch (e) {
                _snack('❌ Falha ao excluir: $e', bg: Colors.red);
              }
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  // Editar texto (mantido)
  void _mostrarDialogoPerdaOuEditar(
    String id,
    String detalheAtual,
    String obsAtual,
  ) {
    final detalheCtrl = TextEditingController(text: detalheAtual);
    final obsCtrl = TextEditingController(text: obsAtual);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar / Ajustar'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Aqui você edita o texto do registro.\n'
                'Para baixa inteligente (que mexe no saldo), use "Registrar Perda".',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: detalheCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Detalhes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: obsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Observação',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _db.collection('historico_manejo').doc(id).update({
                  'detalhes': detalheCtrl.text,
                  'observacao_extra': obsCtrl.text,
                });
                if (!mounted) return;
                Navigator.pop(ctx);
                _snack('✅ Registro atualizado!', bg: Colors.green);
                await _refreshHistorico();
              } catch (e) {
                _snack('❌ Falha ao atualizar: $e', bg: Colors.red);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ).whenComplete(() {
      detalheCtrl.dispose();
      obsCtrl.dispose();
    });
  }

  // -----------------------
  // UI principal
  // -----------------------
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('canteiros').doc(widget.canteiroId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Canteiro'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            body: _buildFirestoreError(snapshot.error),
          );
        }

        if (!snapshot.hasData ||
            snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final raw = snapshot.data!.data();
        if (raw == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Canteiro não encontrado'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Text(
                  'Esse canteiro não existe mais (foi apagado/arquivado).\nVolte e selecione outro.',
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final dados = Map<String, dynamic>.from(raw as Map);
        final canteiroRef = _db.collection('canteiros').doc(widget.canteiroId);

        // inicializa agregados se faltarem
        _ensureAggFields(canteiroRef, dados);

        final bool ativo = (dados['ativo'] ?? true) == true;
        final String status = (dados['status'] ?? 'livre').toString();
        final double comp = _toDouble(dados['comprimento']);
        final double larg = _toDouble(dados['largura']);
        final double area = _toDouble(dados['area_m2']);

        String finalidade = (dados['finalidade'] ?? 'consumo').toString();
        if (finalidade != 'consumo' && finalidade != 'comercio')
          finalidade = 'consumo';

        // ciclo premium
        final cicloId = (dados['agg_ciclo_id'] ?? '').toString();
        final cicloConcluido = (dados['agg_ciclo_concluido'] ?? false) == true;
        final cicloMapa = _intMapFromAny(dados['agg_ciclo_mapa']);
        final temPlantioAtivo =
            (status == 'ocupado') && cicloId.isNotEmpty && !cicloConcluido;

        // carrega histórico paginado 1x por tela
        if (_isLogado && _docs.isEmpty && _loadingFirst) {
          // chama fora do build “real”
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _refreshHistorico();
          });
        }

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    (dados['nome'] ?? 'Canteiro').toString(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () =>
                      _editarNomeCanteiro((dados['nome'] ?? '').toString()),
                  tooltip: 'Renomear',
                ),
              ],
            ),
            backgroundColor: _getCorAppBar(status),
            foregroundColor: Colors.white,
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'e') _mostrarDialogoEditarCanteiro(dados);
                  if (v == 's') _alternarStatus(ativo);
                  if (v == 'x') _confirmarExclusaoCanteiro();
                  if (v == 'r') _recalcularAgregadosDev();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'e', child: Text('Editar')),
                  PopupMenuItem(
                    value: 's',
                    child: Text(ativo ? 'Arquivar' : 'Reativar'),
                  ),
                  if (_enableHardDelete)
                    const PopupMenuItem(
                      value: 'x',
                      child: Text('Excluir DEFINITIVO (DEV)'),
                    ),
                  if (_enableHardDelete)
                    const PopupMenuItem(
                      value: 'r',
                      child: Text('Recalcular agregados (DEV)'),
                    ),
                ],
              ),
            ],
          ),
          floatingActionButton: ativo
              ? FloatingActionButton.extended(
                  onPressed: () => _mostrarOpcoesManejo(comp, larg, status),
                  label: const Text('MANEJO'),
                  backgroundColor: _getCorAppBar(status),
                  icon: const Icon(Icons.add_task),
                )
              : null,
          body: RefreshIndicator(
            onRefresh: _refreshHistorico,
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(
                  child: _buildDashboard(
                    dadosCanteiro: dados,
                    area: area,
                    status: status,
                    finalidade: finalidade,
                  ),
                ),

                if (_err != null)
                  SliverToBoxAdapter(child: _buildFirestoreError(_err)),

                if (_loadingFirst)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_docs.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text('Sem histórico ainda. Use o botão MANEJO 👇'),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((ctx, i) {
                      final e =
                          (_docs[i].data() as Map<String, dynamic>?) ?? {};
                      final concluido = (e['concluido'] ?? false) == true;
                      final tipo = (e['tipo_manejo'] ?? '').toString();
                      final produto = (e['produto'] ?? '').toString();
                      final detalhes = (e['detalhes'] ?? '').toString();
                      final custo = _toDouble(e['custo']);
                      final receita = _toDouble(e['receita']);
                      final ts = e['data'] is Timestamp
                          ? e['data'] as Timestamp
                          : null;

                      IconData iconByTipo(String tipo) {
                        switch (tipo) {
                          case 'Plantio':
                            return Icons.spa;
                          case 'Irrigação':
                            return Icons.water_drop;
                          case 'Colheita':
                            return Icons.agriculture;
                          case 'Perda':
                            return Icons.bug_report;
                          case 'Calagem':
                            return Icons.landscape;
                          default:
                            return Icons.event_note;
                        }
                      }

                      Color colorByTipo(String tipo) {
                        switch (tipo) {
                          case 'Plantio':
                            return Colors.green;
                          case 'Irrigação':
                            return Colors.blue;
                          case 'Colheita':
                            return Colors.teal;
                          case 'Perda':
                            return Colors.red;
                          case 'Calagem':
                            return Colors.orange;
                          default:
                            return Colors.grey;
                        }
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colorByTipo(
                              tipo,
                            ).withOpacity(0.12),
                            child: Icon(
                              iconByTipo(tipo),
                              color: colorByTipo(tipo),
                            ),
                          ),
                          title: Text(
                            produto.isEmpty ? tipo : produto,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              decoration: concluido
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (tipo.isNotEmpty)
                                Text(
                                  tipo,
                                  style: TextStyle(
                                    color: colorByTipo(tipo),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              if (_fmtData(ts).isNotEmpty)
                                Text(
                                  _fmtData(ts),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                              if (detalhes.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(detalhes),
                              ],
                              if (custo > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Custo: ${_money(custo)}',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              if (receita > 0) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Receita: ${_money(receita)}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'excluir')
                                _confirmarExclusaoItem(_docs[i].id);
                              if (value == 'editar') {
                                _mostrarDialogoPerdaOuEditar(
                                  _docs[i].id,
                                  (e['detalhes'] ?? '').toString(),
                                  (e['observacao_extra'] ?? '').toString(),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'editar',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.edit,
                                      color: Colors.orange,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Editar texto'),
                                  ],
                                ),
                              ),
                              if (_enableHardDelete)
                                const PopupMenuItem(
                                  value: 'excluir',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Excluir (DEV)'),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: _docs.length),
                  ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: _loadingMore
                          ? const CircularProgressIndicator()
                          : (!_hasMore
                                ? const Text('Fim do histórico.')
                                : TextButton.icon(
                                    onPressed: _loadMore,
                                    icon: const Icon(Icons.expand_more),
                                    label: const Text('Carregar mais'),
                                  )),
                    ),
                  ),
                ),

                const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// -----------------------
// UI widgets pequenos
// -----------------------
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Card de menu
class _CardMenu extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CardMenu({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
