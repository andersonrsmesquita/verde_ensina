import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:verde_ensina/core/ui/app_ui.dart';



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

  bool _loading = true;
  bool _saving = false;

  // Preferências
  final _nomeCtrl = TextEditingController();
  String _regiao = 'Sudeste';
  String _finalidadePadrao = 'consumo'; // consumo|comercio

  bool _notifIrrigacao = true;
  bool _notifAdubacao = false;
  bool _notifPragas = true;

  // Custos padrão (pra virar “premium” depois)
  final _custoAguaCtrl = TextEditingController(text: '0.00');
  final _custoEnergiaCtrl = TextEditingController(text: '0.00');

  DocumentReference<Map<String, dynamic>> _docRef(String uid) {
    // coleção simples e direta
    return _db.collection('configuracoes_usuario').doc(uid);
  }

  void _snack(String msg, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg),
    );
  }

  double _toDouble(String s) {
    return double.tryParse(s.replaceAll(',', '.')) ?? 0.0;
  }

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);

    if (!_logado) {
      setState(() => _loading = false);
      return;
    }

    try {
      final snap = await _docRef(_uid!).get();
      final d = snap.data();

      if (d != null) {
        _nomeCtrl.text = (d['nome_exibicao'] ?? '').toString();
        _regiao = (d['regiao'] ?? 'Sudeste').toString();
        _finalidadePadrao = (d['finalidade_padrao'] ?? 'consumo').toString();

        _notifIrrigacao = (d['notif_irrigacao'] ?? true) == true;
        _notifAdubacao = (d['notif_adubacao'] ?? false) == true;
        _notifPragas = (d['notif_pragas'] ?? true) == true;

        _custoAguaCtrl.text =
            ((d['custo_padrao_agua'] ?? 0.0) as num).toStringAsFixed(2);
        _custoEnergiaCtrl.text =
            ((d['custo_padrao_energia'] ?? 0.0) as num).toStringAsFixed(2);
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

    setState(() => _saving = true);

    try {
      final payload = <String, dynamic>{
        'uid_usuario': _uid,
        'nome_exibicao': _nomeCtrl.text.trim(),
        'regiao': _regiao,
        'finalidade_padrao': _finalidadePadrao,

        'notif_irrigacao': _notifIrrigacao,
        'notif_adubacao': _notifAdubacao,
        'notif_pragas': _notifPragas,

        'custo_padrao_agua': _toDouble(_custoAguaCtrl.text),
        'custo_padrao_energia': _toDouble(_custoEnergiaCtrl.text),

        'updatedAt': FieldValue.serverTimestamp(),
        if (_loading == false)
          'createdAt': FieldValue
              .serverTimestamp(), // ok se repetir, Firestore só atualiza
      };

      await _docRef(_uid!).set(payload, SetOptions(merge: true));
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
    return PageContainer(
      title: 'Configurações',
      actions: [
        IconButton(
          tooltip: 'Recarregar',
          onPressed: _carregar,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_logado)
                  SectionCard(
                    title: 'Conta',
                    subtitle:
                        'Você não está logado. Algumas configurações ficam indisponíveis.',
                    child: AppButton.secondary(
                      label: 'OK',
                      onPressed: () {},
                    ),
                  ),
                SectionCard(
                  title: 'Perfil',
                  subtitle: 'Preferências básicas do app',
                  child: Column(
                    children: [
                      AppTextField(
                        controller: _nomeCtrl,
                        label: 'Nome de exibição',
                        hint: 'Ex: Anderson',
                        prefixIcon: Icons.person,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _regiao,
                        decoration: const InputDecoration(
                          labelText: 'Região (calendário)',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'Norte', child: Text('Norte')),
                          DropdownMenuItem(
                              value: 'Nordeste', child: Text('Nordeste')),
                          DropdownMenuItem(
                              value: 'Centro-Oeste',
                              child: Text('Centro-Oeste')),
                          DropdownMenuItem(
                              value: 'Sudeste', child: Text('Sudeste')),
                          DropdownMenuItem(value: 'Sul', child: Text('Sul')),
                        ],
                        onChanged: (v) =>
                            setState(() => _regiao = v ?? _regiao),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _finalidadePadrao,
                        decoration: const InputDecoration(
                          labelText: 'Finalidade padrão dos canteiros',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'consumo', child: Text('Consumo')),
                          DropdownMenuItem(
                              value: 'comercio', child: Text('Comércio')),
                        ],
                        onChanged: (v) => setState(
                            () => _finalidadePadrao = v ?? _finalidadePadrao),
                      ),
                    ],
                  ),
                ),
                SectionCard(
                  title: 'Notificações',
                  subtitle:
                      'Lembretes inteligentes (agora simples, depois vira “ultra premium”)',
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _notifIrrigacao,
                        onChanged: (v) => setState(() => _notifIrrigacao = v),
                        title: const Text('Lembrete de irrigação'),
                        subtitle: const Text(
                            'Sugestões automáticas conforme ciclo/chuva.'),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _notifAdubacao,
                        onChanged: (v) => setState(() => _notifAdubacao = v),
                        title: const Text('Lembrete de adubação'),
                        subtitle:
                            const Text('Baseado no calendário e no histórico.'),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _notifPragas,
                        onChanged: (v) => setState(() => _notifPragas = v),
                        title: const Text('Alerta de pragas'),
                        subtitle: const Text(
                            'Quando registrar perda, o app pode sugerir ações.'),
                      ),
                    ],
                  ),
                ),
                SectionCard(
                  title: 'Custos padrão',
                  subtitle: 'Pra ajudar no financeiro quando for “comércio”',
                  child: Column(
                    children: [
                      AppTextField.number(
                        controller: _custoAguaCtrl,
                        label: 'Custo padrão de água (R\$)',
                        prefixIcon: Icons.water_drop,
                      ),
                      const SizedBox(height: 12),
                      AppTextField.number(
                        controller: _custoEnergiaCtrl,
                        label: 'Custo padrão de energia (R\$)',
                        prefixIcon: Icons.bolt,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                AppButton.primary(
                  label: _saving ? 'Salvando...' : 'Salvar configurações',
                  icon: Icons.save,
                  loading: _saving,
                  onPressed: _saving ? null : _salvar,
                ),
              ],
            ),
    );
  }
}
