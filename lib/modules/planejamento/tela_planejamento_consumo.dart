import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/ui/app_ui.dart';

import 'tela_gerador_canteiros.dart';

class TelaPlanejamentoConsumo extends StatefulWidget {
  const TelaPlanejamentoConsumo({super.key});

  @override
  State<TelaPlanejamentoConsumo> createState() =>
      _TelaPlanejamentoConsumoState();
}

class _TelaPlanejamentoConsumoState extends State<TelaPlanejamentoConsumo> {
  User? get _user => FirebaseAuth.instance.currentUser;

  // =========================
  // DADOS (seu mapa original)
  // =========================
  final Map<String, Map<String, dynamic>> _dadosProdutividade = {
    'Abobrinha italiana': {
      'yield': 2.0,
      'unit': 'kg',
      'espaco': 1.0 * 1.0,
      'cat': 'Frutos',
      'info': 'Rica em vitaminas do complexo B.',
    },
    'Abóboras': {
      'yield': 5.0,
      'unit': 'kg',
      'espaco': 3.0 * 2.0,
      'cat': 'Frutos',
      'info': 'Fonte de betacaroteno e fibras.',
    },
    'Acelga': {
      'yield': 0.8,
      'unit': 'maço',
      'espaco': 0.5 * 0.4,
      'cat': 'Folhas',
      'info': 'Ajuda no controle da diabetes.',
    },
    'Alface': {
      'yield': 0.3,
      'unit': 'un',
      'espaco': 0.25 * 0.25,
      'cat': 'Folhas',
      'info': 'Calmante natural e rico em fibras.',
    },
    'Alho': {
      'yield': 0.04,
      'unit': 'kg',
      'espaco': 0.25 * 0.1,
      'cat': 'Bulbos',
      'info': 'Antibiótico natural e anti-inflamatório.',
    },
    'Batata doce': {
      'yield': 1.0,
      'unit': 'kg',
      'espaco': 0.9 * 0.3,
      'cat': 'Raízes',
      'info': 'Carboidrato complexo de baixo índice glicêmico.',
    },
    'Berinjela': {
      'yield': 2.0,
      'unit': 'kg',
      'espaco': 1.0 * 0.8,
      'cat': 'Frutos',
      'info': 'Rica em antioxidantes e saúde do coração.',
    },
    'Beterraba': {
      'yield': 0.15,
      'unit': 'un',
      'espaco': 0.25 * 0.1,
      'cat': 'Raízes',
      'info': 'Melhora o fluxo sanguíneo e pressão arterial.',
    },
    'Brócolis': {
      'yield': 0.5,
      'unit': 'un',
      'espaco': 0.8 * 0.5,
      'cat': 'Flores',
      'info': 'Alto teor de cálcio e combate radicais livres.',
    },
    'Cebola': {
      'yield': 0.15,
      'unit': 'kg',
      'espaco': 0.3 * 0.1,
      'cat': 'Bulbos',
      'info': 'Melhora a circulação e imunidade.',
    },
    'Cebolinha': {
      'yield': 0.2,
      'unit': 'maço',
      'espaco': 0.25 * 0.1,
      'cat': 'Temperos',
      'info': 'Rica em vitamina A e C.',
    },
    'Cenoura': {
      'yield': 0.1,
      'unit': 'kg',
      'espaco': 0.25 * 0.05,
      'cat': 'Raízes',
      'info': 'Essencial para a visão e pele.',
    },
    'Coentro': {
      'yield': 0.2,
      'unit': 'maço',
      'espaco': 0.2 * 0.1,
      'cat': 'Temperos',
      'info': 'Desintoxicante de metais pesados.',
    },
    'Couve': {
      'yield': 1.5,
      'unit': 'maços',
      'espaco': 0.8 * 0.5,
      'cat': 'Folhas',
      'info': 'Desintoxicante e rica em ferro.',
    },
    'Mandioca': {
      'yield': 3.0,
      'unit': 'kg',
      'espaco': 1.0 * 0.6,
      'cat': 'Raízes',
      'info': 'Fonte de energia glúten-free.',
    },
    'Pimentão': {
      'yield': 1.0,
      'unit': 'kg',
      'espaco': 1.0 * 0.5,
      'cat': 'Frutos',
      'info': 'Termogênico e rico em vitamina C.',
    },
    'Quiabo': {
      'yield': 0.8,
      'unit': 'kg',
      'espaco': 1.0 * 0.3,
      'cat': 'Frutos',
      'info': 'Excelente para digestão e flora intestinal.',
    },
    'Rúcula': {
      'yield': 0.5,
      'unit': 'maço',
      'espaco': 0.2 * 0.05,
      'cat': 'Folhas',
      'info': 'Picante, digestiva e rica em ômega-3.',
    },
    'Tomate': {
      'yield': 3.0,
      'unit': 'kg',
      'espaco': 1.0 * 0.5,
      'cat': 'Frutos',
      'info': 'Rico em licopeno, previne câncer.',
    },
  };

  final List<Map<String, dynamic>> _listaDesejos = [];

  // Seleção de canteiro (pra salvar corretamente)
  String? _canteiroId;
  String? _canteiroNome;

  // Controladores e Estados
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

  void _snack(String msg, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }

  String _formatarTexto(String texto) {
    if (texto.isEmpty) return "";
    return texto
        .trim()
        .split(' ')
        .map((word) {
          if (word.isEmpty) return "";
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  void _salvarItem() {
    String nomeFinal;

    if (_modoPersonalizado) {
      if (_customNameController.text.trim().isEmpty) {
        _snack('Informe o nome da cultura.', bg: Colors.orange);
        return;
      }
      nomeFinal = _formatarTexto(_customNameController.text);
    } else {
      if (_culturaSelecionada == null) {
        _snack('Selecione uma cultura.', bg: Colors.orange);
        return;
      }
      nomeFinal = _culturaSelecionada!;
    }

    if (_qtdController.text.trim().isEmpty) {
      _snack('Informe a quantidade.', bg: Colors.orange);
      return;
    }

    final qtd =
        double.tryParse(_qtdController.text.replaceAll(',', '.')) ?? 0.0;
    if (qtd <= 0) {
      _snack('Quantidade inválida.', bg: Colors.orange);
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

  // =========================
  // Selecionar canteiro
  // =========================
  void _selecionarCanteiro() {
    final user = _user;
    if (user == null) {
      _snack('Você precisa estar logado.', bg: Colors.red);
      return;
    }

    final rootContext = context;

    showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final altura = MediaQuery.of(sheetContext).size.height * 0.75;

        return Container(
          height: altura,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.grid_view, color: Colors.green),
                    SizedBox(width: 10),
                    Text(
                      'Salvar em qual canteiro?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Selecione o local onde este planejamento ficará salvo.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('canteiros')
                        .where('uid_usuario', isEqualTo: user.uid)
                        .where('ativo', isEqualTo: true)
                        .snapshots(),
                    builder: (sbContext, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text('Erro ao carregar canteiros.'),
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Você ainda não tem canteiros ativos.',
                              ),
                              const SizedBox(height: 12),
                              AppButtons.elevatedIcon(
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                  Future.microtask(() {
                                    if (!mounted) return;
                                    Navigator.of(rootContext).push(
                                      MaterialPageRoute(
                                        builder: (_) => const SizedBox(),
                                      ),
                                    );
                                  });
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Cadastre um canteiro'),
                              ),
                            ],
                          ),
                        );
                      }

                      final ordenados = [...docs]
                        ..sort((a, b) {
                          final ma = (a.data() as Map<String, dynamic>?) ?? {};
                          final mb = (b.data() as Map<String, dynamic>?) ?? {};
                          final na = (ma['nome'] ?? '')
                              .toString()
                              .toLowerCase();
                          final nb = (mb['nome'] ?? '')
                              .toString()
                              .toLowerCase();
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
                            title: Text(
                              nome,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            trailing: selecionado
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                : const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                            onTap: () {
                              setState(() {
                                _canteiroId = doc.id;
                                _canteiroNome = nome;
                              });
                              Navigator.pop(sheetContext);
                              _snack('Salvando planejamento em: $nome');
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

  // =========================
  // Persistência profissional
  // =========================
  Future<String> _salvarPlanejamentoNoCanteiro({
    required String canteiroId,
    required List<Map<String, dynamic>> itensDesejados,
    required List<Map<String, dynamic>> itensProcessados,
    required double areaTotal,
    required double aguaTotal,
    required double aduboTotal,
  }) async {
    final user = _user;
    if (user == null) throw Exception('Usuário não autenticado.');

    final canteiroRef = FirebaseFirestore.instance
        .collection('canteiros')
        .doc(canteiroId);
    final planejamentoRef = canteiroRef.collection('planejamentos').doc();

    final resumo = {
      'itens': itensDesejados,
      'area_total_m2': areaTotal,
      'agua_l_dia': aguaTotal,
      'adubo_kg': aduboTotal,
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

  // =========================
  // GERAR PLANO + SALVAR
  // =========================
  Future<void> _gerarESalvarEIrParaGerador() async {
    if (_listaDesejos.isEmpty) {
      _snack('Adicione pelo menos um item para planejar!', bg: Colors.orange);
      return;
    }
    if (_canteiroId == null) {
      _snack(
        'Selecione um canteiro para salvar este planejamento.',
        bg: Colors.orange,
      );
      _selecionarCanteiro();
      return;
    }

    setState(() => _salvando = true);

    try {
      // Prepara a lista com dados técnicos para o algoritmo
      final itensProcessados = _listaDesejos.map((item) {
        final nome = item['planta'] as String;
        final meta = (item['meta'] as num).toDouble();

        final info =
            _dadosProdutividade[nome] ??
            {
              'yield': 1.0,
              'espaco': 0.5,
              'evitar': [],
              'par': [],
              'cat': 'Geral',
            };

        final yieldVal = (info['yield'] as num).toDouble();
        final espacoVal = (info['espaco'] as num).toDouble();

        final mudasCalc = meta / yieldVal;
        final mudasReais = (mudasCalc * 1.1).ceil(); // +10% margem
        final areaNecessaria = mudasReais * espacoVal;

        return {
          'planta': nome,
          'mudas': mudasReais,
          'area': areaNecessaria,
          'evitar': info['evitar'] ?? [],
          'par': info['par'] ?? [],
          'cat': info['cat'] ?? 'Geral',
        };
      }).toList();

      // Totais
      final areaTotal = itensProcessados.fold<double>(
        0,
        (sum, it) => sum + ((it['area'] as num).toDouble()),
      );
      final aguaTotal = areaTotal * 4; // L/dia
      final aduboTotal = areaTotal * 3; // kg

      await _salvarPlanejamentoNoCanteiro(
        canteiroId: _canteiroId!,
        itensDesejados: List<Map<String, dynamic>>.from(_listaDesejos),
        itensProcessados: List<Map<String, dynamic>>.from(itensProcessados),
        areaTotal: areaTotal,
        aguaTotal: aguaTotal,
        aduboTotal: aduboTotal,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              TelaGeradorCanteiros(itensPlanejados: itensProcessados),
        ),
      );
    } catch (e) {
      _snack('Erro ao salvar planejamento: $e', bg: Colors.red);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listaCulturasOrdenada = _dadosProdutividade.keys.toList()..sort();

    double areaTotal = 0;
    double aguaTotal = 0;
    double aduboTotal = 0;

    final cards = _listaDesejos.asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;

      final nome = item['planta'] as String;
      final meta = (item['meta'] as num).toDouble();

      final info =
          _dadosProdutividade[nome] ??
          {
            'yield': 1.0,
            'unit': 'kg',
            'espaco': 0.5,
            'info': 'Cultura personalizada.',
          };

      final yieldVal = (info['yield'] as num).toDouble();
      final espacoVal = (info['espaco'] as num).toDouble();

      final plantasExatas = meta / yieldVal;
      final plantasReais = (plantasExatas * 1.1).ceil();
      final areaItem = plantasReais * espacoVal;

      areaTotal += areaItem;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${plantasReais}x',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ),
          title: Text(
            nome,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${meta.toStringAsFixed(1)} ${info['unit']} desejados',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.green[300]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      (info['info'] ?? '').toString(),
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.green[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Ocupa aprox: ${areaItem.toStringAsFixed(2)} m²',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          trailing: PopupMenuButton(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Editar'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Remover'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'edit') _iniciarEdicao(idx);
              if (value == 'delete') _removerItem(idx);
            },
          ),
        ),
      );
    }).toList();

    aguaTotal = areaTotal * 4;
    aduboTotal = areaTotal * 3;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            title: const Text(
              'Planejamento de Consumo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            centerTitle: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.green[800],
            elevation: 0,
            actions: [
              AppButtons.textIcon(
                onPressed: _selecionarCanteiro,
                icon: const Icon(Icons.grid_view),
                label: Text(
                  _canteiroNome == null ? 'Selecionar canteiro' : 'Trocar',
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(25),
                  ),
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
                    // Canteiro selecionado (visual)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _canteiroId == null
                            ? Colors.orange.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _canteiroId == null
                              ? Colors.orange.shade100
                              : Colors.green.shade100,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _canteiroId == null
                                ? Icons.warning_amber
                                : Icons.check_circle,
                            color: _canteiroId == null
                                ? Colors.orange
                                : Colors.green,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _canteiroId == null
                                  ? 'Selecione um canteiro para salvar este planejamento.'
                                  : 'Salvando em: $_canteiroNome',
                              style: TextStyle(
                                color: _canteiroId == null
                                    ? Colors.orange.shade800
                                    : Colors.green.shade800,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _selecionarCanteiro,
                            child: const Text('Selecionar'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _editandoIndex != null
                              ? 'Editando Item...'
                              : 'O que vamos plantar?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _editandoIndex != null
                                ? Colors.blue
                                : Colors.grey[800],
                          ),
                        ),
                        if (_editandoIndex != null)
                          AppButtons.textIcon(
                            onPressed: _cancelarEdicao,
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Cancelar'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: _modoPersonalizado
                              ? TextField(
                                  controller: _customNameController,
                                  decoration: InputDecoration(
                                    labelText: 'Nome da Cultura',
                                    hintText: 'Ex: Jiló',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 15,
                                      vertical: 15,
                                    ),
                                    isDense: true,
                                  ),
                                )
                              : DropdownButtonFormField<String>(
                                  value: _culturaSelecionada,
                                  hint: const Text('Selecione...'),
                                  isExpanded: true,
                                  items: listaCulturasOrdenada.map((key) {
                                    return DropdownMenuItem(
                                      value: key,
                                      child: Text(
                                        key,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (v) =>
                                      setState(() => _culturaSelecionada = v),
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 15,
                                      vertical: 15,
                                    ),
                                    isDense: true,
                                  ),
                                ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _modoPersonalizado = !_modoPersonalizado;
                              _culturaSelecionada = null;
                              _customNameController.clear();
                            });
                          },
                          tooltip: _modoPersonalizado
                              ? 'Voltar para Lista'
                              : 'Digitar outro',
                          icon: Icon(
                            _modoPersonalizado ? Icons.list : Icons.keyboard,
                            color: Colors.green,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _qtdController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9\.,]'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Qtd',
                              suffixText:
                                  !_modoPersonalizado &&
                                      _culturaSelecionada != null
                                  ? (_dadosProdutividade[_culturaSelecionada]!['unit'])
                                        .toString()
                                  : 'kg/un',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 15,
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    SizedBox(
                      width: double.infinity,
                      child: AppButtons.elevatedIcon(
                        onPressed: _salvarItem,
                        icon: Icon(
                          _editandoIndex != null
                              ? Icons.save
                              : Icons.add_circle,
                          color: Colors.white,
                        ),
                        label: Text(
                          _editandoIndex != null
                              ? 'SALVAR ALTERAÇÕES'
                              : 'ADICIONAR À LISTA',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _editandoIndex != null
                              ? Colors.blue
                              : Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _listaDesejos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.spa_outlined,
                              size: 80,
                              color: Colors.grey.withOpacity(0.2),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              'Sua lista está vazia.',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Adicione o que sua família consome.',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          ...cards,
                          const SizedBox(height: 10),

                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.green.shade800,
                                  Colors.green.shade600,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.analytics,
                                      color: Colors.white70,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'ESTIMATIVA TOTAL DO SISTEMA',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(
                                  color: Colors.white24,
                                  height: 25,
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _InfoResumo(
                                      icon: Icons.crop_free,
                                      valor: areaTotal.toStringAsFixed(1),
                                      unidade: 'm²',
                                      label: 'Área Útil',
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.white24,
                                    ),
                                    _InfoResumo(
                                      icon: Icons.water_drop,
                                      valor: aguaTotal.toStringAsFixed(0),
                                      unidade: 'L/dia',
                                      label: 'Água Aprox.',
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.white24,
                                    ),
                                    _InfoResumo(
                                      icon: Icons.compost,
                                      valor: aduboTotal.toStringAsFixed(1),
                                      unidade: 'kg',
                                      label: 'Adubo (Organo15)',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 15),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black12,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '💡 Cálculo inclui +10% de margem de segurança.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: AppButtons.elevatedIcon(
              onPressed: _gerarESalvarEIrParaGerador,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('GERAR PLANO INTELIGENTE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 4,
                shadowColor: Colors.blue.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),

        if (_salvando)
          Container(
            color: Colors.black.withOpacity(0.25),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _InfoResumo extends StatelessWidget {
  final IconData icon;
  final String valor;
  final String unidade;
  final String label;

  const _InfoResumo({
    required this.icon,
    required this.valor,
    required this.unidade,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              valor,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unidade,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
      ],
    );
  }
}
