import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ui/app_ui.dart';

// ============================================================================
// 1. MODELO DE DADOS (Type Safety)
// ============================================================================
class UserConfigModel {
  final String uid;
  final String nome;
  final String regiao;
  final String finalidadePadrao;
  final bool notifIrrigacao;
  final bool notifAdubacao;
  final bool notifPragas;
  final double custoAgua;
  final double custoEnergia;

  UserConfigModel({
    required this.uid,
    this.nome = '',
    this.regiao = 'Sudeste',
    this.finalidadePadrao = 'consumo',
    this.notifIrrigacao = true,
    this.notifAdubacao = false,
    this.notifPragas = true,
    this.custoAgua = 0.0,
    this.custoEnergia = 0.0,
  });

  // Factory para criar a partir do Firestore com segurança contra nulos
  factory UserConfigModel.fromMap(String uid, Map<String, dynamic>? map) {
    if (map == null) return UserConfigModel(uid: uid);
    return UserConfigModel(
      uid: uid,
      nome: (map['nome_exibicao'] ?? '').toString(),
      regiao: (map['regiao'] ?? 'Sudeste').toString(),
      finalidadePadrao: (map['finalidade_padrao'] ?? 'consumo').toString(),
      notifIrrigacao: map['notif_irrigacao'] == true,
      notifAdubacao: map['notif_adubacao'] == true,
      notifPragas: map['notif_pragas'] == true,
      custoAgua: _toDouble(map['custo_padrao_agua']),
      custoEnergia: _toDouble(map['custo_padrao_energia']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid_usuario': uid,
      'nome_exibicao': nome,
      'regiao': regiao,
      'finalidade_padrao': finalidadePadrao,
      'notif_irrigacao': notifIrrigacao,
      'notif_adubacao': notifAdubacao,
      'notif_pragas': notifPragas,
      'custo_padrao_agua': custoAgua,
      'custo_padrao_energia': custoEnergia,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Helper estático para conversão segura
  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0;
  }

  // Método copyWith para facilitar a verificação de mudanças (Dirty State)
  UserConfigModel copyWith({
    String? nome,
    String? regiao,
    String? finalidadePadrao,
    bool? notifIrrigacao,
    bool? notifAdubacao,
    bool? notifPragas,
    double? custoAgua,
    double? custoEnergia,
  }) {
    return UserConfigModel(
      uid: this.uid,
      nome: nome ?? this.nome,
      regiao: regiao ?? this.regiao,
      finalidadePadrao: finalidadePadrao ?? this.finalidadePadrao,
      notifIrrigacao: notifIrrigacao ?? this.notifIrrigacao,
      notifAdubacao: notifAdubacao ?? this.notifAdubacao,
      notifPragas: notifPragas ?? this.notifPragas,
      custoAgua: custoAgua ?? this.custoAgua,
      custoEnergia: custoEnergia ?? this.custoEnergia,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserConfigModel &&
        other.nome == nome &&
        other.regiao == regiao &&
        other.finalidadePadrao == finalidadePadrao &&
        other.notifIrrigacao == notifIrrigacao &&
        other.notifAdubacao == notifAdubacao &&
        other.notifPragas == notifPragas &&
        other.custoAgua == custoAgua &&
        other.custoEnergia == custoEnergia;
  }

  @override
  int get hashCode => Object.hash(nome, regiao, finalidadePadrao, notifIrrigacao, custoAgua);
}

// ============================================================================
// 2. REPOSITORY (Isolamento do Firebase)
// ============================================================================
class ConfigRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference _docRef(String uid) => _db.collection('configuracoes_usuario').doc(uid);

  Future<UserConfigModel> fetchConfig(String uid) async {
    final snap = await _docRef(uid).get();
    return UserConfigModel.fromMap(uid, snap.data() as Map<String, dynamic>?);
  }

  Future<void> saveConfig(UserConfigModel config) async {
    final ref = _docRef(config.uid);
    // Transaction garante atomicidade e previne condições de corrida
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = config.toMap();
      
      if (!snap.exists) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      
      tx.set(ref, data, SetOptions(merge: true));
    });
  }
}

// ============================================================================
// 3. TELA (UI)
// ============================================================================
class TelaConfiguracoes extends StatefulWidget {
  const TelaConfiguracoes({super.key});

  @override
  State<TelaConfiguracoes> createState() => _TelaConfiguracoesState();
}

class _TelaConfiguracoesState extends State<TelaConfiguracoes> {
  final _auth = FirebaseAuth.instance;
  final _repository = ConfigRepository(); // Injeção de dependência simples
  
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _custoAguaCtrl = TextEditingController();
  final _custoEnergiaCtrl = TextEditingController();

  // Estados
  bool _loading = true;
  bool _saving = false;
  UserConfigModel? _originalConfig; // Para comparar se houve mudança
  late UserConfigModel _currentConfig; // Estado atual da tela

  String? get _uid => _auth.currentUser?.uid;
  bool get _logado => _uid != null;

  // Verifica se houve alteração para habilitar o botão Salvar (Premium UX)
  bool get _hasChanges {
    if (_originalConfig == null) return false;
    return _originalConfig != _currentConfig;
  }

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _custoAguaCtrl.dispose();
    _custoEnergiaCtrl.dispose();
    super.dispose();
  }

  // --- Lógica de Carregamento ---
  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      if (!_logado) {
        _resetToDefaults();
        return;
      }

      final config = await _repository.fetchConfig(_uid!);
      _syncModelToUI(config);
      
    } catch (e) {
      _snack('Erro ao carregar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetToDefaults() {
    final empty = UserConfigModel(uid: '');
    _syncModelToUI(empty);
  }

  void _syncModelToUI(UserConfigModel config) {
    _originalConfig = config;
    _currentConfig = config;

    _nomeCtrl.text = config.nome;
    _custoAguaCtrl.text = _fmtMoney(config.custoAgua);
    _custoEnergiaCtrl.text = _fmtMoney(config.custoEnergia);
  }

  // --- Lógica de Salvamento ---
  Future<void> _salvar() async {
    if (!_logado || _saving) return;
    if (!_formKey.currentState!.validate()) return;

    // Atualiza o modelo com os valores dos TextControllers antes de salvar
    _updateConfigFromControllers();

    setState(() => _saving = true);
    try {
      await _repository.saveConfig(_currentConfig);
      
      // Atualiza o original para o novo estado salvo (desabilita o botão salvar)
      _originalConfig = _currentConfig;
      
      _snack('Configurações salvas com sucesso!', bg: Colors.green);
    } catch (e) {
      _snack('Falha ao salvar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // --- Helpers UI & Formatter ---
  void _updateConfigFromControllers() {
    setState(() {
      _currentConfig = _currentConfig.copyWith(
        nome: _nomeCtrl.text.trim(),
        custoAgua: _moneyToDouble(_custoAguaCtrl.text),
        custoEnergia: _moneyToDouble(_custoEnergiaCtrl.text),
      );
    });
  }

  void _snack(String msg, {bool isError = false, Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bg ?? (isError ? Colors.red : Colors.green),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _fmtMoney(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
  
  double _moneyToDouble(String s) {
    final t = s.trim().replaceAll(',', '.');
    return double.tryParse(t) ?? 0.0;
  }

  // ==========================================================================
  // VIEW (BUILD)
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        actions: [
          if (_loading)
            const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          if (!_loading)
            IconButton(icon: const Icon(Icons.refresh), onPressed: _carregar, tooltip: 'Recarregar'),
        ],
      ),
      body: _loading && _originalConfig == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              onChanged: _updateConfigFromControllers, // Detecta mudanças nos TextFields
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  if (!_logado) _buildGuestWarning(theme),
                  
                  _buildSectionHeader(theme, 'Perfil'),
                  _buildProfileCard(),
                  
                  const SizedBox(height: 24),
                  _buildSectionHeader(theme, 'Notificações'),
                  _buildNotificationsCard(),

                  const SizedBox(height: 24),
                  _buildSectionHeader(theme, 'Custos Operacionais'),
                  _buildCostsCard(),
                ],
              ),
            ),
      bottomNavigationBar: _buildSaveBar(),
    );
  }

  Widget _buildGuestWarning(ThemeData theme) {
    return Card(
      color: theme.colorScheme.errorContainer,
      margin: const EdgeInsets.only(bottom: 20),
      child: ListTile(
        leading: Icon(Icons.lock_outline, color: theme.colorScheme.onErrorContainer),
        title: Text('Modo Visitante', style: TextStyle(color: theme.colorScheme.onErrorContainer, fontWeight: FontWeight.bold)),
        subtitle: Text('Faça login para salvar suas preferências.', style: TextStyle(color: theme.colorScheme.onErrorContainer)),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _nomeCtrl,
              enabled: _logado,
              decoration: const InputDecoration(labelText: 'Nome de exibição', prefixIcon: Icon(Icons.person_outline), hintText: 'Como quer ser chamado?'),
              validator: (v) => (v != null && v.length > 40) ? 'Nome muito longo' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _currentConfig.regiao,
              decoration: const InputDecoration(labelText: 'Região (Calendário)', prefixIcon: Icon(Icons.map_outlined)),
              items: ['Norte', 'Nordeste', 'Centro-Oeste', 'Sudeste', 'Sul']
                  .map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: _logado ? (v) => setState(() => _currentConfig = _currentConfig.copyWith(regiao: v)) : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _currentConfig.finalidadePadrao,
              decoration: const InputDecoration(labelText: 'Finalidade Padrão', prefixIcon: Icon(Icons.flag_outlined)),
              items: const [
                DropdownMenuItem(value: 'consumo', child: Text('Consumo Próprio')),
                DropdownMenuItem(value: 'comercio', child: Text('Comércio/Venda')),
              ],
              onChanged: _logado ? (v) => setState(() => _currentConfig = _currentConfig.copyWith(finalidadePadrao: v)) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsCard() {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Lembrete de Irrigação'),
            subtitle: const Text('Sugestões baseadas no clima.'),
            value: _currentConfig.notifIrrigacao,
            onChanged: _logado ? (v) => setState(() => _currentConfig = _currentConfig.copyWith(notifIrrigacao: v)) : null,
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Lembrete de Adubação'),
            subtitle: const Text('Alertas de ciclos nutricionais.'),
            value: _currentConfig.notifAdubacao,
            onChanged: _logado ? (v) => setState(() => _currentConfig = _currentConfig.copyWith(notifAdubacao: v)) : null,
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Alerta de Pragas'),
            subtitle: const Text('Avisos de surtos na região.'),
            value: _currentConfig.notifPragas,
            onChanged: _logado ? (v) => setState(() => _currentConfig = _currentConfig.copyWith(notifPragas: v)) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCostsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Esses valores são usados para calcular o ROI automático quando a finalidade for "Comércio".',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _custoAguaCtrl,
              enabled: _logado,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')), LengthLimitingTextInputFormatter(10)],
              decoration: const InputDecoration(labelText: 'Custo Água (R\$)', prefixIcon: Icon(Icons.water_drop_outlined), hintText: '0,00'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _custoEnergiaCtrl,
              enabled: _logado,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')), LengthLimitingTextInputFormatter(10)],
              decoration: const InputDecoration(labelText: 'Custo Energia (R\$)', prefixIcon: Icon(Icons.bolt_outlined), hintText: '0,00'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: AppButtons.elevatedIcon(
          onPressed: (_logado && !_saving && _hasChanges) ? _salvar : null,
          icon: _saving 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'SALVANDO...' : (_hasChanges ? 'SALVAR ALTERAÇÕES' : 'SEM ALTERAÇÕES')),
        ),
      ),
    );
  }
}