import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'tela_detalhes_canteiro.dart';

class TelaCanteiros extends StatefulWidget {
  const TelaCanteiros({super.key});

  @override
  State<TelaCanteiros> createState() => _TelaCanteirosState();
}

class _TelaCanteirosState extends State<TelaCanteiros> {
  User? get _user => FirebaseAuth.instance.currentUser;

  /// ativos | arquivados | todos
  String _filtro = 'ativos';

  // =========================
  // Helpers seguros
  // =========================

  void _runNextFrame(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      fn();
    });
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
      return '${vol.toStringAsFixed(1)} Litros';
    } else {
      final area = _num(dados['area_m2']).toDouble();
      return '${area.toStringAsFixed(2)} m²';
    }
  }

  // =========================
  // Query
  // =========================

  Query<Map<String, dynamic>> _buildQuery() {
    final user = _user;

    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
      'canteiros',
    );

    // Segurança: sem user, não consulta nada real
    q = q.where('uid_usuario', isEqualTo: user?.uid ?? '__sem_user__');

    if (_filtro == 'ativos') {
      q = q.where('ativo', isEqualTo: true);
    } else if (_filtro == 'arquivados') {
      q = q.where('ativo', isEqualTo: false);
    }

    // ⚠️ precisa de índice composto quando existe filtro 'ativo'
    return q.orderBy('data_criacao', descending: true);
  }

  // =========================
  // CRUD
  // =========================

  Future<void> _criarOuEditarLocal({
    DocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final user = _user;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você precisa estar logado.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bool editando = doc != null;
    final dados = doc?.data() ?? <String, dynamic>{};
    final parentContext = context;

    final nomeController = TextEditingController(
      text: (dados['nome'] ?? '').toString(),
    );

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
              // ✅ fecha o BOTTOM SHEET pelo contexto dele (sem risco de pop errado)
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
                  areaM2 = 0; // ✅ profissional: area_m2 é área, não volume
                }

                final payload = <String, dynamic>{
                  'uid_usuario': user.uid,
                  'nome': nome,
                  'tipo': tipoLocal,
                  'comprimento': comp,
                  'largura': larg,
                  'area_m2': areaM2,
                  'volume_l': (tipoLocal == 'Vaso') ? volumeL : 0,
                  'ativo': (dados['ativo'] ?? true) == true,
                  'status': (dados['status'] ?? 'livre').toString(),
                  'data_atualizacao': FieldValue.serverTimestamp(),
                };

                if (!editando) {
                  payload['data_criacao'] = FieldValue.serverTimestamp();
                  payload['status'] = 'livre';
                  payload['ativo'] = true;
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
                  if (!mounted) return;
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        editando ? 'Local atualizado.' : 'Local cadastrado!',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                });
              } catch (e) {
                _runNextFrame(() {
                  if (!mounted) return;
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao salvar: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                });
              } finally {
                if (sheetCtx.mounted) setModalState(() => salvando = false);
              }
            }

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                          Icon(
                            editando ? Icons.edit : Icons.add_circle_outline,
                            color: Colors.green,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            editando ? 'Editar Local' : 'Novo Local de Cultivo',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: closeSheet,
                            icon: const Icon(Icons.close),
                          ),
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
                      const SizedBox(height: 15),
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
                      const SizedBox(height: 15),
                      if (tipoLocal == 'Canteiro') ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: compController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9\.,]'),
                                  ),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Comp. (m)',
                                  suffixText: 'm',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) {
                                  final val =
                                      double.tryParse(
                                        (v ?? '').replaceAll(',', '.'),
                                      ) ??
                                      0;
                                  if (val <= 0) return 'Informe > 0';
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
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9\.,]'),
                                  ),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Larg. (m)',
                                  suffixText: 'm',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) {
                                  final val =
                                      double.tryParse(
                                        (v ?? '').replaceAll(',', '.'),
                                      ) ??
                                      0;
                                  if (val <= 0) return 'Informe > 0';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Área será calculada automaticamente (Comp. × Larg.).',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ] else ...[
                        TextFormField(
                          controller: volumeController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9\.,]'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Volume do Vaso (Litros)',
                            suffixText: 'L',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.local_drink),
                            helperText: 'Ex: Baldes comuns têm ~12 Litros.',
                          ),
                          validator: (v) {
                            final val =
                                double.tryParse(
                                  (v ?? '').replaceAll(',', '.'),
                                ) ??
                                0;
                            if (val <= 0) return 'Informe > 0';
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: salvando ? null : salvar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              parentContext,
                            ).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
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

  Future<void> _excluirHard(String id) async {
    await FirebaseFirestore.instance.collection('canteiros').doc(id).delete();
  }

  Future<void> _confirmarExcluirHard(String id, String nome) async {
    if (!kDebugMode) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir de vez?'),
        content: Text(
          'Isso apaga "$nome" permanentemente.\n\nSem choro depois. 😅',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _excluirHard(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Excluído (hard delete).'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _chipsFiltro() {
    Widget chip(String key, String label, IconData icon) {
      final selected = _filtro == key;
      return ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
        selected: selected,
        onSelected: (_) => setState(() => _filtro = key),
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

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Meus Locais',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _criarOuEditarLocal(),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('NOVO LOCAL'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          children: [
            _chipsFiltro(),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _buildQuery().snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    final err = snapshot.error;
                    if (err is FirebaseException &&
                        err.code == 'failed-precondition') {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'Faltando índice no Firestore para essa consulta.\n'
                            'Crie o índice composto (uid_usuario + ativo + data_criacao) e reinicie o app.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Erro ao carregar.'),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (user == null) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Faça login para ver seus locais.'),
                      ),
                    );
                  }

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
                            child: Icon(
                              Icons.spa_outlined,
                              size: 60,
                              color: Colors.green.shade300,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _filtro == 'arquivados'
                                ? 'Nenhum local arquivado.'
                                : 'Sua horta está vazia.',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _filtro == 'arquivados'
                                ? 'Arquive um local pra ele aparecer aqui.'
                                : 'Adicione seu primeiro vaso ou canteiro.',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _criarOuEditarLocal(),
                            icon: const Icon(Icons.add),
                            label: const Text('Cadastrar Local'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(0, 6, 0, 90),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final dados = doc.data();
                      final id = doc.id;

                      final nome = (dados['nome'] ?? 'Sem Nome').toString();
                      final tipo = (dados['tipo'] ?? 'Canteiro').toString();
                      final bool ativo = (dados['ativo'] ?? true) == true;
                      final String status = (dados['status'] ?? 'livre')
                          .toString();

                      final corStatus = _getCorStatus(status);

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    TelaDetalhesCanteiro(canteiroId: id),
                              ),
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
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _iconeTipo(tipo),
                                    color: ativo ? corStatus : Colors.grey,
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
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
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
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: ativo
                                                  ? corStatus.withOpacity(0.10)
                                                  : Colors.grey.shade300,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: ativo
                                                  ? Border.all(
                                                      color: corStatus
                                                          .withOpacity(0.25),
                                                    )
                                                  : null,
                                            ),
                                            child: Text(
                                              ativo
                                                  ? _getTextoStatus(status)
                                                  : 'ARQUIVADO',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: ativo
                                                    ? corStatus
                                                    : Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            _iconeMedida(tipo),
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _labelMedida(dados),
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 13,
                                            ),
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
                                                    canteiroId: id,
                                                  ),
                                            ),
                                          );
                                        });
                                      },
                                      child: const Row(
                                        children: [
                                          Icon(Icons.open_in_new, size: 18),
                                          SizedBox(width: 10),
                                          Text('Abrir detalhes'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'editar',
                                      onTap: () {
                                        _runNextFrame(() async {
                                          await _criarOuEditarLocal(doc: doc);
                                        });
                                      },
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
                                      onTap: () {
                                        _runNextFrame(() async {
                                          await _toggleAtivo(id, ativo);
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                ativo
                                                    ? 'Arquivado.'
                                                    : 'Reativado.',
                                              ),
                                              backgroundColor: Colors.blueGrey,
                                            ),
                                          );
                                        });
                                      },
                                      child: Row(
                                        children: [
                                          Icon(
                                            ativo
                                                ? Icons.archive
                                                : Icons.unarchive,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(ativo ? 'Arquivar' : 'Reativar'),
                                        ],
                                      ),
                                    ),
                                    if (kDebugMode)
                                      PopupMenuItem<String>(
                                        value: 'excluir_hard',
                                        onTap: () {
                                          _runNextFrame(() async {
                                            await _confirmarExcluirHard(
                                              id,
                                              nome,
                                            );
                                          });
                                        },
                                        child: const Row(
                                          children: [
                                            Icon(
                                              Icons.delete,
                                              size: 18,
                                              color: Colors.red,
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              'Excluir (DEV)',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: Colors.grey,
                                  ),
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
      ),
    );
  }
}
