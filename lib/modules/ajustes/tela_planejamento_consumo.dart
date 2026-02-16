// FILE: lib/modules/planejamento/tela_planejamento_consumo.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/ui/app_ui.dart';
import '../../core/firebase/firebase_paths.dart';
import '../../core/session/app_session.dart';
import '../../core/session/session_scope.dart';

import '../canteiros/guia_culturas.dart';
import '../planejamento/tela_gerador_canteiros.dart';
import '../canteiros/widgets/canteiro_picker_dropdown.dart';

class TelaPlanejamentoConsumo extends StatefulWidget {
  const TelaPlanejamentoConsumo({super.key});

  @override
  State<TelaPlanejamentoConsumo> createState() =>
      _TelaPlanejamentoConsumoState();
}

class _TelaPlanejamentoConsumoState extends State<TelaPlanejamentoConsumo> {
  User? get _user => FirebaseAuth.instance.currentUser;

  final List<Map<String, dynamic>> _listaDesejos = [];

  String? _canteiroId;
  double _areaTotalDoCanteiroSelecionado = 0.0;
  String? _culturaSelecionada;
  String _regiaoSelecionada = 'Sudeste';

  final List<String> _regioes = [
    'Norte',
    'Nordeste',
    'Centro-Oeste',
    'Sudeste',
    'Sul'
  ];

  final _qtdController = TextEditingController();
  final _customNameController = TextEditingController();

  bool _modoPersonalizado = false;
  int? _editandoIndex;
  bool _salvando = false;

  @override
  void dispose() {
    _qtdController.dispose();
    _customNameController.dispose();
    super.dispose();
  }

  // --- UI Helpers ---
  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // --- Lógica de Dados ---

  String _formatarTexto(String texto) {
    final t = texto.trim();
    if (t.isEmpty) return '';
    return t.split(RegExp(r'\s+')).map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  double _parseQtd(String v) {
    return double.tryParse(v.trim().replaceAll(',', '.')) ?? 0.0;
  }

  String _obterMesAtual() {
    const meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro'
    ];
    return meses[DateTime.now().month - 1];
  }

  Future<void> _fetchAreaCanteiro(String canteiroId, AppSession session) async {
    try {
      final doc = await FirebaseFirestore.instance
          .doc(FirebasePaths.canteiroRef(session.tenantId, canteiroId).path)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          if (data.containsKey('area_m2')) {
            _areaTotalDoCanteiroSelecionado =
                (data['area_m2'] as num).toDouble();
          } else if (data['comprimento'] != null && data['largura'] != null) {
            _areaTotalDoCanteiroSelecionado =
                (data['comprimento'] as num).toDouble() *
                    (data['largura'] as num).toDouble();
          } else {
            _areaTotalDoCanteiroSelecionado = 0.0;
          }
        });
      }
    } catch (e) {
      debugPrint("Erro ao buscar área: $e");
    }
  }

  // --- NOVA FUNÇÃO: CRIAÇÃO RÁPIDA DE CANTEIRO ---
  Future<void> _criarCanteiroRapido(AppSession session) async {
    final nomeCtl = TextEditingController();
    final compCtl = TextEditingController();
    final largCtl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Novo Local de Plantio"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Crie um canteiro ou vaso rapidamente para usar agora."),
            const SizedBox(height: 16),
            TextField(
              controller: nomeCtl,
              decoration: const InputDecoration(
                  labelText: "Nome (ex: Canteiro 1, Vaso Grande)",
                  border: OutlineInputBorder()),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: compCtl,
                    decoration: const InputDecoration(
                        labelText: "Comp. (m)",
                        border: OutlineInputBorder(),
                        hintText: "ex: 2.0"),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: largCtl,
                    decoration: const InputDecoration(
                        labelText: "Larg. (m)",
                        border: OutlineInputBorder(),
                        hintText: "ex: 1.0"),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              final nome = nomeCtl.text.trim();
              final comp =
                  double.tryParse(compCtl.text.replaceAll(',', '.')) ?? 0.0;
              final larg =
                  double.tryParse(largCtl.text.replaceAll(',', '.')) ?? 0.0;

              if (nome.isEmpty || comp <= 0 || larg <= 0) {
                // Feedback rápido de erro
                return;
              }

              try {
                // 1. Salva no Firestore
                final docRef = await FirebaseFirestore.instance
                    .collection(
                        FirebasePaths.canteirosCol(session.tenantId).path)
                    .add({
                  'nome': nome,
                  'comprimento': comp,
                  'largura': larg,
                  'area_m2': (comp * larg), // Já salva a área calculada
                  'tipo': 'canteiro', // Default
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (!mounted) return;
                Navigator.pop(ctx); // Fecha dialog

                // 2. Seleciona automaticamente o novo canteiro
                setState(() {
                  _canteiroId = docRef.id;
                });

                // 3. Atualiza a barra de progresso
                _fetchAreaCanteiro(docRef.id, session);

                _toast("Local '$nome' criado e selecionado!");
              } catch (e) {
                _toast("Erro ao criar: $e", isError: true);
              }
            },
            child: const Text("Criar e Usar"),
          )
        ],
      ),
    );
  }
  // ------------------------------------------------

  bool _isNaEpoca(String planta) {
    try {
      List<String> recomendadas =
          culturasPorRegiaoMes(_regiaoSelecionada, _obterMesAtual());
      return recomendadas.any((r) => r.toLowerCase() == planta.toLowerCase());
    } catch (e) {
      return true;
    }
  }

  double _calcularAreaOcupadaAtual() {
    double area = 0.0;
    for (var item in _listaDesejos) {
      final nome = item['planta'] as String;
      final meta = (item['meta'] as num).toDouble();
      final info = GuiaCulturas.dados[nome] ?? {'yield': 1.0, 'espaco': 0.5};
      final yieldVal = (info['yield'] as num).toDouble();
      final espacoVal = (info['espaco'] as num).toDouble();
      final mudas = ((meta / yieldVal) * 1.1).ceil();
      area += mudas * espacoVal;
    }
    return area;
  }

  // --- Funcionalidades de Ajuda e Reset ---

  void _mostrarTutorial() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.help_outline, color: Colors.blue),
          SizedBox(width: 8),
          Text("Como funciona?")
        ]),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _TutorialStep(
                  num: "1",
                  text:
                      "Escolha o Local. Se não tiver, clique no '+' para criar um rápido."),
              _TutorialStep(
                  num: "2",
                  text:
                      "Adicione as culturas. O sistema avisa se está na época certa!"),
              _TutorialStep(
                  num: "3",
                  text: "Use o botão 'Sugerir' se sobrar espaço no canteiro."),
              _TutorialStep(
                  num: "4", text: "Finalize para gerar o calendário."),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Entendi")),
        ],
      ),
    );
  }

  void _confirmarLimpeza() {
    if (_listaDesejos.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Limpar lista?"),
        content: const Text("Isso removerá todos os itens adicionados."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar")),
          TextButton(
              onPressed: () {
                setState(() => _listaDesejos.clear());
                Navigator.pop(ctx);
              },
              child: const Text("Limpar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _adicionarSugestaoInteligente() {
    final areaLivre =
        _areaTotalDoCanteiroSelecionado - _calcularAreaOcupadaAtual();
    if (areaLivre < 0.2) {
      _toast("Seu canteiro já está cheio!", isError: true);
      return;
    }

    final todasCulturas = GuiaCulturas.dados.keys.toList();
    final naEpoca = todasCulturas.where((p) => _isNaEpoca(p)).toList();

    String? melhorCandidata;
    int melhorScore = -100;

    for (var candidata in naEpoca) {
      if (_listaDesejos.any((e) => e['planta'] == candidata)) continue;

      final infoCand = GuiaCulturas.dados[candidata]!;
      final espacoCand = (infoCand['espaco'] as num).toDouble();
      if (espacoCand > areaLivre) continue;

      int score = 0;
      bool conflitoFatal = false;
      final evitarCand = (infoCand['evitar'] as List?)?.cast<String>() ?? [];
      final parCand = (infoCand['par'] as List?)?.cast<String>() ?? [];

      for (var itemExistente in _listaDesejos) {
        String plantaExistente = itemExistente['planta'];
        if (evitarCand.contains(plantaExistente)) {
          conflitoFatal = true;
          break;
        }
        if (parCand.contains(plantaExistente)) score += 5;
      }

      if (!conflitoFatal) {
        if (score > melhorScore) {
          melhorScore = score;
          melhorCandidata = candidata;
        }
      }
    }

    if (melhorCandidata != null) {
      setState(() {
        _culturaSelecionada = melhorCandidata;
        _qtdController.text = "1";
        _toast("Sugestão: $melhorCandidata");
      });
    } else {
      _toast("Sem sugestões ideais para o espaço.");
    }
  }

  Future<void> _salvarItem() async {
    String nomeFinal;
    if (_modoPersonalizado) {
      if (_customNameController.text.trim().isEmpty) {
        _toast('Informe o nome.', isError: true);
        return;
      }
      nomeFinal = _formatarTexto(_customNameController.text);
    } else {
      if (_culturaSelecionada == null) {
        _toast('Selecione uma cultura.', isError: true);
        return;
      }
      nomeFinal = _culturaSelecionada!;
    }

    final qtd = _parseQtd(_qtdController.text);
    if (qtd <= 0) {
      _toast('Qtd inválida.', isError: true);
      return;
    }

    if (_canteiroId != null && _areaTotalDoCanteiroSelecionado > 0) {
      final info =
          GuiaCulturas.dados[nomeFinal] ?? {'yield': 1.0, 'espaco': 0.5};
      final mudas = ((qtd / (info['yield'] as num)) * 1.1).ceil();
      final areaItem = mudas * (info['espaco'] as num);
      final ocupada = _calcularAreaOcupadaAtual();

      if (ocupada + areaItem > _areaTotalDoCanteiroSelecionado) {
        bool? confirmar = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
                  title: const Text('Falta de Espaço'),
                  content: Text(
                      'Este item requer ${areaItem.toStringAsFixed(1)}m², mas só restam ${(_areaTotalDoCanteiroSelecionado - ocupada).toStringAsFixed(1)}m².\n\nAdicionar assim mesmo?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Adicionar',
                            style: TextStyle(color: Colors.orange))),
                  ],
                ));
        if (confirmar != true) return;
      }
    }

    setState(() {
      final novoItem = {
        'planta': nomeFinal,
        'meta': qtd,
        'isCustom': _modoPersonalizado
      };
      if (_editandoIndex != null) {
        _listaDesejos[_editandoIndex!] = novoItem;
        _editandoIndex = null;
      } else {
        _listaDesejos.add(novoItem);
      }
      _culturaSelecionada = null;
      _qtdController.clear();
      _customNameController.clear();
      _modoPersonalizado = false;
      FocusScope.of(context).unfocus();
    });
  }

  void _iniciarEdicao(int index) {
    final item = _listaDesejos[index];
    setState(() {
      _editandoIndex = index;
      _qtdController.text = (item['meta'] as num).toString();
      final nome = (item['planta'] as String).trim();
      if (GuiaCulturas.dados.containsKey(nome)) {
        _modoPersonalizado = false;
        _culturaSelecionada = nome;
      } else {
        _modoPersonalizado = true;
        _customNameController.text = nome;
      }
    });
  }

  void _removerItem(int index) {
    setState(() {
      _listaDesejos.removeAt(index);
      if (_editandoIndex == index) {
        _editandoIndex = null;
        _qtdController.clear();
        _customNameController.clear();
      }
    });
  }

  Future<void> _gerarESalvarEIrParaGerador(AppSession session) async {
    if (_listaDesejos.isEmpty) {
      _toast('Adicione itens à lista.', isError: true);
      return;
    }
    if (_canteiroId == null) {
      _toast('Selecione um canteiro.', isError: true);
      return;
    }
    final user = _user;
    if (user == null) return;

    setState(() => _salvando = true);

    try {
      double areaTotalCalculada = 0.0;
      double horasTotaisProjeto = 0.0;

      final itensProcessados = _listaDesejos.map((item) {
        final nome = item['planta'] as String;
        final meta = (item['meta'] as num).toDouble();
        final info = GuiaCulturas.dados[nome] ??
            {
              'yield': 1.0,
              'unit': 'kg',
              'espaco': 0.5,
              'cicloDias': 60,
              'evitar': [],
              'par': [],
              'cat': 'Geral',
              'icone': '🌱'
            };

        final yieldVal = (info['yield'] as num).toDouble();
        final espacoVal = (info['espaco'] as num).toDouble();
        final cicloDias = (info['cicloDias'] as int?) ?? 60;

        final mudasCalc = meta / yieldVal;
        final mudasReais = (mudasCalc * 1.1).ceil();
        final areaNecessaria = mudasReais * espacoVal;

        int nSemanas = (cicloDias / 7).ceil();
        if (nSemanas < 1) nSemanas = 1;

        final horasFase1 = areaNecessaria * 0.25;
        final horasFase2 = areaNecessaria * 0.083 * nSemanas;
        final horasFase3 = areaNecessaria * 0.016;
        final totalHorasItem = horasFase1 + horasFase2 + horasFase3;

        areaTotalCalculada += areaNecessaria;
        horasTotaisProjeto += totalHorasItem;

        return {
          'planta': nome,
          'mudas': mudasReais,
          'area': areaNecessaria,
          'ciclo_dias': cicloDias,
          'ciclo_semanas': nSemanas,
          'horas_totais': totalHorasItem,
          'cat': info['cat'] ?? 'Geral',
          'icone': info['icone'] ?? '🌱',
        };
      }).toList();

      final aguaTotalDia = areaTotalCalculada * 5.0;
      final aduboTotalCiclo = areaTotalCalculada * 3.0;

      final batch = FirebaseFirestore.instance.batch();
      final canteiroRef =
          FirebasePaths.canteiroRef(session.tenantId, _canteiroId!);
      final planRef =
          FirebasePaths.canteiroPlanejamentosCol(session.tenantId, _canteiroId!)
              .doc();

      final resumo = {
        'itens_qtd': _listaDesejos.length,
        'area_ocupada_m2': areaTotalCalculada,
        'agua_l_dia': aguaTotalDia,
        'adubo_kg_ciclo': aduboTotalCiclo,
        'horas_trabalho_total': horasTotaisProjeto,
        'regiao_base': _regiaoSelecionada,
        'planejamentoId': planRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      batch.set(planRef, {
        'uid_criador': user.uid,
        'tipo': 'consumo',
        'status': 'ativo',
        'itens_input': _listaDesejos,
        'itens_calculados': itensProcessados,
        'metricas': resumo,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.update(canteiroRef, {
        'planejamento_ativo': resumo,
        'planejamento_ativo_id': planRef.id,
        'ultima_atividade': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;
      setState(() => _salvando = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              TelaGeradorCanteiros(itensPlanejados: itensProcessados),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _salvando = false);
      _toast('Erro ao salvar: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final session = SessionScope.of(context).session;

    if (session == null) {
      return const PageContainer(
        title: 'Carregando...',
        scroll: false,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final listaCulturas = GuiaCulturas.dados.keys.toList();
    final naEpoca = listaCulturas.where((c) => _isNaEpoca(c)).toList()..sort();
    final foraEpoca = listaCulturas.where((c) => !_isNaEpoca(c)).toList()
      ..sort();
    final listaOrdenada = [...naEpoca, ...foraEpoca];

    double areaTotalItens = 0;
    for (var item in _listaDesejos) {
      final nome = item['planta'] as String;
      final meta = (item['meta'] as num).toDouble();
      final info = GuiaCulturas.dados[nome] ?? {'yield': 1.0, 'espaco': 0.5};
      final mudas = ((meta / (info['yield'] as num)) * 1.1).ceil();
      areaTotalItens += mudas * (info['espaco'] as num);
    }

    return PageContainer(
      title: 'Plano de Consumo',
      subtitle: 'Assistente Inteligente',
      scroll: true,
      backgroundColor: cs.surfaceContainerLowest,
      maxWidth: double.infinity,
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline),
          color: Colors.blue,
          tooltip: 'Guia Rápido',
          onPressed: _mostrarTutorial,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          color: Colors.red,
          tooltip: 'Limpar Lista',
          onPressed: _confirmarLimpeza,
        ),
      ],
      bottomBar: SizedBox(
        height: 50,
        width: double.infinity,
        child: AppButtons.elevatedIcon(
          onPressed:
              _salvando ? null : () => _gerarESalvarEIrParaGerador(session),
          icon: _salvando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.check_circle),
          label: Text(_salvando ? 'PROCESSANDO...' : 'FINALIZAR PLANEJAMENTO'),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // SEÇÃO 1
          SectionCard(
            title: '1) Local e Ocupação',
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 3,
                      child: CanteiroPickerDropdown(
                        tenantId: session.tenantId,
                        selectedId: _canteiroId,
                        onSelect: (id) {
                          setState(() => _canteiroId = id);
                          if (id != null) _fetchAreaCanteiro(id, session);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // BOTÃO DE CRIAR NOVO CANTEIRO (AQUI!)
                    Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(8)),
                      child: IconButton(
                        icon: const Icon(Icons.add_location_alt_outlined),
                        tooltip: 'Criar Novo Local Agora',
                        onPressed: () => _criarCanteiroRapido(session),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _regiaoSelecionada,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Região',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 14),
                        ),
                        items: _regioes
                            .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(r,
                                    style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _regiaoSelecionada = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_canteiroId != null &&
                    _areaTotalDoCanteiroSelecionado > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Ocupação',
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 12)),
                      Text(
                          '${areaTotalItens.toStringAsFixed(1)} / ${_areaTotalDoCanteiroSelecionado.toStringAsFixed(1)} m²',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (areaTotalItens / _areaTotalDoCanteiroSelecionado)
                          .clamp(0.0, 1.0),
                      minHeight: 12,
                      backgroundColor: cs.surfaceVariant,
                      color: areaTotalItens > _areaTotalDoCanteiroSelecionado
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ] else
                  const Text(
                      'Selecione um local ou crie um novo para ver o espaço.',
                      style:
                          TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ),
          ),

          const SizedBox(height: AppTokens.md),

          // SEÇÃO 2
          SectionCard(
            title:
                _editandoIndex != null ? 'Editando item' : '2) O que plantar?',
            child: Column(
              children: [
                if (!_modoPersonalizado)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _adicionarSugestaoInteligente,
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Sugestão Mágica'),
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.orange.shade800,
                          visualDensity: VisualDensity.compact),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _modoPersonalizado
                          ? AppTextField(
                              controller: _customNameController,
                              labelText: 'Nome manual')
                          : DropdownButtonFormField<String>(
                              value: _culturaSelecionada,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  labelText: 'Cultura',
                                  border: OutlineInputBorder()),
                              items: listaOrdenada.map((k) {
                                final isIdeal = naEpoca.contains(k);
                                final icone =
                                    (GuiaCulturas.dados[k]?['icone'] ?? '🌱')
                                        .toString();
                                return DropdownMenuItem(
                                  value: k,
                                  child: Row(
                                    children: [
                                      Text(icone),
                                      const SizedBox(width: 8),
                                      Text(k),
                                      if (isIdeal) ...[
                                        const Spacer(),
                                        const Text('IDEAL',
                                            style: TextStyle(
                                                fontSize: 9,
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold)),
                                      ]
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) =>
                                  setState(() => _culturaSelecionada = v),
                            ),
                    ),
                    IconButton(
                      onPressed: () => setState(
                          () => _modoPersonalizado = !_modoPersonalizado),
                      icon: Icon(
                          _modoPersonalizado ? Icons.list : Icons.keyboard),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _qtdController,
                        labelText: 'Qtd',
                        suffixText: _culturaSelecionada != null
                            ? (GuiaCulturas.dados[_culturaSelecionada]
                                        ?['unit'] ??
                                    'un')
                                .toString()
                            : 'un',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButtons.elevatedIcon(
                        onPressed: _salvarItem,
                        icon: Icon(
                            _editandoIndex != null ? Icons.save : Icons.add),
                        label: Text(
                            _editandoIndex != null ? 'SALVAR' : 'ADICIONAR'),
                      ),
                    )
                  ],
                )
              ],
            ),
          ),

          const SizedBox(height: AppTokens.md),

          // SEÇÃO 3
          SectionCard(
            title: '3) Sua Lista (${_listaDesejos.length})',
            child: _listaDesejos.isEmpty
                ? _buildEmptyState(cs)
                : Column(
                    children: _listaDesejos.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      return _buildSmartListItem(i, item, cs);
                    }).toList(),
                  ),
          ),

          if (_listaDesejos.isNotEmpty) ...[
            const SizedBox(height: AppTokens.md),
            _buildResumoGeral(areaTotalItens, cs),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSmartListItem(
      int index, Map<String, dynamic> item, ColorScheme cs) {
    final nome = item['planta'] as String;
    final meta = item['meta'];
    final info = GuiaCulturas.dados[nome];

    bool temAmigo = false;
    bool temInimigo = false;

    if (info != null) {
      final amigos = (info['par'] as List?)?.cast<String>() ?? [];
      final inimigos = (info['evitar'] as List?)?.cast<String>() ?? [];

      for (var outroItem in _listaDesejos) {
        if (outroItem == item) continue;
        String outroNome = outroItem['planta'];
        if (amigos.contains(outroNome)) temAmigo = true;
        if (inimigos.contains(outroNome)) temInimigo = true;
      }
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
            color: temInimigo ? Colors.red.shade200 : cs.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: temInimigo
              ? Colors.red.shade50
              : (temAmigo ? Colors.green.shade50 : cs.surfaceVariant),
          child: Text(info?['icone'] ?? '🌱',
              style: const TextStyle(fontSize: 20)),
        ),
        title: Row(
          children: [
            Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            if (temAmigo)
              const Icon(Icons.favorite, size: 16, color: Colors.green),
            if (temInimigo)
              const Icon(Icons.warning, size: 16, color: Colors.red),
          ],
        ),
        subtitle: Text('Meta: $meta ${(info?['unit'] ?? 'un')}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _iniciarEdicao(index)),
            IconButton(
                icon: Icon(Icons.delete, size: 20, color: cs.error),
                onPressed: () => _removerItem(index)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.playlist_add,
                size: 40, color: cs.outline.withOpacity(0.5)),
            const SizedBox(height: 8),
            Text('Nenhuma cultura adicionada.',
                style: TextStyle(color: cs.outline)),
          ],
        ),
      ),
    );
  }

  Widget _buildResumoGeral(double area, ColorScheme cs) {
    final agua = area * 5.0;
    final adubo = area * 3.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cs.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.primary.withOpacity(0.2))),
      child: Column(
        children: [
          Text("Estimativa de Recursos",
              style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _miniInfo("Água", "${agua.toStringAsFixed(0)} L/dia",
                  Icons.water_drop, Colors.blue),
              _miniInfo("Adubo", "${adubo.toStringAsFixed(1)} kg", Icons.grass,
                  Colors.brown),
              _miniInfo("Área", "${area.toStringAsFixed(1)} m²",
                  Icons.aspect_ratio, Colors.green),
            ],
          )
        ],
      ),
    );
  }

  Widget _miniInfo(String label, String val, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(val,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// Widget auxiliar simples para o texto do tutorial
class _TutorialStep extends StatelessWidget {
  final String num;
  final String text;
  const _TutorialStep({required this.num, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
              radius: 10,
              backgroundColor: Colors.blue.shade100,
              child: Text(num,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
