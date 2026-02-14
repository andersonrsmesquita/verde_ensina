import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/logic/base_agronomica.dart';
import '../../core/ui/app_ui.dart';
import '../../core/firebase/firebase_paths.dart';
import '../../core/session/session_scope.dart';

enum _ModoReceita { canteiro, vaso }

class TelaAdubacaoOrgano15 extends StatefulWidget {
  const TelaAdubacaoOrgano15({super.key});

  @override
  State<TelaAdubacaoOrgano15> createState() => _TelaAdubacaoOrgano15State();
}

class _TelaAdubacaoOrgano15State extends State<TelaAdubacaoOrgano15> {
  User? get _user => FirebaseAuth.instance.currentUser;

  final _formKey = GlobalKey<FormState>();
  final _inputController = TextEditingController();

  bool _salvando = false;

  _ModoReceita _modo = _ModoReceita.canteiro;
  String _tipoAdubo = 'bovino';
  bool _isSoloArgiloso = false;

  bool _usarCanteiroCadastrado = true;
  String? _canteiroId;
  String _nomeCanteiro = '';
  double _areaM2 = 0;

  Map<String, double>? _resultado;
  bool _resultadoEhCanteiro = true;

  final Map<String, String> _opcoesAdubo = const {
    'bovino': 'Esterco Bovino / Composto',
    'galinha': 'Esterco de Galinha',
    'bokashi': 'Bokashi',
    'mamona': 'Torta de Mamona',
  };

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  double? _toNum(String? v) {
    if (v == null) return null;
    final t = v.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  String _fmt(num v, {int dec = 2}) =>
      v.toStringAsFixed(dec).replaceAll('.', ',');

  String _nomeAdubo() => _opcoesAdubo[_tipoAdubo] ?? _tipoAdubo;

  void _resetResultado() => setState(() => _resultado = null);

  void _resetTudoAoTrocarModo(_ModoReceita novo) {
    setState(() {
      _modo = novo;
      _resultado = null;
      _usarCanteiroCadastrado = (novo == _ModoReceita.canteiro);
      _canteiroId = null;
      _nomeCanteiro = '';
      _areaM2 = 0;
      _inputController.clear();
      _isSoloArgiloso = false;
    });
  }

  Future<void> _carregarCanteiro(String id) async {
    final user = _user;
    if (user == null) return;

    try {
      final appSession = SessionScope.of(context).session;
      if (appSession == null) return;

      final doc =
          await FirebasePaths.canteirosCol(appSession.tenantId).doc(id).get();

      if (!doc.exists || !mounted) return;

      final data = doc.data() ?? {};
      final nome = (data['nome'] ?? 'Canteiro').toString();
      final area = data['area_m2'];

      double areaM2 = 0;
      if (area is num) areaM2 = area.toDouble();
      if (area is String) areaM2 = double.tryParse(area) ?? 0;

      setState(() {
        _canteiroId = id;
        _nomeCanteiro = nome;
        _areaM2 = areaM2;
        _inputController.text = areaM2 > 0 ? _fmt(areaM2, dec: 2) : '';
        _resultado = null;
      });
    } catch (e) {
      AppMessenger.error('Erro ao carregar canteiro: $e');
    }
  }

  void _calcular() {
    FocusScope.of(context).unfocus();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final valor = _toNum(_inputController.text) ?? 0;
    if (valor <= 0) {
      AppMessenger.warn('Digite um valor maior que zero.');
      return;
    }

    if (_modo == _ModoReceita.canteiro) {
      final res = BaseAgronomica.calcularAdubacaoCanteiro(
        areaM2: valor,
        isSoloArgiloso: _isSoloArgiloso,
        tipoAduboOrganico: _tipoAdubo,
      );

      setState(() {
        _resultado = res;
        _resultadoEhCanteiro = true;
      });
    } else {
      final res = BaseAgronomica.calcularMisturaVaso(
        volumeVasoLitros: valor,
        tipoAdubo: _tipoAdubo,
      );

      setState(() {
        _resultado = res;
        _resultadoEhCanteiro = false;
      });
    }

    _mostrarResultado();
  }

  Future<void> _salvarNoCadernoDeCampo(BuildContext sheetContext) async {
    final user = _user;
    if (user == null) {
      AppMessenger.warn('Faça login para salvar.');
      return;
    }
    if (_resultado == null || _salvando) return;

    setState(() => _salvando = true);

    try {
      final fs = FirebaseFirestore.instance;
      final batch = fs.batch();
      final agora = FieldValue.serverTimestamp();
      final appSession = SessionScope.of(context).session;

      if (appSession == null) throw Exception('Sem tenant selecionado');

      final modo = _resultadoEhCanteiro ? 'canteiro' : 'vaso';
      final nomeAdubo = _nomeAdubo();
      final itens = <String, dynamic>{};
      String detalhes = '';

      if (_resultadoEhCanteiro) {
        itens.addAll({
          'adubo_organico_g': (_resultado!['adubo_organico'] ?? 0).toDouble(),
          'calcario_g': (_resultado!['calcario'] ?? 0).toDouble(),
          'termofosfato_g': (_resultado!['termofosfato'] ?? 0).toDouble(),
          'gesso_g': (_resultado!['gesso'] ?? 0).toDouble(),
          'solo_argiloso': _isSoloArgiloso,
          'tipo_adubo': _tipoAdubo,
          'area_m2': _toNum(_inputController.text) ?? 0.0,
        });
        detalhes = 'Organo15 (Canteiro) | Adubo: $nomeAdubo';
      } else {
        itens.addAll({
          'terra_litros': (_resultado!['terra_litros'] ?? 0).toDouble(),
          'adubo_litros': (_resultado!['adubo_litros'] ?? 0).toDouble(),
          'calcario_g': (_resultado!['calcario_gramas'] ?? 0).toDouble(),
          'termofosfato_g':
              (_resultado!['termofosfato_gramas'] ?? 0).toDouble(),
          'tipo_adubo': _tipoAdubo,
          'volume_vaso_l': _toNum(_inputController.text) ?? 0.0,
        });
        detalhes = 'Mistura (Vaso) | Adubo: $nomeAdubo';
      }

      final histRef =
          FirebasePaths.historicoManejoCol(appSession.tenantId).doc();
      final historicoPayload = {
        'uid_usuario': user.uid,
        'data': agora,
        'tipo_manejo':
            _resultadoEhCanteiro ? 'Adubação Orgânica' : 'Mistura Vaso',
        'produto': _resultadoEhCanteiro ? 'Organo15' : 'Mistura',
        'detalhes': detalhes,
        'modo': modo,
        'itens': itens,
        'concluido': true,
        'createdAt': agora,
      };

      if (_resultadoEhCanteiro && _canteiroId != null) {
        historicoPayload['canteiro_id'] = _canteiroId!;
        if (_nomeCanteiro.isNotEmpty) {
          historicoPayload['nome_canteiro'] = _nomeCanteiro;
        }
      }

      batch.set(histRef, _sanitizeMap(historicoPayload));

      if (_resultadoEhCanteiro && _canteiroId != null) {
        final canteiroRef =
            FirebasePaths.canteirosCol(appSession.tenantId).doc(_canteiroId);
        final canteiroPayload = {
          'updatedAt': agora,
          'totais_insumos.adubo_organico_g':
              FieldValue.increment(itens['adubo_organico_g']),
          'totais_insumos.calcario_g':
              FieldValue.increment(itens['calcario_g']),
          'totais_insumos.termofosfato_g':
              FieldValue.increment(itens['termofosfato_g']),
          'totais_insumos.gesso_g': FieldValue.increment(itens['gesso_g']),
          'totais_insumos.aplicacoes_organo15': FieldValue.increment(1),
          'ult_manejo': {
            'tipo': 'Organo15',
            'hist_id': histRef.id,
            'resumo': detalhes,
            'atualizadoEm': agora,
          }
        };
        batch.set(canteiroRef, _sanitizeMap(canteiroPayload),
            SetOptions(merge: true));
      }

      await batch.commit();

      if (!mounted) return;
      Navigator.of(sheetContext).pop();
      AppMessenger.success('Receita salva no Caderno de Campo!');
    } catch (e) {
      AppMessenger.error('Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appSession = SessionScope.of(context).session;

    if (appSession == null) {
      return const Scaffold(
        body:
            Center(child: Text('Selecione um espaço (tenant) para continuar.')),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculadora Organo15'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_salvando) const LinearProgressIndicator(),

            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Modo de Aplicação',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SegmentedButton<_ModoReceita>(
                      style: ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: const [
                        ButtonSegment(
                          value: _ModoReceita.canteiro,
                          label: Text('Canteiro (m²)'),
                          icon: Icon(Icons.eco_outlined),
                        ),
                        ButtonSegment(
                          value: _ModoReceita.vaso,
                          label: Text('Vaso (L)'),
                          icon: Icon(Icons.local_florist_outlined),
                        ),
                      ],
                      selected: {_modo},
                      onSelectionChanged: _salvando
                          ? null
                          : (set) => _resetTudoAoTrocarModo(set.first),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Parâmetros',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (_modo == _ModoReceita.canteiro) ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Usar canteiro cadastrado'),
                        subtitle: const Text('Puxa a área automaticamente.'),
                        value: _usarCanteiroCadastrado,
                        onChanged: _salvando
                            ? null
                            : (v) {
                                setState(() {
                                  _usarCanteiroCadastrado = v;
                                  _canteiroId = null;
                                  _nomeCanteiro = '';
                                  _areaM2 = 0;
                                  _inputController.clear();
                                  _resultado = null;
                                });
                              },
                      ),
                      if (_usarCanteiroCadastrado) ...[
                        const SizedBox(height: 8),
                        _CanteiroPicker(
                          selectedId: _canteiroId,
                          onSelect: _carregarCanteiro,
                        ),
                        if (_canteiroId != null && _areaM2 > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('Área carregada: ${_fmt(_areaM2)} m²',
                                style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ],
                      const Divider(height: 24),
                    ],
                    TextFormField(
                      controller: _inputController,
                      readOnly: _modo == _ModoReceita.canteiro &&
                          _usarCanteiroCadastrado,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (v) {
                        if (_modo == _ModoReceita.canteiro &&
                            _usarCanteiroCadastrado &&
                            _canteiroId == null) {
                          return 'Selecione um canteiro';
                        }
                        if (_toNum(v) == null || _toNum(v)! <= 0)
                          return 'Inválido';
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: _modo == _ModoReceita.canteiro
                            ? 'Área do canteiro'
                            : 'Volume do vaso',
                        hintText: _modo == _ModoReceita.canteiro
                            ? 'Ex: 5,50'
                            : 'Ex: 20',
                        suffixText: _modo == _ModoReceita.canteiro ? 'm²' : 'L',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => _resetResultado(),
                    ),
                    const SizedBox(height: 16),
                    if (_modo == _ModoReceita.canteiro) ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Solo argiloso?'),
                        subtitle: const Text(
                            "Ative se a terra for 'pesada' ou formar liga."),
                        value: _isSoloArgiloso,
                        onChanged: _salvando
                            ? null
                            : (val) => setState(() {
                                  _isSoloArgiloso = val;
                                  _resultado = null;
                                }),
                      ),
                      const SizedBox(height: 8),
                    ],
                    DropdownButtonFormField<String>(
                      value: _tipoAdubo,
                      decoration: const InputDecoration(
                        labelText: 'Adubo disponível',
                        border: OutlineInputBorder(),
                      ),
                      items: _opcoesAdubo.entries
                          .map((e) => DropdownMenuItem(
                              value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: _salvando
                          ? null
                          : (val) => setState(() {
                                _tipoAdubo = val ?? 'bovino';
                                _resultado = null;
                              }),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ✅ CORREÇÃO: Usando AppButtons.elevatedIcon (ajustado para bater com seu Design System)
            AppButtons.elevatedIcon(
              onPressed: _salvando ? null : _calcular,
              label: const Text('GERAR RECEITA'),
              icon: const Icon(Icons.auto_awesome),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarResultado() {
    if (_resultado == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        bool savingLocal = false;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isCanteiro = _resultadoEhCanteiro;

            Future<void> onSave() async {
              if (savingLocal) return;
              setSheetState(() => savingLocal = true);
              try {
                await _salvarNoCadernoDeCampo(sheetContext);
              } finally {
                if (ctx.mounted) setSheetState(() => savingLocal = false);
              }
            }

            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(isCanteiro ? Icons.eco : Icons.local_florist,
                          color: Theme.of(ctx).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isCanteiro ? 'Receita Organo15' : 'Mistura para Vaso',
                          style: Theme.of(ctx)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close)),
                    ],
                  ),
                  if (isCanteiro && _nomeCanteiro.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Para: $_nomeCanteiro',
                          style: TextStyle(
                              color: Theme.of(ctx).colorScheme.secondary)),
                    ),
                  const Divider(),
                  const SizedBox(height: 12),
                  if (isCanteiro) ...[
                    _ResultRow('Adubo Orgânico',
                        '${((_resultado!['adubo_organico'] ?? 0) / 1000).toStringAsFixed(2)} kg'),
                    _ResultRow('Calcário',
                        '${(_resultado!['calcario'] ?? 0).toStringAsFixed(0)} g'),
                    _ResultRow('Termofosfato',
                        '${(_resultado!['termofosfato'] ?? 0).toStringAsFixed(0)} g'),
                    _ResultRow('Gesso Agrícola',
                        '${(_resultado!['gesso'] ?? 0).toStringAsFixed(0)} g',
                        isOptional: true),
                  ] else ...[
                    _ResultRow('Terra/Substrato',
                        '${(_resultado!['terra_litros'] ?? 0).toStringAsFixed(1)} L'),
                    _ResultRow('Adubo Orgânico',
                        '${(_resultado!['adubo_litros'] ?? 0).toStringAsFixed(1)} L'),
                    _ResultRow('Calcário',
                        '${(_resultado!['calcario_gramas'] ?? 0).toStringAsFixed(1)} g'),
                    _ResultRow('Termofosfato',
                        '${(_resultado!['termofosfato_gramas'] ?? 0).toStringAsFixed(1)} g'),
                  ],
                  const SizedBox(height: 20),
                  Card(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isCanteiro
                                  ? 'Aplique o calcário ~30 dias antes se possível.'
                                  : 'Misture tudo numa bacia antes de encher o vaso.',
                              style: Theme.of(ctx).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ✅ CORREÇÃO: Usando elevatedIcon aqui também para consistência
                  AppButtons.elevatedIcon(
                    onPressed: savingLocal ? null : onSave,
                    icon: savingLocal
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_alt),
                    label:
                        Text(savingLocal ? 'SALVANDO...' : 'SALVAR NO CADERNO'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> map) {
    return (_sanitize(map) as Map).cast<String, dynamic>();
  }

  dynamic _sanitize(dynamic value) {
    if (value == null) return null;
    if (value is String || value is bool || value is int) return value;
    if (value is double) return (value.isNaN || value.isInfinite) ? 0.0 : value;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is List) return value.map((e) => _sanitize(e)).toList();
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _sanitize(v)));
    }
    return value;
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isOptional;

  const _ResultRow(this.label, this.value, {this.isOptional = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label${isOptional ? " (Opcional)" : ""}',
              style: isOptional
                  ? TextStyle(color: Theme.of(context).colorScheme.outline)
                  : null),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

class _CanteiroPicker extends StatelessWidget {
  final String? selectedId;
  final void Function(String id) onSelect;

  const _CanteiroPicker({required this.onSelect, this.selectedId});

  @override
  Widget build(BuildContext context) {
    final appSession = SessionScope.of(context).session;
    if (appSession == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebasePaths.canteirosCol(appSession.tenantId)
          .where('ativo', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Nenhum canteiro ativo encontrado.',
                style: TextStyle(color: Colors.orange)),
          );
        }

        return DropdownButtonFormField<String>(
          value: selectedId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Selecione o Canteiro',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final area =
                double.tryParse(data['area_m2']?.toString() ?? '0') ?? 0;
            return DropdownMenuItem(
              value: d.id,
              child: Text('${data['nome']} (${area.toStringAsFixed(2)} m²)'),
            );
          }).toList(),
          onChanged: (id) => id != null ? onSelect(id) : null,
        );
      },
    );
  }
}
