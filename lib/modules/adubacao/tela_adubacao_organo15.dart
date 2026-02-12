import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/logic/base_agronomica.dart';

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

  // Controllers
  final _inputController = TextEditingController();

  // Estado UI
  bool _salvando = false;

  // Modo
  bool _isCanteiro = true; // true=Canteiro, false=Vaso
  String _tipoAdubo = 'bovino';
  bool _isSoloArgiloso = false;

  // Premium: puxar área do canteiro
  bool _usarCanteiroCadastrado = true;
  String? _canteiroId;
  String _nomeCanteiro = '';
  double _areaM2 = 0;

  // Resultado
  Map<String, double>? _resultado;
  bool _resultadoEhCanteiro = true;

  // Opções de Dropdown
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

  // ---------- Helpers ----------
  void _snack(String msg, {Color? cor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
      ),
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

  Future<void> _carregarCanteiro(String id) async {
    final user = _user;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('canteiros')
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
        // espelha no input (readonly)
        _inputController.text = areaM2 > 0 ? _fmt(areaM2, dec: 2) : '';
      });
    } catch (e) {
      _snack('Erro ao carregar canteiro: $e', cor: Colors.red);
    }
  }

  // ---------- Cálculo ----------
  void _calcular() {
    FocusScope.of(context).unfocus();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final valor = _toNum(_inputController.text) ?? 0;
    if (valor <= 0) {
      _snack('Digite um valor maior que zero.', cor: Colors.red);
      return;
    }

    Map<String, double> res;

    if (_isCanteiro) {
      final areaM2 = valor;

      res = BaseAgronomica.calcularAdubacaoCanteiro(
        areaM2: areaM2,
        isSoloArgiloso: _isSoloArgiloso,
        tipoAduboOrganico: _tipoAdubo,
      );

      setState(() {
        _resultado = res;
        _resultadoEhCanteiro = true;
      });

      _mostrarResultado();
    } else {
      // Vaso
      res = BaseAgronomica.calcularMisturaVaso(
        volumeVasoLitros: valor,
        tipoAdubo: _tipoAdubo,
      );

      setState(() {
        _resultado = res;
        _resultadoEhCanteiro = false;
      });

      _mostrarResultado();
    }
  }

  // ---------- Salvamento Premium ----------
  Future<void> _salvarNoCadernoDeCampo() async {
    final user = _user;
    if (user == null) {
      _snack('Faça login para salvar.', cor: Colors.red);
      return;
    }
    if (_resultado == null) return;

    setState(() => _salvando = true);

    try {
      final fs = FirebaseFirestore.instance;
      final batch = fs.batch();

      final agora = FieldValue.serverTimestamp();

      final modo = _resultadoEhCanteiro ? 'canteiro' : 'vaso';
      final nomeAdubo = _nomeAdubo();

      // Monta itens para histórico (tudo number, sem string)
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
        });

        detalhes = 'Mistura (Vaso) | Adubo: $nomeAdubo';
      }

      // Documento do histórico
      final histRef = fs.collection('historico_manejo').doc();
      batch.set(histRef, {
        'uid_usuario': user.uid,
        'data': agora,
        'tipo_manejo': _resultadoEhCanteiro
            ? 'Adubação Orgânica'
            : 'Mistura de Substrato',
        'produto': _resultadoEhCanteiro ? 'Organo15' : 'Mistura para Vaso',
        'detalhes': detalhes,
        'modo': modo,
        'itens': itens,
        'concluido': true,
        'createdAt': agora,
        'updatedAt': agora,

        // Local (canteiro opcional)
        'canteiro_id': _resultadoEhCanteiro ? _canteiroId : null,
        'nome_canteiro': (_resultadoEhCanteiro && _nomeCanteiro.isNotEmpty)
            ? _nomeCanteiro
            : null,
      });

      // Premium: se é canteiro e tem id -> incrementa totais no canteiro (sem ler tudo)
      if (_resultadoEhCanteiro && _canteiroId != null) {
        final aduboG = (_resultado!['adubo_organico'] ?? 0).toDouble();
        final calcarioG = (_resultado!['calcario'] ?? 0).toDouble();
        final termoG = (_resultado!['termofosfato'] ?? 0).toDouble();
        final gessoG = (_resultado!['gesso'] ?? 0).toDouble();

        final canteiroRef = fs.collection('canteiros').doc(_canteiroId);
        batch.set(canteiroRef, {
          'updatedAt': agora,
          'totais_insumos': {
            // acumuladores
            'adubo_organico_g': FieldValue.increment(aduboG),
            'calcario_g': FieldValue.increment(calcarioG),
            'termofosfato_g': FieldValue.increment(termoG),
            'gesso_g': FieldValue.increment(gessoG),
            'aplicacoes_organo15': FieldValue.increment(1),
          },
          'ult_manejo': {
            'tipo': 'Organo15',
            'hist_id': histRef.id,
            'resumo': detalhes,
            'atualizadoEm': agora,
          },
        }, SetOptions(merge: true));
      }

      await batch.commit();

      if (!mounted) return;
      _snack('✅ Receita salva no Caderno de Campo!', cor: Colors.green);
      Navigator.pop(context); // fecha sheet
    } catch (e) {
      _snack('Erro ao salvar: $e', cor: Colors.red);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // ---------- BottomSheet Premium ----------
  void _mostrarResultado() {
    if (_resultado == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Icon(
                      _resultadoEhCanteiro ? Icons.eco : Icons.local_florist,
                      color: const Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _resultadoEhCanteiro
                            ? 'Receita Organo15 (Canteiro)'
                            : 'Mistura para Vaso',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                Divider(color: Colors.grey.shade200),

                if (_resultadoEhCanteiro) ...[
                  if (_canteiroId != null && _nomeCanteiro.isNotEmpty) ...[
                    _InfoLine(title: 'Local', value: _nomeCanteiro),
                    const SizedBox(height: 6),
                  ],
                  _ItemResultado(
                    titulo: "Adubo Orgânico",
                    valor:
                        "${((_resultado!['adubo_organico'] ?? 0) / 1000).toStringAsFixed(2)} kg",
                  ),
                  _ItemResultado(
                    titulo: "Calcário (Calagem)",
                    valor:
                        "${(_resultado!['calcario'] ?? 0).toStringAsFixed(0)} g",
                  ),
                  _ItemResultado(
                    titulo: "Termofosfato (Yoorin)",
                    valor:
                        "${(_resultado!['termofosfato'] ?? 0).toStringAsFixed(0)} g",
                  ),
                  _ItemResultado(
                    titulo: "Gesso Agrícola (Opcional)",
                    valor:
                        "${(_resultado!['gesso'] ?? 0).toStringAsFixed(0)} g",
                  ),
                  const SizedBox(height: 12),
                  _InfoBox(
                    icon: Icons.info_outline,
                    cor: Colors.blue,
                    texto:
                        'Dica agronômica: se der, aplique o calcário ~30 dias antes do plantio e incorpore nos primeiros 20cm.',
                  ),
                ] else ...[
                  _ItemResultado(
                    titulo: "Terra/Substrato",
                    valor:
                        "${(_resultado!['terra_litros'] ?? 0).toStringAsFixed(1)} L",
                  ),
                  _ItemResultado(
                    titulo: "Adubo Orgânico",
                    valor:
                        "${(_resultado!['adubo_litros'] ?? 0).toStringAsFixed(1)} L",
                  ),
                  _ItemResultado(
                    titulo: "Calcário",
                    valor:
                        "${(_resultado!['calcario_gramas'] ?? 0).toStringAsFixed(1)} g",
                  ),
                  _ItemResultado(
                    titulo: "Termofosfato",
                    valor:
                        "${(_resultado!['termofosfato_gramas'] ?? 0).toStringAsFixed(1)} g",
                  ),
                  const SizedBox(height: 12),
                  _InfoBox(
                    icon: Icons.info_outline,
                    cor: Colors.blue,
                    texto:
                        'Misture tudo numa bacia/lona antes de encher o vaso. Terra e adubo em LITROS (volume).',
                  ),
                ],

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _salvando
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('FECHAR'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _salvando ? null : _salvarNoCadernoDeCampo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: _salvando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_alt),
                        label: Text(
                          _salvando ? 'SALVANDO...' : 'SALVAR NO CADERNO',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Calculadora Organo15"),
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Seletor de modo
              _SegmentedMode(
                leftLabel: 'Canteiro (m²)',
                rightLabel: 'Vaso (Litros)',
                isLeftSelected: _isCanteiro,
                onLeft: () {
                  setState(() {
                    _isCanteiro = true;
                    _resultado = null;
                    // se usar canteiro cadastrado, mantém
                  });
                },
                onRight: () {
                  setState(() {
                    _isCanteiro = false;
                    _resultado = null;
                    // vaso sempre manual
                    _usarCanteiroCadastrado = false;
                    _canteiroId = null;
                    _nomeCanteiro = '';
                    _areaM2 = 0;
                    _inputController.clear();
                  });
                },
              ),

              const SizedBox(height: 18),

              // Card principal
              _CardPersonalizado(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Local premium (só canteiro)
                    if (_isCanteiro) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.place,
                            size: 18,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Local',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          Switch(
                            value: _usarCanteiroCadastrado,
                            activeColor: const Color(0xFF2E7D32),
                            onChanged: (v) {
                              setState(() {
                                _usarCanteiroCadastrado = v;
                                _resultado = null;
                                _canteiroId = null;
                                _nomeCanteiro = '';
                                _areaM2 = 0;
                                _inputController.clear();
                              });
                            },
                          ),
                        ],
                      ),
                      Text(
                        _usarCanteiroCadastrado
                            ? 'Usar canteiro cadastrado (puxa área automático)'
                            : 'Digitar área manualmente',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 12),

                      if (_usarCanteiroCadastrado)
                        _CanteiroPicker(
                          onSelect: (id) => _carregarCanteiro(id),
                          selectedId: _canteiroId,
                        ),

                      if (_usarCanteiroCadastrado) const SizedBox(height: 12),
                      Divider(color: Colors.grey.shade200),
                      const SizedBox(height: 12),
                    ],

                    Text(
                      _isCanteiro ? "Tamanho da Área" : "Volume do Vaso",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: _inputController,
                      readOnly: _isCanteiro && _usarCanteiroCadastrado,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (v) {
                        final val = _toNum(v);
                        if (val == null) return 'Obrigatório';
                        if (val <= 0) return 'Precisa ser maior que zero';
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: _isCanteiro ? "Ex: 5,50" : "Ex: 20",
                        suffixText: _isCanteiro ? "m²" : "L",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: (_isCanteiro && _usarCanteiroCadastrado)
                            ? Colors.grey[200]
                            : Colors.grey[50],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Textura (só canteiro)
                    if (_isCanteiro) ...[
                      const Text(
                        "Textura do Solo",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Solo Argiloso?"),
                        subtitle: const Text(
                          "Ative se a terra forma uma 'minhoquinha' firme.",
                        ),
                        value: _isSoloArgiloso,
                        activeColor: const Color(0xFF2E7D32),
                        onChanged: (val) => setState(() {
                          _isSoloArgiloso = val;
                          _resultado = null;
                        }),
                      ),
                      Divider(color: Colors.grey.shade200),
                      const SizedBox(height: 10),
                    ],

                    // Adubo
                    const Text(
                      "Adubo Disponível",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[50],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _tipoAdubo,
                          isExpanded: true,
                          items: _opcoesAdubo.entries.map((e) {
                            return DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() {
                            _tipoAdubo = val!;
                            _resultado = null;
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoBox(
                      icon: Icons.shield_outlined,
                      cor: Colors.blue,
                      texto:
                          'Isso gera uma receita base. O ajuste fino (principalmente calagem) fica perfeito quando você combina com laudo.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Botão
              ElevatedButton(
                onPressed: _calcular,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                  shadowColor: const Color(0xFF2E7D32).withOpacity(0.4),
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  "GERAR RECEITA",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =================== WIDGETS PREMIUM ===================

class _SegmentedMode extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final bool isLeftSelected;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  const _SegmentedMode({
    required this.leftLabel,
    required this.rightLabel,
    required this.isLeftSelected,
    required this.onLeft,
    required this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: isLeftSelected
                      ? const Color(0xFF2E7D32)
                      : Colors.white,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(15),
                  ),
                ),
                child: Text(
                  leftLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isLeftSelected ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onRight,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: !isLeftSelected
                      ? const Color(0xFF2E7D32)
                      : Colors.white,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(15),
                  ),
                ),
                child: Text(
                  rightLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !isLeftSelected ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _InfoBox(
        icon: Icons.lock_outline,
        cor: Colors.red,
        texto: 'Faça login para selecionar canteiros.',
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('canteiros')
          .where('uid_usuario', isEqualTo: user.uid)
          .where('ativo', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _InfoBox(
            icon: Icons.error_outline,
            cor: Colors.red,
            texto: 'Erro ao carregar canteiros: ${snap.error}',
          );
        }
        if (!snap.hasData) return const LinearProgressIndicator();

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _InfoBox(
            icon: Icons.warning_amber,
            cor: Colors.orange,
            texto: 'Nenhum canteiro ativo. Crie um primeiro.',
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[50],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedId,
              isExpanded: true,
              hint: const Text('Selecione um canteiro'),
              items: docs.map((d) {
                final data = (d.data() as Map<String, dynamic>? ?? {});
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
            ),
          ),
        );
      },
    );
  }
}

class _CardPersonalizado extends StatelessWidget {
  final Widget child;
  const _CardPersonalizado({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ItemResultado extends StatelessWidget {
  final String titulo;
  final String valor;

  const _ItemResultado({required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              titulo,
              style: const TextStyle(fontSize: 15, color: Colors.black54),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String title;
  final String value;

  const _InfoLine({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$title: ', style: TextStyle(color: Colors.grey[600])),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final Color cor;
  final String texto;

  const _InfoBox({required this.icon, required this.cor, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: cor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                color: cor.withOpacity(0.90),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
