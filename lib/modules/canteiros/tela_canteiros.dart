import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tela_detalhes_canteiro.dart';

class TelaCanteiros extends StatefulWidget {
  const TelaCanteiros({super.key});

  @override
  State<TelaCanteiros> createState() => _TelaCanteirosState();
}

class _TelaCanteirosState extends State<TelaCanteiros> {
  User? get _user => FirebaseAuth.instance.currentUser;

  /// ativos | arquivados | todos
  String _filtroAtivo = 'ativos';

  /// todos | livre | ocupado | manutencao
  String _filtroStatus = 'todos';

  /// recentes | nome_az | nome_za | medida_maior | medida_menor
  String _ordem = 'recentes';

  final TextEditingController _buscaCtrl = TextEditingController();
  Timer? _debounce;
  String _busca = '';

  @override
  void initState() {
    super.initState();

    // ✅ Faz o suffixIcon (clear) funcionar na hora, sem depender do debounce
    _buscaCtrl.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  // =========================
  // Helpers seguros
  // =========================

  void _runNextFrame(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      fn();
    });
  }

  void _snack(String msg, {Color? cor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: cor ?? Colors.blueGrey,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  num _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    if (v is String) return num.tryParse(v.replaceAll(',', '.')) ?? 0;
    return 0;
  }

  double _doubleFromController(TextEditingController c) {
    return double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0.0;
  }

  String _norm(String s) => s.trim().toLowerCase();

  // =========================
  // Status helpers
  // =========================

  Color _getCorStatus(String? status) {
    switch (status) {
      case 'ocupado':
        return Colors.red;
      case 'manutencao':
        return Colors.orange;
      default:
        return Colors.green;
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

  IconData _iconeTipo(String tipo) {
    return tipo == 'Vaso' ? Icons.local_florist : Icons.grid_on;
  }

  IconData _iconeMedida(String tipo) {
    return tipo == 'Vaso' ? Icons.water_drop : Icons.aspect_ratio;
  }

  String _labelMedida(Map<String, dynamic> dados) {
    final tipo = (dados['tipo'] ?? 'Canteiro').toString();
    if (tipo == 'Vaso') {
      final vol = _num(dados['volume_l']).toDouble();
      return '${vol.toStringAsFixed(1)} L';
    } else {
      final area = _num(dados['area_m2']).toDouble();
      return '${area.toStringAsFixed(2)} m²';
    }
  }

  String _labelFinalidade(Map<String, dynamic> dados) {
    final f = (dados['finalidade'] ?? 'consumo').toString();
    if (f == 'comercio') return 'Comércio';
    return 'Consumo';
  }

  Color _corFinalidade(String f) {
    return f == 'comercio' ? Colors.blue : Colors.grey;
  }

  String _tituloFiltroAtivo() {
    switch (_filtroAtivo) {
      case 'arquivados':
        return 'Arquivados';
      case 'todos':
        return 'Todos';
      default:
        return 'Ativos';
    }
  }

  String _tituloFiltroStatus() {
    switch (_filtroStatus) {
      case 'livre':
        return 'Livre';
      case 'ocupado':
        return 'Ocupado';
      case 'manutencao':
        return 'Manutenção';
      default:
        return 'Status: Todos';
    }
  }

  String _tituloOrdem() {
    switch (_ordem) {
      case 'nome_az':
        return 'Nome A→Z';
      case 'nome_za':
        return 'Nome Z→A';
      case 'medida_maior':
        return 'Maior medida';
      case 'medida_menor':
        return 'Menor medida';
      default:
        return 'Mais recentes';
    }
  }

  // =========================
  // Query
  // =========================

  Query<Map<String, dynamic>> _buildQuery() {
    final user = _user;

    Query<Map<String, dynamic>> q =
        FirebaseFirestore.instance.collection('canteiros');

    // Segurança: sem user, não consulta nada real
    q = q.where('uid_usuario', isEqualTo: user?.uid ?? '__sem_user__');

    if (_filtroAtivo == 'ativos') {
      q = q.where('ativo', isEqualTo: true);
    } else if (_filtroAtivo == 'arquivados') {
      q = q.where('ativo', isEqualTo: false);
    }

    if (_filtroStatus != 'todos') {
      q = q.where('status', isEqualTo: _filtroStatus);
    }

    // Busca server-side por prefixo (nome_lower)
    if (_busca.trim().isNotEmpty) {
      final term = _norm(_busca);
      return q.orderBy('nome_lower').startAt([term]).endAt(['$term\uf8ff']);
    }

    return q.orderBy('data_criacao', descending: true);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortLocal(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final list = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);

    int cmpNum(num a, num b) => a.compareTo(b);

    num medidaOf(Map<String, dynamic> d) {
      final tipo = (d['tipo'] ?? 'Canteiro').toString();
      if (tipo == 'Vaso') return _num(d['volume_l']);
      return _num(d['area_m2']);
    }

    String nomeLowerOf(Map<String, dynamic> d) =>
        (d['nome_lower'] ?? (d['nome'] ?? '')).toString().toLowerCase();

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
      default:
        break;
    }

    return list;
  }

  // =========================
  // MIGRAÇÃO LEVE (DEV)
  // =========================

  Future<void> _migrarCamposBasicosDev() async {
    final user = _user;
    if (user == null) return;

    final db = FirebaseFirestore.instance;
    final q = await db
        .collection('canteiros')
        .where('uid_usuario', isEqualTo: user.uid)
        .get();

    int count = 0;
    final batch = db.batch();

    for (final doc in q.docs) {
      final d = doc.data();

      final nome = (d['nome'] ?? '').toString().trim();
      final nomeLower = (d['nome_lower'] ?? '').toString().trim();
      final finalidade = (d['finalidade'] ?? '').toString().trim();
      final status = (d['status'] ?? '').toString().trim();

      final updates = <String, dynamic>{};

      if (nome.isNotEmpty && nomeLower.isEmpty) {
        updates['nome_lower'] = nome.toLowerCase();
      }

      if (finalidade.isEmpty) {
        updates['finalidade'] = 'consumo';
      }

      if (status.isEmpty) {
        updates['status'] = 'livre';
      }

      // ✅ Compat com planejamento: cria largura_m/comprimento_m se tiver largura/comprimento
      final larg = _num(d['largura']).toDouble();
      final comp = _num(d['comprimento']).toDouble();
      if ((d['largura_m'] == null || _num(d['largura_m']) == 0) && larg > 0) {
        updates['largura_m'] = larg;
      }
      if ((d['comprimento_m'] == null || _num(d['comprimento_m']) == 0) &&
          comp > 0) {
        updates['comprimento_m'] = comp;
      }

      if (updates.isNotEmpty) {
        updates['data_atualizacao'] = FieldValue.serverTimestamp();
        batch.update(doc.reference, updates);
        count++;
      }
    }

    if (count > 0) {
      await batch.commit();
      _snack('Migração DEV OK: $count documentos ajustados.',
          cor: Colors.blueGrey);
    } else {
      _snack('Nada pra migrar. Tá tudo certo já. ✅', cor: Colors.green);
    }
  }

  // =========================
  // CRUD
  // =========================

  Future<void> _criarOuEditarLocal(
      {DocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final user = _user;
    if (user == null) {
      _snack('Você precisa estar logado.', cor: Colors.red);
      return;
    }

    final bool editando = doc != null;
    final dados = doc?.data() ?? <String, dynamic>{};
    final parentContext = context;

    final nomeController =
        TextEditingController(text: (dados['nome'] ?? '').toString());

    final compController = TextEditingController(
      text: _num(dados['comprimento']).toDouble() == 0
          ? ''
          : _num(dados['comprimento']).toString().replaceAll('.', ','),
    );

    final largController = TextEditingController(
      text: _num(dados['largura']).toDouble() == 0
          ? ''
          : _num(dados['largura']).toString().replaceAll('.', ','),
    );

    final volumeController = TextEditingController(
      text: _num(dados['volume_l']).toDouble() == 0
          ? ''
          : _num(dados['volume_l']).toString().replaceAll('.', ','),
    );

    String tipoLocal = (dados['tipo'] ?? 'Canteiro').toString();
    if (tipoLocal != 'Canteiro' && tipoLocal != 'Vaso') tipoLocal = 'Canteiro';

    String finalidade = (dados['finalidade'] ?? 'consumo').toString().trim();
    if (finalidade != 'consumo' && finalidade != 'comercio')
      finalidade = 'consumo';

    String status = (dados['status'] ?? 'livre').toString().trim();
    if (status != 'livre' && status != 'ocupado' && status != 'manutencao')
      status = 'livre';

    bool ativo = (dados['ativo'] ?? true) == true;

    final formKey = GlobalKey<FormState>();
    bool salvando = false;

    try {
      await showModalBottomSheet(
        context: parentContext,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => StatefulBuilder(
          builder: (context, setModalState) {
            void closeSheet() {
              if (Navigator.of(sheetCtx).canPop()) Navigator.of(sheetCtx).pop();
            }

            Future<void> salvar() async {
              FocusScope.of(context).unfocus();
              if (salvando) return;

              final ok = formKey.currentState?.validate() ?? false;
              if (!ok) return;

              setModalState(() => salvando = true);

              try {
                final nome = nomeController.text.trim();

                double areaM2 = 0;
                double comp = 0;
                double larg = 0;
                double volumeL = 0;

                if (tipoLocal == 'Canteiro') {
                  comp = _doubleFromController(compController);
                  larg = _doubleFromController(largController);
                  areaM2 = comp * larg;
                } else {
                  volumeL = _doubleFromController(volumeController);
                  areaM2 = 0;
                }

                final payload = <String, dynamic>{
                  'uid_usuario': user.uid,
                  'nome': nome,
                  'nome_lower': nome.toLowerCase(),

                  'tipo': tipoLocal,

                  // mantém os campos antigos
                  'comprimento': comp,
                  'largura': larg,

                  // ✅ compat com planejamento
                  'comprimento_m': comp,
                  'largura_m': larg,

                  'area_m2': areaM2,
                  'volume_l': (tipoLocal == 'Vaso') ? volumeL : 0,

                  'ativo': ativo,
                  'status': status,
                  'finalidade': finalidade,

                  'data_atualizacao': FieldValue.serverTimestamp(),
                };

                if (!editando) {
                  payload['data_criacao'] = FieldValue.serverTimestamp();
                  payload['ativo'] = true;
                  payload['status'] = 'livre';

                  await FirebaseFirestore.instance
                      .collection('canteiros')
                      .add(payload);
                } else {
                  await FirebaseFirestore.instance
                      .collection('canteiros')
                      .doc(doc!.id)
                      .update(payload);
                }

                closeSheet();

                _runNextFrame(() {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Text(
                          editando ? 'Local atualizado.' : 'Local cadastrado!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                });
              } catch (e) {
                _runNextFrame(() {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao salvar: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                });
              } finally {
                if (sheetCtx.mounted) setModalState(() => salvando = false);
              }
            }

            Widget chipFinalidade(String key, String label, IconData icon) {
              final selected = finalidade == key;
              final color = key == 'comercio' ? Colors.blue : Colors.grey;
              return Expanded(
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon,
                          size: 16, color: selected ? Colors.white : color),
                      const SizedBox(width: 8),
                      Text(label),
                    ],
                  ),
                  selected: selected,
                  onSelected: (_) => setModalState(() => finalidade = key),
                  selectedColor: color,
                  backgroundColor: Colors.grey.shade200,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }

            Widget chipStatus(
                String key, String label, IconData icon, Color cor) {
              final selected = status == key;
              return Expanded(
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon,
                          size: 16, color: selected ? Colors.white : cor),
                      const SizedBox(width: 8),
                      Text(label),
                    ],
                  ),
                  selected: selected,
                  onSelected: (_) => setModalState(() => status = key),
                  selectedColor: cor,
                  backgroundColor: Colors.grey.shade200,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }

            String previewMedida() {
              if (tipoLocal == 'Vaso') {
                final vol = _doubleFromController(volumeController);
                if (vol <= 0) return '—';
                return '${vol.toStringAsFixed(1)} L';
              } else {
                final c = _doubleFromController(compController);
                final l = _doubleFromController(largController);
                final a = c * l;
                if (a <= 0) return '—';
                return '${a.toStringAsFixed(2)} m²';
              }
            }

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 18,
                left: 20,
                right: 20,
              ),
              child: SafeArea(
                top: false,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(editando ? Icons.edit : Icons.add_circle_outline,
                              color: Colors.green, size: 28),
                          const SizedBox(width: 10),
                          Text(
                            editando ? 'Editar Local' : 'Novo Local de Cultivo',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                              onPressed: closeSheet,
                              icon: const Icon(Icons.close)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nomeController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Nome (Ex: Horta 1, Vaso da Varanda)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.label_outline),
                        ),
                        validator: (v) {
                          final txt = (v ?? '').trim();
                          if (txt.isEmpty) return 'Informe um nome.';
                          if (txt.length < 3) return 'Nome muito curto.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text('Finalidade do cultivo',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          chipFinalidade(
                              'consumo', 'Consumo', Icons.restaurant),
                          const SizedBox(width: 10),
                          chipFinalidade(
                              'comercio', 'Comércio', Icons.storefront),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        finalidade == 'comercio'
                            ? 'Ativa módulos de mercado/financeiro e receita.'
                            : 'Foco em consumo: sem obrigar preço de venda.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      const Text('Status do local',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          chipStatus('livre', 'Livre', Icons.check_circle,
                              Colors.green),
                          const SizedBox(width: 10),
                          chipStatus(
                              'ocupado', 'Ocupado', Icons.block, Colors.red),
                          const SizedBox(width: 10),
                          chipStatus('manutencao', 'Manut.', Icons.build,
                              Colors.orange),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Canteiro / Chão'),
                              selected: tipoLocal == 'Canteiro',
                              onSelected: (_) =>
                                  setModalState(() => tipoLocal = 'Canteiro'),
                              selectedColor: Colors.green.shade100,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Vaso / Recipiente'),
                              selected: tipoLocal == 'Vaso',
                              onSelected: (_) =>
                                  setModalState(() => tipoLocal = 'Vaso'),
                              selectedColor: Colors.green.shade100,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                                      RegExp(r'[0-9\.,]')),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Comp. (m)',
                                  suffixText: 'm',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) {
                                  final val = double.tryParse(
                                          (v ?? '').replaceAll(',', '.')) ??
                                      0;
                                  if (val <= 0) return 'Informe > 0';
                                  if (val > 1000) return 'Tá grande demais 😅';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: TextFormField(
                                controller: largController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9\.,]')),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Larg. (m)',
                                  suffixText: 'm',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) {
                                  final val = double.tryParse(
                                          (v ?? '').replaceAll(',', '.')) ??
                                      0;
                                  if (val <= 0) return 'Informe > 0';
                                  if (val > 1000) return 'Tá grande demais 😅';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Área calculada: ${previewMedida()} (Comp. × Larg.)',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ] else ...[
                        TextFormField(
                          controller: volumeController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9\.,]')),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Volume do Vaso (Litros)',
                            suffixText: 'L',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.local_drink),
                            helperText: 'Ex: Baldes comuns têm ~12 L.',
                          ),
                          validator: (v) {
                            final val = double.tryParse(
                                    (v ?? '').replaceAll(',', '.')) ??
                                0;
                            if (val <= 0) return 'Informe > 0';
                            if (val > 5000) return 'Tá virando caixa d’água 😅';
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Volume informado: ${previewMedida()}',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (editando) ...[
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Ativo'),
                          subtitle: Text(ativo
                              ? 'Aparece nos Ativos.'
                              : 'Vai pros Arquivados.'),
                          value: ativo,
                          onChanged: (v) => setModalState(() => ativo = v),
                        ),
                        const SizedBox(height: 6),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: salvando ? null : salvar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(parentContext).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: salvando
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  editando
                                      ? 'SALVAR ALTERAÇÕES'
                                      : 'SALVAR LOCAL',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      if (kDebugMode) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                salvando ? null : _migrarCamposBasicosDev,
                            icon: const Icon(Icons.build),
                            label: const Text('Migrar campos básicos (DEV)'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    } finally {
      nomeController.dispose();
      compController.dispose();
      largController.dispose();
      volumeController.dispose();
    }
  }

  Future<void> _toggleAtivo(String id, bool ativoAtual) async {
    await FirebaseFirestore.instance.collection('canteiros').doc(id).update({
      'ativo': !ativoAtual,
      'data_atualizacao': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _toggleAtivoComUndo({
    required String id,
    required bool ativoAtual,
    required String nome,
  }) async {
    try {
      await _toggleAtivo(id, ativoAtual);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(ativoAtual ? '"$nome" arquivado.' : '"$nome" reativado.'),
          backgroundColor: Colors.blueGrey,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'DESFAZER',
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('canteiros')
                    .doc(id)
                    .update({
                  'ativo': ativoAtual,
                  'data_atualizacao': FieldValue.serverTimestamp(),
                });
              } catch (_) {
                _snack('Não deu pra desfazer. Verifique internet/regras.',
                    cor: Colors.red);
              }
            },
          ),
        ),
      );
    } catch (e) {
      _snack('Erro ao arquivar/reativar: $e', cor: Colors.red);
    }
  }

  Future<void> _excluirHard(String id) async {
    await FirebaseFirestore.instance.collection('canteiros').doc(id).delete();
  }

  Future<void> _confirmarExcluirHard(String id, String nome) async {
    if (!kDebugMode) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir de vez?'),
        content:
            Text('Isso apaga "$nome" permanentemente.\n\nSem choro depois. 😅'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _excluirHard(id);
      _snack('Excluído (hard delete).', cor: Colors.red);
    }
  }

  // =========================
  // UI
  // =========================

  Widget _chipsFiltroAtivo() {
    Widget chip(String key, String label, IconData icon) {
      final selected = _filtroAtivo == key;
      return ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16, color: selected ? Colors.white : Colors.grey[700]),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
        selected: selected,
        onSelected: (_) => setState(() => _filtroAtivo = key),
        selectedColor: Theme.of(context).colorScheme.primary,
        backgroundColor: Colors.grey[200],
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.grey[800],
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('ativos', 'Ativos', Icons.check_circle),
          const SizedBox(width: 8),
          chip('arquivados', 'Arquivados', Icons.archive),
          const SizedBox(width: 8),
          chip('todos', 'Todos', Icons.all_inbox),
        ],
      ),
    );
  }

  Widget _chipsFiltroStatus() {
    Widget chip(String key, String label, IconData icon, Color cor) {
      final selected = _filtroStatus == key;
      return ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : cor),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
        selected: selected,
        onSelected: (_) => setState(() => _filtroStatus = key),
        selectedColor: cor,
        backgroundColor: Colors.grey[200],
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.grey[800],
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('todos', 'Todos', Icons.tune, Colors.blueGrey),
          const SizedBox(width: 8),
          chip('livre', 'Livre', Icons.check_circle, Colors.green),
          const SizedBox(width: 8),
          chip('ocupado', 'Ocupado', Icons.block, Colors.red),
          const SizedBox(width: 8),
          chip('manutencao', 'Manut.', Icons.build, Colors.orange),
        ],
      ),
    );
  }

  Widget _buscaEOrdem() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _buscaCtrl,
            onChanged: (v) {
              // atualiza o termo com debounce, mas UI já atualiza pelo listener do controller
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () {
                if (!mounted) return;
                setState(() => _busca = v);
              });
            },
            decoration: InputDecoration(
              hintText: 'Buscar por nome...',
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
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 10),
        PopupMenuButton<String>(
          tooltip: 'Ordenar',
          onSelected: (v) => setState(() => _ordem = v),
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'recentes', child: Text('Mais recentes')),
            PopupMenuItem(value: 'nome_az', child: Text('Nome A→Z')),
            PopupMenuItem(value: 'nome_za', child: Text('Nome Z→A')),
            PopupMenuItem(value: 'medida_maior', child: Text('Maior medida')),
            PopupMenuItem(value: 'medida_menor', child: Text('Menor medida')),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort, size: 18),
                const SizedBox(width: 8),
                Text(_tituloOrdem(),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cardResumo(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int ativos = 0;
    int arquivados = 0;
    int livres = 0;
    int ocupados = 0;
    int manut = 0;

    double totalArea = 0;
    double totalVol = 0;

    for (final d in docs) {
      final data = d.data();
      final ativo = (data['ativo'] ?? true) == true;
      final status = (data['status'] ?? 'livre').toString();
      final tipo = (data['tipo'] ?? 'Canteiro').toString();

      if (ativo) {
        ativos++;
      } else {
        arquivados++;
      }

      if (status == 'ocupado') {
        ocupados++;
      } else if (status == 'manutencao') {
        manut++;
      } else {
        livres++;
      }

      if (tipo == 'Vaso') {
        totalVol += _num(data['volume_l']).toDouble();
      } else {
        totalArea += _num(data['area_m2']).toDouble();
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumo',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _miniPill(Icons.check_circle, 'Ativos', '$ativos', Colors.green),
              _miniPill(
                  Icons.archive, 'Arquivados', '$arquivados', Colors.blueGrey),
              _miniPill(Icons.spa, 'Área', '${totalArea.toStringAsFixed(2)} m²',
                  Colors.teal),
              _miniPill(Icons.water_drop, 'Volume',
                  '${totalVol.toStringAsFixed(1)} L', Colors.blue),
              _miniPill(Icons.check, 'Livre', '$livres', Colors.green),
              _miniPill(Icons.block, 'Ocupado', '$ocupados', Colors.red),
              _miniPill(Icons.build, 'Manut.', '$manut', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniPill(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text('$label: ',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          Text(
            value,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _buscaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Meus Locais',
            style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: user == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _criarOuEditarLocal(),
              backgroundColor: primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('NOVO LOCAL'),
            ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          children: [
            // ✅ bloco premium de filtros
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                children: [
                  _buscaEOrdem(),
                  const SizedBox(height: 12),
                  _chipsFiltroAtivo(),
                  const SizedBox(height: 10),
                  _chipsFiltroStatus(),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _buildQuery().snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (user == null) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Faça login para ver seus locais.'),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    final err = snapshot.error;

                    if (err is FirebaseException) {
                      if (err.code == 'failed-precondition') {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'Tá faltando índice no Firestore.\n\n'
                              'Abra o link do erro no console do Firebase e crie o índice.\n\n'
                              'Dica comum: (uid_usuario + ativo + status + data_criacao)\n'
                              'E pra busca: (uid_usuario + ativo + status + nome_lower)',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      if (err.code == 'permission-denied') {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'Sem permissão. Verifique regras do Firestore.\n'
                              'O usuário deve acessar apenas docs do próprio uid.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      if (err.code == 'unavailable') {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'Sem conexão agora.\n'
                              'Confira internet e tente de novo.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                    }

                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Erro ao carregar.'),
                      ),
                    );
                  }

                  final rawDocs = snapshot.data?.docs ?? [];
                  final docs = _sortLocal(rawDocs);

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.spa_outlined,
                                size: 60, color: Colors.green.shade300),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Nada aqui com esses filtros.',
                            style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ativo: ${_tituloFiltroAtivo()} • ${_tituloFiltroStatus()}',
                            style: const TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _criarOuEditarLocal(),
                            icon: const Icon(Icons.add),
                            label: const Text('Cadastrar Local'),
                          ),
                          if (_busca.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: () {
                                _buscaCtrl.clear();
                                setState(() => _busca = '');
                              },
                              child: const Text('Limpar busca'),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async =>
                        Future.delayed(const Duration(milliseconds: 400)),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(0, 6, 0, 90),
                      itemCount: docs.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index == 0) return _cardResumo(docs);

                        final doc = docs[index - 1];
                        final dados = doc.data();
                        final id = doc.id;

                        final nome = (dados['nome'] ?? 'Sem Nome').toString();
                        final tipo = (dados['tipo'] ?? 'Canteiro').toString();
                        final bool ativo = (dados['ativo'] ?? true) == true;
                        final String status =
                            (dados['status'] ?? 'livre').toString();
                        final String finalidade =
                            (dados['finalidade'] ?? 'consumo').toString();
                        final corStatus = _getCorStatus(status);

                        return Dismissible(
                          key: ValueKey(id),
                          direction: DismissDirection.horizontal,
                          confirmDismiss: (dir) async {
                            if (dir == DismissDirection.startToEnd) {
                              await _toggleAtivoComUndo(
                                  id: id, ativoAtual: ativo, nome: nome);
                              return false;
                            } else if (dir == DismissDirection.endToStart) {
                              _runNextFrame(
                                  () async => _criarOuEditarLocal(doc: doc));
                              return false;
                            }
                            return false;
                          },
                          background: Container(
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Icon(ativo ? Icons.archive : Icons.unarchive,
                                    color: Colors.blueGrey),
                                const SizedBox(width: 10),
                                Text(
                                  ativo ? 'Arquivar' : 'Reativar',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey),
                                ),
                              ],
                            ),
                          ),
                          secondaryBackground: Container(
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.centerRight,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('Editar',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green)),
                                SizedBox(width: 10),
                                Icon(Icons.edit, color: Colors.green),
                              ],
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => TelaDetalhesCanteiro(
                                            canteiroId: id)),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: ativo
                                              ? corStatus.withOpacity(0.10)
                                              : Colors.grey.withOpacity(0.10),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          _iconeTipo(tipo),
                                          color:
                                              ativo ? corStatus : Colors.grey,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    nome,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: ativo
                                                          ? Colors.black87
                                                          : Colors.grey,
                                                      decoration: ativo
                                                          ? null
                                                          : TextDecoration
                                                              .lineThrough,
                                                    ),
                                                  ),
                                                ),
                                                _Tag(
                                                  text: ativo
                                                      ? _getTextoStatus(status)
                                                      : 'ARQUIVADO',
                                                  color: ativo
                                                      ? corStatus
                                                      : Colors.blueGrey,
                                                  muted: !ativo,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(_iconeMedida(tipo),
                                                    size: 14,
                                                    color: Colors.grey[600]),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _labelMedida(dados),
                                                  style: TextStyle(
                                                      color: Colors.grey[700],
                                                      fontSize: 13),
                                                ),
                                                const SizedBox(width: 10),
                                                _Tag(
                                                  text: _labelFinalidade(dados),
                                                  color: _corFinalidade(
                                                      finalidade),
                                                  muted: false,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      PopupMenuButton<String>(
                                        itemBuilder: (ctx) => [
                                          PopupMenuItem<String>(
                                            value: 'detalhes',
                                            onTap: () {
                                              _runNextFrame(() {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        TelaDetalhesCanteiro(
                                                            canteiroId: id),
                                                  ),
                                                );
                                              });
                                            },
                                            child: const Row(
                                              children: [
                                                Icon(Icons.open_in_new,
                                                    size: 18),
                                                SizedBox(width: 10),
                                                Text('Abrir detalhes'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem<String>(
                                            value: 'editar',
                                            onTap: () => _runNextFrame(() =>
                                                _criarOuEditarLocal(doc: doc)),
                                            child: const Row(
                                              children: [
                                                Icon(Icons.edit, size: 18),
                                                SizedBox(width: 10),
                                                Text('Editar'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem<String>(
                                            value: 'toggle_ativo',
                                            onTap: () =>
                                                _runNextFrame(() async {
                                              await _toggleAtivoComUndo(
                                                id: id,
                                                ativoAtual: ativo,
                                                nome: nome,
                                              );
                                            }),
                                            child: Row(
                                              children: [
                                                Icon(
                                                    ativo
                                                        ? Icons.archive
                                                        : Icons.unarchive,
                                                    size: 18),
                                                const SizedBox(width: 10),
                                                Text(ativo
                                                    ? 'Arquivar'
                                                    : 'Reativar'),
                                              ],
                                            ),
                                          ),
                                          if (kDebugMode)
                                            PopupMenuItem<String>(
                                              value: 'excluir_hard',
                                              onTap: () => _runNextFrame(() =>
                                                  _confirmarExcluirHard(
                                                      id, nome)),
                                              child: const Row(
                                                children: [
                                                  Icon(Icons.delete,
                                                      size: 18,
                                                      color: Colors.red),
                                                  SizedBox(width: 10),
                                                  Text('Excluir (DEV)',
                                                      style: TextStyle(
                                                          color: Colors.red)),
                                                ],
                                              ),
                                            ),
                                        ],
                                        icon: const Icon(Icons.more_vert,
                                            color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  final bool muted;

  const _Tag({required this.text, required this.color, required this.muted});

  @override
  Widget build(BuildContext context) {
    final bg = muted ? Colors.grey.shade300 : color.withOpacity(0.12);
    final border = muted ? Colors.grey.shade300 : color.withOpacity(0.25);
    final fg = muted ? Colors.white : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }
}
