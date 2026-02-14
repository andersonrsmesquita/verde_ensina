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
  // Auth
  User? get _user => FirebaseAuth.instance.currentUser;

  // Form
  final _formKey = GlobalKey<FormState>();
  final _inputController = TextEditingController();

  bool _salvando = false;

  // Modo
  _ModoReceita _modo = _ModoReceita.canteiro;

  // Config
  String _tipoAdubo = 'bovino';
  bool _isSoloArgiloso = false;

  // Canteiro (puxar área)
  bool _usarCanteiroCadastrado = true;
  String? _canteiroId;
  String _nomeCanteiro = '';
  double _areaM2 = 0;

  // Resultado
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

  // ===========================================================================
  // Helpers
  // ===========================================================================
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
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

  // ===========================================================================
  // Sanitizador Firestore (anti abort() / NaN / tipos bizarros)
  // ===========================================================================
  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> map) {
    final val = _sanitize(map, r'$');
    return (val as Map).cast<String, dynamic>();
  }

  dynamic _sanitize(dynamic value, String path) {
    if (value == null) return null;

    if (value is String || value is bool || value is int) return value;

    if (value is double) {
      if (value.isNaN || value.isInfinite) {
        throw ArgumentError(
            'Firestore: double inválido em $path (NaN/Infinity).');
      }
      return value;
    }

    if (value is num) {
      final d = value.toDouble();
      if (d.isNaN || d.isInfinite) {
        throw ArgumentError('Firestore: num inválido em $path (NaN/Infinity).');
      }
      return d;
    }

    if (value is Timestamp ||
        value is GeoPoint ||
        value is FieldValue ||
        value is DocumentReference) {
      return value;
    }

    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is Enum) return value.name;

    if (value is List) {
      return value.asMap().entries.map((e) {
        return _sanitize(e.value, '$path[${e.key}]');
      }).toList();
    }

    if (value is Map) {
      final out = <String, dynamic>{};
      for (final entry in value.entries) {
        final k = entry.key;
        if (k is! String) {
          throw ArgumentError(
            'Firestore: chave não-String em $path -> "$k" (${k.runtimeType})',
          );
        }
        out[k] = _sanitize(entry.value, '$path.$k');
      }
      return out;
    }

    throw UnsupportedError(
      'Firestore: tipo NÃO suportado em $path -> ${value.runtimeType}.',
    );
  }

  // ===========================================================================
  // Canteiro
  // ===========================================================================
  Future<void> _carregarCanteiro(String id) async {
    final user = _user;
    if (user == null) return;

    try {
      final appSession = SessionScope.of(context).session;
      if (appSession == null) return;

      final doc = await FirebasePaths.canteirosCol(appSession.tenantId)
          .doc(id)
          .get();
      if (!doc.exists || !mounted) return;

      final data = doc.data() ?? {};
      final uidDoc = (data['uid_usuario'] ?? '').toString();
      if (uidDoc.isNotEmpty && uidDoc != user.uid) return;

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
      _showSnack('Erro ao carregar canteiro: $e');
    }
  }

  // ===========================================================================
  // Cálculo
  // ===========================================================================
  void _calcular() {
    FocusScope.of(context).unfocus();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final valor = _toNum(_inputController.text) ?? 0;
    if (valor <= 0) {
      _showSnack('Digite um valor maior que zero.');
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

      _mostrarResultado();
      return;
    }

    final res = BaseAgronomica.calcularMisturaVaso(
      volumeVasoLitros: valor,
      tipoAdubo: _tipoAdubo,
    );

    setState(() {
      _resultado = res;
      _resultadoEhCanteiro = false;
    });

    _mostrarResultado();
  }

  // ===========================================================================
  // Salvamento
  // ===========================================================================
  Future<void> _salvarNoCadernoDeCampo(BuildContext sheetContext) async {
    final user = _user;
    if (user == null) {
      _showSnack('Faça login para salvar.');
      return;
    }
    if (_resultado == null) return;
    if (_salvando) return;

    setState(() => _salvando = true);

    try {
      final fs = FirebaseFirestore.instance;
      final batch = fs.batch();
      final agora = FieldValue.serverTimestamp();

      final modo = _resultadoEhCanteiro ? 'canteiro' : 'vaso';
      final nomeAdubo = _nomeAdubo();

      final itens = <String, dynamic>{};
      String detalhes = '';

      if (_resultadoEhCanteiro) {
        final aduboG = (_resultado!['adubo_organico'] ?? 0).toDouble();
        final calcarioG = (_resultado!['calcario'] ?? 0).toDouble();
        final termoG = (_resultado!['termofosfato'] ?? 0).toDouble();
        final gessoG = (_resultado!['gesso'] ?? 0).toDouble();

        itens.addAll({
          'adubo_organico_g': aduboG,
          'calcario_g': calcarioG,
          'termofosfato_g': termoG,
          'gesso_g': gessoG,
          'solo_argiloso': _isSoloArgiloso,
          'tipo_adubo': _tipoAdubo,
          'area_m2': _toNum(_inputController.text) ?? 0.0,
        });

        detalhes =
            'Organo15 (Canteiro) | Adubo: $nomeAdubo | Solo argiloso: ${_isSoloArgiloso ? "sim" : "não"}';
      } else {
        final terraL = (_resultado!['terra_litros'] ?? 0).toDouble();
        final aduboL = (_resultado!['adubo_litros'] ?? 0).toDouble();
        final calcarioG = (_resultado!['calcario_gramas'] ?? 0).toDouble();
        final termoG = (_resultado!['termofosfato_gramas'] ?? 0).toDouble();

        itens.addAll({
          'terra_litros': terraL,
          'adubo_litros': aduboL,
          'calcario_g': calcarioG,
          'termofosfato_g': termoG,
          'tipo_adubo': _tipoAdubo,
          'volume_vaso_l': _toNum(_inputController.text) ?? 0.0,
        });

        detalhes = 'Mistura (Vaso) | Adubo: $nomeAdubo';
      }

      final appSession = SessionScope.of(context).session;
      if (appSession == null) throw Exception('Sem tenant selecionado');

      final histRef = FirebasePaths.historicoManejoCol(appSession.tenantId).doc();

      final historicoPayload = <String, dynamic>{
        'uid_usuario': user.uid,
        'data': agora,
        'tipo_manejo':
            _resultadoEhCanteiro ? 'Adubação Orgânica' : 'Mistura de Substrato',
        'produto': _resultadoEhCanteiro ? 'Organo15' : 'Mistura para Vaso',
        'detalhes': detalhes,
        'modo': modo,
        'itens': itens,
        'concluido': true,
        'createdAt': agora,
        'updatedAt': agora,
      };

      if (_resultadoEhCanteiro && _canteiroId != null) {
        historicoPayload['canteiro_id'] = _canteiroId;
        if (_nomeCanteiro.trim().isNotEmpty) {
          historicoPayload['nome_canteiro'] = _nomeCanteiro.trim();
        }
      }

      batch.set(histRef, _sanitizeMap(historicoPayload));

      if (_resultadoEhCanteiro && _canteiroId != null) {
        final aduboG = (_resultado!['adubo_organico'] ?? 0).toDouble();
        final calcarioG = (_resultado!['calcario'] ?? 0).toDouble();
        final termoG = (_resultado!['termofosfato'] ?? 0).toDouble();
        final gessoG = (_resultado!['gesso'] ?? 0).toDouble();

        final appSession = SessionScope.of(context).session;
        if (appSession == null) throw Exception('Sem tenant selecionado');

        final canteiroRef = FirebasePaths.canteirosCol(appSession.tenantId).doc(_canteiroId);

        final canteiroPayload = <String, dynamic>{
          'updatedAt': agora,
          'totais_insumos.adubo_organico_g': FieldValue.increment(aduboG),
          'totais_insumos.calcario_g': FieldValue.increment(calcarioG),
          'totais_insumos.termofosfato_g': FieldValue.increment(termoG),
          'totais_insumos.gesso_g': FieldValue.increment(gessoG),
          'totais_insumos.aplicacoes_organo15': FieldValue.increment(1),
          'ult_manejo.tipo': 'Organo15',
          'ult_manejo.hist_id': histRef.id,
          'ult_manejo.resumo': detalhes,
          'ult_manejo.atualizadoEm': agora,
        };

        batch.set(
          canteiroRef,
          _sanitizeMap(canteiroPayload),
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      if (!mounted) return;

      Navigator.of(sheetContext).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSnack('✅ Receita salva no Caderno de Campo!');
      });
    } catch (e) {
      _showSnack('Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // ===========================================================================
  // BottomSheet resultado (Theme + Material only)
  // ===========================================================================
  void _mostrarResultado() {
    if (_resultado == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        bool savingLocal = false;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isCanteiro = _resultadoEhCanteiro;
            final title = isCanteiro
                ? 'Receita Organo15 (Canteiro)'
                : 'Mistura para Vaso';
            final icon =
                isCanteiro ? Icons.eco_outlined : Icons.local_florist_outlined;

            Future<void> onSave() async {
              if (savingLocal) return;
              setSheetState(() => savingLocal = true);
              try {
                await _salvarNoCadernoDeCampo(sheetContext);
              } finally {
                if (ctx.mounted) setSheetState(() => savingLocal = false);
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(icon),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: isCanteiro && _nomeCanteiro.trim().isNotEmpty
                            ? Text(_nomeCanteiro.trim())
                            : null,
                      ),
                      const Divider(),

                      // Itens
                      if (isCanteiro) ...[
                        _ResultTile(
                          title: 'Adubo Orgânico',
                          value:
                              '${((_resultado!['adubo_organico'] ?? 0) / 1000).toStringAsFixed(2)} kg',
                        ),
                        _ResultTile(
                          title: 'Calcário (Calagem)',
                          value:
                              '${(_resultado!['calcario'] ?? 0).toStringAsFixed(0)} g',
                        ),
                        _ResultTile(
                          title: 'Termofosfato (Yoorin)',
                          value:
                              '${(_resultado!['termofosfato'] ?? 0).toStringAsFixed(0)} g',
                        ),
                        _ResultTile(
                          title: 'Gesso Agrícola (Opcional)',
                          value:
                              '${(_resultado!['gesso'] ?? 0).toStringAsFixed(0)} g',
                        ),
                        const SizedBox(height: 10),
                        _MessageCard(
                          icon: Icons.info_outline,
                          title: 'Dica',
                          subtitle:
                              'Se der, aplique o calcário ~30 dias antes do plantio e incorpore nos primeiros 20 cm.',
                        ),
                      ] else ...[
                        _ResultTile(
                          title: 'Terra/Substrato',
                          value:
                              '${(_resultado!['terra_litros'] ?? 0).toStringAsFixed(1)} L',
                        ),
                        _ResultTile(
                          title: 'Adubo Orgânico',
                          value:
                              '${(_resultado!['adubo_litros'] ?? 0).toStringAsFixed(1)} L',
                        ),
                        _ResultTile(
                          title: 'Calcário',
                          value:
                              '${(_resultado!['calcario_gramas'] ?? 0).toStringAsFixed(1)} g',
                        ),
                        _ResultTile(
                          title: 'Termofosfato',
                          value:
                              '${(_resultado!['termofosfato_gramas'] ?? 0).toStringAsFixed(1)} g',
                        ),
                        const SizedBox(height: 10),
                        _MessageCard(
                          icon: Icons.info_outline,
                          title: 'Dica',
                          subtitle:
                              'Misture tudo numa bacia/lona antes de encher o vaso. Terra e adubo são em LITROS (volume).',
                        ),
                      ],

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: savingLocal
                                  ? null
                                  : () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.close),
                              label: const Text('FECHAR'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppButtons.elevatedIcon(
                              onPressed: savingLocal ? null : onSave,
                              icon: savingLocal
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save_alt_outlined),
                              label: Text(savingLocal
                                  ? 'SALVANDO...'
                                  : 'SALVAR NO CADERNO'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // UI
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final appSession = SessionScope.of(context).session;
    if (appSession == null) {
      return const Scaffold(
        body: Center(child: Text('Selecione um espaço (tenant) para continuar.')),
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 92),
          children: [
            if (_salvando) const LinearProgressIndicator(),

            // Modo
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Modo',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<_ModoReceita>(
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
                          : (set) {
                              final novo = set.first;
                              if (novo == _modo) return;
                              _resetTudoAoTrocarModo(novo);
                            },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Configuração
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Configuração',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Defina local, textura do solo e o adubo disponível.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),

                    if (_modo == _ModoReceita.canteiro) ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Usar canteiro cadastrado'),
                        subtitle: const Text(
                            'Puxa a área automaticamente do seu canteiro.'),
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
                      const SizedBox(height: 10),
                      if (_usarCanteiroCadastrado) ...[
                        _CanteiroPicker(
                          selectedId: _canteiroId,
                          onSelect: _carregarCanteiro,
                        ),
                        if (_canteiroId != null && _areaM2 > 0) ...[
                          const SizedBox(height: 10),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.square_foot_outlined),
                            title: const Text('Área puxada'),
                            trailing: Text('${_fmt(_areaM2, dec: 2)} m²'),
                          ),
                        ],
                        const Divider(),
                      ],
                    ],

                    // Entrada numérica
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
                            _usarCanteiroCadastrado) {
                          if (_canteiroId == null)
                            return 'Selecione um canteiro primeiro';
                        }
                        final val = _toNum(v);
                        if (val == null) return 'Obrigatório';
                        if (val <= 0) return 'Precisa ser maior que zero';
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
                      ),
                      onChanged: (_) => _resetResultado(),
                    ),

                    const SizedBox(height: 12),

                    if (_modo == _ModoReceita.canteiro) ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Solo argiloso?'),
                        subtitle: const Text(
                            "Ative se a terra forma uma 'minhoquinha' firme."),
                        value: _isSoloArgiloso,
                        onChanged: _salvando
                            ? null
                            : (val) => setState(() {
                                  _isSoloArgiloso = val;
                                  _resultado = null;
                                }),
                      ),
                      const Divider(),
                    ],

                    DropdownButtonFormField<String>(
                      value: _tipoAdubo,
                      decoration: const InputDecoration(
                        labelText: 'Adubo disponível',
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

                    const SizedBox(height: 12),

                    const _MessageCard(
                      icon: Icons.shield_outlined,
                      title: 'Nota rápida',
                      subtitle:
                          'Isso gera uma receita base. O ajuste fino (principalmente calagem) fica perfeito quando você combina com laudo.',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Ações
            AppButtons.elevatedIcon(
              onPressed: _salvando ? null : _calcular,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('GERAR RECEITA'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Widgets auxiliares (sem “design na unha”: só Card/ListTile/Theme)
// ============================================================================
class _CanteiroPicker extends StatelessWidget {
  final String? selectedId;
  final void Function(String id) onSelect;

  const _CanteiroPicker({
    required this.onSelect,
    this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    final appSession = SessionScope.of(context).session;

    if (appSession == null) {
      return const _MessageCard(
        icon: Icons.lock_outline,
        title: 'Espaço não selecionado',
        subtitle: 'Selecione um espaço (tenant) para listar canteiros.',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebasePaths.canteirosCol(appSession.tenantId)
            .where('ativo', isEqualTo: true)
            .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _MessageCard(
            icon: Icons.error_outline,
            title: 'Erro',
            subtitle: 'Erro ao carregar canteiros: ${snap.error}',
          );
        }

        if (!snap.hasData) return const LinearProgressIndicator();

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const _MessageCard(
            icon: Icons.warning_amber_outlined,
            title: 'Sem canteiros',
            subtitle: 'Nenhum canteiro ativo. Crie um primeiro.',
          );
        }

        return DropdownButtonFormField<String>(
          value: selectedId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Canteiro',
          ),
          hint: const Text('Selecione um canteiro'),
          items: docs.map((d) {
            final data = d.data();
            final nome = (data['nome'] ?? 'Canteiro').toString();

            final area = data['area_m2'];
            double areaM2 = 0;
            if (area is num) areaM2 = area.toDouble();
            if (area is String) areaM2 = double.tryParse(area) ?? 0;

            return DropdownMenuItem(
              value: d.id,
              child: Text('$nome (${areaM2.toStringAsFixed(2)} m²)'),
            );
          }).toList(),
          onChanged: (id) {
            if (id == null) return;
            onSelect(id);
          },
        );
      },
    );
  }
}

class _ResultTile extends StatelessWidget {
  final String title;
  final String value;

  const _ResultTile({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
      ),
    );
  }
}
