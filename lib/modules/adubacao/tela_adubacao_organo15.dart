// FILE: lib/modules/adubacao/tela_adubacao_organo15.dart
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
  double _medidaLocal =
      0.0; // Agora serve tanto para Área (m²) quanto para Volume (L)

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

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String)
      return double.tryParse(v.trim().replaceAll(',', '.')) ?? 0.0;
    return 0.0;
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

  // ✅ BLINDAGEM: Zera a memória ao trocar de Canteiro para Vaso para não salvar no lugar errado
  void _resetTudoAoTrocarModo(_ModoReceita novo) {
    setState(() {
      _modo = novo;
      _resultado = null;
      _usarCanteiroCadastrado = true; // Mantém a opção de vincular sempre ativa
      _canteiroId = null;
      _nomeCanteiro = '';
      _medidaLocal = 0.0;
      _inputController.clear();
      _isSoloArgiloso = false;
    });
  }

  // ✅ LÓGICA INTELIGENTE: Lê m² se for Canteiro, Lê Litros se for Vaso
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
      final nome = (data['nome'] ?? 'Local').toString();

      double medidaFinal = 0.0;

      if (_modo == _ModoReceita.vaso) {
        // Puxa o Volume em Litros
        medidaFinal = _toDouble(data['volume_l']);
        if (medidaFinal <= 0) {
          // Fallback caso alguém tenha cadastrado vaso sem litro mas com área
          medidaFinal = _toDouble(data['area_m2']) / 0.005;
        }
      } else {
        // Puxa a Área em m²
        medidaFinal = _toDouble(data['area_m2']);
        if (medidaFinal <= 0) {
          medidaFinal =
              _toDouble(data['comprimento']) * _toDouble(data['largura']);
        }
      }

      setState(() {
        _canteiroId = id;
        _nomeCanteiro = nome;
        _medidaLocal = medidaFinal;
        _inputController.text =
            medidaFinal > 0 ? _fmt(medidaFinal, dec: 2) : '';
        _resultado = null;
      });
    } catch (e) {
      AppMessenger.error('Erro ao carregar os dados do local.');
    }
  }

  void _calcular() {
    FocusScope.of(context).unfocus();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) {
      AppMessenger.warn('Preencha os dados necessários.');
      return;
    }

    final valor = _toNum(_inputController.text) ?? 0.0;
    if (valor <= 0) {
      AppMessenger.error('O valor deve ser maior que zero.');
      return;
    }

    try {
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

      Future.delayed(const Duration(milliseconds: 150), () {
        FocusManager.instance.primaryFocus?.unfocus();
        _mostrarResultado();
      });
    } catch (e) {
      AppMessenger.error('Erro na geração da receita.');
    }
  }

  // ✅ SALVAMENTO UNIVERSAL: Salva no diário tanto do Canteiro quanto do Vaso
  Future<void> _salvarNoCadernoDeCampo(BuildContext sheetContext) async {
    final user = _user;
    if (user == null) {
      AppMessenger.warn('Faça login para salvar.');
      return;
    }

    // Auto-calcula se o usuário clicou em registrar sem calcular
    if (_resultado == null) {
      _calcular();
      if (_resultado == null) return;
    }

    if (_salvando) return;
    setState(() => _salvando = true);

    try {
      final fs = FirebaseFirestore.instance;
      final batch = fs.batch();
      final agora = FieldValue.serverTimestamp();
      final appSession = SessionScope.of(context).session;

      if (appSession == null) throw Exception('Sem tenant selecionado');

      final modoTexto = _resultadoEhCanteiro ? 'canteiro' : 'vaso';
      final nomeAdubo = _nomeAdubo();
      final itens = <String, dynamic>{};
      String detalhes = '';

      if (_resultadoEhCanteiro) {
        itens.addAll({
          'adubo_organico_g': (_resultado!['adubo_organico'] ?? 0.0).toDouble(),
          'calcario_g': (_resultado!['calcario'] ?? 0.0).toDouble(),
          'termofosfato_g': (_resultado!['termofosfato'] ?? 0.0).toDouble(),
          'gesso_g': (_resultado!['gesso'] ?? 0.0).toDouble(),
          'solo_argiloso': _isSoloArgiloso,
          'tipo_adubo': _tipoAdubo,
          'area_m2': _toNum(_inputController.text) ?? 0.0,
        });
        detalhes = 'Adubação de Base (Organo15) | Fonte: $nomeAdubo';
      } else {
        itens.addAll({
          'terra_litros': (_resultado!['terra_litros'] ?? 0.0).toDouble(),
          'adubo_litros': (_resultado!['adubo_litros'] ?? 0.0).toDouble(),
          'calcario_g': (_resultado!['calcario_gramas'] ?? 0.0).toDouble(),
          'termofosfato_g':
              (_resultado!['termofosfato_gramas'] ?? 0.0).toDouble(),
          'tipo_adubo': _tipoAdubo,
          'volume_vaso_l': _toNum(_inputController.text) ?? 0.0,
        });
        detalhes = 'Mistura de Substrato (Vaso) | Fonte: $nomeAdubo';
      }

      final histRef =
          FirebasePaths.historicoManejoCol(appSession.tenantId).doc();

      final historicoPayload = {
        'uid_usuario': user.uid,
        'data': agora,
        'tipo_manejo':
            _resultadoEhCanteiro ? 'Adubação Orgânica' : 'Adubação (Vaso)',
        'produto': _resultadoEhCanteiro ? 'Organo15' : 'Mistura Substrato',
        'detalhes': detalhes,
        'observacao_extra':
            'Aplicado: ${_fmt(itens['adubo_organico_g'] ?? itens['adubo_litros'])} ${_resultadoEhCanteiro ? 'g' : 'L'}',
        'modo': modoTexto,
        'itens': itens,
        'concluido': true,
        'status': 'concluido',
        'estado': 'realizado',
        'createdAt': agora,
      };

      if (_usarCanteiroCadastrado && _canteiroId != null) {
        historicoPayload['canteiro_id'] = _canteiroId!;
        if (_nomeCanteiro.isNotEmpty) {
          historicoPayload['nome_canteiro'] = _nomeCanteiro;
        }
      }

      batch.set(histRef, _sanitizeMap(historicoPayload));

      // Atualiza o Lote/Vaso pai
      if (_usarCanteiroCadastrado && _canteiroId != null) {
        final canteiroRef =
            FirebasePaths.canteirosCol(appSession.tenantId).doc(_canteiroId);
        batch.update(canteiroRef, {
          'updatedAt': agora,
          'data_atualizacao': agora,
          'totais_insumos.adubo_organico_g':
              FieldValue.increment(itens['adubo_organico_g'] ?? 0.0),
          'totais_insumos.calcario_g':
              FieldValue.increment(itens['calcario_g'] ?? 0.0),
          'totais_insumos.termofosfato_g':
              FieldValue.increment(itens['termofosfato_g'] ?? 0.0),
          'totais_insumos.aplicacoes_organo15': FieldValue.increment(1),
          'ult_manejo.tipo': 'Adubação',
          'ult_manejo.hist_id': histRef.id,
          'ult_manejo.resumo': detalhes,
          'ult_manejo.atualizadoEm': agora,
        });
      }

      await batch.commit();

      if (!mounted) return;
      if (Navigator.canPop(sheetContext)) Navigator.of(sheetContext).pop();
      AppMessenger.success('✅ Receita salva no histórico do Local!');
    } catch (e) {
      AppMessenger.error('Falha de conexão ao salvar.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _abrirClinicaDaPlanta() {
    AppMessenger.info('Módulo de clínica em construção!');
  }

  void _mostrarAjuda(String titulo, String mensagem) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.help, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
                child: Text(titulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16))),
          ],
        ),
        content: Text(mensagem, style: const TextStyle(height: 1.4)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ENTENDI'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appSession = SessionScope.of(context).session;
    final cs = Theme.of(context).colorScheme;

    if (appSession == null || _user == null) {
      return Scaffold(
        backgroundColor: cs.surfaceContainerLowest,
        body: Center(
            child: Text('Carregando sessão...',
                style: TextStyle(color: cs.outline))),
      );
    }

    final isVaso = _modo == _ModoReceita.vaso;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Calculadora Organo15',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: cs.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirClinicaDaPlanta,
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.health_and_safety),
        label: const Text('Diagnóstico Visual',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(
                left: 16, right: 16, top: 16, bottom: 100),
            children: [
              // Banner Informativo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.spa, color: cs.primary),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'A nutrição de base prepara a "cama" da planta. Escolha a fonte orgânica e nós montamos a receita ideal.',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),

              SectionCard(
                title: '1) Tipo de Plantio',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<_ModoReceita>(
                      style: ButtonStyle(
                        shape: MaterialStateProperty.all(RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                      ),
                      segments: const [
                        ButtonSegment(
                            value: _ModoReceita.canteiro,
                            label: Text('Solo (Canteiro)'),
                            icon: Icon(Icons.eco_outlined)),
                        ButtonSegment(
                            value: _ModoReceita.vaso,
                            label: Text('Vaso/Saco'),
                            icon: Icon(Icons.local_florist_outlined)),
                      ],
                      selected: {_modo},
                      onSelectionChanged: _salvando
                          ? null
                          : (set) => _resetTudoAoTrocarModo(set.first),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              SectionCard(
                title: '2) Dados do Local',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          isVaso
                              ? 'Vincular a um Vaso salvo'
                              : 'Vincular a um Canteiro salvo',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text(
                          'Puxa a área/volume automaticamente.',
                          style: TextStyle(fontSize: 12)),
                      value: _usarCanteiroCadastrado,
                      activeColor: cs.primary,
                      onChanged: _salvando
                          ? null
                          : (v) {
                              setState(() {
                                _usarCanteiroCadastrado = v;
                                _canteiroId = null;
                                _nomeCanteiro = '';
                                _medidaLocal = 0;
                                _inputController.clear();
                                _resultado = null;
                              });
                            },
                    ),
                    if (_usarCanteiroCadastrado) ...[
                      const SizedBox(height: 8),
                      // ✅ PASSANDO A VARIÁVEL MODO PARA FILTRAR O DROPDOWN
                      _CanteiroPicker(
                        selectedId: _canteiroId,
                        tenantId: appSession.tenantId,
                        modoVaso: isVaso,
                        onSelect: _carregarCanteiro,
                      ),
                    ],
                    const Divider(height: 24),
                    TextFormField(
                      controller: _inputController,
                      readOnly: _usarCanteiroCadastrado,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]'))
                      ],
                      decoration: InputDecoration(
                        labelText:
                            isVaso ? 'Volume do Vaso' : 'Área útil do Canteiro',
                        hintText: isVaso ? 'Ex: 20' : 'Ex: 5,50',
                        suffixText: isVaso ? 'Litros' : 'm²',
                        filled: true,
                        fillColor: _usarCanteiroCadastrado
                            ? Colors.grey.shade100
                            : Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                      validator: (v) {
                        if (_usarCanteiroCadastrado && _canteiroId == null) {
                          return 'Selecione um local acima';
                        }
                        if (_toNum(v) == null || _toNum(v)! <= 0)
                          return 'Obrigatório';
                        return null;
                      },
                      onChanged: (_) => _resetResultado(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              SectionCard(
                title: '3) Parâmetros Agronômicos',
                child: Column(
                  children: [
                    if (!isVaso) ...[
                      Row(
                        children: [
                          Expanded(
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('O Solo é Argiloso?',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              subtitle: const Text(
                                  "Ative se a terra formar liga (barro).",
                                  style: TextStyle(fontSize: 12)),
                              value: _isSoloArgiloso,
                              activeColor: cs.primary,
                              onChanged: _salvando
                                  ? null
                                  : (val) => setState(() {
                                        _isSoloArgiloso = val;
                                        _resultado = null;
                                      }),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.help_outline, color: cs.primary),
                            onPressed: () => _mostrarAjuda(
                                'Solo Argiloso x Arenoso',
                                'Solos argilosos (barro) são mais pesados e compactam fácil, por isso exigem Gesso Agrícola na receita para soltar a terra e ajudar a raiz a descer.'),
                          )
                        ],
                      ),
                      const Divider(height: 24),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _tipoAdubo,
                            decoration: InputDecoration(
                              labelText: 'Fonte de Adubo Orgânico',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              isDense: true,
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
                        ),
                        IconButton(
                          icon: Icon(Icons.help_outline, color: cs.primary),
                          onPressed: () => _mostrarAjuda('Tipos de Adubo',
                              'Esterco de Galinha e Bokashi são extremamente concentrados. Por isso, a calculadora exigirá uma quantidade menor deles em comparação ao Esterco Bovino para não queimar as raízes.'),
                        )
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: AppButtons.outlinedIcon(
                  onPressed: _salvando ? null : _calcular,
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('CALCULAR'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: AppButtons.elevatedIcon(
                  onPressed: _salvando
                      ? null
                      : () {
                          // Proteção: Se não calculou, calcula. Se calculou, mostra o modal e lá dentro salva.
                          if (_resultado == null) {
                            _calcular();
                          } else {
                            _mostrarResultado();
                          }
                        },
                  icon: Icon(_salvando ? Icons.hourglass_top : Icons.save_alt),
                  label: Text(_salvando ? 'SALVANDO...' : 'REGISTRAR'),
                ),
              ),
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
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        bool savingLocal = false;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isCanteiro = _resultadoEhCanteiro;
            final theme = Theme.of(ctx);
            final cs = theme.colorScheme;

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
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        child: Icon(
                            isCanteiro ? Icons.eco : Icons.local_florist,
                            color: cs.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isCanteiro ? 'Receita Organo15' : 'Mistura para Vaso',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close)),
                    ],
                  ),
                  if (_nomeCanteiro.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text('Aplicação para: $_nomeCanteiro',
                          style: TextStyle(
                              color: cs.primary, fontWeight: FontWeight.bold)),
                    ),
                  const Divider(),
                  const SizedBox(height: 12),
                  if (isCanteiro) ...[
                    _ResultRow('Adubo Orgânico (${_nomeAdubo()})',
                        '${((_resultado!['adubo_organico'] ?? 0) / 1000).toStringAsFixed(2)} kg'),
                    _ResultRow('Calcário',
                        '${(_resultado!['calcario'] ?? 0).toStringAsFixed(0)} g'),
                    _ResultRow('Termofosfato',
                        '${(_resultado!['termofosfato'] ?? 0).toStringAsFixed(0)} g'),
                    _ResultRow('Gesso Agrícola',
                        '${(_resultado!['gesso'] ?? 0).toStringAsFixed(0)} g',
                        isOptional: true),
                  ] else ...[
                    _ResultRow('Terra Viva/Substrato',
                        '${(_resultado!['terra_litros'] ?? 0).toStringAsFixed(1)} L'),
                    _ResultRow('Adubo Orgânico',
                        '${(_resultado!['adubo_litros'] ?? 0).toStringAsFixed(1)} L'),
                    _ResultRow('Calcário',
                        '${(_resultado!['calcario_gramas'] ?? 0).toStringAsFixed(1)} g'),
                    _ResultRow('Termofosfato',
                        '${(_resultado!['termofosfato_gramas'] ?? 0).toStringAsFixed(1)} g'),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isCanteiro
                                ? 'Espalhe uniformemente sobre a terra, incorpore bem e irrigue. Aguarde o tempo de cura antes de plantar.'
                                : 'Misture todos os ingredientes em uma bacia/lona antes de encher o vaso definitivo.',
                            style: const TextStyle(fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppButtons.elevatedIcon(
                    onPressed: savingLocal ? null : onSave,
                    icon: savingLocal
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_alt),
                    label:
                        Text(savingLocal ? 'SALVANDO...' : 'SALVAR NO DIÁRIO'),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '$label${isOptional ? " (Opcional)" : ""}',
              style: TextStyle(
                  color: isOptional
                      ? Theme.of(context).colorScheme.outline
                      : Colors.black87,
                  fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// ✅ PICKER INTELIGENTE: Filtra a lista com base no tipo selecionado (Canteiro ou Vaso)
class _CanteiroPicker extends StatelessWidget {
  final String? selectedId;
  final void Function(String id) onSelect;
  final String tenantId;
  final bool modoVaso; // Passado pela tela principal

  const _CanteiroPicker({
    required this.onSelect,
    this.selectedId,
    required this.tenantId,
    required this.modoVaso,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebasePaths.canteirosCol(tenantId)
          .where('ativo', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();

        // 🛡️ Filtro Inteligente: Separa Canteiros de Vasos para não misturar unidades
        final docs = snap.data!.docs.where((d) {
          final tipo = ((d.data() as Map)['tipo'] ?? '').toString();
          if (modoVaso) {
            return tipo == 'Vaso';
          } else {
            return tipo !=
                'Vaso'; // Considera tudo que não for vaso como Canteiro
          }
        }).toList();

        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
                modoVaso
                    ? 'Nenhum Vaso cadastrado no sistema.'
                    : 'Nenhum Canteiro de solo cadastrado.',
                style: const TextStyle(color: Colors.red)),
          );
        }

        return DropdownButtonFormField<String>(
          value: docs.any((d) => d.id == selectedId) ? selectedId : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: modoVaso ? 'Selecione o Vaso' : 'Selecione o Canteiro',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
          ),
          items: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;

            double valorExibido = 0.0;
            if (modoVaso) {
              valorExibido =
                  double.tryParse(data['volume_l']?.toString() ?? '0') ?? 0.0;
            } else {
              valorExibido =
                  double.tryParse(data['area_m2']?.toString() ?? '0') ?? 0.0;
              if (valorExibido <= 0.0) {
                valorExibido =
                    (double.tryParse(data['comprimento']?.toString() ?? '0') ??
                            0.0) *
                        (double.tryParse(data['largura']?.toString() ?? '0') ??
                            0.0);
              }
            }

            return DropdownMenuItem(
              value: d.id,
              child: Text(
                  '${data['nome']} (${valorExibido.toStringAsFixed(1)} ${modoVaso ? "L" : "m²"})'),
            );
          }).toList(),
          onChanged: (id) => id != null ? onSelect(id) : null,
        );
      },
    );
  }
}
