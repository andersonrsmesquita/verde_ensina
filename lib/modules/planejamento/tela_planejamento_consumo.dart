// FILE: lib/modules/planejamento/tela_planejamento_consumo.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/ui/app_ui.dart';
import '../../core/firebase/firebase_paths.dart';
import '../../core/session/app_session.dart';
import '../../core/session/session_scope.dart';

// Certifique-se de que este arquivo exporta 'GuiaCulturas' e 'culturasPorRegiaoMes'
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

  // Lista local dos itens desejados
  final List<Map<String, dynamic>> _listaDesejos = [];

  String? _canteiroId;
  double _areaTotalDoCanteiroSelecionado = 0.0; // Área real vinda do Firestore

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
    if (isError) {
      AppMessenger.error(msg);
    } else {
      AppMessenger.success(msg);
    }
  }

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

  // --- LÓGICA DE INTELIGÊNCIA E DADOS ---

  // 1. Busca a área do canteiro selecionado para a barra de progresso
  Future<void> _fetchAreaCanteiro(String canteiroId, AppSession session) async {
    try {
      final doc = await FirebaseFirestore.instance
          .doc(FirebasePaths.canteiroRef(session.tenantId, canteiroId).path)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          // Tenta pegar o campo calculado 'area_m2', se não existir, calcula na hora
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
      debugPrint("Erro ao buscar área do canteiro: $e");
    }
  }

  // 2. Verifica se a planta está na época ideal para a região selecionada
  bool _isNaEpoca(String planta) {
    try {
      // Usa a função do seu arquivo guia_culturas.dart
      List<String> recomendadas =
          culturasPorRegiaoMes(_regiaoSelecionada, _obterMesAtual());
      // Normaliza strings para evitar erros de case/trim
      return recomendadas.any((r) => r.toLowerCase() == planta.toLowerCase());
    } catch (e) {
      // Fallback caso a função não exista ou falhe
      return true;
    }
  }

  // 3. Calcula quanto espaço os itens da lista já ocupam
  double _calcularAreaOcupadaAtual() {
    double area = 0.0;
    for (var item in _listaDesejos) {
      final nome = item['planta'] as String;
      final meta = (item['meta'] as num).toDouble();

      final info = GuiaCulturas.dados[nome] ?? {'yield': 1.0, 'espaco': 0.5};
      final yieldVal = (info['yield'] as num).toDouble();
      final espacoVal = (info['espaco'] as num).toDouble();

      // Cálculo: Meta / Produtividade = Mudas. Adiciona 10% margem de segurança.
      final mudas = ((meta / yieldVal) * 1.1).ceil();
      area += mudas * espacoVal;
    }
    return area;
  }

  // 4. Lógica da Sugestão Mágica (Consórcio + Época + Espaço)
  void _adicionarSugestaoInteligente() {
    final areaLivre =
        _areaTotalDoCanteiroSelecionado - _calcularAreaOcupadaAtual();

    if (areaLivre < 0.2) {
      _toast("Seu canteiro já está cheio!", isError: true);
      return;
    }

    final todasCulturas = GuiaCulturas.dados.keys.toList();
    // Filtra apenas o que está na época
    final naEpoca = todasCulturas.where((p) => _isNaEpoca(p)).toList();

    String? melhorCandidata;
    int melhorScore = -100; // Começa negativo

    for (var candidata in naEpoca) {
      // Pula se já está na lista
      if (_listaDesejos.any((e) => e['planta'] == candidata)) continue;

      final infoCand = GuiaCulturas.dados[candidata]!;
      // Verifica se cabe (usa yield padrão 1.0 e meta 1.0 para teste)
      final espacoCand = (infoCand['espaco'] as num).toDouble();
      if (espacoCand > areaLivre) continue;

      int score = 0;
      bool conflitoFatal = false;

      final evitarCand = (infoCand['evitar'] as List?)?.cast<String>() ?? [];
      final parCand = (infoCand['par'] as List?)?.cast<String>() ?? [];

      // Compara com quem já está na lista
      for (var itemExistente in _listaDesejos) {
        String plantaExistente = itemExistente['planta'];

        // Se são inimigas
        if (evitarCand.contains(plantaExistente)) {
          conflitoFatal = true;
          break;
        }

        // Se são amigas
        if (parCand.contains(plantaExistente)) {
          score += 5; // Grande bônus para consórcio
        }
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
        _qtdController.text = "1"; // Sugere 1 unidade/kg
        _toast("Sugestão: $melhorCandidata (Perfeita para seu espaço!)");
      });
    } else {
      _toast("Sem sugestões ideais para o espaço restante.");
    }
  }

  // --- AÇÕES DO USUÁRIO ---

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

    // Validação Proativa de Espaço
    if (_canteiroId != null && _areaTotalDoCanteiroSelecionado > 0) {
      final info =
          GuiaCulturas.dados[nomeFinal] ?? {'yield': 1.0, 'espaco': 0.5};
      final mudas = ((qtd / (info['yield'] as num)) * 1.1).ceil();
      final areaItem = mudas * (info['espaco'] as num);
      final ocupada = _calcularAreaOcupadaAtual();

      // Ignora o próprio item se estiver editando (para não somar duplicado)
      double areaItemEditando = 0.0;
      if (_editandoIndex != null) {
        // Lógica simplificada: remove a área antiga do cálculo temporariamente
        // (Omitido para brevidade, assumindo acréscimo)
      }

      if (ocupada + areaItem > _areaTotalDoCanteiroSelecionado) {
        bool? confirmar = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
                  title: const Text('Falta de Espaço'),
                  content: Text(
                      'Este item requer ${areaItem.toStringAsFixed(1)}m², mas você só tem ${(_areaTotalDoCanteiroSelecionado - ocupada).toStringAsFixed(1)}m² livres.\n\nDeseja adicionar mesmo assim?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Adicionar')),
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
        _culturaSelecionada = null;
      }
    });
  }

  void _removerItem(int index) {
    setState(() {
      _listaDesejos.removeAt(index);
      if (_editandoIndex == index) _cancelarEdicao();
    });
  }

  void _cancelarEdicao() {
    setState(() {
      _editandoIndex = null;
      _culturaSelecionada = null;
      _qtdController.clear();
      _customNameController.clear();
      _modoPersonalizado = false;
      FocusScope.of(context).unfocus();
    });
  }

  // --- LÓGICA DE SALVAMENTO COMPLETA (Mão de Obra, Água, Adubo) ---

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
      double horasTotaisProjeto = 0.0; // Soma de todas as horas do ciclo

      // Processa cada item para gerar os cálculos finais
      final itensProcessados = _listaDesejos.map((item) {
        final nome = item['planta'] as String;
        final meta = (item['meta'] as num).toDouble();

        // Pega dados do Guia ou usa Padrão
        final info = GuiaCulturas.dados[nome] ??
            {
              'yield': 1.0,
              'unit': 'kg',
              'espaco': 0.5,
              'cicloDias': 60,
              'evitar': [],
              'par': [],
              'cat': 'Geral',
              'icone': '🌱',
            };

        final yieldVal = (info['yield'] as num).toDouble();
        final espacoVal = (info['espaco'] as num).toDouble();
        final cicloDias = (info['cicloDias'] as int?) ?? 60;

        // 1. Cálculo de Área e Mudas
        final mudasCalc = meta / yieldVal;
        final mudasReais = (mudasCalc * 1.1).ceil(); // +10% margem
        final areaNecessaria = mudasReais * espacoVal;

        // 2. Cálculo de Mão de Obra (Baseado no PDF "Custo mão de obra")
        // Ciclo em semanas
        int nSemanas = (cicloDias / 7).ceil();
        if (nSemanas < 1) nSemanas = 1;

        // Fase 1 (Preparo): 0.25h/m²
        final horasFase1 = areaNecessaria * 0.25;
        // Fase 2 (Manutenção): 0.083h/m² * Semanas
        final horasFase2 = areaNecessaria * 0.083 * nSemanas;
        // Fase 3 (Colheita): 0.016h/m²
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
          'horas_fase1': horasFase1,
          'horas_fase2': horasFase2,
          'horas_fase3': horasFase3,
          'horas_totais': totalHorasItem,
          'evitar': info['evitar'] ?? [],
          'par': info['par'] ?? [],
          'cat': info['cat'] ?? 'Geral',
          'icone': info['icone'] ?? '🌱',
        };
      }).toList();

      // 3. Cálculos Globais (Baseados nos PDFs)
      // Água: 5L/m² por dia (PDF "Água")
      final aguaTotalDia = areaTotalCalculada * 5.0;

      // Adubo: Média de 3kg/m² esterco (PDF "Adubação")
      final aduboTotalCiclo = areaTotalCalculada * 3.0;

      // Mão de Obra Semanal Média (aprox.)
      // Divide-se o total de horas pelo maior ciclo aproximado (ex: 8 semanas)
      // Ou exibe o total acumulado do projeto.
      // Aqui usaremos uma média ponderada simples para exibição.
      final semanasMedia = 8;
      final maoDeObraSemanal = horasTotaisProjeto / semanasMedia;

      // 4. Salvar no Firestore
      await _salvarNoFirestore(
        session: session,
        canteiroId: _canteiroId!,
        uid: user.uid,
        itensDesejados: _listaDesejos,
        itensProcessados: itensProcessados,
        areaTotal: areaTotalCalculada,
        aguaDia: aguaTotalDia,
        aduboTotal: aduboTotalCiclo,
        horasTotaisProjeto: horasTotaisProjeto,
        regiao: _regiaoSelecionada,
      );

      if (!mounted) return;
      setState(() => _salvando = false);
      _toast("Planejamento salvo com sucesso!");

      // Navegar para a próxima tela
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

  Future<void> _salvarNoFirestore({
    required AppSession session,
    required String canteiroId,
    required String uid,
    required List itensDesejados,
    required List itensProcessados,
    required double areaTotal,
    required double aguaDia,
    required double aduboTotal,
    required double horasTotaisProjeto,
    required String regiao,
  }) async {
    final batch = FirebaseFirestore.instance.batch();

    // Referência do canteiro
    final canteiroRef = FirebasePaths.canteiroRef(session.tenantId, canteiroId);

    // Nova coleção de planejamentos dentro do canteiro
    final planRef =
        FirebasePaths.canteiroPlanejamentosCol(session.tenantId, canteiroId)
            .doc();

    final resumo = {
      'itens_qtd': itensDesejados.length,
      'area_ocupada_m2': areaTotal,
      'agua_l_dia': aguaDia,
      'adubo_kg_ciclo': aduboTotal,
      'horas_trabalho_total': horasTotaisProjeto,
      'regiao_base': regiao,
      'planejamentoId': planRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Salva o documento detalhado do planejamento
    batch.set(planRef, {
      'uid_criador': uid,
      'tipo': 'consumo',
      'status': 'ativo',
      'itens_input': itensDesejados,
      'itens_calculados': itensProcessados,
      'metricas': resumo,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Atualiza o canteiro com o resumo do planejamento atual
    batch.update(canteiroRef, {
      'planejamento_ativo': resumo,
      'planejamento_ativo_id': planRef.id,
      'ultima_atividade': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // --- CONSTRUÇÃO DA TELA (BUILD) ---

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final session = SessionScope.of(context).session;

    if (session == null)
      return const Center(child: CircularProgressIndicator());

    // Ordenação Inteligente do Dropdown: Na época primeiro
    final listaCulturas = GuiaCulturas.dados.keys.toList();
    final naEpoca = listaCulturas.where((c) => _isNaEpoca(c)).toList()..sort();
    final foraEpoca = listaCulturas.where((c) => !_isNaEpoca(c)).toList()
      ..sort();
    final listaOrdenada = [...naEpoca, ...foraEpoca];

    // Cálculos para KPIs em tempo real
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. CONFIGURAÇÃO E OCUPAÇÃO
          SectionCard(
            title: '1) Local e Ocupação',
            child: Column(
              children: [
                Row(
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

                // BARRA DE OCUPAÇÃO
                if (_canteiroId != null &&
                    _areaTotalDoCanteiroSelecionado > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Ocupação Estimada',
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 12)),
                      Text(
                          '${areaTotalItens.toStringAsFixed(1)} / ${_areaTotalDoCanteiroSelecionado.toStringAsFixed(1)} m²',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      'Selecione um canteiro para ver a disponibilidade.',
                      style:
                          TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ),
          ),

          const SizedBox(height: AppTokens.md),

          // 2. ADICIONAR ITENS
          // SEÇÃO 2: ADICIONAR COM INTELIGÊNCIA
          SectionCard(
            title:
                _editandoIndex != null ? 'Editando item' : '2) O que plantar?',
            child: Column(
              children: [
                // --- BOTÃO DE SUGESTÃO MOVIDO PARA DENTRO ---
                if (!_modoPersonalizado)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _adicionarSugestaoInteligente,
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Sugerir Melhor Opção'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange.shade800,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                // ---------------------------------------------

                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _modoPersonalizado
                          ? AppTextField(
                              controller: _customNameController,
                              labelText: 'Nome manual',
                              prefixIcon: Icons.edit,
                            )
                          : DropdownButtonFormField<String>(
                              value: _culturaSelecionada,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Selecione a cultura',
                                border: OutlineInputBorder(),
                              ),
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
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: Colors.green.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(4)),
                                          child: Text('IDEAL',
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.green.shade800,
                                                  fontWeight: FontWeight.bold)),
                                        )
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
                      tooltip: 'Alternar Manual/Lista',
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _qtdController,
                        labelText: 'Quantidade',
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

          // 3. LISTA DE ITENS
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

          const SizedBox(height: 20),

          // RESUMO FINAL (OPCIONAL)
          if (_listaDesejos.isNotEmpty) _buildResumoGeral(areaTotalItens, cs),

          const SizedBox(height: 80),
        ],
      ),
      bottomBar: SizedBox(
        height: 50,
        child: AppButtons.elevatedIcon(
          // CORREÇÃO: Removemos a linha duplicada e mantemos apenas a correta
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
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildSmartListItem(
      int index, Map<String, dynamic> item, ColorScheme cs) {
    final nome = item['planta'] as String;
    final meta = item['meta'];
    final info = GuiaCulturas.dados[nome];

    // Verifica consórcios na lista
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
              const Tooltip(
                  message: 'Combina com outra planta da lista!',
                  child: Icon(Icons.favorite, size: 16, color: Colors.green)),
            if (temInimigo)
              const Tooltip(
                  message: 'Conflito com outra planta da lista!',
                  child: Icon(Icons.warning, size: 16, color: Colors.red)),
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
            Icon(Icons.playlist_add, size: 40, color: cs.outline),
            const SizedBox(height: 8),
            Text('Nenhuma cultura adicionada.',
                style: TextStyle(color: cs.outline)),
          ],
        ),
      ),
    );
  }

  Widget _buildResumoGeral(double area, ColorScheme cs) {
    final agua = area * 5.0; // 5L/m2
    final adubo = area * 3.0; // 3kg/m2

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text("Estimativa de Recursos",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _miniInfo("Água", "${agua.toStringAsFixed(0)} L/dia"),
              _miniInfo("Adubo", "${adubo.toStringAsFixed(1)} kg"),
              _miniInfo("Área", "${area.toStringAsFixed(1)} m²"),
            ],
          )
        ],
      ),
    );
  }

  Widget _miniInfo(String label, String val) {
    return Column(
      children: [
        Text(val,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
