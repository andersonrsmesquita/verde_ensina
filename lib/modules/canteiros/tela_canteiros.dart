import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'tela_detalhes_canteiro.dart';
import '../../core/ui/app_ui.dart';
import '../../core/session/session_scope.dart';
import '../../core/repositories/canteiro_repository.dart';

class TelaCanteiros extends StatefulWidget {
  const TelaCanteiros({super.key});

  @override
  State<TelaCanteiros> createState() => _TelaCanteirosState();
}

class _TelaCanteirosState extends State<TelaCanteiros> {
  User? get _user => FirebaseAuth.instance.currentUser;
  CanteiroRepository? _repo;

  bool get _enableHardDelete => kDebugMode;

  String _filtroAtivo = 'ativos';
  String _filtroStatus = 'todos';
  String _ordem = 'recentes';
  String _busca = '';

  // Controladores
  final TextEditingController _buscaCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _buscaCtrl.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _busca = _buscaCtrl.text);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_repo == null) {
      final session = SessionScope.of(context).session;
      if (session != null) {
        _repo = CanteiroRepository(session.tenantId);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _buscaCtrl.dispose();
    super.dispose();
  }

  // --- Helpers UI ---

  void _runNextFrame(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      fn();
    });
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  double _doubleFromController(TextEditingController c) {
    return double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0.0;
  }

  Color _getCorStatus(String? status, ColorScheme cs) {
    switch (status) {
      case 'ocupado':
        return cs.error;
      case 'manutencao':
        return Colors.orange.shade700;
      default:
        return cs.primary;
    }
  }

  String _getTextoStatus(String? status) {
    switch (status) {
      case 'ocupado':
        return 'Ocupado';
      case 'manutencao':
        return 'Manutenção';
      default:
        return 'Livre';
    }
  }

  IconData _iconeTipo(String tipo) =>
      tipo == 'Vaso' ? Icons.local_florist : Icons.grid_on;

  IconData _iconeMedida(String tipo) =>
      tipo == 'Vaso' ? Icons.water_drop : Icons.aspect_ratio;

  String _labelMedida(Map<String, dynamic> dados) {
    final tipo = (dados['tipo'] ?? 'Canteiro').toString();
    if (tipo == 'Vaso') {
      final vol = double.tryParse(dados['volume_l']?.toString() ?? '0') ?? 0.0;
      return '${vol.toStringAsFixed(1)} L';
    } else {
      final area = double.tryParse(dados['area_m2']?.toString() ?? '0') ?? 0.0;
      return '${area.toStringAsFixed(2)} m²';
    }
  }

  // --- Lógica de Ordenação Local ---

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtrarEOrdenarLocal(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    var list = docs.where((doc) {
      final nomeLower = (doc.data()['nome_lower'] ?? (doc.data()['nome'] ?? ''))
          .toString()
          .toLowerCase();
      final buscaTerm = _busca.trim().toLowerCase();
      if (buscaTerm.isEmpty) return true;
      return nomeLower.contains(buscaTerm);
    }).toList();

    int cmpNum(num a, num b) => a.compareTo(b);

    num medidaOf(Map<String, dynamic> d) {
      final tipo = (d['tipo'] ?? 'Canteiro').toString();
      if (tipo == 'Vaso')
        return double.tryParse(d['volume_l']?.toString() ?? '0') ?? 0.0;
      return double.tryParse(d['area_m2']?.toString() ?? '0') ?? 0.0;
    }

    String nomeLowerOf(Map<String, dynamic> d) =>
        (d['nome_lower'] ?? (d['nome'] ?? '')).toString().toLowerCase();

    Timestamp tsOf(Map<String, dynamic> d) => d['data_criacao'] is Timestamp
        ? d['data_criacao']
        : Timestamp.fromMillisecondsSinceEpoch(0);

    switch (_ordem) {
      case 'nome_az':
        list.sort(
            (a, b) => nomeLowerOf(a.data()).compareTo(nomeLowerOf(b.data())));
        break;
      case 'nome_za':
        list.sort(
            (a, b) => nomeLowerOf(b.data()).compareTo(nomeLowerOf(a.data())));
        break;
      case 'medida_maior':
        list.sort((a, b) => cmpNum(medidaOf(b.data()), medidaOf(a.data())));
        break;
      case 'medida_menor':
        list.sort((a, b) => cmpNum(medidaOf(a.data()), medidaOf(b.data())));
        break;
      default: // 'recentes'
        list.sort((a, b) => tsOf(b.data()).compareTo(tsOf(a.data())));
        break;
    }
    return list;
  }

  // --- Modal Criar/Editar ---

  void _criarOuEditarLocal({DocumentSnapshot<Map<String, dynamic>>? doc}) {
    if (_user == null || _repo == null) {
      _snack('Sessão inválida.', isError: true);
      return;
    }

    final bool editando = doc != null;
    final dados = doc?.data() ?? <String, dynamic>{};
    final cs = Theme.of(context).colorScheme;

    final nomeController =
        TextEditingController(text: (dados['nome'] ?? '').toString());
    final compController = TextEditingController(
        text: dados['comprimento_m']?.toString().replaceAll('.', ',') ?? '');
    final largController = TextEditingController(
        text: dados['largura_m']?.toString().replaceAll('.', ',') ?? '');
    final volumeController = TextEditingController(
        text: dados['volume_l']?.toString().replaceAll('.', ',') ?? '');

    String tipoLocal = (dados['tipo'] ?? 'Canteiro').toString();
    if (tipoLocal != 'Canteiro' && tipoLocal != 'Vaso') tipoLocal = 'Canteiro';

    String finalidade = (dados['finalidade'] ?? 'consumo').toString().trim();
    if (finalidade != 'consumo' && finalidade != 'comercio')
      finalidade = 'consumo';

    final formKey = GlobalKey<FormState>();
    bool salvando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (ctxModal, setModalState) {
              Future<void> salvar() async {
                FocusScope.of(ctxModal).unfocus();
                if (salvando) return;
                if (!(formKey.currentState?.validate() ?? false)) return;

                setModalState(() => salvando = true);

                try {
                  final nome = nomeController.text.trim();
                  double areaM2 = 0, comp = 0, larg = 0, volumeL = 0;

                  if (tipoLocal == 'Canteiro') {
                    comp = _doubleFromController(compController);
                    larg = _doubleFromController(largController);
                    areaM2 = comp * larg;
                  } else {
                    volumeL = _doubleFromController(volumeController);
                  }

                  final payload = <String, dynamic>{
                    'uid_usuario': _user!.uid,
                    'nome': nome,
                    'nome_lower': nome.toLowerCase(),
                    'tipo': tipoLocal,
                    'comprimento_m': comp,
                    'largura_m': larg,
                    'area_m2': areaM2,
                    'volume_l': volumeL,
                    'finalidade': finalidade,
                  };

                  await _repo!.salvarLocal(docId: doc?.id, payload: payload);

                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  _snack(editando
                      ? 'Lote atualizado com sucesso!'
                      : 'Lote cadastrado com sucesso!');
                } catch (e) {
                  _snack('Erro ao salvar: $e', isError: true);
                  setModalState(() => salvando = false);
                }
              }

              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(AppTokens.xl),
                child: SafeArea(
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  editando
                                      ? 'Editar Local'
                                      : 'Criar Novo Local',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold)),
                              IconButton(
                                  onPressed: () => Navigator.pop(sheetCtx),
                                  icon: const Icon(Icons.close)),
                            ],
                          ),
                          const SizedBox(height: AppTokens.md),
                          TextFormField(
                            controller: nomeController,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: 'Nome do Lote/Vaso',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppTokens.radiusMd)),
                              prefixIcon: const Icon(Icons.label_outline),
                            ),
                            validator: (v) => (v?.trim().isEmpty ?? true)
                                ? 'Informe um nome.'
                                : null,
                          ),
                          const SizedBox(height: AppTokens.lg),
                          Text('Este local é um:',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: AppTokens.sm),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setModalState(
                                      () => tipoLocal = 'Canteiro'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: tipoLocal == 'Canteiro'
                                          ? cs.primary
                                          : cs.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(
                                          AppTokens.radiusMd),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text('Canteiro / Solo',
                                        style: TextStyle(
                                            color: tipoLocal == 'Canteiro'
                                                ? Colors.white
                                                : cs.onSurfaceVariant,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppTokens.md),
                              Expanded(
                                child: InkWell(
                                  onTap: () =>
                                      setModalState(() => tipoLocal = 'Vaso'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: tipoLocal == 'Vaso'
                                          ? cs.primary
                                          : cs.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(
                                          AppTokens.radiusMd),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text('Vaso / Recipiente',
                                        style: TextStyle(
                                            color: tipoLocal == 'Vaso'
                                                ? Colors.white
                                                : cs.onSurfaceVariant,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTokens.lg),
                          if (tipoLocal == 'Canteiro') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: compController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9\.,]'))
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Comprimento',
                                      suffixText: 'm',
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                              AppTokens.radiusMd)),
                                    ),
                                    validator: (v) =>
                                        _doubleFromController(compController) <=
                                                0
                                            ? 'Obrigatório'
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: AppTokens.md),
                                Expanded(
                                  child: TextFormField(
                                    controller: largController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9\.,]'))
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Largura',
                                      suffixText: 'm',
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                              AppTokens.radiusMd)),
                                    ),
                                    validator: (v) =>
                                        _doubleFromController(largController) <=
                                                0
                                            ? 'Obrigatório'
                                            : null,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            TextFormField(
                              controller: volumeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9\.,]'))
                              ],
                              decoration: InputDecoration(
                                labelText: 'Volume de Terra',
                                suffixText: 'Litros',
                                prefixIcon: const Icon(Icons.local_drink),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppTokens.radiusMd)),
                              ),
                              validator: (v) =>
                                  _doubleFromController(volumeController) <= 0
                                      ? 'Obrigatório'
                                      : null,
                            ),
                          ],
                          const SizedBox(height: AppTokens.lg),
                          Text('Finalidade do Cultivo:',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: AppTokens.sm),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                  value: 'consumo',
                                  label: Text('Consumo Familiar')),
                              ButtonSegment(
                                  value: 'comercio',
                                  label: Text('Comercial (Venda)')),
                            ],
                            selected: {finalidade},
                            onSelectionChanged: (set) =>
                                setModalState(() => finalidade = set.first),
                          ),
                          const SizedBox(height: AppTokens.xl),
                          AppButtons.elevatedIcon(
                            onPressed: salvando ? null : salvar,
                            icon: salvando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.save),
                            label: Text(salvando
                                ? 'SALVANDO...'
                                : (editando
                                    ? 'SALVAR ALTERAÇÕES'
                                    : 'CRIAR LOCAL')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // --- Ações de Arquivar/Excluir ---

  Future<void> _toggleAtivoComUndo(
      String id, bool ativoAtual, String nome) async {
    try {
      await _repo!.alternarStatusAtivo(id, ativoAtual);
      _snack(ativoAtual ? '"$nome" arquivado.' : '"$nome" reativado.');
    } catch (e) {
      _snack('Erro ao arquivar.', isError: true);
    }
  }

  void _confirmarExclusaoCanteiro(String id, String nome) {
    if (!_enableHardDelete) {
      _snack('🚫 Uso restrito a Devs. Use "Arquivar".', isError: true);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir DEFINITIVO?'),
        content:
            Text('Apaga "$nome" E todo o histórico dele.\n\nNão tem volta.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _repo!.excluirDefinitivoCascade(_user!.uid, id);
              _snack('✅ Lote Excluído com sucesso.');
            },
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );
  }

  // --- Widgets de Build da Tela ---

  Widget _buildFiltros() {
    final cs = Theme.of(context).colorScheme;

    Widget chip(String key, String label, String currentVal,
        Function(String) onSelect) {
      final selected = currentVal == key;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelect(key),
        selectedColor: cs.primaryContainer,
        labelStyle: TextStyle(
          color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppTokens.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _buscaCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar lote...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _buscaCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _buscaCtrl.clear();
                        setState(() => _busca = '');
                      },
                    ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppTokens.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                chip('ativos', 'Ativos', _filtroAtivo,
                    (v) => setState(() => _filtroAtivo = v)),
                const SizedBox(width: 8),
                chip('arquivados', 'Arquivados', _filtroAtivo,
                    (v) => setState(() => _filtroAtivo = v)),
                const SizedBox(width: 8),
                chip('todos', 'Todos', _filtroAtivo,
                    (v) => setState(() => _filtroAtivo = v)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardResumo(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final cs = Theme.of(context).colorScheme;
    int ativos = 0;
    double totalArea = 0;

    for (final d in docs) {
      final data = d.data();
      if ((data['ativo'] ?? true) == true) ativos++;
      if ((data['tipo'] ?? 'Canteiro').toString() != 'Vaso') {
        totalArea += double.tryParse(data['area_m2']?.toString() ?? '0') ?? 0.0;
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppTokens.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [cs.primary, cs.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        boxShadow: [
          BoxShadow(
              color: cs.primary.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('VISÃO GERAL',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(children: [
                Text('${totalArea.toStringAsFixed(1)} m²',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const Text('Área Útil',
                    style: TextStyle(color: Colors.white70, fontSize: 10)),
              ]),
              Container(width: 1, height: 40, color: Colors.white24),
              Column(children: [
                Text('$ativos',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const Text('Lotes Ativos',
                    style: TextStyle(color: Colors.white70, fontSize: 10)),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_repo == null) {
      return Scaffold(
          body: Center(
              child: Text('Tenant não selecionado.',
                  style: TextStyle(color: cs.outline))));
    }

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Meus Locais',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: cs.surface,
        foregroundColor: cs.primary,
        elevation: 0,
      ),
      floatingActionButton: _user == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _criarOuEditarLocal(),
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('NOVO LOTE',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
      body: Column(
        children: [
          Padding(
              padding: const EdgeInsets.all(AppTokens.md),
              child: _buildFiltros()),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _repo!
                  .queryCanteiros(
                      filtroAtivo: _filtroAtivo,
                      filtroStatus: _filtroStatus,
                      busca: "")
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                      child: Text('Falha de sincronização.',
                          style: TextStyle(color: cs.error)));
                }

                final rawDocs = snapshot.data?.docs ?? [];
                final docs = _filtrarEOrdenarLocal(rawDocs);

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.grid_off,
                            size: 64, color: cs.outlineVariant),
                        const SizedBox(height: AppTokens.md),
                        const Text('Nenhum lote encontrado.',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      AppTokens.md, 0, AppTokens.md, 100),
                  itemCount: docs.length + 1,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppTokens.sm),
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildCardResumo(docs);

                    final doc = docs[index - 1];
                    final dados = doc.data();
                    final id = doc.id;
                    final nome = (dados['nome'] ?? 'Sem Nome').toString();
                    final tipo = (dados['tipo'] ?? 'Canteiro').toString();
                    final bool ativo = (dados['ativo'] ?? true) == true;
                    final String status =
                        (dados['status'] ?? 'livre').toString();
                    final corStatus = _getCorStatus(status, cs);

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: cs.outlineVariant),
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      TelaDetalhesCanteiro(canteiroId: id)));
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(AppTokens.md),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppTokens.md),
                                decoration: BoxDecoration(
                                  color: ativo
                                      ? corStatus.withOpacity(0.15)
                                      : cs.surfaceContainerHighest,
                                  borderRadius:
                                      BorderRadius.circular(AppTokens.radiusMd),
                                ),
                                child: Icon(_iconeTipo(tipo),
                                    color: ativo ? corStatus : cs.outline),
                              ),
                              const SizedBox(width: AppTokens.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(nome,
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: ativo
                                                ? cs.onSurface
                                                : cs.outline,
                                            decoration: ativo
                                                ? null
                                                : TextDecoration.lineThrough)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(_iconeMedida(tipo),
                                            size: 14, color: cs.outline),
                                        const SizedBox(width: 4),
                                        Text(_labelMedida(dados),
                                            style: TextStyle(
                                                color: cs.onSurfaceVariant,
                                                fontSize: 13)),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color:
                                                ativo ? corStatus : cs.outline,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            ativo
                                                ? _getTextoStatus(status)
                                                : 'ARQUIVADO',
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert, color: cs.outline),
                                itemBuilder: (ctx) => [
                                  PopupMenuItem(
                                    value: 'editar',
                                    onTap: () => _runNextFrame(
                                        () => _criarOuEditarLocal(doc: doc)),
                                    child: Row(children: [
                                      Icon(Icons.edit,
                                          size: 18, color: cs.primary),
                                      const SizedBox(width: 8),
                                      const Text('Editar Lote'),
                                    ]),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle_ativo',
                                    onTap: () => _runNextFrame(() async =>
                                        await _toggleAtivoComUndo(
                                            id, ativo, nome)),
                                    child: Row(children: [
                                      Icon(
                                          ativo
                                              ? Icons.archive
                                              : Icons.unarchive,
                                          size: 18),
                                      const SizedBox(width: 8),
                                      Text(ativo ? 'Arquivar' : 'Reativar'),
                                    ]),
                                  ),
                                  if (_enableHardDelete)
                                    PopupMenuItem(
                                      value: 'excluir',
                                      onTap: () => _runNextFrame(() =>
                                          _confirmarExclusaoCanteiro(id, nome)),
                                      child: const Row(children: [
                                        Icon(Icons.delete,
                                            size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Excluir (DEV)',
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ]),
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
            ),
          ),
        ],
      ),
    );
  }
}
