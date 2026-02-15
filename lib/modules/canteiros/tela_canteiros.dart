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
  String _ordem =
      'recentes'; // recentes | nome_az | nome_za | medida_maior | medida_menor
  String _busca = '';

  final TextEditingController _buscaCtrl = TextEditingController();
  Timer? _debounce;

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

  // -----------------------
  // Helpers
  // -----------------------

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

  String _labelOrdem(String v) {
    switch (v) {
      case 'nome_az':
        return 'Nome (A–Z)';
      case 'nome_za':
        return 'Nome (Z–A)';
      case 'medida_maior':
        return 'Maior medida';
      case 'medida_menor':
        return 'Menor medida';
      default:
        return 'Recentes';
    }
  }

  // -----------------------
  // Busca / Debounce
  // -----------------------

  void _onBuscaChanged(String v) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _busca = v);
    });
  }

  // -----------------------
  // Filtro + Ordenação local
  // -----------------------

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtrarEOrdenarLocal(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final buscaTerm = _busca.trim().toLowerCase();

    num medidaOf(Map<String, dynamic> d) {
      final tipo = (d['tipo'] ?? 'Canteiro').toString();
      if (tipo == 'Vaso') {
        return double.tryParse(d['volume_l']?.toString() ?? '0') ?? 0.0;
      }
      return double.tryParse(d['area_m2']?.toString() ?? '0') ?? 0.0;
    }

    String nomeLowerOf(Map<String, dynamic> d) =>
        (d['nome_lower'] ?? (d['nome'] ?? '')).toString().toLowerCase();

    Timestamp tsOf(Map<String, dynamic> d) => d['data_criacao'] is Timestamp
        ? d['data_criacao']
        : Timestamp.fromMillisecondsSinceEpoch(0);

    var list = docs.where((doc) {
      final d = doc.data();

      // filtro tipo (local)
      if (_filtroTipo != 'todos') {
        final tipo = (d['tipo'] ?? 'Canteiro').toString();
        if (_filtroTipo == 'canteiro' && tipo == 'Vaso') return false;
        if (_filtroTipo == 'vaso' && tipo != 'Vaso') return false;
      }

      // busca (local)
      if (buscaTerm.isEmpty) return true;
      final nomeLower = nomeLowerOf(d);
      return nomeLower.contains(buscaTerm);
    }).toList();

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

  // -----------------------
  // Criar / Editar
  // -----------------------

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
      text: (dados['comprimento_m']?.toString() ?? '').replaceAll('.', ','),
    );
    final largCtrl = TextEditingController(
      text: (dados['largura_m']?.toString() ?? '').replaceAll('.', ','),
    );
    final volumeCtrl = TextEditingController(
      text: (dados['volume_l']?.toString() ?? '').replaceAll('.', ','),
    );
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
        statusLocal != 'manutencao') {
      statusLocal = 'livre';
    }

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
                  _msg('Erro ao salvar: $e', isError: true);
                  setModalState(() => salvando = false);
                }
              }

              return Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(AppTokens.xl),
                child: SafeArea(
                  top: false,
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
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
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(sheetCtx),
                                icon: const Icon(Icons.close),
                              ),
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
                                : null,
                          ),
                          const SizedBox(height: AppTokens.lg),
                          Text(
                            'Tipo',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: AppTokens.sm),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius:
                                      BorderRadius.circular(AppTokens.radiusMd),
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
                                    child: Text(
                                      'Canteiro / Solo',
                                      style: TextStyle(
                                        color: tipoLocal == 'Canteiro'
                                            ? cs.onPrimary
                                            : cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppTokens.md),
                              Expanded(
                                child: InkWell(
                                  borderRadius:
                                      BorderRadius.circular(AppTokens.radiusMd),
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
                                    child: Text(
                                      'Vaso / Recipiente',
                                      style: TextStyle(
                                        color: tipoLocal == 'Vaso'
                                            ? cs.onPrimary
                                            : cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
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
                                  child: AppTextField(
                                    controller: compCtrl,
                                    labelText: 'Comprimento',
                                    hintText: '0,00',
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9\.,]'))
                                    ],
                                    suffixText: 'm',
                                    validator: (_) =>
                                        _doubleFromController(compCtrl) <= 0
                                            ? 'Obrigatório'
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: AppTokens.md),
                                Expanded(
                                  child: AppTextField(
                                    controller: largCtrl,
                                    labelText: 'Largura',
                                    hintText: '0,00',
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9\.,]'))
                                    ],
                                    suffixText: 'm',
                                    validator: (_) =>
                                        _doubleFromController(largCtrl) <= 0
                                            ? 'Obrigatório'
                                            : null,
                                  ),
                                ),
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
                                      : null,
                            ),
                          ],
                          const SizedBox(height: AppTokens.lg),
                          Text(
                            'Finalidade',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: AppTokens.sm),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                  value: 'consumo', label: Text('Consumo')),
                              ButtonSegment(
                                  value: 'comercio', label: Text('Venda')),
                            ],
                            selected: {finalidade},
                            onSelectionChanged: (set) =>
                                setModalState(() => finalidade = set.first),
                          ),
                          const SizedBox(height: AppTokens.lg),
                          Text(
                            'Status',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: AppTokens.sm),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                  value: 'livre', label: Text('Livre')),
                              ButtonSegment(
                                  value: 'ocupado', label: Text('Ocupado')),
                              ButtonSegment(
                                  value: 'manutencao',
                                  label: Text('Manutenção')),
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
                            prefixIcon: Icons.place_outlined,
                          ),
                          const SizedBox(height: AppTokens.md),
                          AppTextField(
                            controller: obsCtrl,
                            labelText: 'Observações (opcional)',
                            hintText: 'Ex: solo arenoso, recebe sol até 14h...',
                            prefixIcon: Icons.notes_outlined,
                            minLines: 2,
                            maxLines: 4,
                          ),
                          const SizedBox(height: AppTokens.xl),
                          AppButtons.elevatedIcon(
                            onPressed: salvando ? null : salvar,
                            icon: salvando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
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

  // -----------------------
  // Ações rápidas
  // -----------------------

  Future<void> _toggleAtivo(String id, bool ativoAtual, String nome) async {
    try {
      await _repo!.alternarStatusAtivo(id, ativoAtual);
      _msg(ativoAtual ? '"$nome" arquivado.' : '"$nome" reativado.');
    } catch (e) {
      _msg('Erro ao alterar ativo: $e', isError: true);
    }
  }

  void _confirmarExclusao(String id, String nome) {
    if (!_enableHardDelete) {
      _msg('Uso restrito a DEV. Use “Arquivar”.', isError: true);
      return;
    }

    AppDialogs.confirm(
      context,
      title: 'Excluir definitivo?',
      message:
          'Isso apaga "$nome" e o histórico ligado a ele.\n\nNão tem volta.',
      confirmText: 'EXCLUIR',
      isDanger: true,
      onConfirm: () async {
        try {
          await _repo!.excluirDefinitivoCascade(_user!.uid, id);
          _msg('Local excluído com sucesso.');
        } catch (e) {
          _msg('Falha ao excluir: $e', isError: true);
        }
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(AppTokens.lg),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Status do local',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppTokens.sm),
                Text(
                  nome,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppTokens.lg),
                _statusTile(ctx, id, 'livre', atual),
                _statusTile(ctx, id, 'ocupado', atual),
                _statusTile(ctx, id, 'manutencao', atual),
                const SizedBox(height: AppTokens.md),
                AppButtons.outlinedIcon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                  label: const Text('FECHAR'),
                ),
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
      leading: Icon(
        isSel ? Icons.radio_button_checked : Icons.radio_button_off,
        color: isSel ? cs.primary : cs.outline,
      ),
      title: Text(_getTextoStatus(status),
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(status),
      onTap: () async {
        try {
          await _repo!.atualizarStatus(id, status);
          if (ctx.mounted) Navigator.pop(ctx);
          _msg('Status atualizado.');
        } catch (e) {
          _msg('Erro ao atualizar status: $e', isError: true);
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
            labelText: 'Novo nome',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Duplicar'),
          ),
        ],
      ),
    );

    ctrl.dispose();
    if (novoNome == null || novoNome.trim().isEmpty) return;

    try {
      await _repo!.duplicar(data: d, novoNome: novoNome.trim());
      _msg('Duplicado com sucesso.');
    } catch (e) {
      _msg('Falha ao duplicar: $e', isError: true);
    }
  }

  // -----------------------
  // Widgets UI
  // -----------------------

  Widget _chip({
    required ColorScheme cs,
    required String key,
    required String label,
    required String current,
    required void Function(String) onSelect,
  }) {
    final selected = current == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelect(key),
      selectedColor: cs.primaryContainer,
      labelStyle: TextStyle(
        color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
      ),
      side: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
    );
  }

  Widget _buildFiltros() {
    final cs = Theme.of(context).colorScheme;

    return SectionCard(
      title: 'Filtros',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField.search(
            controller: _buscaCtrl,
            hintText: 'Buscar local...',
            onChanged: _onBuscaChanged,
            onClear: () {
              _buscaCtrl.clear();
              setState(() => _busca = '');
            },
          ),
          const SizedBox(height: AppTokens.md),
          Text('Ativo',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: AppTokens.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                  cs: cs,
                  key: 'ativos',
                  label: 'Ativos',
                  current: _filtroAtivo,
                  onSelect: (v) => setState(() => _filtroAtivo = v)),
              _chip(
                  cs: cs,
                  key: 'arquivados',
                  label: 'Arquivados',
                  current: _filtroAtivo,
                  onSelect: (v) => setState(() => _filtroAtivo = v)),
              _chip(
                  cs: cs,
                  key: 'todos',
                  label: 'Todos',
                  current: _filtroAtivo,
                  onSelect: (v) => setState(() => _filtroAtivo = v)),
            ],
          ),
          const SizedBox(height: AppTokens.md),
          Text('Status',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: AppTokens.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                  cs: cs,
                  key: 'todos',
                  label: 'Todos',
                  current: _filtroStatus,
                  onSelect: (v) => setState(() => _filtroStatus = v)),
              _chip(
                  cs: cs,
                  key: 'livre',
                  label: 'Livre',
                  current: _filtroStatus,
                  onSelect: (v) => setState(() => _filtroStatus = v)),
              _chip(
                  cs: cs,
                  key: 'ocupado',
                  label: 'Ocupado',
                  current: _filtroStatus,
                  onSelect: (v) => setState(() => _filtroStatus = v)),
              _chip(
                  cs: cs,
                  key: 'manutencao',
                  label: 'Manutenção',
                  current: _filtroStatus,
                  onSelect: (v) => setState(() => _filtroStatus = v)),
            ],
          ),
          const SizedBox(height: AppTokens.md),
          Text('Tipo',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: AppTokens.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                  cs: cs,
                  key: 'todos',
                  label: 'Todos',
                  current: _filtroTipo,
                  onSelect: (v) => setState(() => _filtroTipo = v)),
              _chip(
                  cs: cs,
                  key: 'canteiro',
                  label: 'Canteiro',
                  current: _filtroTipo,
                  onSelect: (v) => setState(() => _filtroTipo = v)),
              _chip(
                  cs: cs,
                  key: 'vaso',
                  label: 'Vaso',
                  current: _filtroTipo,
                  onSelect: (v) => setState(() => _filtroTipo = v)),
            ],
          ),
          const SizedBox(height: AppTokens.md),
          AppTextField.dropdown<String>(
            labelText: 'Ordenar por',
            value: _ordem,
            items: const [
              DropdownMenuItem(value: 'recentes', child: Text('Recentes')),
              DropdownMenuItem(value: 'nome_az', child: Text('Nome (A–Z)')),
              DropdownMenuItem(value: 'nome_za', child: Text('Nome (Z–A)')),
              DropdownMenuItem(
                  value: 'medida_maior', child: Text('Maior medida')),
              DropdownMenuItem(
                  value: 'medida_menor', child: Text('Menor medida')),
            ],
            onChanged: (v) => setState(() => _ordem = v ?? 'recentes'),
          ),
        ],
      ),
    );
  }

  Widget _buildResumo(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final cs = Theme.of(context).colorScheme;

    int ativos = 0;
    int arquivados = 0;
    int livre = 0;
    int ocupado = 0;
    int manutencao = 0;

    double totalArea = 0;
    double totalVolume = 0;

    for (final d in docs) {
      final data = d.data();
      final isAtivo = (data['ativo'] ?? true) == true;
      if (isAtivo)
        ativos++;
      else
        arquivados++;

      final st = (data['status'] ?? 'livre').toString();
      if (st == 'ocupado')
        ocupado++;
      else if (st == 'manutencao')
        manutencao++;
      else
        livre++;

      final tipo = (data['tipo'] ?? 'Canteiro').toString();
      if (tipo == 'Vaso') {
        totalVolume +=
            double.tryParse(data['volume_l']?.toString() ?? '0') ?? 0.0;
      } else {
        totalArea += double.tryParse(data['area_m2']?.toString() ?? '0') ?? 0.0;
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppTokens.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'VISÃO GERAL',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            runSpacing: 10,
            spacing: 14,
            children: [
              _miniKpi('Área', '${totalArea.toStringAsFixed(1)} m²'),
              _miniKpi('Volume', '${totalVolume.toStringAsFixed(1)} L'),
              _miniKpi('Ativos', '$ativos'),
              _miniKpi('Arquivados', '$arquivados'),
              _miniKpi('Livre', '$livre'),
              _miniKpi('Ocupado', '$ocupado'),
              _miniKpi('Manut.', '$manutencao'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniKpi(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  // -----------------------
  // Build
  // -----------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final session = SessionScope.of(context).session;

    if (session == null) {
      return PageContainer(
        title: 'Locais de cultivo',
        subtitle: 'Selecione um espaço para continuar.',
        body: AppStateView(
          state: AppViewState.error,
          title: 'Nenhum espaço selecionado',
          message:
              'Volte e selecione/crie um Espaço (tenant) antes de acessar os canteiros.',
          icon: Icons.apartment,
          actionLabel: 'IR PARA ESPAÇOS',
          onAction: () => context.go('/tenant'),
        ),
      );
    }

    if (_repo == null) {
      return PageContainer(
        title: 'Locais de cultivo',
        subtitle: 'Carregando espaço...',
        body: const AppStateView(state: AppViewState.loading),
      );
    }

    return PageContainer(
      title: 'Locais de cultivo',
      subtitle: 'Espaço: ${session.tenantName}',
      body: Column(
        children: [
          _buildFiltros(),
          const SizedBox(height: AppTokens.md),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _repo!
                  .queryCanteiros(
                    filtroAtivo: _filtroAtivo,
                    filtroStatus: _filtroStatus,
                    busca: '',
                  )
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppStateView(state: AppViewState.loading);
                }

                if (snapshot.hasError) {
                  return AppStateView(
                    state: AppViewState.error,
                    title: 'Falha de sincronização',
                    message:
                        'Não consegui carregar os locais agora. Tente novamente.',
                    icon: Icons.cloud_off,
                  );
                }

                final rawDocs = snapshot.data?.docs ?? [];
                final docs = _filtrarEOrdenarLocal(rawDocs);

                if (docs.isEmpty) {
                  return AppStateView(
                    state: AppViewState.empty,
                    title: 'Nada por aqui',
                    message:
                        'Crie seu primeiro local (canteiro/vaso) e comece o controle.',
                    icon: Icons.grid_off,
                    actionLabel: _user == null ? null : 'CRIAR LOCAL',
                    onAction:
                        _user == null ? null : () => _criarOuEditarLocal(),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: docs.length + 1,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppTokens.sm),
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildResumo(docs);

                    final doc = docs[index - 1];
                    final d = doc.data();
                    final id = doc.id;

                    final nome = (d['nome'] ?? 'Sem nome').toString();
                    final tipo = (d['tipo'] ?? 'Canteiro').toString();
                    final ativo = (d['ativo'] ?? true) == true;
                    final status = (d['status'] ?? 'livre').toString();

                    final corStatus = _getCorStatus(status, cs);

                    return Material(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TelaDetalhesCanteiro(canteiroId: id),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusMd),
                            border: Border.all(
                                color: cs.outlineVariant.withOpacity(0.7)),
                          ),
                          padding: const EdgeInsets.all(AppTokens.md),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppTokens.md),
                                decoration: BoxDecoration(
                                  color: ativo
                                      ? corStatus.withOpacity(0.14)
                                      : cs.surfaceContainerHighest,
                                  borderRadius:
                                      BorderRadius.circular(AppTokens.radiusMd),
                                ),
                                child: Icon(
                                  _iconeTipo(tipo),
                                  color: ativo ? corStatus : cs.outline,
                                ),
                              ),
                              const SizedBox(width: AppTokens.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nome,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color:
                                            ativo ? cs.onSurface : cs.outline,
                                        decoration: ativo
                                            ? null
                                            : TextDecoration.lineThrough,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(_iconeMedida(tipo),
                                            size: 14, color: cs.outline),
                                        const SizedBox(width: 6),
                                        Text(
                                          _labelMedida(d),
                                          style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color:
                                                ativo ? corStatus : cs.outline,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            ativo
                                                ? _getTextoStatus(status)
                                                : 'ARQUIVADO',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Ordenação: ${_labelOrdem(_ordem)}',
                                      style: TextStyle(
                                          color: cs.outline, fontSize: 11),
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
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit,
                                            size: 18, color: cs.primary),
                                        const SizedBox(width: 8),
                                        const Text('Editar'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'status',
                                    onTap: () => _runNextFrame(
                                        () => _alterarStatus(id, nome, status)),
                                    child: Row(
                                      children: [
                                        Icon(Icons.tune,
                                            size: 18, color: cs.primary),
                                        const SizedBox(width: 8),
                                        const Text('Alterar status'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'duplicar',
                                    onTap: () =>
                                        _runNextFrame(() => _duplicar(doc)),
                                    child: Row(
                                      children: [
                                        Icon(Icons.copy,
                                            size: 18, color: cs.primary),
                                        const SizedBox(width: 8),
                                        const Text('Duplicar'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle_ativo',
                                    onTap: () => _runNextFrame(
                                        () => _toggleAtivo(id, ativo, nome)),
                                    child: Row(
                                      children: [
                                        Icon(
                                            ativo
                                                ? Icons.archive
                                                : Icons.unarchive,
                                            size: 18),
                                        const SizedBox(width: 8),
                                        Text(ativo ? 'Arquivar' : 'Reativar'),
                                      ],
                                    ),
                                  ),
                                  if (_enableHardDelete)
                                    PopupMenuItem(
                                      value: 'excluir',
                                      onTap: () => _runNextFrame(
                                          () => _confirmarExclusao(id, nome)),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.delete,
                                              size: 18, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Excluir (DEV)',
                                              style:
                                                  TextStyle(color: Colors.red)),
                                        ],
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
            ),
          ),
        ],
      ),
      bottomBar: _user == null
          ? null
          : Padding(
              padding: const EdgeInsets.all(AppTokens.md),
              child: AppButtons.elevatedIcon(
                onPressed: () => _criarOuEditarLocal(),
                icon: const Icon(Icons.add),
                label: const Text('NOVO LOCAL'),
              ),
            ),
    );
  }
}
