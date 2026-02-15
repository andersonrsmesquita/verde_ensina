import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/ui/app_ui.dart';
import '../../core/firebase/firebase_paths.dart';
import '../../core/session/app_session.dart';
import '../../core/session/session_scope.dart';

// Importe o Guia de Culturas que você já tem (ou crie se não tiver)
// Se não tiver, crie um arquivo guia_culturas.dart com o mapa _dadosProdutividade
import '../canteiros/guia_culturas.dart'; // Ajuste o caminho conforme sua estrutura
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

  AppSession? get _sessionOrNull => SessionScope.of(context).session;
  AppSession get appSession {
    final s = _sessionOrNull;
    if (s == null) {
      throw StateError('Sessão indisponível (tenant não selecionado)');
    }
    return s;
  }

  // --- Estado da Tela ---
  final List<Map<String, dynamic>> _listaDesejos = [];
  String? _canteiroId;
  String? _canteiroNome; // Para mostrar feedback visual
  String? _culturaSelecionada;

  // Controladores
  final _qtdController = TextEditingController();
  final _customNameController = TextEditingController();

  // Flags de UI
  bool _modoPersonalizado = false;
  int? _editandoIndex;
  bool _salvando = false;

  @override
  void dispose() {
    _qtdController.dispose();
    _customNameController.dispose();
    super.dispose();
  }

  // Helper de Feedback
  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (isError) {
      AppMessenger.error(msg);
    } else {
      AppMessenger.success(msg);
    }
  }

  // Helper de Formatação de Texto
  String _formatarTexto(String texto) {
    if (texto.isEmpty) return "";
    return texto.trim().split(' ').map((word) {
      if (word.isEmpty) return "";
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // --- Lógica de Negócio Local (CRUD da Lista) ---

  void _salvarItem() {
    // 1. Validação do Nome
    String nomeFinal;
    if (_modoPersonalizado) {
      if (_customNameController.text.trim().isEmpty) {
        return _snack('Informe o nome da cultura.', isError: true);
      }
      nomeFinal = _formatarTexto(_customNameController.text);
    } else {
      if (_culturaSelecionada == null) {
        return _snack('Selecione uma cultura.', isError: true);
      }
      nomeFinal = _culturaSelecionada!;
    }

    // 2. Validação da Quantidade
    if (_qtdController.text.trim().isEmpty) {
      return _snack('Informe a quantidade.', isError: true);
    }
    final qtd =
        double.tryParse(_qtdController.text.replaceAll(',', '.')) ?? 0.0;
    if (qtd <= 0) {
      return _snack('Quantidade inválida.', isError: true);
    }

    // 3. Atualização da Lista
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

      // Reset dos campos
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

      // Verifica se é uma cultura padrão ou customizada
      // OBS: GuiaCulturas.dados é onde você deve centralizar o mapa _dadosProdutividade
      if (GuiaCulturas.dados.containsKey(item['planta'])) {
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

  // --- Lógica de Negócio Global (Processamento e Salvamento) ---

  Future<void> _gerarESalvarEIrParaGerador() async {
    if (_listaDesejos.isEmpty) {
      return _snack('Adicione pelo menos um item para planejar!',
          isError: true);
    }
    if (_canteiroId == null) {
      _snack('Por favor, selecione um lote no topo da tela.', isError: true);
      return;
    }

    setState(() => _salvando = true);

    try {
      // 1. Processamento Matemático
      double areaTotalCalculada = 0.0;
      double horasMaoDeObraTotal = 0.0;

      final itensProcessados = _listaDesejos.map((item) {
        final nome = item['planta'] as String;
        final meta = (item['meta'] as num).toDouble();

        // Fallback seguro se não encontrar no guia
        final info = GuiaCulturas.dados[nome] ??
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

        // Cálculo de Mudas e Área
        final mudasCalc = meta / yieldVal;
        final mudasReais =
            (mudasCalc * 1.1).ceil(); // Margem de segurança de 10%
        final areaNecessaria = mudasReais * espacoVal;

        // Cálculo de Mão de Obra (Baseado no PDF Custo Mão de Obra)
        int cicloSemanas = (cicloDias / 7).ceil();
        if (cicloSemanas < 1) cicloSemanas = 1;

        double horasFase1 = areaNecessaria * 0.25; // Preparo
        double horasFase2 = areaNecessaria * 0.083 * cicloSemanas; // Manutenção
        double horasFase3 = areaNecessaria * 0.016; // Colheita
        double horasTotaisCultura = horasFase1 + horasFase2 + horasFase3;

        areaTotalCalculada += areaNecessaria;
        horasMaoDeObraTotal +=
            (horasTotaisCultura / cicloSemanas); // Média semanal

        return {
          'planta': nome,
          'mudas': mudasReais,
          'area': areaNecessaria,
          'evitar': info['evitar'] ?? [],
          'par': info['par'] ?? [],
          'cat': info['cat'] ?? 'Geral',
        };
      }).toList();

      // Estimativas de Insumos (Baseado no PDF Organo 15)
      final aguaTotal = areaTotalCalculada * 5.0; // 5mm/dia
      final aduboTotal = areaTotalCalculada * 3.0; // 3kg/m² (Média esterco)

      // 2. Persistência no Firestore (Transação Segura)
      await _salvarPlanejamentoNoCanteiro(
        canteiroId: _canteiroId!,
        itensDesejados: List<Map<String, dynamic>>.from(_listaDesejos),
        itensProcessados: List<Map<String, dynamic>>.from(itensProcessados),
        areaTotal: areaTotalCalculada,
        aguaTotal: aguaTotal,
        aduboTotal: aduboTotal,
        maoDeObraTotal: horasMaoDeObraTotal,
      );

      if (mounted) setState(() => _salvando = false);

      // Pequeno delay para garantir que o loading saia da tela
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;

      // 3. Navegação para o Gerador (Próxima etapa da trilha)
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

    // Cria o documento detalhado do planejamento
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

    // Atualiza o cabeçalho do canteiro com o planejamento ATIVO
    batch.update(canteiroRef, {
      'planejamento_atual': resumo,
      'planejamento_ativo_id': planejamentoRef.id,
      'planejamento_updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return planejamentoRef.id;
  }

  // =======================================================================
  // INTERFACE GRÁFICA (UI)
  // =======================================================================

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Lista ordenada para o dropdown
    final listaCulturasOrdenada = GuiaCulturas.dados.keys.toList()..sort();

    // Cálculos em tempo real para o Card de Resumo (Feedback imediato)
    double areaTotal = 0;
    double horasSemanaisTotal = 0;

    final cardsWidgets = _listaDesejos.asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;

      final nome = item['planta'] as String;
      final meta = (item['meta'] as num).toDouble();

      final info = GuiaCulturas.dados[nome] ??
          {'yield': 1.0, 'unit': 'kg', 'espaco': 0.5, 'cicloDias': 60};

      final yieldVal = (info['yield'] as num).toDouble();
      final espacoVal = (info['espaco'] as num).toDouble();
      final cicloDias = (info['cicloDias'] as int?) ?? 60;

      final plantasReais = ((meta / yieldVal) * 1.1).ceil();
      final areaItem = plantasReais * espacoVal;

      areaTotal += areaItem;

      int cicloSemanas = (cicloDias / 7).ceil();
      if (cicloSemanas < 1) cicloSemanas = 1;

      double horasItem = (areaItem * 0.25) +
          (areaItem * 0.083 * cicloSemanas) +
          (areaItem * 0.016);

      horasSemanaisTotal += (horasItem / cicloSemanas);

      return _buildItemCard(idx, nome, meta, info, plantasReais, areaItem, cs);
    }).toList();

    return PageContainer(
      title: 'Plano de Consumo',
      subtitle: 'Defina o que você quer colher',
      scroll: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Seletor de Canteiro (Componente Reutilizável)
          SectionCard(
            title: '1) Qual Lote vai receber o plantio?',
            child: CanteiroPickerDropdown(
              tenantId: appSession.tenantId,
              selectedId: _canteiroId,
              onSelect: (id) => setState(() => _canteiroId = id),
            ),
          ),

          const SizedBox(height: 16),

          // 2. Formulário de Adição
          SectionCard(
            title: _editandoIndex != null
                ? 'Editando Cultura...'
                : '2) Adicionar Cultura',
            child: Column(
              children: [
                _buildFormularioAdicao(cs, listaCulturasOrdenada),
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

          // 3. Lista de Itens ou Estado Vazio
          if (_listaDesejos.isEmpty)
            _buildEmptyState(cs)
          else ...[
            Text('Itens Adicionados',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...cardsWidgets,

            const SizedBox(height: 16),

            // 4. Card de Resumo (Estimativa Total)
            _buildResumoTotal(cs, areaTotal, horasSemanaisTotal),
          ]
        ],
      ),
      bottomBar: SizedBox(
        height: 50,
        width: double.infinity,
        child: AppButtons.elevatedIcon(
          onPressed: _salvando ? null : _gerarESalvarEIrParaGerador,
          icon: _salvando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.auto_awesome),
          label: Text(_salvando ? 'PROCESSANDO...' : 'GERAR PLANO INTELIGENTE'),
        ),
      ),
    );
  }

  // --- Widgets Auxiliares de Construção ---

  Widget _buildFormularioAdicao(ColorScheme cs, List<String> listaCulturas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('O que você quer colher?',
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
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
                  ? TextFormField(
                      controller: _customNameController,
                      decoration: const InputDecoration(
                          labelText: 'Nome da Cultura',
                          border: OutlineInputBorder(),
                          isDense: true),
                    )
                  : DropdownButtonFormField<String>(
                      value: _culturaSelecionada,
                      hint: const Text('Selecione...'),
                      isExpanded: true,
                      decoration: const InputDecoration(
                          border: OutlineInputBorder(), isDense: true),
                      items: listaCulturas
                          .map((k) => DropdownMenuItem(
                              value: k,
                              child: Text(k,
                                  style: const TextStyle(fontSize: 14))))
                          .toList(),
                      onChanged: (v) => setState(() => _culturaSelecionada = v),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _qtdController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]'))
                ],
                decoration: InputDecoration(
                  labelText: 'Qtd',
                  suffixText: !_modoPersonalizado && _culturaSelecionada != null
                      ? (GuiaCulturas.dados[_culturaSelecionada]!['unit'])
                          .toString()
                      : 'kg/un',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
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
              label: Text('Cancelar Edição', style: TextStyle(color: cs.error)),
            ),
          ),
      ],
    );
  }

  Widget _buildItemCard(int idx, String nome, double meta, Map info,
      int plantasReais, double areaItem, ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
          side: BorderSide(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(12)),
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
        title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${meta.toStringAsFixed(1)} ${info['unit']} desejados',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 4),
            Text('Ocupa aprox: ${areaItem.toStringAsFixed(2)} m²',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.eco_outlined, size: 64, color: cs.outlineVariant),
          const SizedBox(height: 16),
          Text('Sua lista de plantio está vazia.',
              style: TextStyle(
                  fontSize: 16,
                  color: cs.outline,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildResumoTotal(
      ColorScheme cs, double areaTotal, double horasSemanaisTotal) {
    return SectionCard(
      title: 'Estimativa Total do Sistema',
      child: Column(
        children: [
          AppKeyValueRow(
              label: 'Área Útil Ocupada',
              value: '${areaTotal.toStringAsFixed(1)} m²',
              color: cs.primary),
          AppKeyValueRow(
              label: 'Água Necessária',
              value: '${(areaTotal * 5.0).toStringAsFixed(0)} L/dia',
              color: Colors.blue.shade700),
          AppKeyValueRow(
              label: 'Adubo Base',
              value: '${(areaTotal * 3.0).toStringAsFixed(1)} kg',
              color: Colors.brown.shade700),
          const Divider(),
          AppKeyValueRow(
              label: 'Mão de Obra',
              value: '${horasSemanaisTotal.toStringAsFixed(1)} h/sem',
              isBold: true),
        ],
      ),
    );
  }
}

// ⚠️ Se você ainda não tiver este arquivo, crie 'guia_culturas.dart' na mesma pasta ou em core/constants
class GuiaCulturas {
  static const Map<String, Map<String, dynamic>> dados = {
    'Abobrinha italiana': {
      'yield': 2.0,
      'unit': 'kg',
      'espaco': 1.0,
      'cat': 'Frutos',
      'cicloDias': 60
    },
    'Abóboras': {
      'yield': 5.0,
      'unit': 'kg',
      'espaco': 6.0,
      'cat': 'Frutos',
      'cicloDias': 120
    },
    'Acelga': {
      'yield': 0.8,
      'unit': 'maço',
      'espaco': 0.2,
      'cat': 'Folhas',
      'cicloDias': 70
    },
    'Alface': {
      'yield': 0.3,
      'unit': 'un',
      'espaco': 0.0625,
      'cat': 'Folhas',
      'cicloDias': 60
    },
    'Alho': {
      'yield': 0.04,
      'unit': 'kg',
      'espaco': 0.025,
      'cat': 'Bulbos',
      'cicloDias': 150
    },
    'Batata doce': {
      'yield': 1.0,
      'unit': 'kg',
      'espaco': 0.27,
      'cat': 'Raízes',
      'cicloDias': 150
    },
    'Berinjela': {
      'yield': 2.0,
      'unit': 'kg',
      'espaco': 0.8,
      'cat': 'Frutos',
      'cicloDias': 120
    },
    'Beterraba': {
      'yield': 0.15,
      'unit': 'un',
      'espaco': 0.025,
      'cat': 'Raízes',
      'cicloDias': 70
    },
    'Brócolis': {
      'yield': 0.5,
      'unit': 'un',
      'espaco': 0.4,
      'cat': 'Flores',
      'cicloDias': 100
    },
    'Cebola': {
      'yield': 0.15,
      'unit': 'kg',
      'espaco': 0.03,
      'cat': 'Bulbos',
      'cicloDias': 150
    },
    'Cebolinha': {
      'yield': 0.2,
      'unit': 'maço',
      'espaco': 0.025,
      'cat': 'Temperos',
      'cicloDias': 90
    },
    'Cenoura': {
      'yield': 0.1,
      'unit': 'kg',
      'espaco': 0.0125,
      'cat': 'Raízes',
      'cicloDias': 100
    },
    'Coentro': {
      'yield': 0.2,
      'unit': 'maço',
      'espaco': 0.02,
      'cat': 'Temperos',
      'cicloDias': 60
    },
    'Couve': {
      'yield': 1.5,
      'unit': 'maços',
      'espaco': 0.4,
      'cat': 'Folhas',
      'cicloDias': 90
    },
    'Mandioca': {
      'yield': 3.0,
      'unit': 'kg',
      'espaco': 0.6,
      'cat': 'Raízes',
      'cicloDias': 365
    },
    'Pimentão': {
      'yield': 1.0,
      'unit': 'kg',
      'espaco': 0.5,
      'cat': 'Frutos',
      'cicloDias': 120
    },
    'Quiabo': {
      'yield': 0.8,
      'unit': 'kg',
      'espaco': 0.3,
      'cat': 'Frutos',
      'cicloDias': 80
    },
    'Rúcula': {
      'yield': 0.5,
      'unit': 'maço',
      'espaco': 0.01,
      'cat': 'Folhas',
      'cicloDias': 50
    },
    'Tomate': {
      'yield': 3.0,
      'unit': 'kg',
      'espaco': 0.5,
      'cat': 'Frutos',
      'cicloDias': 120
    },
  };
}
