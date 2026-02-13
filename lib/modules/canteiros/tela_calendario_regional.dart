import 'package:flutter/material.dart';

import 'guia_culturas.dart';
import 'package:verde_ensina/core/ui/app_ui.dart';

class TelaCalendarioRegional extends StatefulWidget {
  const TelaCalendarioRegional({super.key});

  @override
  State<TelaCalendarioRegional> createState() => _TelaCalendarioRegionalState();
}

class _TelaCalendarioRegionalState extends State<TelaCalendarioRegional> {
  String _regiao = 'Sudeste';
  String _mes = 'Fevereiro';

  @override
  Widget build(BuildContext context) {
    final regioes = calendarioRegional.keys.toList()..sort();
    final mesesDisponiveis = (calendarioRegional[_regiao]?.keys.toList() ?? [])
      ..sort();

    if (!mesesDisponiveis.contains(_mes) && mesesDisponiveis.isNotEmpty) {
      _mes = mesesDisponiveis.first;
    }

    final culturas = culturasPorRegiaoMes(_regiao, _mes);

    return PageContainer(
      title: 'Calendário Regional',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'Filtros',
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _regiao,
                  decoration: const InputDecoration(
                    labelText: 'Região',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                  items: regioes
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setState(() => _regiao = v ?? 'Sudeste'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _mes,
                  decoration: const InputDecoration(
                    labelText: 'Mês',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  items: mesesDisponiveis
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setState(() => _mes = v ?? 'Fevereiro'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          SectionCard(
            title: 'Sugestões para $_regiao • $_mes (${culturas.length})',
            subtitle: 'Toque para ver detalhes da cultura.',
            child: Column(
              children: culturas.map((nome) {
                final info = getCulturaInfo(nome);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(nome, style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(info == null
                      ? 'Sem detalhes no guia'
                      : '${info.categoria} • ciclo ${info.cicloDias} dias'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: info == null ? null : () => _detalhes(context, info),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _detalhes(BuildContext context, CulturaInfo info) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(info.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            _row('Categoria', info.categoria),
            _row('Ciclo', '${info.cicloDias} dias'),
            _row('Esp. linhas', '${info.espacamentoLinhaM} m'),
            _row('Esp. plantas', '${info.espacamentoPlantaM} m'),
            _row('Companheiras', info.companheiras.isEmpty ? '—' : info.companheiras.join(', ')),
            _row('Evitar', info.evitar.isEmpty ? '—' : info.evitar.join(', ')),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(k, style: TextStyle(color: Colors.grey.shade700))),
          const SizedBox(width: 10),
          Expanded(
            child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
