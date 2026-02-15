import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/repositories/canteiro_repository.dart';
import '../../core/session/session_scope.dart';
import '../../core/ui/app_ui.dart';
import 'tela_detalhes_canteiro.dart';

class TelaCanteiros extends StatefulWidget {
  const TelaCanteiros({super.key});

  @override
  State<TelaCanteiros> createState() => _TelaCanteirosState();
}

class _TelaCanteirosState extends State<TelaCanteiros> {
  User? get _user => FirebaseAuth.instance.currentUser;
  CanteiroRepository? _repo;

  bool get _enableHardDelete => kDebugMode;

  String _filtroAtivo = 'ativos'; // ativos | arquivados | todos
  String _filtroStatus = 'todos'; // todos | livre | ocupado | manutencao
  String _filtroTipo = 'todos'; // todos | canteiro | vaso
  String _ordem = 'recentes';
  String _busca = '';

  final TextEditingController _buscaCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _buscaCtrl.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionScope.of(context).session;
    if (_repo == null && session != null) {
      _repo = CanteiroRepository(session.tenantId);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _buscaCtrl.dispose();
    super.dispose();
  }

  // ===========================================================================
  // Helpers Visuais e Lógica
  // ===========================================================================
  void _runNextFrame(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      fn();
    });
  }

  void _msg(String text, {bool isError = false}) {
    AppMessenger.show(isError ? '❌ $text' : '✅ $text');
  }

  double _doubleFromController(TextEditingController c) {
    return double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0.0;
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
    }
    final area = double.tryParse(dados['area_m2']?.toString() ?? '0') ?? 0.0;
    return '${area.toStringAsFixed(2)} m²';
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

  // A FUNÇÃO QUE FALTAVA (Para não travar a busca)
  void _onBuscaChanged(String v) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _busca = v);
    });
  }

  // ===========================================================================
  // ORDENAÇÃO E FILTRO NA RAM (BLINDAGEM CONTRA ERRO DE FIREBASE)
  // ===========================================================================
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtrarEOrdenarLocal(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final buscaTerm = _busca.trim().toLowerCase();

    var list = docs.where((doc) {
      final d = doc.data();

      // Filtro Ativo/Arquivado
      final isAtivo = (d['ativo'] ?? true) == true;
      if (_filtroAtivo == 'ativos' && !isAtivo) return false;
      if (_filtroAtivo == 'arquivados' && isAtivo) return false;

      // Filtro Status
      final status = (d['status'] ?? 'livre').toString();
      if (_filtroStatus != 'todos' && status != _filtroStatus) return false;

      // Filtro Tipo
      final tipo = (d['tipo'] ?? 'Canteiro').toString();
      if (_filtroTipo == 'canteiro' && tipo == 'Vaso') return false;
      if (_filtroTipo == 'vaso' && tipo != 'Vaso') return false;

      // Busca de Texto
      if (buscaTerm.isNotEmpty) {
        final nomeLower =
            (d['nome_lower'] ?? (d['nome'] ?? '')).toString().toLowerCase();
        if (!nomeLower.contains(buscaTerm)) return false;
      }

      return true;
    }).toList();

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
        list.sort((a, b) => medidaOf(b.data()).compareTo(medidaOf(a.data())));
        break;
      case 'medida_menor':
        list.sort((a, b) => medidaOf(a.data()).compareTo(medidaOf(b.data())));
        break;
      default:
        list.sort((a, b) => tsOf(b.data()).compareTo(tsOf(a.data())));
        break;
    }

    return list;
  }

  // ===========================================================================
  // MODAIS CRUD
  // ===========================================================================
  void _criarOuEditarLocal({DocumentSnapshot<Map<String, dynamic>>? doc}) {
    if (_user == null || _repo == null) {
      _msg('Sessão inválida.', isError: true);
      return;
    }

    final cs = Theme.of(context).colorScheme;
    final editando = doc != null;
    final dados = doc?.data() ?? <String, dynamic>{};

    final nomeCtrl =
        TextEditingController(text: (dados['nome'] ?? '').toString());
    final compCtrl = TextEditingController(
        text: (dados['comprimento_m']?.toString() ?? '').replaceAll('.', ','));
    final largCtrl = TextEditingController(
        text: (dados['largura_m']?.toString() ?? '').replaceAll('.', ','));
    final volumeCtrl = TextEditingController(
        text: (dados['volume_l']?.toString() ?? '').replaceAll('.', ','));
    final obsCtrl =
        TextEditingController(text: (dados['observacoes'] ?? '').toString());
    final localCtrl =
        TextEditingController(text: (dados['localizacao'] ?? '').toString());

    String tipoLocal = (dados['tipo'] ?? 'Canteiro').toString();
    if (tipoLocal != 'Canteiro' && tipoLocal != 'Vaso') tipoLocal = 'Canteiro';

    String finalidade = (dados['finalidade'] ?? 'consumo').toString().trim();
    if (finalidade != 'consumo' && finalidade != 'comercio')
      finalidade = 'consumo';

    String statusLocal = (dados['status'] ?? 'livre').toString().trim();
    if (statusLocal != 'livre' &&
        statusLocal != 'ocupado' &&
        statusLocal != 'manutencao') statusLocal = 'livre';

    final formKey = GlobalKey<FormState>();
    bool salvando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom),
          child: StatefulBuilder(
            builder: (ctxModal, setModalState) {
              Future<void> salvar() async {
                FocusScope.of(ctxModal).unfocus();
                if (salvando) return;
                if (!(formKey.currentState?.validate() ?? false)) return;

                setModalState(() => salvando = true);

                try {
                  final nome = nomeCtrl.text.trim();
                  double areaM2 = 0, comp = 0, larg = 0, volumeL = 0;

                  if (tipoLocal == 'Canteiro') {
                    comp = _doubleFromController(compCtrl);
                    larg = _doubleFromController(largCtrl);
                    areaM2 = comp * larg;
                  } else {
                    volumeL = _doubleFromController(volumeCtrl);
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
                    'status': statusLocal,
                    'observacoes': obsCtrl.text.trim(),
                    'localizacao': localCtrl.text.trim(),
                  };

                  await _repo!.salvarLocal(docId: doc?.id, payload: payload);

                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  _msg(editando
                      ? 'Local atualizado com sucesso.'
                      : 'Local criado com sucesso.');
                } catch (e) {
                  _msg('Erro ao salvar.', isError: true);
                  setModalState(() => salvando = false);
                }
              }

              return Container(
                decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24))),
                padding: const EdgeInsets.all(AppTokens.xl),
                child: SafeArea(
                  top: false,
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                  child: Text(
                                      editando ? 'Editar local' : 'Novo local',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                              fontWeight: FontWeight.w800))),
                              IconButton(
                                  onPressed: () => Navigator.pop(sheetCtx),
                                  icon: const Icon(Icons.close)),
                            ],
                          ),
                          const SizedBox(height: AppTokens.lg),
                          AppTextField(
                              controller: nomeCtrl,
                              labelText: 'Nome',
                              hintText: 'Ex: Canteiro 01 / Vaso da varanda',
                              prefixIcon: Icons.label_outline,
                              validator: (v) => (v?.trim().isEmpty ?? true)
                                  ? 'Informe um nome.'
                                  : null),
                          const SizedBox(height: AppTokens.lg),
                          Text('Tipo',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: AppTokens.sm),
                          Row(
                            children: [
                              Expanded(
                                  child: InkWell(
                                      borderRadius: BorderRadius.circular(
                                          AppTokens.radiusMd),
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
                                                  AppTokens.radiusMd)),
                                          alignment: Alignment.center,
                                          child: Text('Canteiro / Solo',
                                              style: TextStyle(
                                                  color: tipoLocal == 'Canteiro'
                                                      ? cs.onPrimary
                                                      : cs.onSurfaceVariant,
                                                  fontWeight: FontWeight.w800))))),
                              const SizedBox(width: AppTokens.md),
                              Expanded(
                                  child: InkWell(
                                      borderRadius: BorderRadius.circular(
                                          AppTokens.radiusMd),
                                      onTap: () => setModalState(
                                          () => tipoLocal = 'Vaso'),
                                      child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          decoration: BoxDecoration(
                                              color: tipoLocal == 'Vaso'
                                                  ? cs.primary
                                                  : cs.surfaceContainerHighest,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppTokens.radiusMd)),
                                          alignment: Alignment.center,
                                          child: Text('Vaso / Recipiente',
                                              style: TextStyle(
                                                  color: tipoLocal == 'Vaso'
                                                      ? cs.onPrimary
                                                      : cs.onSurfaceVariant,
                                                  fontWeight: FontWeight.w800))))),
                            ],
                          ),
                          const SizedBox(height: AppTokens.lg),
                          if (tipoLocal == 'Canteiro') ...[
                            Row(
                              children: [
                                Expanded(
                                    child: AppTextField(
                                        controller: compCtrl,
                                        labelText: 'Comprimento',
                                        hintText: '0,00',
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                              RegExp(r'[0-9\.,]'))
                                        ],
                                        suffixText: 'm',
                                        validator: (_) =>
                                            _doubleFromController(compCtrl) <= 0
                                                ? 'Obrigatório'
                                                : null)),
                                const SizedBox(width: AppTokens.md),
                                Expanded(
                                    child: AppTextField(
                                        controller: largCtrl,
                                        labelText: 'Largura',
                                        hintText: '0,00',
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                              RegExp(r'[0-9\.,]'))
                                        ],
                                        suffixText: 'm',
                                        validator: (_) =>
                                            _doubleFromController(largCtrl) <= 0
                                                ? 'Obrigatório'
                                                : null)),
                              ],
                            ),
                          ] else ...[
                            AppTextField(
                                controller: volumeCtrl,
                                labelText: 'Volume de terra',
                                hintText: '0,0',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9\.,]'))
                                ],
                                prefixIcon: Icons.local_drink,
                                suffixText: 'L',
                                validator: (_) =>
                                    _doubleFromController(volumeCtrl) <= 0
                                        ? 'Obrigatório'
                                        : null),
                          ],
                          const SizedBox(height: AppTokens.lg),
                          Text('Finalidade',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: AppTokens.sm),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                  value: 'consumo', label: Text('Consumo')),
                              ButtonSegment(
                                  value: 'comercio', label: Text('Venda'))
                            ],
                            selected: {finalidade},
                            onSelectionChanged: (set) =>
                                setModalState(() => finalidade = set.first),
                          ),
                          const SizedBox(height: AppTokens.lg),
                          Text('Status',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: AppTokens.sm),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                  value: 'livre', label: Text('Livre')),
                              ButtonSegment(
                                  value: 'ocupado', label: Text('Ocupado')),
                              ButtonSegment(
                                  value: 'manutencao',
                                  label: Text('Manutenção'))
                            ],
                            selected: {statusLocal},
                            onSelectionChanged: (set) =>
                                setModalState(() => statusLocal = set.first),
                          ),
                          const SizedBox(height: AppTokens.lg),
                          AppTextField(
                              controller: localCtrl,
                              labelText: 'Localização (opcional)',
                              hintText: 'Ex: Fundos / Estufa / Varanda',
                              prefixIcon: Icons.place_outlined),
                          const SizedBox(height: AppTokens.md),
                          AppTextField(
                              controller: obsCtrl,
                              labelText: 'Observações (opcional)',
                              hintText:
                                  'Ex: solo arenoso, recebe sol até 14h...',
                              prefixIcon: Icons.notes_outlined,
                              minLines: 2,
                              maxLines: 4),
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
                                : (editando ? 'SALVAR' : 'CRIAR')),
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

  void _alterarStatus(String id, String nome, String atual) {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
              color: cs.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(AppTokens.lg),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Status do local',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: AppTokens.sm),
                Text(nome,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: AppTokens.lg),
                _statusTile(ctx, id, 'livre', atual),
                _statusTile(ctx, id, 'ocupado', atual),
                _statusTile(ctx, id, 'manutencao', atual),
                const SizedBox(height: AppTokens.md),
                AppButtons.outlinedIcon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                    label: const Text('FECHAR')),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusTile(BuildContext ctx, String id, String status, String atual) {
    final cs = Theme.of(context).colorScheme;
    final isSel = status == atual;

    return ListTile(
      leading: Icon(isSel ? Icons.radio_button_checked : Icons.radio_button_off,
          color: isSel ? cs.primary : cs.outline),
      title: Text(_getTextoStatus(status),
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(status),
      onTap: () async {
        try {
          await _repo!.atualizarStatus(id, status);
          if (ctx.mounted) Navigator.pop(ctx);
          _msg('Status atualizado.');
        } catch (e) {
          _msg('Erro ao atualizar status', isError: true);
        }
      },
    );
  }

  Future<void> _duplicar(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final d = doc.data();
    final nome = (d['nome'] ?? 'Sem nome').toString();
    final ctrl = TextEditingController(text: 'Cópia - $nome');

    final novoNome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duplicar local'),
        content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
                labelText: 'Novo nome', border: OutlineInputBorder())),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Duplicar')),
        ],
      ),
    );

    ctrl.dispose();
    if (novoNome == null || novoNome.trim().isEmpty) return;
    try {
      await _repo!.duplicar(data: d, novoNome: novoNome.trim());
      _msg('Duplicado com sucesso.');
    } catch (e) {
      _msg('Falha ao duplicar', isError: true);
    }
  }

  void _confirmarExclusao(String id, String nome) {
    if (!_enableHardDelete) {
      _msg('Uso restrito a DEV. Use “Arquivar”.', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir definitivo?'),
        content: Text(
            'Isso apaga "$nome" e o histórico ligado a ele.\n\nNão tem volta.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _repo!.excluirDefinitivoCascade(_user!.uid, id);
                _msg('Local excluído com sucesso.');
              } catch (e) {
                _msg('Falha ao excluir.', isError: true);
              }
            },
            child: const Text('EXCLUIR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAtivoComUndo(
      String id, bool ativoAtual, String nome) async {
    try {
      await _repo!.alternarStatusAtivo(id, ativoAtual);
      _msg(ativoAtual ? '"$nome" arquivado.' : '"$nome" reativado.');
    } catch (e) {
      _msg('Erro ao arquivar.', isError: true);
    }
  }

  // -----------------------
  // Construção Visual
  // -----------------------
  Widget _chip(
      {required ColorScheme cs,
      required String key,
      required String label,
      required String current,
      required void Function(String) onSelect}) {
    final selected = current == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelect(key),
      selectedColor: cs.primaryContainer,
      labelStyle: TextStyle(
          color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500),
      side: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
    );
  }

  Widget _buildFiltros() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTokens.md),
      decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.5))),
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
                      }),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
              isDense: true,
            ),
            onChanged: _onBuscaChanged,
          ),
          const SizedBox(height: AppTokens.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(
                    cs: cs,
                    key: 'ativos',
                    label: 'Ativos',
                    current: _filtroAtivo,
                    onSelect: (v) => setState(() => _filtroAtivo = v)),
                const SizedBox(width: 8),
                _chip(
                    cs: cs,
                    key: 'arquivados',
                    label: 'Arquivados',
                    current: _filtroAtivo,
                    onSelect: (v) => setState(() => _filtroAtivo = v)),
                const SizedBox(width: 8),
                _chip(
                    cs: cs,
                    key: 'todos',
                    label: 'Todos',
                    current: _filtroAtivo,
                    onSelect: (v) => setState(() => _filtroAtivo = v)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 AQUI ESTÁ O CÓDIGO SUBSTITUÍDO (Usando SectionCard e sem degradê)
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

    return SectionCard(
      title: 'Visão Geral dos Lotes',
      child: Row(
        children: [
          Expanded(
              child: _miniKpi('Área Útil', '${totalArea.toStringAsFixed(1)} m²',
                  Icons.crop_free, cs)),
          Container(
              width: 1, height: 40, color: cs.outlineVariant.withOpacity(0.5)),
          Expanded(
              child:
                  _miniKpi('Lotes Ativos', '$ativos', Icons.eco_outlined, cs)),
        ],
      ),
    );
  }

  Widget _miniKpi(String label, String value, IconData icon, ColorScheme cs) {
    return Column(
      children: [
        Icon(icon, color: cs.primary, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
              color: cs.onSurface, fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // 🛡️ O SCAFFOLD NATIVO SALVA A TELA DE SUMIR NO WINDOWS!
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
      body: _repo == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                    padding: const EdgeInsets.all(AppTokens.md),
                    child: _buildFiltros()),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    // 🛡️ MÁGICA: SEM FILTROS NO BANCO. Filtramos localmente para evitar Erro de Índice!
                    stream: _repo!.queryCanteiros().snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting)
                        return const Center(child: CircularProgressIndicator());
                      if (snapshot.hasError)
                        return Center(
                            child: Text('Erro: ${snapshot.error}',
                                style: TextStyle(color: cs.error)));

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
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
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
                                borderRadius:
                                    BorderRadius.circular(AppTokens.radiusMd)),
                            child: InkWell(
                              borderRadius:
                                  BorderRadius.circular(AppTokens.radiusMd),
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => TelaDetalhesCanteiro(
                                            canteiroId: id)));
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(AppTokens.md),
                                child: Row(
                                  children: [
                                    Container(
                                      padding:
                                          const EdgeInsets.all(AppTokens.md),
                                      decoration: BoxDecoration(
                                          color: ativo
                                              ? corStatus.withOpacity(0.15)
                                              : cs.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                              AppTokens.radiusMd)),
                                      child: Icon(_iconeTipo(tipo),
                                          color:
                                              ativo ? corStatus : cs.outline),
                                    ),
                                    const SizedBox(width: AppTokens.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                                      : TextDecoration
                                                          .lineThrough)),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(_iconeMedida(tipo),
                                                  size: 14, color: cs.outline),
                                              const SizedBox(width: 4),
                                              Text(_labelMedida(dados),
                                                  style: TextStyle(
                                                      color:
                                                          cs.onSurfaceVariant,
                                                      fontSize: 13)),
                                              const SizedBox(width: 8),
                                              Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                      color: ativo
                                                          ? corStatus
                                                          : cs.outline,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4)),
                                                  child: Text(
                                                      ativo
                                                          ? _getTextoStatus(
                                                              status)
                                                          : 'ARQUIVADO',
                                                      style: const TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.white,
                                                          fontWeight: FontWeight
                                                              .bold))),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_vert,
                                          color: cs.outline),
                                      itemBuilder: (ctx) => [
                                        PopupMenuItem(
                                            value: 'editar',
                                            onTap: () => _runNextFrame(() =>
                                                _criarOuEditarLocal(doc: doc)),
                                            child: Row(children: [
                                              Icon(Icons.edit,
                                                  size: 18, color: cs.primary),
                                              const SizedBox(width: 8),
                                              const Text('Editar Lote')
                                            ])),
                                        PopupMenuItem(
                                            value: 'toggle_ativo',
                                            onTap: () => _runNextFrame(
                                                () async =>
                                                    await _toggleAtivoComUndo(
                                                        id, ativo, nome)),
                                            child: Row(children: [
                                              Icon(
                                                  ativo
                                                      ? Icons.archive
                                                      : Icons.unarchive,
                                                  size: 18),
                                              const SizedBox(width: 8),
                                              Text(ativo
                                                  ? 'Arquivar'
                                                  : 'Reativar')
                                            ])),
                                        if (_enableHardDelete)
                                          PopupMenuItem(
                                              value: 'excluir',
                                              onTap: () => _runNextFrame(() =>
                                                  _confirmarExclusao(id, nome)),
                                              child: const Row(children: [
                                                Icon(Icons.delete,
                                                    size: 18,
                                                    color: Colors.red),
                                                SizedBox(width: 8),
                                                Text('Excluir (DEV)',
                                                    style: TextStyle(
                                                        color: Colors.red))
                                              ])),
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
