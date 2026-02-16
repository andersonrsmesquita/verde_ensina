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

  double _custoAguaCache = 6.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
      if (c > 0 && mounted) setState(() => _custoAguaCache = c);
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_repo == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Manejo Hídrico'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSmartPanel(theme),
          const SizedBox(height: AppTokens.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.md),
            child: AppButtons.elevatedIcon(
              onPressed: _abrirRegistro,
              icon: const Icon(Icons.water_drop),
              label: const Text('REGISTRAR IRRIGAÇÃO'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppTokens.md),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: AppTokens.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.md),
            child: Text(
              'Histórico Recente',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppTokens.sm),
          Expanded(child: _buildHistoryList(theme)),
        ],
      ),
    );
  }

  Widget _buildHistoryList(ThemeData theme) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _repo!.watchHistorico(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Erro: ${snap.error}'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) return const _EmptyState();

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
              AppTokens.md, 0, AppTokens.md, AppTokens.xl),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppTokens.sm),
          itemBuilder: (ctx, i) => _RegaCard(data: docs[i].data()),
        );
      },
    );
  }

  Widget _buildSmartPanel(ThemeData theme) {
    return FutureBuilder<WeatherData>(
      future: _weatherFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 120,
            margin: const EdgeInsets.all(AppTokens.md),
            decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final w = snapshot.data!;
        final isAlert = w.isRaining || w.humidity > 85;
        final gradientColors = isAlert
            ? [Colors.blueGrey.shade700, Colors.blueGrey.shade500]
            : [Colors.blue.shade800, Colors.blue.shade500];

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(AppTokens.md),
          padding: const EdgeInsets.all(AppTokens.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
            boxShadow: [
              BoxShadow(
                  color: gradientColors[0].withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.location_on,
                            color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(w.city,
                            style: theme.textTheme.labelMedium
                                ?.copyWith(color: Colors.white70)),
                      ]),
                      const SizedBox(height: 2),
                      Text('${w.temp.toStringAsFixed(0)}°C',
                          style: theme.textTheme.displayMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              height: 1.0)),
                    ],
                  ),
                  Icon(w.isRaining ? Icons.thunderstorm : Icons.wb_sunny,
                      size: 48, color: Colors.white.withOpacity(0.9)),
                ],
              ),
              const SizedBox(height: AppTokens.md),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: Row(
                  children: [
                    Icon(
                        isAlert
                            ? Icons.warning_amber
                            : Icons.water_drop_outlined,
                        color: Colors.white,
                        size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(w.recommendation,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final date = (data['data'] as Timestamp?)?.toDate() ?? DateTime.now();
    final custo = double.tryParse(data['custo_estimado'].toString()) ?? 0.0;
    final vol = double.tryParse(data['volume_l'].toString()) ?? 0.0;
    final local = data['canteiro_nome'] ?? 'Lote';
    final detalhe = data['canteiros_detalhe'];

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.md),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.water_drop, color: Colors.blue.shade700, size: 24),
            ),
            const SizedBox(width: AppTokens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(local,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (detalhe != null && detalhe != local)
                    Text(detalhe,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.outline),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    "${data['metodo']} • ${DateFormat('dd/MM HH:mm').format(date)}",
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("${vol.toStringAsFixed(0)} L",
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.blue.shade800)),
                Text("R\$ ${custo.toStringAsFixed(2)}",
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.opacity, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: AppTokens.md),
          Text(
            "Sem registros de rega.",
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// =======================================================================
// BOTTOM SHEET COM O PROBLEMA CORRIGIDO
// E SEM CONFLITO DE CITAÇÕES
// =======================================================================
class _SheetNovaRega extends StatefulWidget {
  final IrrigacaoRepository repo;
  final double custoAguaM3;
  const _SheetNovaRega({required this.repo, required this.custoAguaM3});

  @override
  State<_SheetNovaRega> createState() => _SheetNovaRegaState();
}

class _SheetNovaRegaState extends State<_SheetNovaRega> {
  final List<Map<String, dynamic>> _selecionados = [];
  String _metodo = 'Aspersão';
  int _tempo = 4;
  bool _salvando = false;
  final _obsCtrl = TextEditingController();

  double get _areaTotalSelecionada =>
      _selecionados.fold(0.0, (sum, c) => sum + (c['area'] as double));

  // A meta diária recomendada
  double get _metaDiariaLitros => _areaTotalSelecionada * 5.0;

  // O volume real que está saindo da mangueira/sistema baseado apenas no tempo e método
  double get _volumeEstimadoLitros {
    double vazaoLPM = 2.0;
    if (_metodo == 'Aspersão') vazaoLPM = 10.0;
    if (_metodo == 'Manual (Mangueira)') vazaoLPM = 15.0;
    if (_metodo == 'Regador') vazaoLPM = 5.0;
    return _tempo * vazaoLPM;
  }

  double get _custoEstimado =>
      _volumeEstimadoLitros * (widget.custoAguaM3 / 1000);

  void _abrirSelecao(List<QueryDocumentSnapshot> docs) async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg)),
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
                    final area =
                        double.tryParse((data['area_m2'] ?? 0).toString()) ??
                            0.0;
                    final isSelected = _selecionados.any((s) => s['id'] == id);

                    return CheckboxListTile(
                      activeColor: Colors.blue.shade800,
                      contentPadding: EdgeInsets.zero,
                      title: Text(nome,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
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
                        this.setState(() {});
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CONCLUIR',
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
          content: Text('⚠️ Selecione pelo menos um local.'),
          behavior: SnackBarBehavior.floating));
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
        content: Text('✅ Irrigação registrada com sucesso!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.water_drop, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text('Nova Rega',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),
            StreamBuilder<QuerySnapshot>(
              stream: widget.repo.watchCanteiros(),
              builder: (context, snap) {
                if (!snap.hasData) return const LinearProgressIndicator();
                final docs = snap.data!.docs;

                if (docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(AppTokens.md),
                    decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusSm)),
                    child: const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.deepOrange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Nenhum canteiro ativo encontrado.',
                            style: TextStyle(color: Colors.deepOrange),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return InkWell(
                  onTap: () => _abrirSelecao(docs),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.grid_on_rounded, color: Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selecionados.isEmpty
                                ? 'Selecione os Locais'
                                : '${_selecionados.length} locais selecionados',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selecionados.isEmpty
                                    ? Colors.grey.shade600
                                    : Colors.black87),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.blue),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (_selecionados.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: _selecionados
                    .map((c) => Chip(
                          label: Text(c['nome'],
                              style: const TextStyle(fontSize: 11)),
                          backgroundColor: Colors.blue.shade50,
                          side: BorderSide.none,
                          onDeleted: () =>
                              setState(() => _selecionados.remove(c)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 20),
            Row(children: [
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
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
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
                      labelText: 'Tempo',
                      suffixText: 'min',
                      border: OutlineInputBorder()),
                  initialValue: _tempo.toString(),
                  onChanged: (v) =>
                      setState(() => _tempo = int.tryParse(v) ?? 0),
                ),
              )
            ]),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade100)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoItem(
                      'VOLUME APLICADO',
                      '${_volumeEstimadoLitros.toStringAsFixed(0)} L',
                      Colors.blue.shade900),
                  Container(width: 1, height: 40, color: Colors.blue.shade200),
                  _buildInfoItem(
                      'CUSTO',
                      'R\$ ${_custoEstimado.toStringAsFixed(2)}',
                      Colors.green.shade800),
                ],
              ),
            ),
            if (_areaTotalSelecionada > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.eco, color: Colors.green.shade700, size: 18),
                        const SizedBox(width: 8),
                        Text('Dicas Agronômicas',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                        '• Meta diária recomendada: ${_metaDiariaLitros.toStringAsFixed(0)}L totais para a área selecionada.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.green.shade900)),
                    const SizedBox(height: 4),
                    Text(
                        '• Solos arenosos secam rápido, prefira dividir a rega.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.green.shade900)),
                    const SizedBox(height: 4),
                    Text('• Use sempre água de boa procedência.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.green.shade900)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _salvando
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text('CONFIRMAR REGISTRO',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color.withOpacity(0.7))),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }
}
