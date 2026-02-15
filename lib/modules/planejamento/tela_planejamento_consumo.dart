import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/ui/app_ui.dart';
import '../../core/firebase/firebase_paths.dart';
import '../../core/session/app_session.dart';
import '../../core/session/session_scope.dart';

import 'tela_gerador_canteiros.dart';

class TelaPlanejamentoConsumo extends StatefulWidget {
  const TelaPlanejamentoConsumo({super.key});

  @override
  State<TelaPlanejamentoConsumo> createState() =>
      _TelaPlanejamentoConsumoState();
}

class _TelaPlanejamentoConsumoState extends State<TelaPlanejamentoConsumo> {
  User? get _user => FirebaseAuth.instance.currentUser;

  AppSession? get _sessionOrNull => SessionScope.of(context).session;
  AppSession get appSession {
    final s = _sessionOrNull;
    if (s == null) {
      throw StateError('Sessão indisponível (tenant não selecionado)');
    }
    return s;
  }

  // =======================================================================
  // DADOS AGRONÔMICOS (Enriquecido com Ciclo em Dias para Mão de Obra)
  // =======================================================================
  final Map<String, Map<String, dynamic>> _dadosProdutividade = {
    'Abobrinha italiana': {
      'yield': 2.0,
      'unit': 'kg',
      'espaco': 1.0 * 1.0,
      'cat': 'Frutos',
      'cicloDias': 60,
      'info': 'Rica em vitaminas do complexo B.',
    },
    'Abóboras': {
      'yield': 5.0,
      'unit': 'kg',
      'espaco': 3.0 * 2.0,
      'cat': 'Frutos',
      'cicloDias': 120,
      'info': 'Fonte de betacaroteno e fibras.',
    },
    'Acelga': {
      'yield': 0.8,
      'unit': 'maço',
      'espaco': 0.5 * 0.4,
      'cat': 'Folhas',
      'cicloDias': 70,
      'info': 'Ajuda no controle da diabetes.',
    },
    'Alface': {
      'yield': 0.3,
      'unit': 'un',
      'espaco': 0.25 * 0.25,
      'cat': 'Folhas',
      'cicloDias': 60,
      'info': 'Calmante natural e rico em fibras.',
    },
    'Alho': {
      'yield': 0.04,
      'unit': 'kg',
      'espaco': 0.25 * 0.1,
      'cat': 'Bulbos',
      'cicloDias': 150,
      'info': 'Antibiótico natural e anti-inflamatório.',
    },
    'Batata doce': {
      'yield': 1.0,
      'unit': 'kg',
      'espaco': 0.9 * 0.3,
      'cat': 'Raízes',
      'cicloDias': 150,
      'info': 'Carboidrato complexo de baixo índice glicêmico.',
    },
    'Berinjela': {
      'yield': 2.0,
      'unit': 'kg',
      'espaco': 1.0 * 0.8,
      'cat': 'Frutos',
      'cicloDias': 120,
      'info': 'Rica em antioxidantes e saúde do coração.',
    },
    'Beterraba': {
      'yield': 0.15,
      'unit': 'un',
      'espaco': 0.25 * 0.1,
      'cat': 'Raízes',
      'cicloDias': 70,
      'info': 'Melhora o fluxo sanguíneo e pressão arterial.',
    },
    'Brócolis': {
      'yield': 0.5,
      'unit': 'un',
      'espaco': 0.8 * 0.5,
      'cat': 'Flores',
      'cicloDias': 100,
      'info': 'Alto teor de cálcio e combate radicais livres.',
    },
    'Cebola': {
      'yield': 0.15,
      'unit': 'kg',
      'espaco': 0.3 * 0.1,
      'cat': 'Bulbos',
      'cicloDias': 150,
      'info': 'Melhora a circulação e imunidade.',
    },
    'Cebolinha': {
      'yield': 0.2,
      'unit': 'maço',
      'espaco': 0.25 * 0.1,
      'cat': 'Temperos',
      'cicloDias': 90,
      'info': 'Rica em vitamina A e C.',
    },
    'Cenoura': {
      'yield': 0.1,
      'unit': 'kg',
      'espaco': 0.25 * 0.05,
      'cat': 'Raízes',
      'cicloDias': 100,
      'info': 'Essencial para a visão e pele.',
    },
    'Coentro': {
      'yield': 0.2,
      'unit': 'maço',
      'espaco': 0.2 * 0.1,
      'cat': 'Temperos',
      'cicloDias': 60,
      'info': 'Desintoxicante de metais pesados.',
    },
    'Couve': {
      'yield': 1.5,
      'unit': 'maços',
      'espaco': 0.8 * 0.5,
      'cat': 'Folhas',
      'cicloDias': 90,
      'info': 'Desintoxicante e rica em ferro.',
    },
    'Mandioca': {
      'yield': 3.0,
      'unit': 'kg',
      'espaco': 1.0 * 0.6,
      'cat': 'Raízes',
      'cicloDias': 365,
      'info': 'Fonte de energia glúten-free.',
    },
    'Pimentão': {
      'yield': 1.0,
      'unit': 'kg',
      'espaco': 1.0 * 0.5,
      'cat': 'Frutos',
      'cicloDias': 120,
      'info': 'Termogênico e rico em vitamina C.',
    },
    'Quiabo': {
      'yield': 0.8,
      'unit': 'kg',
      'espaco': 1.0 * 0.3,
      'cat': 'Frutos',
      'cicloDias': 80,
      'info': 'Excelente para digestão e flora intestinal.',
    },
    'Rúcula': {
      'yield': 0.5,
      'unit': 'maço',
      'espaco': 0.2 * 0.05,
      'cat': 'Folhas',
      'cicloDias': 50,
      'info': 'Picante, digestiva e rica em ômega-3.',
    },
    'Tomate': {
      'yield': 3.0,
      'unit': 'kg',
      'espaco': 1.0 * 0.5,
      'cat': 'Frutos',
      'cicloDias': 120,
      'info': 'Rico em licopeno, previne câncer.',
    },
  };

  final List<Map<String, dynamic>> _listaDesejos = [];

  String? _canteiroId;
  String? _canteiroNome;

  String? _culturaSelecionada;
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

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (isError) {
      AppMessenger.error(msg);
    } else {
      AppMessenger.success(msg);
    }
  }

  String _formatarTexto(String texto) {
    if (texto.isEmpty) return "";
    return texto.trim().split(' ').map((word) {
      if (word.isEmpty) return "";
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  void _salvarItem() {
    String nomeFinal;

    if (_modoPersonalizado) {
      if (_customNameController.text.trim().isEmpty) {
        _snack('Informe o nome da cultura.', isError: true);
        return;
      }
      nomeFinal = _formatarTexto(_customNameController.text);
    } else {
      if (_culturaSelecionada == null) {
        _snack('Selecione uma cultura.', isError: true);
        return;
      }
      nomeFinal = _culturaSelecionada!;
    }

    if (_qtdController.text.trim().isEmpty) {
      _snack('Informe a quantidade.', isError: true);
      return;
    }

    final qtd =
        double.tryParse(_qtdController.text.replaceAll(',', '.')) ?? 0.0;
    if (qtd <= 0) {
      _snack('Quantidade inválida.', isError: true);
      return;
    }

    setState(() {
      final novoItem = {
        'planta': nomeFinal,
        'meta': qtd,
        'isCustom': _modoPersonalizado,
      };

      if (_editandoIndex != null) {
        _listaDesejos[_editandoIndex!] = novoItem;
        _editandoIndex = null;
        _snack('Item atualizado com sucesso!');
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
      _qtdController.text = item['meta'].toString();

      if (_dadosProdutividade.containsKey(item['planta'])) {
        _modoPersonalizado = false;
        _culturaSelecionada = item['planta'];
      } else {
        _modoPersonalizado = true;
        _customNameController.text = item['planta'];
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

  void _selecionarCanteiro() {
    if (_user == null) {
      _snack('Você precisa estar logado.', isError: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final altura = MediaQuery.of(sheetContext).size.height * 0.75;

        return Container(
          height: altura,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.grid_view, color: Colors.green),
                        SizedBox(width: 10),
                        Text('Salvar em qual Lote?',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Selecione o local onde este plantio ficará salvo.',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebasePaths.canteirosCol(appSession.tenantId)
                        .where('ativo', isEqualTo: true)
                        .snapshots(),
                    builder: (sbContext, snapshot) {
                      if (snapshot.hasError)
                        return const Center(
                            child: Text('Erro ao carregar lotes.'));
                      if (snapshot.connectionState == ConnectionState.waiting)
                        return const Center(child: CircularProgressIndicator());

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(
                            child: Text(
                                'Você ainda não tem lotes ativos. Vá no menu "Locais" e crie um lote primeiro.',
                                textAlign: TextAlign.center));
                      }

                      final ordenados = [...docs]..sort((a, b) {
                          final ma = (a.data() as Map<String, dynamic>?) ?? {};
                          final mb = (b.data() as Map<String, dynamic>?) ?? {};
                          final na =
                              (ma['nome'] ?? '').toString().toLowerCase();
                          final nb =
                              (mb['nome'] ?? '').toString().toLowerCase();
                          return na.compareTo(nb);
                        });

                      return ListView.separated(
                        itemCount: ordenados.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final doc = ordenados[i];
                          final data =
                              (doc.data() as Map<String, dynamic>?) ?? {};
                          final nome = (data['nome'] ?? 'Sem nome').toString();
                          final selecionado = _canteiroId == doc.id;

                          return ListTile(
                            title: Text(nome,
                                style: TextStyle(
                                    fontWeight: selecionado
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: selecionado
                                        ? Colors.green.shade800
                                        : Colors.black87)),
                            trailing: selecionado
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : const Icon(Icons.arrow_forward_ios,
                                    size: 14, color: Colors.grey),
                            onTap: () {
                              setState(() {
                                _canteiroId = doc.id;
                                _canteiroNome = nome;
                              });
                              Navigator.pop(sheetContext);
                              _snack('Lote selecionado: $nome');
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String> _salvarPlanejamentoNoCanteiro({
    required String canteiroId,
    required List<Map<String, dynamic>> itensDesejados,
    required List<Map<String, dynamic>> itensProcessados,
    required double areaTotal,
    required double aguaTotal,
    required double aduboTotal,
    required double maoDeObraTotal,
  }) async {
    final user = _user;
    if (user == null) throw Exception('Usuário não autenticado.');

    final canteiroRef =
        FirebasePaths.canteiroRef(appSession.tenantId, canteiroId);
    final planejamentoRef =
        FirebasePaths.canteiroPlanejamentosCol(appSession.tenantId, canteiroId)
            .doc();

    final resumo = {
      'itens': itensDesejados,
      'area_total_m2': areaTotal,
      'agua_l_dia': aguaTotal,
      'adubo_kg': aduboTotal,
      'mao_de_obra_h_sem': maoDeObraTotal,
      'updatedAt': FieldValue.serverTimestamp(),
      'planejamentoId': planejamentoRef.id,
    };

    final batch = FirebaseFirestore.instance.batch();

    batch.set(planejamentoRef, {
      'uid_usuario': user.uid,
      'tipo': 'consumo',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'itens_desejados': itensDesejados,
      'itens_processados': itensProcessados,
      'totais': {
        'area_total_m2': areaTotal,
        'agua_l_dia': aguaTotal,
        'adubo_kg': aduboTotal,
        'mao_de_obra_h_sem': maoDeObraTotal,
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

  Future<void> _gerarESalvarEIrParaGerador() async {
    if (_listaDesejos.isEmpty) {
      _snack('Adicione pelo menos um item para planejar!', isError: true);
      return;
    }
    if (_canteiroId == null) {
      _snack(
          'Por favor, selecione um lote no aviso laranja antes de gerar o plano.',
          isError: true);
      _selecionarCanteiro();
      return;
    }

    setState(() => _salvando = true);

    try {
      double areaTotalCalculada = 0.0;
      double horasMaoDeObraTotal = 0.0;

      final itensProcessados = _listaDesejos.map((item) {
        final nome = item['planta'] as String;
        final meta = (item['meta'] as num).toDouble();

        final info = _dadosProdutividade[nome] ??
            {
              'yield': 1.0,
              'espaco': 0.5,
              'cicloDias': 60,
              'evitar': [],
              'par': [],
              'cat': 'Geral',
            };

        final yieldVal = (info['yield'] as num).toDouble();
        final espacoVal = (info['espaco'] as num).toDouble();
        final cicloDias = (info['cicloDias'] as int?) ?? 60;

        final mudasCalc = meta / yieldVal;
        final mudasReais = (mudasCalc * 1.1).ceil();
        final areaNecessaria = mudasReais * espacoVal;

        int cicloSemanas = (cicloDias / 7).ceil();
        if (cicloSemanas < 1) cicloSemanas = 1;

        double horasFase1 = areaNecessaria * 0.25;
        double horasFase2 = areaNecessaria * 0.083 * cicloSemanas;
        double horasFase3 = areaNecessaria * 0.016;
        double horasTotaisCultura = horasFase1 + horasFase2 + horasFase3;

        areaTotalCalculada += areaNecessaria;
        horasMaoDeObraTotal += (horasTotaisCultura / cicloSemanas);

        return {
          'planta': nome,
          'mudas': mudasReais,
          'area': areaNecessaria,
          'evitar': info['evitar'] ?? [],
          'par': info['par'] ?? [],
          'cat': info['cat'] ?? 'Geral',
        };
      }).toList();

      final aguaTotal = areaTotalCalculada * 5.0;
      final aduboTotal = areaTotalCalculada * 3.0;

      await _salvarPlanejamentoNoCanteiro(
        canteiroId: _canteiroId!,
        itensDesejados: List<Map<String, dynamic>>.from(_listaDesejos),
        itensProcessados: List<Map<String, dynamic>>.from(itensProcessados),
        areaTotal: areaTotalCalculada,
        aguaTotal: aguaTotal,
        aduboTotal: aduboTotal,
        maoDeObraTotal: horasMaoDeObraTotal,
      );

      // Desliga o loading ANTES do navegador para não bugar a árvore do Flutter
      if (mounted) setState(() => _salvando = false);

      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              TelaGeradorCanteiros(itensPlanejados: itensProcessados),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _salvando = false);
      _snack('Erro ao salvar planejamento: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final listaCulturasOrdenada = _dadosProdutividade.keys.toList()..sort();

    double areaTotal = 0;
    double horasSemanaisTotal = 0;

    final cardsWidgets = _listaDesejos.asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;

      final nome = item['planta'] as String;
      final meta = (item['meta'] as num).toDouble();

      final info = _dadosProdutividade[nome] ??
          {
            'yield': 1.0,
            'unit': 'kg',
            'espaco': 0.5,
            'cicloDias': 60,
            'info': 'Cultura personalizada.',
          };

      final yieldVal = (info['yield'] as num).toDouble();
      final espacoVal = (info['espaco'] as num).toDouble();
      final cicloDias = (info['cicloDias'] as int?) ?? 60;

      final plantasExatas = meta / yieldVal;
      final plantasReais = (plantasExatas * 1.1).ceil();
      final areaItem = plantasReais * espacoVal;

      areaTotal += areaItem;

      int cicloSemanas = (cicloDias / 7).ceil();
      if (cicloSemanas < 1) cicloSemanas = 1;
      double horasItem = (areaItem * 0.25) +
          (areaItem * 0.083 * cicloSemanas) +
          (areaItem * 0.016);
      horasSemanaisTotal += (horasItem / cicloSemanas);

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: Text('${plantasReais}x',
                style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
          title:
              Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${meta.toStringAsFixed(1)} ${info['unit']} desejados',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 4),
              Text('Ocupa aprox: ${areaItem.toStringAsFixed(2)} m²',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold)),
            ],
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
    }).toList();

    double aguaTotal = areaTotal * 5.0;
    double aduboTotal = areaTotal * 3.0;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text('Planejamento',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        backgroundColor: cs.surface,
        foregroundColor: cs.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AVISO LARANJA / VERDE QUE AGORA É UM BOTÃO GIGANTE
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _selecionarCanteiro,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _canteiroId == null
                              ? cs.errorContainer
                              : cs.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  _canteiroId == null ? cs.error : cs.primary),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _canteiroId == null
                                  ? Icons.warning_amber
                                  : Icons.check_circle,
                              color: _canteiroId == null
                                  ? cs.onErrorContainer
                                  : cs.onPrimaryContainer,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _canteiroId == null
                                    ? 'CLIQUE AQUI PARA SELECIONAR UM LOTE'
                                    : 'Lote selecionado: $_canteiroNome\n(Clique para trocar)',
                                style: TextStyle(
                                  color: _canteiroId == null
                                      ? cs.onErrorContainer
                                      : cs.onPrimaryContainer,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Icon(Icons.touch_app,
                                color: _canteiroId == null
                                    ? cs.onErrorContainer
                                    : cs.onPrimaryContainer),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          _editandoIndex != null
                              ? 'Editando Planta...'
                              : 'O que vamos plantar?',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      if (_editandoIndex != null)
                        TextButton.icon(
                            onPressed: _cancelarEdicao,
                            icon: Icon(Icons.close, size: 16, color: cs.error),
                            label: Text('Cancelar',
                                style: TextStyle(color: cs.error))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: _modoPersonalizado
                            ? TextField(
                                controller: _customNameController,
                                decoration: const InputDecoration(
                                    labelText: 'Nome',
                                    hintText: 'Ex: Jiló',
                                    border: OutlineInputBorder(),
                                    isDense: true),
                              )
                            : DropdownButtonFormField<String>(
                                value: _culturaSelecionada,
                                hint: const Text('Selecione a planta...'),
                                isExpanded: true,
                                items: listaCulturasOrdenada
                                    .map((k) => DropdownMenuItem(
                                        value: k,
                                        child: Text(k,
                                            style:
                                                const TextStyle(fontSize: 14))))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _culturaSelecionada = v),
                                decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    isDense: true),
                              ),
                      ),
                      IconButton(
                        onPressed: () => setState(() {
                          _modoPersonalizado = !_modoPersonalizado;
                          _culturaSelecionada = null;
                          _customNameController.clear();
                        }),
                        tooltip: 'Digitar outro nome',
                        icon: Icon(
                            _modoPersonalizado ? Icons.list : Icons.keyboard,
                            color: cs.primary),
                      ),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _qtdController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9\.,]'))
                          ],
                          decoration: InputDecoration(
                            labelText: 'Qtd',
                            suffixText: !_modoPersonalizado &&
                                    _culturaSelecionada != null
                                ? (_dadosProdutividade[_culturaSelecionada]![
                                        'unit'])
                                    .toString()
                                : 'kg/un',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _salvarItem,
                      icon: Icon(_editandoIndex != null
                          ? Icons.save
                          : Icons.add_circle),
                      label: Text(
                          _editandoIndex != null
                              ? 'SALVAR ALTERAÇÕES'
                              : 'ADICIONAR À LISTA',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ],
              ),
            ),
            if (_listaDesejos.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.spa_outlined,
                        size: 80, color: cs.outlineVariant),
                    const SizedBox(height: 16),
                    Text('Sua lista está vazia.',
                        style: TextStyle(
                            fontSize: 16,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ...cardsWidgets,
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [cs.primary, cs.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: cs.primary.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5))
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text('ESTIMATIVA TOTAL DO SISTEMA',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.0)),
                          const Divider(color: Colors.white24, height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _InfoResumo(
                                  icon: Icons.crop_free,
                                  valor: areaTotal.toStringAsFixed(1),
                                  unidade: 'm²',
                                  label: 'Área Útil'),
                              Container(
                                  width: 1, height: 40, color: Colors.white24),
                              _InfoResumo(
                                  icon: Icons.water_drop,
                                  valor: aguaTotal.toStringAsFixed(0),
                                  unidade: 'L/dia',
                                  label: 'Água Aprox.'),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _InfoResumo(
                                  icon: Icons.compost,
                                  valor: aduboTotal.toStringAsFixed(1),
                                  unidade: 'kg',
                                  label: 'Adubo Base'),
                              Container(
                                  width: 1, height: 40, color: Colors.white24),
                              _InfoResumo(
                                  icon: Icons.handyman,
                                  valor: horasSemanaisTotal.toStringAsFixed(1),
                                  unidade: 'h/sem',
                                  label: 'Mão de Obra'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5))
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _salvando ? null : _gerarESalvarEIrParaGerador,
          icon: _salvando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.auto_awesome),
          label: Text(_salvando ? 'PROCESSANDO...' : 'GERAR PLANO INTELIGENTE',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}

class _InfoResumo extends StatelessWidget {
  final IconData icon;
  final String valor;
  final String unidade;
  final String label;

  const _InfoResumo(
      {required this.icon,
      required this.valor,
      required this.unidade,
      required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 20)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(valor,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            Text(unidade,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }
}
