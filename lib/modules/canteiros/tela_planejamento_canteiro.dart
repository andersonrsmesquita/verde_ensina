// FILE: lib/modules/canteiros/tela_planejamento_canteiro.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/firebase/firebase_paths.dart';
import '../../core/session/app_session.dart';
import '../../core/session/session_scope.dart';
import '../../core/ui/app_ui.dart';

import '../planejamento/tela_gerador_canteiros.dart';
import 'widgets/canteiro_picker_dropdown.dart';

class TelaPlanejamentoCanteiro extends StatefulWidget {
  const TelaPlanejamentoCanteiro({super.key});

  @override
  State<TelaPlanejamentoCanteiro> createState() =>
      _TelaPlanejamentoCanteiroState();
}

class _TelaPlanejamentoCanteiroState extends State<TelaPlanejamentoCanteiro> {
  User? get _user => FirebaseAuth.instance.currentUser;

  AppSession? get _sessionOrNull => SessionScope.of(context).session;

  // =======================================================================
  // DADOS AGRONÔMICOS (mantido aqui pra não mexer no seu fluxo atual)
  // =======================================================================
  final Map<String, Map<String, dynamic>> _dadosProdutividade = {
    'Abobrinha italiana': {
      'yield': 2.0,
      'unit': 'kg',
      'espaco': 1.0 * 1.0,
      'cat': 'Frutos',
      'cicloDias': 60
    },
    'Abóboras': {
      'yield': 5.0,
      'unit': 'kg',
      'espaco': 3.0 * 2.0,
      'cat': 'Frutos',
      'cicloDias': 120
    },
    'Acelga': {
      'yield': 0.8,
      'unit': 'maço',
      'espaco': 0.5 * 0.4,
      'cat': 'Folhas',
      'cicloDias': 70
    },
    'Alface': {
      'yield': 0.3,
      'unit': 'un',
      'espaco': 0.25 * 0.25,
      'cat': 'Folhas',
      'cicloDias': 60
    },
    'Alho': {
      'yield': 0.04,
      'unit': 'kg',
      'espaco': 0.25 * 0.1,
      'cat': 'Bulbos',
      'cicloDias': 150
    },
    'Batata doce': {
      'yield': 1.0,
      'unit': 'kg',
      'espaco': 0.9 * 0.3,
      'cat': 'Raízes',
      'cicloDias': 150
    },
    'Berinjela': {
      'yield': 2.0,
      'unit': 'kg',
      'espaco': 1.0 * 0.8,
      'cat': 'Frutos',
      'cicloDias': 120
    },
    'Beterraba': {
      'yield': 0.15,
      'unit': 'un',
      'espaco': 0.25 * 0.1,
      'cat': 'Raízes',
      'cicloDias': 70
    },
    'Brócolis': {
      'yield': 0.5,
      'unit': 'un',
      'espaco': 0.8 * 0.5,
      'cat': 'Flores',
      'cicloDias': 100
    },
    'Cebola': {
      'yield': 0.15,
      'unit': 'kg',
      'espaco': 0.3 * 0.1,
      'cat': 'Bulbos',
      'cicloDias': 150
    },
    'Cebolinha': {
      'yield': 0.2,
      'unit': 'maço',
      'espaco': 0.25 * 0.1,
      'cat': 'Temperos',
      'cicloDias': 90
    },
    'Cenoura': {
      'yield': 0.1,
      'unit': 'kg',
      'espaco': 0.25 * 0.05,
      'cat': 'Raízes',
      'cicloDias': 100
    },
    'Coentro': {
      'yield': 0.2,
      'unit': 'maço',
      'espaco': 0.2 * 0.1,
      'cat': 'Temperos',
      'cicloDias': 60
    },
    'Couve': {
      'yield': 1.5,
      'unit': 'maços',
      'espaco': 0.8 * 0.5,
      'cat': 'Folhas',
      'cicloDias': 90
    },
    'Mandioca': {
      'yield': 3.0,
      'unit': 'kg',
      'espaco': 1.0 * 0.6,
      'cat': 'Raízes',
      'cicloDias': 365
    },
    'Pimentão': {
      'yield': 1.0,
      'unit': 'kg',
      'espaco': 1.0 * 0.5,
      'cat': 'Frutos',
      'cicloDias': 120
    },
    'Quiabo': {
      'yield': 0.8,
      'unit': 'kg',
      'espaco': 1.0 * 0.3,
      'cat': 'Frutos',
      'cicloDias': 80
    },
    'Rúcula': {
      'yield': 0.5,
      'unit': 'maço',
      'espaco': 0.2 * 0.05,
      'cat': 'Folhas',
      'cicloDias': 50
    },
    'Tomate': {
      'yield': 3.0,
      'unit': 'kg',
      'espaco': 1.0 * 0.5,
      'cat': 'Frutos',
      'cicloDias': 120
    },
  };

  final List<Map<String, dynamic>> _listaDesejos = [];

  String? _canteiroId;
  String? _canteiroNome; // mantido caso você use depois
  String? _culturaSelecionada;

  final TextEditingController _qtdController = TextEditingController();
  final TextEditingController _customNameController = TextEditingController();

  bool _modoPersonalizado = false;
  int? _editandoIndex;
  bool _salvando = false;

  @override
  void dispose() {
    _qtdController.dispose();
    _customNameController.dispose();
    super.dispose();
  }

  // =========================
  // UX helpers
  // =========================
  void _snack(String msg, {bool isError = false}) {
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
    final parts = t.split(RegExp(r'\s+'));
    return parts.map((word) {
      if (word.isEmpty) return '';
      final first = word.characters.first.toUpperCase();
      final rest = word.characters.skip(1).toString().toLowerCase();
      return '$first$rest';
    }).join(' ');
  }

  double _parseQtd(String raw) {
    final v = raw.trim().replaceAll(',', '.');
    return double.tryParse(v) ?? 0.0;
  }

  // =========================
  // CRUD da lista
  // =========================
  void _salvarItem() {
    String nomeFinal;

    if (_modoPersonalizado) {
      final custom = _customNameController.text.trim();
      if (custom.isEmpty)
        return _snack('Informe o nome da cultura.', isError: true);
      nomeFinal = _formatarTexto(custom);
    } else {
      if (_culturaSelecionada == null)
        return _snack('Selecione uma cultura.', isError: true);
      nomeFinal = _culturaSelecionada!;
    }

    final qtdRaw = _qtdController.text.trim();
    if (qtdRaw.isEmpty) return _snack('Informe a quantidade.', isError: true);

    final qtd = _parseQtd(qtdRaw);
    if (qtd <= 0) return _snack('Quantidade inválida.', isError: true);

    setState(() {
      final novoItem = <String, dynamic>{
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
      _qtdController.text = (item['meta'] as num).toString();

      final planta = (item['planta'] as String?) ?? '';
      if (_dadosProdutividade.containsKey(planta)) {
        _modoPersonalizado = false;
        _culturaSelecionada = planta;
        _customNameController.clear();
      } else {
        _modoPersonalizado = true;
        _customNameController.text = planta;
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
  // Persistência (Firestore)
  // =========================
  Future<String> _salvarPlanejamentoNoCanteiro({
    required AppSession session,
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

    final canteiroRef = FirebasePaths.canteiroRef(session.tenantId, canteiroId);
    final planejamentoRef =
        FirebasePaths.canteiroPlanejamentosCol(session.tenantId, canteiroId)
            .doc();

    final resumo = <String, dynamic>{
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

  Future<void> _gerarESalvarEIrParaGerador(AppSession session) async {
    if (_listaDesejos.isEmpty) {
      return _snack('Adicione pelo menos um item para planejar!',
          isError: true);
    }
    if (_canteiroId == null) {
      return _snack('Por favor, selecione um lote.', isError: true);
    }

    if (_salvando) return;
    setState(() => _salvando = true);

    try {
      double areaTotalCalculada = 0.0;
      double horasMaoDeObraTotal = 0.0;

      final itensProcessados = _listaDesejos.map((item) {
        final nome = item['planta'] as String;
        final meta = (item['meta'] as num).toDouble();

        final info = _dadosProdutividade[nome] ??
            <String, dynamic>{
              'yield': 1.0,
              'unit': 'un',
              'espaco': 0.5,
              'cicloDias': 60,
              'evitar': <dynamic>[],
              'par': <dynamic>[],
              'cat': 'Geral',
            };

        final yieldVal = (info['yield'] as num).toDouble();
        final espacoVal = (info['espaco'] as num).toDouble();
        final cicloDias = (info['cicloDias'] as int?) ?? 60;

        final mudasCalc = meta / yieldVal;
        final mudasReais = (mudasCalc * 1.1).ceil(); // margem 10%
        final areaNecessaria = mudasReais * espacoVal;

        int cicloSemanas = (cicloDias / 7).ceil();
        if (cicloSemanas < 1) cicloSemanas = 1;

        final horasFase1 = areaNecessaria * 0.25;
        final horasFase2 = areaNecessaria * 0.083 * cicloSemanas;
        final horasFase3 = areaNecessaria * 0.016;
        final horasTotaisCultura = horasFase1 + horasFase2 + horasFase3;

        areaTotalCalculada += areaNecessaria;
        horasMaoDeObraTotal += (horasTotaisCultura / cicloSemanas);

        return <String, dynamic>{
          'planta': nome,
          'mudas': mudasReais,
          'area': areaNecessaria,
          'evitar': info['evitar'] ?? <dynamic>[],
          'par': info['par'] ?? <dynamic>[],
          'cat': info['cat'] ?? 'Geral',
        };
      }).toList();

      final aguaTotal = areaTotalCalculada * 5.0;
      final aduboTotal = areaTotalCalculada * 3.0;

      await _salvarPlanejamentoNoCanteiro(
        session: session,
        canteiroId: _canteiroId!,
        itensDesejados: List<Map<String, dynamic>>.from(_listaDesejos),
        itensProcessados: List<Map<String, dynamic>>.from(itensProcessados),
        areaTotal: areaTotalCalculada,
        aguaTotal: aguaTotal,
        aduboTotal: aduboTotal,
        maoDeObraTotal: horasMaoDeObraTotal,
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
      _snack('Erro ao salvar planejamento: $e', isError: true);
    }
  }

  // =======================================================================
  // UI
  // =======================================================================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final session = _sessionOrNull;
    if (session == null) {
      return PageContainer(
        title: 'Plano de Consumo',
        subtitle: 'Selecione um tenant para continuar',
        scroll: true,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(
              title: 'Sessão indisponível',
              child: Text(
                'Nenhum tenant foi selecionado. Volte e escolha seu ambiente (tenant) para carregar os canteiros.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    final listaCulturasOrdenada = _dadosProdutividade.keys.toList()..sort();

    double areaTotal = 0;
    double horasSemanaisTotal = 0;

    final cardsWidgets = _listaDesejos.asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;

      final nome = item['planta'] as String;
      final meta = (item['meta'] as num).toDouble();

      final info = _dadosProdutividade[nome] ??
          <String, dynamic>{
            'yield': 1.0,
            'unit': 'un',
            'espaco': 0.5,
            'cicloDias': 60,
            'info': 'Personalizada',
          };

      final yieldVal = (info['yield'] as num).toDouble();
      final espacoVal = (info['espaco'] as num).toDouble();
      final cicloDias = (info['cicloDias'] as int?) ?? 60;

      final plantasReais = ((meta / yieldVal) * 1.1).ceil();
      final areaItem = plantasReais * espacoVal;

      areaTotal += areaItem;

      int cicloSemanas = (cicloDias / 7).ceil();
      if (cicloSemanas < 1) cicloSemanas = 1;

      horasSemanaisTotal += (((areaItem * 0.25) +
              (areaItem * 0.083 * cicloSemanas) +
              (areaItem * 0.016)) /
          cicloSemanas);

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: Text(
              '${plantasReais}x',
              style: TextStyle(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          title:
              Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${meta.toStringAsFixed(1)} ${info['unit']} desejados',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                'Ocupa aprox: ${areaItem.toStringAsFixed(2)} m²',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: cs.outline),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(
                value: 'delete',
                child: Text('Remover', style: TextStyle(color: cs.error)),
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

    return PageContainer(
      title: 'Plano de Consumo',
      subtitle: 'Defina o que você quer colher',
      scroll: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: '1) Qual Lote vai receber o plantio?',
            child: CanteiroPickerDropdown(
              tenantId: session.tenantId,
              selectedId: _canteiroId,
              onSelect: (id) => setState(() => _canteiroId = id),
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: _editandoIndex != null
                ? 'Editando Cultura...'
                : '2) Adicionar Cultura',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('O que você quer colher?',
                        style: TextStyle(
                            fontSize: 14, color: cs.onSurfaceVariant)),
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
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _modoPersonalizado
                          ? TextFormField(
                              controller: _customNameController,
                              decoration: const InputDecoration(
                                labelText: 'Nome da Cultura',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: _culturaSelecionada,
                              hint: const Text('Selecione...'),
                              isExpanded: true,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: listaCulturasOrdenada
                                  .map((k) => DropdownMenuItem(
                                        value: k,
                                        child: Text(k,
                                            style:
                                                const TextStyle(fontSize: 14)),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _culturaSelecionada = v),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _qtdController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9\.,]')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Qtd',
                          suffixText:
                              !_modoPersonalizado && _culturaSelecionada != null
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
                if (_editandoIndex != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _cancelarEdicao,
                    icon: Icon(Icons.close, size: 16, color: cs.error),
                    label: Text('Cancelar Edição',
                        style: TextStyle(color: cs.error)),
                  ),
                ],
                const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          if (_listaDesejos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.eco_outlined, size: 64, color: cs.outlineVariant),
                  const SizedBox(height: 16),
                  Text(
                    'Sua lista de plantio está vazia.',
                    style: TextStyle(
                        fontSize: 16,
                        color: cs.outline,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          else ...[
            Text(
              'Itens Adicionados',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...cardsWidgets,
            const SizedBox(height: 16),
            SectionCard(
              title: 'Estimativa Total do Sistema',
              child: Column(
                children: [
                  AppKeyValueRow(
                    label: 'Área Útil Ocupada',
                    value: '${areaTotal.toStringAsFixed(1)} m²',
                    color: cs.primary,
                  ),
                  AppKeyValueRow(
                    label: 'Água Necessária',
                    value: '${(areaTotal * 5.0).toStringAsFixed(0)} L/dia',
                    color: cs.secondary,
                  ),
                  AppKeyValueRow(
                    label: 'Adubo Base',
                    value: '${(areaTotal * 3.0).toStringAsFixed(1)} kg',
                    color: cs.tertiary,
                  ),
                  const Divider(),
                  AppKeyValueRow(
                    label: 'Mão de Obra',
                    value: '${horasSemanaisTotal.toStringAsFixed(1)} h/sem',
                    isBold: true,
                  ),
                ],
              ),
            ),
          ],
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
}
