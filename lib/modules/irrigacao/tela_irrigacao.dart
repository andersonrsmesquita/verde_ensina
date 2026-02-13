import 'package:flutter/material.dart';

class TelaIrrigacao extends StatefulWidget {
  const TelaIrrigacao({super.key});

  @override
  State<TelaIrrigacao> createState() => _TelaIrrigacaoState();
}

class _TelaIrrigacaoState extends State<TelaIrrigacao> {
  final _formKey = GlobalKey<FormState>();

  // Configurações (mock)
  bool _modoAutomatico = true;
  bool _pausarSeChuva = true;

  // Regra: dias selecionados
  final Map<int, bool> _dias = {
    1: true, // Seg
    2: false, // Ter
    3: true, // Qua
    4: false, // Qui
    5: true, // Sex
    6: false, // Sáb
    7: false, // Dom
  };

  TimeOfDay _horaInicio = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _horaFim = const TimeOfDay(hour: 8, minute: 0);

  int _duracaoMin = 12;
  int _umidadeMin = 35; // % (mock)
  int _chuvaLimiteMm = 3; // mm (mock)

  // Mock “clima”
  final _clima = _Clima(
    chuvaPrevistaMm: 2.0,
    umidadePct: 41,
    ventoKmh: 9,
    temperaturaC: 26,
  );

  // Histórico (mock)
  final List<_IrrigacaoEvento> _historico = [
    _IrrigacaoEvento(
      when: DateTime.now().subtract(const Duration(hours: 20)),
      duracaoMin: 12,
      modo: 'Automático',
      status: _IrrigacaoStatus.executado,
      obs: 'Solo ok',
    ),
    _IrrigacaoEvento(
      when: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
      duracaoMin: 12,
      modo: 'Automático',
      status: _IrrigacaoStatus.puladoPorChuva,
      obs: 'Chuva prevista alta',
    ),
    _IrrigacaoEvento(
      when: DateTime.now().subtract(const Duration(days: 3, hours: 2)),
      duracaoMin: 8,
      modo: 'Manual',
      status: _IrrigacaoStatus.executado,
      obs: 'Ajuste pós adubação',
    ),
  ];

  String _fmtTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _fmtDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  String _diaLabel(int weekday) {
    switch (weekday) {
      case 1:
        return 'Seg';
      case 2:
        return 'Ter';
      case 3:
        return 'Qua';
      case 4:
        return 'Qui';
      case 5:
        return 'Sex';
      case 6:
        return 'Sáb';
      case 7:
        return 'Dom';
      default:
        return '';
    }
  }

  List<int> get _diasSelecionados =>
      _dias.entries.where((e) => e.value).map((e) => e.key).toList()..sort();

  String get _diasTexto {
    final d = _diasSelecionados;
    if (d.isEmpty) return 'Nenhum dia selecionado';
    return d.map(_diaLabel).join(', ');
  }

  bool get _bloquearPorChuva =>
      _pausarSeChuva && _clima.chuvaPrevistaMm >= _chuvaLimiteMm;

  bool get _bloquearPorUmidade => _clima.umidadePct >= _umidadeMin;

  String get _statusHoje {
    if (!_modoAutomatico) return 'Manual';
    if (_bloquearPorChuva) return 'Pausado (chuva)';
    if (_bloquearPorUmidade) return 'Pausado (umidade alta)';
    return 'Automático (ok)';
  }

  Color _statusColor(ThemeData theme) {
    if (!_modoAutomatico) return Colors.blueGrey;
    if (_bloquearPorChuva || _bloquearPorUmidade) return Colors.orange;
    return theme.colorScheme.primary;
  }

  DateTime? get _proximaIrrigacao {
    // Mock: calcula a próxima ocorrência baseada nos dias selecionados e horaInicio
    final now = DateTime.now();
    final selected = _diasSelecionados;
    if (!_modoAutomatico || selected.isEmpty) return null;

    for (int i = 0; i < 14; i++) {
      final day = now.add(Duration(days: i));
      final wd = day.weekday;
      if (selected.contains(wd)) {
        final dt = DateTime(
            day.year, day.month, day.day, _horaInicio.hour, _horaInicio.minute);
        if (dt.isAfter(now)) return dt;
      }
    }
    return null;
  }

  List<_AgendaItem> get _agendaSemana {
    final now = DateTime.now();
    final selected = _diasSelecionados;

    final items = <_AgendaItem>[];
    for (int i = 0; i < 7; i++) {
      final d = now.add(Duration(days: i));
      final wd = d.weekday;
      final isDia = selected.contains(wd);
      items.add(
        _AgendaItem(
          date: d,
          ativo: isDia && _modoAutomatico,
          janela: '${_fmtTime(_horaInicio)}–${_fmtTime(_horaFim)}',
          duracaoMin: _duracaoMin,
        ),
      );
    }
    return items;
  }

  Future<void> _pickHoraInicio() async {
    final res =
        await showTimePicker(context: context, initialTime: _horaInicio);
    if (res != null) setState(() => _horaInicio = res);
  }

  Future<void> _pickHoraFim() async {
    final res = await showTimePicker(context: context, initialTime: _horaFim);
    if (res != null) setState(() => _horaFim = res);
  }

  void _toggleDia(int weekday) {
    setState(() => _dias[weekday] = !(_dias[weekday] ?? false));
  }

  void _salvarRegras() {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('✅ Regras salvas (mock). Depois a gente liga no Firestore.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _irrigarAgora() {
    // Registra evento no histórico (mock)
    setState(() {
      _historico.insert(
        0,
        _IrrigacaoEvento(
          when: DateTime.now(),
          duracaoMin: _duracaoMin,
          modo: 'Manual',
          status: _IrrigacaoStatus.executado,
          obs: 'Disparo manual',
        ),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('💧 Irrigação iniciada (mock).'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _registrarManual() {
    showDialog(
      context: context,
      builder: (ctx) {
        final obsCtrl = TextEditingController();
        int dur = 10;
        return AlertDialog(
          title: const Text('Registrar irrigação manual'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('Duração (min)'),
                  const Spacer(),
                  DropdownButton<int>(
                    value: dur,
                    items: const [5, 8, 10, 12, 15, 20, 25]
                        .map((v) =>
                            DropdownMenuItem(value: v, child: Text('$v')))
                        .toList(),
                    onChanged: (v) => dur = v ?? dur,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: obsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Observação (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _historico.insert(
                    0,
                    _IrrigacaoEvento(
                      when: DateTime.now(),
                      duracaoMin: dur,
                      modo: 'Manual',
                      status: _IrrigacaoStatus.executado,
                      obs: obsCtrl.text.trim().isEmpty
                          ? 'Registro manual'
                          : obsCtrl.text.trim(),
                    ),
                  );
                });
                Navigator.pop(ctx);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📝 Registro adicionado no histórico.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = _proximaIrrigacao;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Irrigação'),
        actions: [
          IconButton(
            tooltip: 'Salvar regras',
            onPressed: _salvarRegras,
            icon: const Icon(Icons.save),
          ),
          const SizedBox(width: 6),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _registrarManual,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Registrar manual'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _irrigarAgora,
                  icon: const Icon(Icons.water_drop),
                  label: const Text('Irrigar agora'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            // Dashboard
            _Section(
              title: 'Resumo',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryRow(
                    leftTitle: 'Status',
                    leftValue: _statusHoje,
                    leftValueColor: _statusColor(theme),
                    rightTitle: 'Próxima',
                    rightValue: next == null ? '--' : _fmtDateTime(next),
                  ),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    leftTitle: 'Última',
                    leftValue: _historico.isEmpty
                        ? '--'
                        : _fmtDateTime(_historico.first.when),
                    rightTitle: 'Duração padrão',
                    rightValue: '$_duracaoMin min',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Clima rápido
            _Section(
              title: 'Clima (mock)',
              trailing: TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('🌦️ Depois a gente liga numa API de clima.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.link),
                label: const Text('Conectar'),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: _MiniStat(
                              icon: Icons.thermostat,
                              label: 'Temp',
                              value: '${_clima.temperaturaC}°C')),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _MiniStat(
                              icon: Icons.water,
                              label: 'Umidade',
                              value: '${_clima.umidadePct}%')),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _MiniStat(
                              icon: Icons.air,
                              label: 'Vento',
                              value: '${_clima.ventoKmh} km/h')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: _MiniStat(
                              icon: Icons.cloudy_snowing,
                              label: 'Chuva prevista',
                              value:
                                  '${_clima.chuvaPrevistaMm.toStringAsFixed(1)} mm')),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniStat(
                          icon: Icons.rule,
                          label: 'Pausa por chuva',
                          value: _pausarSeChuva ? 'Ativa' : 'Desligada',
                        ),
                      ),
                    ],
                  ),
                  if (_modoAutomatico &&
                      _pausarSeChuva &&
                      _bloquearPorChuva) ...[
                    const SizedBox(height: 10),
                    _Hint(
                      icon: Icons.warning_amber,
                      text:
                          'Hoje o automático pode pausar: chuva prevista (${_clima.chuvaPrevistaMm.toStringAsFixed(1)} mm) >= limite ($_chuvaLimiteMm mm).',
                    ),
                  ],
                  if (_modoAutomatico && _bloquearPorUmidade) ...[
                    const SizedBox(height: 10),
                    _Hint(
                      icon: Icons.info_outline,
                      text:
                          'Umidade atual (${_clima.umidadePct}%) >= mínimo ($_umidadeMin%). Pode pausar o automático.',
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Regras
            _Section(
              title: 'Regras de irrigação',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    value: _modoAutomatico,
                    onChanged: (v) => setState(() => _modoAutomatico = v),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Modo automático'),
                    subtitle: Text(_modoAutomatico
                        ? 'Segue agenda e regras (chuva/umidade).'
                        : 'Você controla manualmente.'),
                  ),
                  const Divider(height: 18),
                  Text('Dias da semana',
                      style: TextStyle(
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(7, (i) {
                      final wd = i + 1;
                      final sel = _dias[wd] ?? false;
                      return ChoiceChip(
                        label: Text(_diaLabel(wd)),
                        selected: sel,
                        onSelected: (_) => _toggleDia(wd),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Selecionado: $_diasTexto',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _PickTile(
                          title: 'Janela início',
                          value: _fmtTime(_horaInicio),
                          onTap: _pickHoraInicio,
                          icon: Icons.schedule,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PickTile(
                          title: 'Janela fim',
                          value: _fmtTime(_horaFim),
                          onTap: _pickHoraFim,
                          icon: Icons.schedule_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    initialValue: '$_duracaoMin',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duração (min)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer),
                    ),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null || n < 1 || n > 120)
                        return 'Informe de 1 a 120';
                      return null;
                    },
                    onSaved: (v) => _duracaoMin = int.parse(v!.trim()),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _pausarSeChuva,
                    onChanged: (v) => setState(() => _pausarSeChuva = v),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pausar se houver chuva'),
                    subtitle: Text(
                        'Se chuva prevista >= $_chuvaLimiteMm mm, o automático pausa.'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: '$_chuvaLimiteMm',
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Limite de chuva (mm)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.cloudy_snowing),
                          ),
                          validator: (v) {
                            final n = int.tryParse((v ?? '').trim());
                            if (n == null || n < 0 || n > 50) return '0 a 50';
                            return null;
                          },
                          onSaved: (v) => _chuvaLimiteMm = int.parse(v!.trim()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: '$_umidadeMin',
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Umidade mínima (%)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.water),
                          ),
                          validator: (v) {
                            final n = int.tryParse((v ?? '').trim());
                            if (n == null || n < 0 || n > 100) return '0 a 100';
                            return null;
                          },
                          onSaved: (v) => _umidadeMin = int.parse(v!.trim()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _salvarRegras,
                    icon: const Icon(Icons.save),
                    label: const Text('Salvar regras'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Agenda
            _Section(
              title: 'Agenda (próximos 7 dias)',
              child: Column(
                children: _agendaSemana.map((a) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AgendaCard(
                      item: a,
                      fmtDate: (d) {
                        final dd = d.day.toString().padLeft(2, '0');
                        final mm = d.month.toString().padLeft(2, '0');
                        final w = _diaLabel(d.weekday);
                        return '$w • $dd/$mm';
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 14),

            // Histórico
            _Section(
              title: 'Histórico',
              trailing: TextButton.icon(
                onPressed: () {
                  setState(() => _historico.clear());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🧹 Histórico limpo (mock).'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Limpar'),
              ),
              child: _historico.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Sem registros por enquanto.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    )
                  : Column(
                      children: _historico.take(12).map((e) {
                        return _HistoricoTile(
                          evento: e,
                          fmt: _fmtDateTime,
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------
// COMPONENTES
// -----------------
class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _Section({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16)),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String leftTitle;
  final String leftValue;
  final Color? leftValueColor;
  final String rightTitle;
  final String rightValue;

  const _SummaryRow({
    required this.leftTitle,
    required this.leftValue,
    required this.rightTitle,
    required this.rightValue,
    this.leftValueColor,
  });

  @override
  Widget build(BuildContext context) {
    final styleTitle = TextStyle(color: Colors.grey.shade700, fontSize: 12);
    final styleValue =
        const TextStyle(fontWeight: FontWeight.w900, fontSize: 14);

    return Row(
      children: [
        Expanded(
          child: _Kpi(
              title: leftTitle,
              value: leftValue,
              valueStyle: styleValue.copyWith(color: leftValueColor)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Kpi(
              title: rightTitle, value: rightValue, valueStyle: styleValue),
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  final String title;
  final String value;
  final TextStyle valueStyle;

  const _Kpi({
    required this.title,
    required this.value,
    required this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;
  final IconData icon;

  const _PickTile({
    required this.title,
    required this.value,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Hint({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  color: Colors.orange.shade900, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  final _AgendaItem item;
  final String Function(DateTime) fmtDate;

  const _AgendaCard({
    required this.item,
    required this.fmtDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = item.ativo ? theme.colorScheme.primary : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.ativo
            ? theme.colorScheme.primary.withOpacity(0.06)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: item.ativo
                ? theme.colorScheme.primary.withOpacity(0.25)
                : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(item.ativo ? Icons.event_available : Icons.event_busy,
                color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fmtDate(item.date),
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  item.ativo
                      ? 'Janela: ${item.janela} • ${item.duracaoMin} min'
                      : 'Sem irrigação (regra)',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey.shade600),
        ],
      ),
    );
  }
}

class _HistoricoTile extends StatelessWidget {
  final _IrrigacaoEvento evento;
  final String Function(DateTime) fmt;

  const _HistoricoTile({
    required this.evento,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    IconData icon;
    Color color;
    String statusText;

    switch (evento.status) {
      case _IrrigacaoStatus.executado:
        icon = Icons.check_circle;
        color = theme.colorScheme.primary;
        statusText = 'Executado';
        break;
      case _IrrigacaoStatus.puladoPorChuva:
        icon = Icons.cloud_off;
        color = Colors.orange;
        statusText = 'Pulado (chuva)';
        break;
      case _IrrigacaoStatus.cancelado:
        icon = Icons.cancel;
        color = Colors.redAccent;
        statusText = 'Cancelado';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${fmt(evento.when)} • ${evento.duracaoMin} min',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$statusText • ${evento.modo} • ${evento.obs}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              statusText,
              style: TextStyle(
                  fontWeight: FontWeight.w900, color: color, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------
// MODELOS (MOCK)
// -----------------
class _Clima {
  final int temperaturaC;
  final int umidadePct;
  final int ventoKmh;
  final double chuvaPrevistaMm;

  const _Clima({
    required this.temperaturaC,
    required this.umidadePct,
    required this.ventoKmh,
    required this.chuvaPrevistaMm,
  });
}

class _AgendaItem {
  final DateTime date;
  final bool ativo;
  final String janela;
  final int duracaoMin;

  const _AgendaItem({
    required this.date,
    required this.ativo,
    required this.janela,
    required this.duracaoMin,
  });
}

enum _IrrigacaoStatus { executado, puladoPorChuva, cancelado }

class _IrrigacaoEvento {
  final DateTime when;
  final int duracaoMin;
  final String modo;
  final _IrrigacaoStatus status;
  final String obs;

  const _IrrigacaoEvento({
    required this.when,
    required this.duracaoMin,
    required this.modo,
    required this.status,
    required this.obs,
  });
}
