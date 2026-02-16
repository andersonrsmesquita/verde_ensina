// FILE: lib/modules/canteiros/tela_canteiros.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  // Variáveis de Filtro e Ordem
  String _filtroAtivo = 'ativos'; // ativos | arquivados | todos
  String _filtroStatus = 'todos'; // todos | livre | ocupado | manutencao
  String _filtroTipo = 'todos'; // todos | canteiro | vaso
  String _ordem =
      'recentes'; // recentes | nome_az | nome_za | medida_maior | medida_menor
  String _busca = '';

  final TextEditingController _buscaCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _buscaCtrl.addListener(() {
      if (!mounted) return;
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
        return cs.primary; // Verde para produzindo
      case 'manutencao':
        return Colors.orange.shade700; // Laranja para manutenção
      default:
        return cs.outline; // Cinza para livre
    }
  }

  String _getTextoStatus(String? status) {
    switch (status) {
      case 'ocupado':
        return 'Produzindo';
      case 'manutencao':
        return 'Em Tratamento';
      default:
        return 'Livre (Pronto)';
    }
  }

  void _onBuscaChanged(String v) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _busca = v);
    });
  }

  // ===========================================================================
  // ORDENAÇÃO E FILTRO NA RAM
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

    // Ordenação
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
    if (finalidade != 'consumo' && finalidade != 'comercio') {
      finalidade = 'consumo';
    }

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
                    areaM2 = volumeL *
                        0.005; // Conversão estimada de Litros para Área
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
                  _msg('Erro ao salvar: ${e.toString()}', isError: true);
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
                              hintText: 'Ex: Canteiro Principal / Vaso 40L',
                              prefixIcon: Icons.label_outline,
                              validator: (v) => (v?.trim().isEmpty ?? true)
                                  ? 'Informe um nome.'
                                  : null),
                          const SizedBox(height: AppTokens.lg),
                          Text('Tipo de Espaço',
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
                                          child: Text('Canteiro de Solo',
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
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                  '💡 Dica: Canteiros suspensos devem ter máx. 1,30m de largura para facilitar o alcance.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade800)),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                    child: AppTextField(
                                        controller: compCtrl,
                                        labelText: 'Comprimento',
                                        hintText: '5,00',
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
                                        hintText: '1,30',
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
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                  '💡 Dica: Vasos de 40L são ideais para Mandioca, Batata, Abóbora e Chuchu.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade800)),
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                                controller: volumeCtrl,
                                labelText: 'Volume de terra',
                                hintText: 'Ex: 40',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9\.,]'))
                                ],
                                prefixIcon: Icons.local_drink,
                                suffixText: 'Litros',
                                validator: (_) =>
                                    _doubleFromController(volumeCtrl) <= 0
                                        ? 'Obrigatório'
                                        : null),
                          ],
                          const SizedBox(height: AppTokens.lg),
                          Text('Finalidade de Produção',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: AppTokens.sm),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                  value: 'consumo',
                                  label: Text('Consumo (Casa)')),
                              ButtonSegment(
                                  value: 'comercio',
                                  label: Text('Venda (Lucro)'))
                            ],
                            selected: {finalidade},
                            onSelectionChanged: (set) =>
                                setModalState(() => finalidade = set.first),
                          ),
                          const SizedBox(height: AppTokens.lg),
                          Text(
                              'Status do Local', // ✅ Modificado de Lote para Local
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
                              hintText:
                                  'Ex: Quintal / Estufa / Varanda da sala',
                              prefixIcon: Icons.place_outlined),
                          const SizedBox(height: AppTokens.md),
                          AppTextField(
                              controller: obsCtrl,
                              labelText: 'Observações (opcional)',
                              hintText:
                                  'Ex: Irrigação feita por gotejamento...',
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
                                : (editando
                                    ? 'SALVAR ALTERAÇÕES'
                                    : 'CRIAR LOCAL')), // ✅ Modificado
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

  void _abrirModalOrdenacao() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ordenar por',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              RadioListTile<String>(
                title: const Text('Mais Recentes'),
                value: 'recentes',
                groupValue: _ordem,
                activeColor: cs.primary,
                onChanged: (val) {
                  setState(() => _ordem = val!);
                  Navigator.pop(ctx);
                },
              ),
              RadioListTile<String>(
                title: const Text('Ordem Alfabética (A-Z)'),
                value: 'nome_az',
                groupValue: _ordem,
                activeColor: cs.primary,
                onChanged: (val) {
                  setState(() => _ordem = val!);
                  Navigator.pop(ctx);
                },
              ),
              RadioListTile<String>(
                title: const Text('Ordem Alfabética (Z-A)'),
                value: 'nome_za',
                groupValue: _ordem,
                activeColor: cs.primary,
                onChanged: (val) {
                  setState(() => _ordem = val!);
                  Navigator.pop(ctx);
                },
              ),
              RadioListTile<String>(
                title: const Text('Maior Espaço'),
                value: 'medida_maior',
                groupValue: _ordem,
                activeColor: cs.primary,
                onChanged: (val) {
                  setState(() => _ordem = val!);
                  Navigator.pop(ctx);
                },
              ),
              RadioListTile<String>(
                title: const Text('Menor Espaço'),
                value: 'medida_menor',
                groupValue: _ordem,
                activeColor: cs.primary,
                onChanged: (val) {
                  setState(() => _ordem = val!);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
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
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelect(key),
        selectedColor: cs.primaryContainer,
        backgroundColor: cs.surface,
        labelStyle: TextStyle(
            color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            fontSize: 12),
        side: BorderSide(
            color: selected
                ? Colors.transparent
                : cs.outlineVariant.withOpacity(0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _buscaCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar local ou vaso...', // ✅ Modificado
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
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusMd)),
                    isDense: true,
                  ),
                  onChanged: _onBuscaChanged,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
                child: IconButton(
                  icon: Icon(Icons.sort, color: cs.primary),
                  tooltip: 'Ordenar',
                  onPressed: _abrirModalOrdenacao,
                ),
              )
            ],
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
                _chip(
                    cs: cs,
                    key: 'arquivados',
                    label: 'Arquivados',
                    current: _filtroAtivo,
                    onSelect: (v) => setState(() => _filtroAtivo = v)),
                _chip(
                    cs: cs,
                    key: 'todos',
                    label: 'Todos os Locais', // ✅ Modificado
                    current: _filtroAtivo,
                    onSelect: (v) => setState(() => _filtroAtivo = v)),
                Container(
                    width: 1,
                    height: 20,
                    color: cs.outlineVariant,
                    margin: const EdgeInsets.symmetric(horizontal: 8)),
                _chip(
                    cs: cs,
                    key: 'todos',
                    label: 'Todos Status',
                    current: _filtroStatus,
                    onSelect: (v) => setState(() => _filtroStatus = v)),
                _chip(
                    cs: cs,
                    key: 'livre',
                    label: 'Livres',
                    current: _filtroStatus,
                    onSelect: (v) => setState(() => _filtroStatus = v)),
                _chip(
                    cs: cs,
                    key: 'ocupado',
                    label: 'Produzindo',
                    current: _filtroStatus,
                    onSelect: (v) => setState(() => _filtroStatus = v)),
                _chip(
                    cs: cs,
                    key: 'manutencao',
                    label: 'Em Tratamento',
                    current: _filtroStatus,
                    onSelect: (v) => setState(() => _filtroStatus = v)),
                Container(
                    width: 1,
                    height: 20,
                    color: cs.outlineVariant,
                    margin: const EdgeInsets.symmetric(horizontal: 8)),
                _chip(
                    cs: cs,
                    key: 'todos',
                    label: 'Ambos os Tipos',
                    current: _filtroTipo,
                    onSelect: (v) => setState(() => _filtroTipo = v)),
                _chip(
                    cs: cs,
                    key: 'canteiro',
                    label: 'Solo',
                    current: _filtroTipo,
                    onSelect: (v) => setState(() => _filtroTipo = v)),
                _chip(
                    cs: cs,
                    key: 'vaso',
                    label: 'Vasos',
                    current: _filtroTipo,
                    onSelect: (v) => setState(() => _filtroTipo = v)),
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
    int emProducao = 0;
    int emManutencao = 0;
    double totalArea = 0;

    for (final d in docs) {
      final data = d.data();
      if ((data['ativo'] ?? true) == true) {
        ativos++;
        final status = (data['status'] ?? 'livre').toString();
        if (status == 'ocupado') emProducao++;
        if (status == 'manutencao') emManutencao++;

        final tipo = (data['tipo'] ?? 'Canteiro').toString();
        if (tipo == 'Vaso') {
          final vol =
              double.tryParse(data['volume_l']?.toString() ?? '0') ?? 0.0;
          totalArea += vol * 0.005; // Estimativa de area de vaso pra o dash
        } else {
          totalArea +=
              double.tryParse(data['area_m2']?.toString() ?? '0') ?? 0.0;
        }
      }
    }

    return SectionCard(
      title: 'Visão Geral do Filtro',
      child: Row(
        children: [
          Expanded(
              child: _miniKpi('Área Útil', '${totalArea.toStringAsFixed(1)} m²',
                  Icons.crop_free, cs.primary, cs)),
          Container(
              width: 1, height: 40, color: cs.outlineVariant.withOpacity(0.5)),
          Expanded(
              child: _miniKpi('Produzindo', '$emProducao', Icons.spa,
                  Colors.green.shade700, cs)),
          if (emManutencao > 0) ...[
            Container(
                width: 1,
                height: 40,
                color: cs.outlineVariant.withOpacity(0.5)),
            Expanded(
                child: _miniKpi('Tratamento', '$emManutencao',
                    Icons.build_circle, Colors.orange.shade800, cs)),
          ]
        ],
      ),
    );
  }

  Widget _miniKpi(
      String label, String value, IconData icon, Color cor, ColorScheme cs) {
    return Column(
      children: [
        Icon(icon, color: cor, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style:
              TextStyle(color: cor, fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
              label: const Text('NOVO LOCAL', // ✅ Modificado de LOTE para LOCAL
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
                              const Text(
                                  'Nenhum local encontrado.', // ✅ Modificado
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
                          final textoStatus = _getTextoStatus(status);

                          // Ícone do Status
                          IconData iconeStatus = Icons.check_circle_outline;
                          if (status == 'ocupado') iconeStatus = Icons.spa;
                          if (status == 'manutencao')
                            iconeStatus = Icons.build_circle;

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                side: BorderSide(
                                    color: cs.outlineVariant.withOpacity(0.5)),
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
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Icon(_iconeMedida(tipo),
                                                  size: 14, color: cs.outline),
                                              const SizedBox(width: 4),
                                              Text(_labelMedida(dados),
                                                  style: TextStyle(
                                                      color:
                                                          cs.onSurfaceVariant,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              const SizedBox(width: 12),
                                              Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                      color: ativo
                                                          ? corStatus
                                                              .withOpacity(0.1)
                                                          : cs.outline
                                                              .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                      border: Border.all(
                                                          color: ativo
                                                              ? corStatus
                                                                  .withOpacity(
                                                                      0.5)
                                                              : cs.outline
                                                                  .withOpacity(
                                                                      0.5))),
                                                  child: Row(
                                                    children: [
                                                      Icon(iconeStatus,
                                                          size: 10,
                                                          color: ativo
                                                              ? corStatus
                                                              : cs.outline),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                          ativo
                                                              ? textoStatus
                                                              : 'ARQUIVADO',
                                                          style: TextStyle(
                                                              fontSize: 10,
                                                              color: ativo
                                                                  ? corStatus
                                                                  : cs.outline,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    ],
                                                  )),
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
                                              const Text(
                                                  'Editar') // ✅ Modificado para ficar neutro
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
