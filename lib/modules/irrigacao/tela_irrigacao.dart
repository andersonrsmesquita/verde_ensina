import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../core/session/session_scope.dart';
import '../../core/ui/app_ui.dart';
import '../../core/repositories/irrigacao_repository.dart';
import '../../core/services/weather_service.dart';

class TelaIrrigacao extends StatefulWidget {
  const TelaIrrigacao({super.key});

  @override
  State<TelaIrrigacao> createState() => _TelaIrrigacaoState();
}

class _TelaIrrigacaoState extends State<TelaIrrigacao> {
  IrrigacaoRepository? _repo;
  final _weatherService = WeatherService();
  Future<WeatherData>? _weatherFuture;

  // Cache do custo para não buscar toda vez que abre o modal
  double _custoAguaCache = 6.0;

  @override
  void initState() {
    super.initState();
    // ✅ CORREÇÃO CRÍTICA: Inicialização movida para cá.
    // O SessionScope precisa de um post-frame callback no initState ou usar didChangeDependencies com flag.
    // Como session pode mudar, vamos usar didChangeDependencies mas com proteção.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Garante que só inicializa uma vez para evitar o loop
    if (_repo == null) {
      final session = SessionScope.of(context).session;
      if (session != null) {
        _repo = IrrigacaoRepository(session.tenantId);
        _weatherFuture = _weatherService.getSmartWeather();
        _carregarCusto();
      }
    }
  }

  Future<void> _carregarCusto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _repo != null) {
      final c = await _repo!.getCustoAguaUsuario(user.uid);
      if (c > 0) {
        if (mounted) setState(() => _custoAguaCache = c);
      }
    }
  }

  void _abrirRegistro() {
    if (_repo == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _SheetNovaRega(repo: _repo!, custoAguaM3: _custoAguaCache),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_repo == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Manejo Hídrico',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSmartPanel(cs),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _abrirRegistro,
                icon: const Icon(Icons.water_drop, color: Colors.white),
                label: const Text('REGISTRAR IRRIGAÇÃO'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(child: _buildHistoryList()),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _repo!.watchHistorico(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Erro: ${snap.error}'));
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        final docs = snap.data!.docs;
        if (docs.isEmpty) return const _EmptyState();

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) => _RegaCard(data: docs[i].data()),
        );
      },
    );
  }

  Widget _buildSmartPanel(ColorScheme cs) {
    return FutureBuilder<WeatherData>(
      future: _weatherFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 120,
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20)),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final w = snapshot.data!;
        final isAlert = w.isRaining || w.humidity > 85;
        final bg = isAlert
            ? [Colors.blueGrey.shade700, Colors.blueGrey.shade500]
            : [Colors.blue.shade800, Colors.blue.shade600];

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: bg,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: bg[0].withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 5))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w.city,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        Text('${w.temp.toStringAsFixed(0)}°C',
                            style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ]),
                  Icon(w.isRaining ? Icons.thunderstorm : Icons.wb_sunny,
                      size: 40, color: Colors.white),
                ],
              ),
              const Divider(color: Colors.white24),
              Text(w.recommendation,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
        );
      },
    );
  }
}

class _RegaCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RegaCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final date = (data['data'] as Timestamp?)?.toDate() ?? DateTime.now();
    final custo = double.tryParse(data['custo_estimado'].toString()) ?? 0.0;
    final vol = double.tryParse(data['volume_l'].toString()) ?? 0.0;
    final local = data['canteiro_nome'] ?? 'Lote';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            child: const Icon(Icons.water_drop, color: Colors.blue)),
        title: Text(local,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            "${data['metodo']} • ${DateFormat('dd/MM HH:mm').format(date)}"),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("${vol.toStringAsFixed(0)} L",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.blue)),
            Text("R\$ ${custo.toStringAsFixed(2)}",
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text("Sem registros de rega."));
}

// ============================================================================
// SOLUÇÃO DEFINITIVA DO MODAL (SUBSTITUA A CLASSE _SheetNovaRega INTEIRA)
// ============================================================================
class _SheetNovaRega extends StatefulWidget {
  final IrrigacaoRepository repo;
  final double custoAguaM3;

  const _SheetNovaRega(
      {super.key, required this.repo, required this.custoAguaM3});

  @override
  State<_SheetNovaRega> createState() => _SheetNovaRegaState();
}

class _SheetNovaRegaState extends State<_SheetNovaRega> {
  // Lista de canteiros selecionados
  final List<Map<String, dynamic>> _selecionados = [];

  String _metodo = 'Gotejamento';
  int _tempo = 30;
  bool _salvando = false;
  final _obsCtrl = TextEditingController();

  // 1. Cálculos (Lógica de Negócio)
  double get _areaTotalSelecionada =>
      _selecionados.fold(0.0, (sum, c) => sum + (c['area'] as double));

  double get _volumeEstimadoLitros {
    // Se tiver área cadastrada, meta é 5L/m2. Se não, estima vazão por tempo.
    if (_areaTotalSelecionada > 0) return _areaTotalSelecionada * 5.0;
    // Vazão média: Manual (15L/min) | Gotejo (2L/min)
    double vazao = _metodo.contains('Manual') ? 15.0 : 2.0;
    return _tempo * vazao;
  }

  double get _custoEstimado =>
      _volumeEstimadoLitros * (widget.custoAguaM3 / 1000);

  // 2. Diálogo de Seleção (Checkbox)
  void _abrirSelecaoCanteiros(List<QueryDocumentSnapshot> docs) async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Selecione os Locais'),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final id = docs[i].id;
                    final nome = data['nome'] ?? 'Sem nome';
                    // Tratamento robusto para número
                    final area =
                        double.tryParse(data['area_m2'].toString()) ?? 0.0;

                    final isSelected = _selecionados.any((s) => s['id'] == id);

                    return CheckboxListTile(
                      activeColor: Colors.green,
                      title: Text(nome,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${area}m²'),
                      value: isSelected,
                      onChanged: (val) {
                        setStateDialog(() {
                          if (val == true) {
                            _selecionados
                                .add({'id': id, 'nome': nome, 'area': area});
                          } else {
                            _selecionados.removeWhere((s) => s['id'] == id);
                          }
                        });
                        // Força atualização da tela de baixo para recalcular custos
                        this.setState(() {});
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('PRONTO',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _salvar() async {
    if (_selecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('⚠️ Selecione onde você regou!'),
          backgroundColor: Colors.orange));
      return;
    }

    setState(() => _salvando = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await widget.repo.registrarRegaEmLote(
          uidUsuario: user.uid,
          canteirosSelecionados: _selecionados,
          tempoMinutos: _tempo,
          metodo: _metodo,
          custoAguaM3: widget.custoAguaM3,
          volumeTotalLitros: _volumeEstimadoLitros,
          obs: _obsCtrl.text,
        );
      }
      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Irrigação salva com sucesso!'),
          backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- TÍTULO ---
          const Text('Nova Rega',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // --- SELETOR DE CANTEIROS (Debug Visual) ---
          StreamBuilder<QuerySnapshot>(
            stream: widget.repo.watchCanteiros(),
            builder: (context, snap) {
              // ESTADO 1: CARREGANDO (Botão Cinza)
              if (snap.connectionState == ConnectionState.waiting) {
                return Container(
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text("Buscando canteiros..."),
                    ],
                  ),
                );
              }

              // ESTADO 2: ERRO (Botão Vermelho)
              if (snap.hasError) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red)),
                  child: Text("Erro ao carregar: ${snap.error}",
                      style: const TextStyle(color: Colors.red)),
                );
              }

              final docs = snap.data?.docs ?? [];

              // ESTADO 3: VAZIO (Botão Laranja)
              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange)),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange),
                      SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              "Nenhum canteiro ativo encontrado no banco de dados.",
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold))),
                    ],
                  ),
                );
              }

              // ESTADO 4: SUCESSO (Botão de Seleção Real)
              return InkWell(
                onTap: () => _abrirSelecaoCanteiros(docs),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.green, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.green.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ]),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('LOCAIS IRRIGADOS',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            _selecionados.isEmpty
                                ? 'Toque para selecionar'
                                : '${_selecionados.length} selecionados',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                          ),
                        ],
                      ),
                      const Icon(Icons.arrow_drop_down_circle,
                          color: Colors.green, size: 28),
                    ],
                  ),
                ),
              );
            },
          ),

          // Chips (Lista visual dos selecionados)
          if (_selecionados.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                children: _selecionados
                    .map((c) => Chip(
                          label: Text(c['nome']),
                          backgroundColor: Colors.green.shade50,
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () =>
                              setState(() => _selecionados.remove(c)),
                        ))
                    .toList(),
              ),
            ),

          const SizedBox(height: 20),

          // --- INPUTS (Método e Tempo) ---
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _metodo,
                  decoration: const InputDecoration(
                      labelText: 'Método', border: OutlineInputBorder()),
                  items: [
                    'Gotejamento',
                    'Aspersão',
                    'Manual (Mangueira)',
                    'Regador'
                  ]
                      .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setState(() => _metodo = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: TextFormField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                      labelText: 'Minutos',
                      border: OutlineInputBorder(),
                      suffixText: 'min'),
                  initialValue: _tempo.toString(),
                  onChanged: (v) =>
                      setState(() => _tempo = int.tryParse(v) ?? 0),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // --- RESUMO FINANCEIRO (Destaque) ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfo(
                    'ÁREA TOTAL',
                    '${_areaTotalSelecionada.toStringAsFixed(1)} m²',
                    Colors.blueGrey),
                _buildInfo(
                    'VOLUME',
                    '${_volumeEstimadoLitros.toStringAsFixed(0)} L',
                    Colors.blue),
                _buildInfo('CUSTO', 'R\$ ${_custoEstimado.toStringAsFixed(2)}',
                    Colors.green),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // --- BOTÃO CONFIRMAR ---
          SizedBox(
            height: 55,
            child: ElevatedButton(
              onPressed: _salvando ? null : _salvar,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 4),
              child: _salvando
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('CONFIRMAR REGISTRO',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }
}
