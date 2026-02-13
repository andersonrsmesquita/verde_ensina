import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:verde_ensina/core/ui/app_ui.dart';


class TelaDiarioManejo extends StatefulWidget {
  const TelaDiarioManejo({super.key});

  @override
  State<TelaDiarioManejo> createState() => _TelaDiarioManejoState();
}

class _TelaDiarioManejoState extends State<TelaDiarioManejo> {
  String? _canteiroIdSelecionado;

  // ---------------------------
  // Helpers (robustos)
  // ---------------------------
  double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) {
      final d = v.toDouble();
      if (d.isNaN || d.isInfinite) return 0.0;
      return d;
    }
    final s = v.toString().replaceAll(',', '.').trim();
    final d = double.tryParse(s) ?? 0.0;
    if (d.isNaN || d.isInfinite) return 0.0;
    return d;
  }

  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) {
      if (v.isNaN || v.isInfinite) return 0;
      return v.round();
    }
    if (v is num) return v.round();
    return int.tryParse(v.toString().trim()) ?? 0;
  }

  String _asString(dynamic v, {String fallback = ''}) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? fallback : s;
  }

  String _formatData(Timestamp? ts) {
    if (ts == null) return '-';
    final d = ts.toDate();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yy $hh:$mi';
  }

  // ---------------------------
  // Sanitizador Firestore (anti “abort()”)
  // ---------------------------
  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> map) {
    final val = _sanitize(map, r'$');
    return (val as Map).cast<String, dynamic>();
  }

  dynamic _sanitize(dynamic value, String path) {
    if (value == null) return null;

    if (value is String || value is bool || value is int) return value;

    if (value is double) {
      if (value.isNaN || value.isInfinite) {
        throw ArgumentError(
            'Firestore: double inválido em $path (NaN/Infinity).');
      }
      return value;
    }

    if (value is num) {
      final d = value.toDouble();
      if (d.isNaN || d.isInfinite) {
        throw ArgumentError('Firestore: num inválido em $path (NaN/Infinity).');
      }
      return d;
    }

    if (value is Timestamp ||
        value is GeoPoint ||
        value is FieldValue ||
        value is DocumentReference) {
      return value;
    }

    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is Enum) return value.name;

    if (value is List) {
      return value.asMap().entries.map((e) {
        return _sanitize(e.value, '$path[${e.key}]');
      }).toList();
    }

    if (value is Map) {
      final out = <String, dynamic>{};
      for (final entry in value.entries) {
        final k = entry.key;
        if (k is! String) {
          throw ArgumentError(
            'Firestore: chave não-String em $path -> "$k" (${k.runtimeType})',
          );
        }
        out[k] = _sanitize(entry.value, '$path.$k');
      }
      return out;
    }

    throw UnsupportedError(
      'Firestore: tipo NÃO suportado em $path -> ${value.runtimeType}. Converta antes de salvar.',
    );
  }

  // ---------------------------
  // Queries
  // ---------------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> _watchCanteirosDoUsuario(
      String uid) {
    return FirebaseFirestore.instance
        .collection('canteiros')
        .where('uid_usuario', isEqualTo: uid)
        .where('ativo', isEqualTo: true)
        .orderBy('data_criacao', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _watchHistorico(String uid,
      {String? canteiroId}) {
    var q = FirebaseFirestore.instance
        .collection('historico_manejo')
        .where('uid_usuario', isEqualTo: uid);

    if (canteiroId != null && canteiroId.trim().isNotEmpty) {
      q = q.where('canteiro_id', isEqualTo: canteiroId.trim());
    }

    // Se você tiver doc antigo sem campo "data", isso pode dar ruim no orderBy.
    // Como nossos inserts já colocam, tá safe.
    return q.orderBy('data', descending: true).limit(200).snapshots();
  }

  // ---------------------------
  // Actions
  // ---------------------------
  Future<void> _abrirCadastroManejo(Map<String, String> canteirosMap) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppMessenger.error('Você precisa estar logado.');
      return;
    }

    String? canteiroId = _canteiroIdSelecionado;
    String tipo = 'Irrigação';
    final ctrlProduto = TextEditingController();
    final ctrlDetalhes = TextEditingController();
    final ctrlQtd = TextEditingController(text: '0');
    DateTime? colheitaPrevista;
    bool concluido = false;

    bool salvando = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModal) {
            final bottom = MediaQuery.of(context).viewInsets.bottom;

            Future<void> salvar() async {
              if (salvando) return;

              if (canteiroId == null || canteiroId!.trim().isEmpty) {
                AppMessenger.error('Selecione um canteiro.');
                return;
              }

              final produto = ctrlProduto.text.trim();
              final detalhes = ctrlDetalhes.text.trim();
              final quantidadeG = _asInt(ctrlQtd.text);

              if (produto.isEmpty) {
                AppMessenger.error('Informe o produto/cultura.');
                return;
              }

              setModal(() => salvando = true);

              try {
                final docRef = FirebaseFirestore.instance
                    .collection('historico_manejo')
                    .doc();

                final payload = <String, dynamic>{
                  'canteiro_id': canteiroId,
                  'canteiro_nome':
                      canteirosMap[canteiroId] ?? '', // ajuda MUITO na UI
                  'uid_usuario': user.uid,
                  'tipo_manejo': tipo,
                  'produto': produto,
                  'detalhes': detalhes,
                  'origem': 'manual',
                  'data': Timestamp.fromDate(
                      DateTime.now()), // evita null em orderBy
                  'quantidade_g': quantidadeG,
                  'concluido': concluido,
                  'data_colheita_prevista': colheitaPrevista == null
                      ? null
                      : Timestamp.fromDate(colheitaPrevista!),
                  'data_criacao': FieldValue.serverTimestamp(),
                  'data_atualizacao': FieldValue.serverTimestamp(),
                  'ativo': true,
                };

                await docRef.set(_sanitizeMap(payload));

                if (!mounted) return;

                Navigator.pop(context);

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  AppMessenger.success('Manejo salvo ✅');
                });
              } catch (e) {
                AppMessenger.error('Erro ao salvar manejo: $e');
              } finally {
                setModal(() => salvando = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Row(
                          children: [
                            Icon(Icons.playlist_add_check_circle_outlined),
                            SizedBox(width: 10),
                            Text(
                              'Registrar Manejo',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Canteiro
                        DropdownButtonFormField<String>(
                          value: canteiroId,
                          items: canteirosMap.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              )
                              .toList(),
                          onChanged: salvando
                              ? null
                              : (v) => setModal(() => canteiroId = v),
                          decoration: InputDecoration(
                            labelText: 'Canteiro',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Tipo
                        DropdownButtonFormField<String>(
                          value: tipo,
                          items: const [
                            'Irrigação',
                            'Plantio',
                            'Adubação',
                            'Poda',
                            'Pulverização',
                            'Pragas/Doenças',
                            'Colheita',
                            'Observação',
                          ]
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t),
                                ),
                              )
                              .toList(),
                          onChanged: salvando
                              ? null
                              : (v) => setModal(() => tipo = v ?? tipo),
                          decoration: InputDecoration(
                            labelText: 'Tipo de manejo',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Produto
                        TextFormField(
                          controller: ctrlProduto,
                          enabled: !salvando,
                          decoration: InputDecoration(
                            labelText: 'Produto/Cultura',
                            hintText: 'Ex: Alface, Tomate, Couve...',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Quantidade (g)
                        TextFormField(
                          controller: ctrlQtd,
                          enabled: !salvando,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Quantidade (g) (opcional)',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Detalhes
                        TextFormField(
                          controller: ctrlDetalhes,
                          enabled: !salvando,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Detalhes',
                            hintText:
                                'Ex: 2 regas no dia, adubo X, sintomas Y...',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Colheita prevista
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: salvando
                                    ? null
                                    : () async {
                                        final now = DateTime.now();
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: colheitaPrevista ??
                                              now.add(const Duration(days: 30)),
                                          firstDate: now.subtract(
                                              const Duration(days: 365)),
                                          lastDate: now
                                              .add(const Duration(days: 3650)),
                                        );
                                        if (picked != null) {
                                          setModal(
                                              () => colheitaPrevista = picked);
                                        }
                                      },
                                icon: const Icon(Icons.event),
                                label: Text(
                                  colheitaPrevista == null
                                      ? 'Colheita prevista (opcional)'
                                      : 'Colheita: ${colheitaPrevista!.day.toString().padLeft(2, '0')}/${colheitaPrevista!.month.toString().padLeft(2, '0')}/${colheitaPrevista!.year}',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              tooltip: 'Limpar',
                              onPressed: salvando
                                  ? null
                                  : () =>
                                      setModal(() => colheitaPrevista = null),
                              icon: const Icon(Icons.clear),
                            ),
                          ],
                        ),

                        // Concluído
                        SwitchListTile(
                          value: concluido,
                          onChanged: salvando
                              ? null
                              : (v) => setModal(() => concluido = v),
                          title: const Text('Marcar como concluído'),
                        ),

                        const SizedBox(height: 8),

                        SizedBox(
                          height: 52,
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: salvando ? null : salvar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 3,
                            ),
                            icon: salvando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.save),
                            label: Text(
                              salvando ? 'Salvando...' : 'SALVAR MANEJO',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleConcluido(String docId, bool atual) async {
    try {
      await FirebaseFirestore.instance
          .collection('historico_manejo')
          .doc(docId)
          .update(
            _sanitizeMap(<String, dynamic>{
              'concluido': !atual,
              'data_atualizacao': FieldValue.serverTimestamp(),
            }),
          );
      AppMessenger.success(!atual ? 'Marcado como concluído ✅' : 'Reaberto 🔁');
    } catch (e) {
      AppMessenger.error('Erro ao atualizar: $e');
    }
  }

  // ---------------------------
  // UI
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final primary = Theme.of(context).colorScheme.primary;

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('Diário de Manejo',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(22),
            child: Text(
              'Você está desconectado.\nFaça login para registrar o manejo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Diário de Manejo',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _watchCanteirosDoUsuario(user.uid),
        builder: (context, snapCanteiros) {
          final docsCanteiros = snapCanteiros.data?.docs ?? [];
          final canteirosMap = <String, String>{
            for (final d in docsCanteiros)
              d.id: _asString(d.data()['nome'], fallback: 'Canteiro'),
          };

          // seleciona o primeiro automaticamente (se nada selecionado)
          if (_canteiroIdSelecionado == null && canteirosMap.isNotEmpty) {
            _canteiroIdSelecionado = canteirosMap.keys.first;
          }

          return Column(
            children: [
              // Filtro topo
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _canteiroIdSelecionado,
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Todos os canteiros'),
                            ),
                            ...canteirosMap.entries.map(
                              (e) => DropdownMenuItem<String>(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _canteiroIdSelecionado = v),
                          decoration: InputDecoration(
                            labelText: 'Filtrar por canteiro',
                            filled: true,
                            fillColor: const Color(0xFFF7F9FC),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        tooltip: 'Registrar Manejo',
                        onPressed: canteirosMap.isEmpty
                            ? null
                            : () => _abrirCadastroManejo(canteirosMap),
                        icon: const Icon(Icons.add_circle),
                        color: Colors.green.shade700,
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _watchHistorico(
                    user.uid,
                    canteiroId: _canteiroIdSelecionado,
                  ),
                  builder: (context, snapHist) {
                    if (snapHist.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final items = snapHist.data?.docs ?? [];

                    if (items.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.history,
                                  size: 46, color: Colors.grey.shade500),
                              const SizedBox(height: 10),
                              const Text(
                                'Nada registrado ainda.',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Toque no + para registrar o primeiro manejo.',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final doc = items[i];
                        final data = doc.data();

                        final tipo =
                            _asString(data['tipo_manejo'], fallback: 'Manejo');
                        final produto =
                            _asString(data['produto'], fallback: '-');
                        final detalhes =
                            _asString(data['detalhes'], fallback: '');
                        final concluido = (data['concluido'] == true);

                        final canteiroNome = _asString(
                          data['canteiro_nome'],
                          fallback:
                              canteirosMap[_asString(data['canteiro_id'])] ??
                                  'Canteiro',
                        );

                        final ts = data['data'] is Timestamp
                            ? data['data'] as Timestamp
                            : null;
                        final qtd = _asInt(data['quantidade_g']);
                        final colheita =
                            data['data_colheita_prevista'] is Timestamp
                                ? data['data_colheita_prevista'] as Timestamp
                                : null;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: concluido
                                          ? Colors.green.shade50
                                          : Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: concluido
                                            ? Colors.green.shade200
                                            : Colors.orange.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      concluido ? 'Concluído' : 'Pendente',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: concluido
                                            ? Colors.green.shade800
                                            : Colors.orange.shade800,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: concluido ? 'Reabrir' : 'Concluir',
                                    onPressed: () =>
                                        _toggleConcluido(doc.id, concluido),
                                    icon: Icon(concluido
                                        ? Icons.undo
                                        : Icons.check_circle),
                                    color: concluido
                                        ? Colors.blueGrey
                                        : Colors.green.shade700,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$tipo • $produto',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Canteiro: $canteiroNome',
                                style: TextStyle(
                                    color: Colors.grey.shade700, fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              if (detalhes.isNotEmpty) ...[
                                Text(detalhes),
                                const SizedBox(height: 10),
                              ],
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _MiniTag(
                                      icon: Icons.schedule,
                                      text: _formatData(ts)),
                                  _MiniTag(
                                    icon: Icons.scale,
                                    text: qtd > 0 ? '$qtd g' : '—',
                                  ),
                                  _MiniTag(
                                    icon: Icons.event,
                                    text: colheita == null
                                        ? 'Sem colheita'
                                        : 'Colheita: ${_formatData(colheita).split(' ').first}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _watchCanteirosDoUsuario(user.uid),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          final canteirosMap = <String, String>{
            for (final d in docs)
              d.id: _asString(d.data()['nome'], fallback: 'Canteiro'),
          };

          return FloatingActionButton.extended(
            onPressed: canteirosMap.isEmpty
                ? null
                : () => _abrirCadastroManejo(canteirosMap),
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Registrar'),
          );
        },
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniTag({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
