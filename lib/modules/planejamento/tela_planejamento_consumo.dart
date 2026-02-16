// FILE: lib/modules/planejamento/tela_planejamento_consumo.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/ui/app_ui.dart';
import '../../core/firebase/firebase_paths.dart';
import '../../core/session/app_session.dart';
import '../../core/session/session_scope.dart';

import '../canteiros/guia_culturas.dart'; // ✅ Trazendo as novas funções e inteligência do guia
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
  String? _culturaSelecionada;

  // ✅ Variável para a Região (Puxaria do perfil do usuário idealmente)
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

  // ✅ Função auxiliar para pegar o mês atual em português
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

  // ✅ Alerta de Conflito (Consórcio Inimigo)
  Future<bool?> _mostrarAlertaConflito(
      String novaPlanta, List<String> conflitos) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Atenção ao Consórcio!'),
          ],
        ),
        content: Text(
            'A cultura "$novaPlanta" não se dá bem quando plantada no mesmo canteiro que: ${conflitos.join(", ")}.\n\n'
            'Isso pode gerar competição por nutrientes ou atrair pragas em comum. '
            'Você pode adicionar esta planta em outro Lote/Canteiro.\n\nDeseja adicionar mesmo assim?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ADICIONAR ASSIM MESMO'),
          ),
        ],
      ),
    );
  }

  // ✅ Alerta de Sazonalidade (Fora de Época)
  Future<bool?> _mostrarAlertaEpoca(String planta, String mes, String regiao) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.thermostat, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Fora de Época'),
          ],
        ),
        content: Text(
            'O mês de $mes não é a época ideal para plantar "$planta" na região $regiao.\n\n'
            'A planta pode ter dificuldade de se desenvolver, exigir mais água e cuidados, ou pendoar precocemente.\n\nDeseja continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('PLANTAR MESMO ASSIM'),
          ),
        ],
      ),
    );
  }

  // ✅ _salvarItem agora é async para aguardar a decisão do usuário nos alertas
  Future<void> _salvarItem() async {
    String nomeFinal;
    if (_modoPersonalizado) {
      if (_customNameController.text.trim().isEmpty) {
        _toast('Informe o nome da cultura.', isError: true);
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

    if (_qtdController.text.trim().isEmpty) {
      _toast('Informe a quantidade.', isError: true);
      return;
    }
    final qtd = _parseQtd(_qtdController.text);
    if (qtd <= 0) {
      _toast('Quantidade inválida.', isError: true);
      return;
    }

    // 🔥 MOTOR DE REGRAS AGRONÔMICAS 🔥
    if (!_modoPersonalizado && _culturaSelecionada != null) {
      final infoNova = GuiaCulturas.dados[nomeFinal] ?? {};
      final evitarNova = (infoNova['evitar'] as List?)?.cast<String>() ?? [];

      // 1. Checar Conflitos (Alelopatia)
      List<String> conflitosEncontrados = [];
      for (var item in _listaDesejos) {
        String plantaNaLista = item['planta'];

        // Verifica se a nova não gosta da que já está na lista
        if (evitarNova.contains(plantaNaLista)) {
          conflitosEncontrados.add(plantaNaLista);
        } else {
          // Verifica se a que já está na lista não gosta da nova
          final infoExistente = GuiaCulturas.dados[plantaNaLista] ?? {};
          final evitarExistente =
              (infoExistente['evitar'] as List?)?.cast<String>() ?? [];
          if (evitarExistente.contains(nomeFinal)) {
            conflitosEncontrados.add(plantaNaLista);
          }
        }
      }

      if (conflitosEncontrados.isNotEmpty) {
        bool? confirmar = await _mostrarAlertaConflito(
            nomeFinal, conflitosEncontrados.toSet().toList());
        if (confirmar != true) return; // O usuário desistiu
      }

      // 2. Checar Época de Plantio
      String mesAtual = _obterMesAtual();
      List<String> recomendadas =
          culturasPorRegiaoMes(_regiaoSelecionada, mesAtual);
      if (!recomendadas.contains(nomeFinal)) {
        bool? confirmarEpoca =
            await _mostrarAlertaEpoca(nomeFinal, mesAtual, _regiaoSelecionada);
        if (confirmarEpoca != true) return; // O usuário desistiu
      }
    }

    if (!mounted) return;

    setState(() {
      final novoItem = {
        'planta': nomeFinal,
        'meta': qtd,
        'isCustom': _modoPersonalizado,
      };

      if (_editandoIndex != null) {
        _listaDesejos[_editandoIndex!] = novoItem;
        _editandoIndex = null;
        _toast('Item atualizado.');
      } else {
        _listaDesejos.add(novoItem);
        _toast('Item adicionado.');
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
        _customNameController.clear();
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
    _toast('Removido.');
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

  Future<void> _gerarESalvarEIrParaGerador(AppSession session) async {
    if (_listaDesejos.isEmpty) {
      _toast('Adicione pelo menos um item para planejar.', isError: true);
      return;
    }
    if (_canteiroId == null) {
      _toast('Selecione um lote no topo.', isError: true);
      return;
    }
    final user = _user;
    if (user == null) {
      _toast('Usuário não autenticado.', isError: true);
      return;
    }

    setState(() => _salvando = true);

    try {
      double areaTotalCalculada = 0.0;
      double horasMaoDeObraSemanal = 0.0;

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
              'icone': '🌱',
            };

        final yieldVal = (info['yield'] as num).toDouble();
        final espacoVal = (info['espaco'] as num).toDouble();
        final cicloDias = (info['cicloDias'] as int?) ?? 60;

        final mudasCalc = meta / yieldVal;
        final mudasReais = (mudasCalc * 1.1).ceil();
        final areaNecessaria = mudasReais * espacoVal;

        int cicloSemanas = (cicloDias / 7).ceil();
        if (cicloSemanas < 1) cicloSemanas = 1;

        final horasFase1 = areaNecessaria * 0.25;
        final horasFase2 = areaNecessaria * 0.083 * cicloSemanas;
        final horasFase3 = areaNecessaria * 0.016;
        final horasTotais = horasFase1 + horasFase2 + horasFase3;

        areaTotalCalculada += areaNecessaria;
        horasMaoDeObraSemanal += (horasTotais / cicloSemanas);

        return {
          'planta': nome,
          'mudas': mudasReais,
          'area': areaNecessaria,
          'evitar': info['evitar'] ?? [],
          'par': info['par'] ?? [],
          'cat': info['cat'] ?? 'Geral',
          'icone': info['icone'] ?? '🌱',
        };
      }).toList();

      final aguaTotal = areaTotalCalculada * 5.0;
      final aduboTotal = areaTotalCalculada * 3.0;

      await _salvarPlanejamentoNoCanteiro(
        session: session,
        canteiroId: _canteiroId!,
        uid: user.uid,
        itensDesejados: List<Map<String, dynamic>>.from(_listaDesejos),
        itensProcessados: List<Map<String, dynamic>>.from(itensProcessados),
        areaTotal: areaTotalCalculada,
        aguaTotal: aguaTotal,
        aduboTotal: aduboTotal,
        maoDeObraTotalSemanal: horasMaoDeObraSemanal,
        regiao: _regiaoSelecionada, // Salvando a região também
      );

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
      _toast('Erro ao salvar planejamento: $e', isError: true);
    }
  }

  Future<String> _salvarPlanejamentoNoCanteiro({
    required AppSession session,
    required String canteiroId,
    required String uid,
    required List<Map<String, dynamic>> itensDesejados,
    required List<Map<String, dynamic>> itensProcessados,
    required double areaTotal,
    required double aguaTotal,
    required double aduboTotal,
    required double maoDeObraTotalSemanal,
    required String regiao,
  }) async {
    final canteiroRef = FirebasePaths.canteiroRef(session.tenantId, canteiroId);

    final planejamentoRef =
        FirebasePaths.canteiroPlanejamentosCol(session.tenantId, canteiroId)
            .doc();

    final resumo = {
      'itens': itensDesejados,
      'area_total_m2': areaTotal,
      'agua_l_dia': aguaTotal,
      'adubo_kg': aduboTotal,
      'mao_de_obra_h_sem': maoDeObraTotalSemanal,
      'updatedAt': FieldValue.serverTimestamp(),
      'planejamentoId': planejamentoRef.id,
      'regiao': regiao,
    };

    final batch = FirebaseFirestore.instance.batch();

    batch.set(planejamentoRef, {
      'uid_usuario': uid,
      'tipo': 'consumo',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'itens_desejados': itensDesejados,
      'itens_processados': itensProcessados,
      'totais': {
        'area_total_m2': areaTotal,
        'agua_l_dia': aguaTotal,
        'adubo_kg': aduboTotal,
        'mao_de_obra_h_sem': maoDeObraTotalSemanal,
      },
      'resumo': resumo,
    });

    batch.update(canteiroRef, {
      'planejamento_atual': resumo,
      'planejamento_ativo_id': planejamentoRef.id,
      'planejamento_updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return planejamentoRef.id;
  }

  // ✅ Função para gerar dicas dinâmicas com base no que já está na lista
  List<String> _gerarDicasDeConsorcio() {
    if (_listaDesejos.isEmpty) return [];

    Set<String> sugestoes = {};
    List<String> plantasAtuais =
        _listaDesejos.map((e) => e['planta'] as String).toList();

    for (var planta in plantasAtuais) {
      final info = GuiaCulturas.dados[planta];
      if (info != null && info['par'] != null) {
        List amigas = info['par'];
        for (String amiga in amigas) {
          if (!plantasAtuais.contains(amiga)) {
            sugestoes.add(amiga);
          }
        }
      }
    }
    return sugestoes
        .take(4)
        .toList(); // Retorna até 4 sugestões para não poluir
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final session = SessionScope.of(context).session;

    if (session == null) {
      return const PageContainer(
        title: 'Plano de Consumo',
        subtitle: 'Carregando sessão...',
        scroll: false,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final listaCulturasOrdenada = GuiaCulturas.dados.keys.toList()..sort();

    double areaTotal = 0;
    double horasSemanaisTotal = 0;

    final itensCards = <Widget>[];
    for (final entry in _listaDesejos.asMap().entries) {
      final idx = entry.key;
      final item = entry.value;

      final nome = item['planta'] as String;
      final meta = (item['meta'] as num).toDouble();

      final info = GuiaCulturas.dados[nome] ??
          {
            'yield': 1.0,
            'unit': 'kg',
            'espaco': 0.5,
            'cicloDias': 60,
            'icone': '🌱'
          };

      final yieldVal = (info['yield'] as num).toDouble();
      final espacoVal = (info['espaco'] as num).toDouble();
      final cicloDias = (info['cicloDias'] as int?) ?? 60;

      final plantasReais = ((meta / yieldVal) * 1.1).ceil();
      final areaItem = plantasReais * espacoVal;
      areaTotal += areaItem;

      int cicloSemanas = (cicloDias / 7).ceil();
      if (cicloSemanas < 1) cicloSemanas = 1;

      final horasItem = (areaItem * 0.25) +
          (areaItem * 0.083 * cicloSemanas) +
          (areaItem * 0.016);
      horasSemanaisTotal += (horasItem / cicloSemanas);

      itensCards.add(
          _buildItemCard(idx, nome, meta, info, plantasReais, areaItem, cs));
    }

    List<String> dicas = _gerarDicasDeConsorcio();

    return PageContainer(
      title: 'Plano de Consumo',
      subtitle: 'Defina o que você quer colher',
      scroll: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: '1) Configurações Locais',
            child: Column(
              children: [
                CanteiroPickerDropdown(
                  tenantId: session.tenantId,
                  selectedId: _canteiroId,
                  onSelect: (id) => setState(() => _canteiroId = id),
                ),
                const SizedBox(height: AppTokens.md),
                // ✅ Dropdown de Região
                DropdownButtonFormField<String>(
                  value: _regiaoSelecionada,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Sua Região',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                  items: _regioes
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setState(() => _regiaoSelecionada = v!),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.md),
          SectionCard(
            title: _editandoIndex != null
                ? 'Editando item'
                : '2) Adicionar cultura',
            child: Column(
              children: [
                _buildFormularioAdicao(cs, listaCulturasOrdenada),
                const SizedBox(height: AppTokens.md),
                AppButtons.elevatedIcon(
                  onPressed: _salvarItem,
                  icon: Icon(
                      _editandoIndex != null ? Icons.save : Icons.add_circle),
                  label: Text(_editandoIndex != null
                      ? 'SALVAR ALTERAÇÕES'
                      : 'ADICIONAR À LISTA'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.md),
          SectionCard(
            title: '3) Itens do plano',
            child: _listaDesejos.isEmpty
                ? _buildEmptyState(cs)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildKpisTop(cs, areaTotal, horasSemanaisTotal),
                      const SizedBox(height: AppTokens.md),
                      ...itensCards,

                      // ✅ Dicas Dinâmicas de Consórcio
                      if (dicas.isNotEmpty) ...[
                        const SizedBox(height: AppTokens.sm),
                        Container(
                          padding: const EdgeInsets.all(AppTokens.sm),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusSm),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.lightbulb_outline,
                                      color: Colors.green, size: 18),
                                  const SizedBox(width: 4),
                                  Text('Dicas de Consórcio',
                                      style: TextStyle(
                                          color: Colors.green.shade800,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Considerando sua lista, estas plantas são ótimas companheiras: ${dicas.join(", ")}.',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.green.shade900),
                              )
                            ],
                          ),
                        ),
                      ]
                    ],
                  ),
          ),
          const SizedBox(height: AppTokens.md),
          if (_listaDesejos.isNotEmpty)
            SectionCard(
              title: 'Estimativa total',
              child: _buildResumoTotal(cs, areaTotal, horasSemanaisTotal),
            ),
        ],
      ),
      bottomBar: SizedBox(
        height: 50,
        width: double.infinity,
        child: AppButtons.elevatedIcon(
          onPressed:
              _salvando ? null : () => _gerarESalvarEIrParaGerador(session),
          icon: _salvando
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: cs.onPrimary,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(_salvando ? 'PROCESSANDO...' : 'GERAR PLANO INTELIGENTE'),
        ),
      ),
    );
  }

  Widget _buildKpisTop(
      ColorScheme cs, double areaTotal, double horasSemanaisTotal) {
    final totalItens = _listaDesejos.length;
    final aguaDia = areaTotal * 5.0;

    return Row(
      children: [
        Expanded(
            child: _miniKpi('Itens', '$totalItens', Icons.playlist_add_check,
                cs.primary, cs)),
        const SizedBox(width: AppTokens.sm),
        Expanded(
            child: _miniKpi('Área', '${areaTotal.toStringAsFixed(1)} m²',
                Icons.crop_free, cs.primary, cs)),
        const SizedBox(width: AppTokens.sm),
        Expanded(
            child: _miniKpi('Água', '${aguaDia.toStringAsFixed(0)} L/d',
                Icons.water_drop, Colors.blue.shade700, cs)),
      ],
    );
  }

  Widget _miniKpi(
      String label, String value, IconData icon, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value,
              style:
                  TextStyle(fontWeight: FontWeight.w900, color: cs.onSurface)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildFormularioAdicao(ColorScheme cs, List<String> listaCulturas) {
    final unit = (!_modoPersonalizado &&
            _culturaSelecionada != null &&
            GuiaCulturas.dados.containsKey(_culturaSelecionada))
        ? (GuiaCulturas.dados[_culturaSelecionada]!['unit']).toString()
        : 'kg/un';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('O que você quer colher?',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant)),
            IconButton(
              onPressed: () => setState(() {
                _modoPersonalizado = !_modoPersonalizado;
                _culturaSelecionada = null;
                _customNameController.clear();
              }),
              tooltip: 'Alternar Lista/Digitar',
              icon: Icon(_modoPersonalizado ? Icons.list : Icons.keyboard,
                  color: cs.primary),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              flex: 4,
              child: _modoPersonalizado
                  ? AppTextField(
                      controller: _customNameController,
                      labelText: 'Nome da cultura',
                      hintText: 'Ex: Alface americana',
                      prefixIcon: Icons.eco_outlined,
                    )
                  : DropdownButtonFormField<String>(
                      value: _culturaSelecionada,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Cultura',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: listaCulturas.map((k) {
                        // ✅ Trazendo o ícone para o Dropdown
                        final icone = (GuiaCulturas.dados[k]?['icone'] ?? '🌱')
                            .toString();
                        return DropdownMenuItem(
                          value: k,
                          child: Text('$icone $k',
                              style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _culturaSelecionada = v),
                    ),
            ),
            const SizedBox(width: AppTokens.md),
            Expanded(
              flex: 2,
              child: AppTextField(
                controller: _qtdController,
                labelText: 'Qtd',
                hintText: '0,0',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]'))
                ],
                suffixText: unit,
                prefixIcon: Icons.confirmation_number_outlined,
              ),
            ),
          ],
        ),
        if (_editandoIndex != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _cancelarEdicao,
              icon: Icon(Icons.close, size: 16, color: cs.error),
              label: Text('Cancelar edição', style: TextStyle(color: cs.error)),
            ),
          ),
      ],
    );
  }

  Widget _buildItemCard(int idx, String nome, double meta, Map info,
      int plantasReais, double areaItem, ColorScheme cs) {
    final unit = (info['unit'] ?? 'un').toString();
    final icone = (info['icone'] ?? '🌱').toString(); // ✅ Lendo o ícone do mapa

    return Card(
      margin: const EdgeInsets.only(bottom: AppTokens.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppTokens.md),
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          // ✅ Mostrando o Ícone (Emoji) em vez de apenas o número
          child: Text(
            icone,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(nome, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${meta.toStringAsFixed(1)} $unit desejados (${plantasReais}x plantas)',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 4),
              Text('Ocupa aprox: ${areaItem.toStringAsFixed(2)} m²',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface)),
            ],
          ),
        ),
        trailing: PopupMenuButton(
          icon: Icon(Icons.more_vert, color: cs.outline),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            PopupMenuItem(
                value: 'delete',
                child: Text('Remover', style: TextStyle(color: cs.error))),
          ],
          onSelected: (value) {
            if (value == 'edit') _iniciarEdicao(idx);
            if (value == 'delete') _removerItem(idx);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.eco_outlined, size: 64, color: cs.outlineVariant),
          const SizedBox(height: AppTokens.md),
          Text('Sua lista está vazia.',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface)),
          const SizedBox(height: 6),
          Text('Adicione culturas acima pra gerar o plano.',
              style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildResumoTotal(
      ColorScheme cs, double areaTotal, double horasSemanaisTotal) {
    return Column(
      children: [
        AppKeyValueRow(
            label: 'Área útil ocupada',
            value: '${areaTotal.toStringAsFixed(1)} m²',
            color: cs.primary),
        AppKeyValueRow(
            label: 'Água necessária',
            value: '${(areaTotal * 5.0).toStringAsFixed(0)} L/dia',
            color: Colors.blue.shade700),
        AppKeyValueRow(
            label: 'Adubo base',
            value: '${(areaTotal * 3.0).toStringAsFixed(1)} kg',
            color: Colors.brown.shade700),
        const Divider(),
        AppKeyValueRow(
            label: 'Mão de obra',
            value: '${horasSemanaisTotal.toStringAsFixed(1)} h/sem',
            isBold: true),
      ],
    );
  }
}
