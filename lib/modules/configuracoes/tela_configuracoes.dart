import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ui/app_ui.dart';

class TelaConfiguracoes extends StatefulWidget {
  const TelaConfiguracoes({super.key});

  @override
  State<TelaConfiguracoes> createState() => _TelaConfiguracoesState();
}

class _TelaConfiguracoesState extends State<TelaConfiguracoes> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;
  bool get _logado => _uid != null;

  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;
  bool _docExiste = false;

  // Preferências
  final _nomeCtrl = TextEditingController();
  String _regiao = 'Sudeste';
  String _finalidadePadrao = 'consumo'; // consumo|comercio

  bool _notifIrrigacao = true;
  bool _notifAdubacao = false;
  bool _notifPragas = true;

  // Custos padrão
  final _custoAguaCtrl = TextEditingController();
  final _custoEnergiaCtrl = TextEditingController();

  DocumentReference<Map<String, dynamic>> _docRef(String uid) {
    return _db.collection('configuracoes_usuario').doc(uid);
  }

  void _snack(String msg, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    final s = v.toString().trim().replaceAll(',', '.');
    return double.tryParse(s) ?? 0.0;
  }

  double _moneyToDouble(String s) {
    final t = s.trim().replaceAll(',', '.');
    final v = double.tryParse(t);
    if (v == null || v.isNaN || v.isInfinite) return 0.0;
    return v;
  }

  String _fmtMoney(num v) => v.toStringAsFixed(2).replaceAll('.', ',');

  List<TextInputFormatter> get _moneyFormatters => [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
        LengthLimitingTextInputFormatter(10),
      ];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);

    if (!_logado) {
      _nomeCtrl.clear();
      _custoAguaCtrl.text = _fmtMoney(0);
      _custoEnergiaCtrl.text = _fmtMoney(0);
      _docExiste = false;
      setState(() => _loading = false);
      return;
    }

    try {
      final snap = await _docRef(_uid!).get();
      _docExiste = snap.exists;

      final d = snap.data();
      if (d != null) {
        _nomeCtrl.text = (d['nome_exibicao'] ?? '').toString();
        _regiao = (d['regiao'] ?? 'Sudeste').toString();
        _finalidadePadrao = (d['finalidade_padrao'] ?? 'consumo').toString();

        _notifIrrigacao = (d['notif_irrigacao'] ?? true) == true;
        _notifAdubacao = (d['notif_adubacao'] ?? false) == true;
        _notifPragas = (d['notif_pragas'] ?? true) == true;

        _custoAguaCtrl.text = _fmtMoney(_toDouble(d['custo_padrao_agua']));
        _custoEnergiaCtrl.text = _fmtMoney(_toDouble(d['custo_padrao_energia']));
      } else {
        // defaults
        _custoAguaCtrl.text = _fmtMoney(0);
        _custoEnergiaCtrl.text = _fmtMoney(0);
      }
    } catch (e) {
      _snack('❌ Falha ao carregar configurações: $e', bg: Colors.red);
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _salvar() async {
    if (!_logado) {
      _snack('⚠️ Faça login pra salvar configurações.', bg: Colors.orange);
      return;
    }
    if (_saving) return;

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _saving = true);

    try {
      final uid = _uid!;
      final ref = _docRef(uid);
      final agora = FieldValue.serverTimestamp();

      final payloadBase = <String, dynamic>{
        'uid_usuario': uid,
        'nome_exibicao': _nomeCtrl.text.trim(),
        'regiao': _regiao,
        'finalidade_padrao': _finalidadePadrao,

        'notif_irrigacao': _notifIrrigacao,
        'notif_adubacao': _notifAdubacao,
        'notif_pragas': _notifPragas,

        'custo_padrao_agua': _moneyToDouble(_custoAguaCtrl.text),
        'custo_padrao_energia': _moneyToDouble(_custoEnergiaCtrl.text),

        'updatedAt': agora,
      };

      // Premium: createdAt só uma vez (sem regravar toda vez)
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (snap.exists) {
          tx.set(ref, payloadBase, SetOptions(merge: true));
        } else {
          tx.set(
            ref,
            {
              ...payloadBase,
              'createdAt': agora,
            },
            SetOptions(merge: true),
          );
        }
      });

      _docExiste = true;
      _snack('✅ Configurações salvas.', bg: Colors.green);
    } catch (e) {
      _snack('❌ Falha ao salvar: $e', bg: Colors.red);
    } finally {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _custoAguaCtrl.dispose();
    _custoEnergiaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        actions: [
          IconButton(
            tooltip: 'Recarregar',
            onPressed: _loading ? null : _carregar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                children: [
                  if (!_logado) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lock_outline,
                                color: theme.colorScheme.error),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Conta',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Você não está logado. As configurações ficam indisponíveis.',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // PERFIL
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Perfil',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Preferências básicas do app.',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _nomeCtrl,
                            enabled: _logado,
                            decoration: const InputDecoration(
                              labelText: 'Nome de exibição',
                              hintText: 'Ex: Anderson',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (_) {
                              if (!_logado) return null;
                              // opcional: pode ficar vazio
                              if (_nomeCtrl.text.trim().length > 40) {
                                return 'Nome muito grande (máx. 40)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          DropdownButtonFormField<String>(
                            value: _regiao,
                            onChanged: !_logado
                                ? null
                                : (v) => setState(() => _regiao = v ?? _regiao),
                            decoration: const InputDecoration(
                              labelText: 'Região (calendário)',
                              prefixIcon: Icon(Icons.map_outlined),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Norte', child: Text('Norte')),
                              DropdownMenuItem(value: 'Nordeste', child: Text('Nordeste')),
                              DropdownMenuItem(value: 'Centro-Oeste', child: Text('Centro-Oeste')),
                              DropdownMenuItem(value: 'Sudeste', child: Text('Sudeste')),
                              DropdownMenuItem(value: 'Sul', child: Text('Sul')),
                            ],
                          ),
                          const SizedBox(height: 12),

                          DropdownButtonFormField<String>(
                            value: _finalidadePadrao,
                            onChanged: !_logado
                                ? null
                                : (v) => setState(() =>
                                    _finalidadePadrao = v ?? _finalidadePadrao),
                            decoration: const InputDecoration(
                              labelText: 'Finalidade padrão dos canteiros',
                              prefixIcon: Icon(Icons.flag_outlined),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'consumo', child: Text('Consumo')),
                              DropdownMenuItem(
                                  value: 'comercio', child: Text('Comércio')),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _docExiste
                                ? 'Tudo certo: suas configurações já estão salvas.'
                                : 'Primeira vez aqui? Salva e o app memoriza.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // NOTIFICAÇÕES
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Notificações',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Lembretes inteligentes (por enquanto simples).',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),

                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _notifIrrigacao,
                            onChanged: !_logado
                                ? null
                                : (v) => setState(() => _notifIrrigacao = v),
                            title: const Text('Lembrete de irrigação'),
                            subtitle: const Text(
                              'Sugestões automáticas conforme ciclo/chuva.',
                            ),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _notifAdubacao,
                            onChanged: !_logado
                                ? null
                                : (v) => setState(() => _notifAdubacao = v),
                            title: const Text('Lembrete de adubação'),
                            subtitle: const Text(
                              'Baseado no calendário e histórico.',
                            ),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _notifPragas,
                            onChanged: !_logado
                                ? null
                                : (v) => setState(() => _notifPragas = v),
                            title: const Text('Alerta de pragas'),
                            subtitle: const Text(
                              'Quando registrar perda, o app sugere ações.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // CUSTOS
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Custos padrão',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ajuda no financeiro quando a finalidade for “Comércio”.',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _custoAguaCtrl,
                            enabled: _logado,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: _moneyFormatters,
                            decoration: const InputDecoration(
                              labelText: 'Custo padrão de água (R\$)',
                              prefixIcon: Icon(Icons.water_drop_outlined),
                              hintText: 'Ex: 12,50',
                            ),
                            validator: (_) {
                              if (!_logado) return null;
                              final v = _moneyToDouble(_custoAguaCtrl.text);
                              if (v < 0) return 'Não pode ser negativo';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _custoEnergiaCtrl,
                            enabled: _logado,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: _moneyFormatters,
                            decoration: const InputDecoration(
                              labelText: 'Custo padrão de energia (R\$)',
                              prefixIcon: Icon(Icons.bolt_outlined),
                              hintText: 'Ex: 22,00',
                            ),
                            validator: (_) {
                              if (!_logado) return null;
                              final v = _moneyToDouble(_custoEnergiaCtrl.text);
                              if (v < 0) return 'Não pode ser negativo';
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Formato: use vírgula ou ponto (ex: 10,50).',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SizedBox(
            height: 48,
            child: AppButtons.elevatedIcon(
              onPressed: (!_logado || _saving) ? null : _salvar,
              icon: Icon(_saving ? Icons.hourglass_top : Icons.save_outlined),
              label: Text(_saving ? 'SALVANDO...' : 'SALVAR CONFIGURAÇÕES'),
            ),
          ),
        ),
      ),
    );
  }
}
