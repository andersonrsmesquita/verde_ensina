import 'package:flutter/material.dart';

import 'guia_culturas.dart';
import 'package:verde_ensina/core/ui/app_ui.dart';

class TelaGuiaCulturas extends StatefulWidget {
  const TelaGuiaCulturas({super.key});

  @override
  State<TelaGuiaCulturas> createState() => _TelaGuiaCulturasState();
}

class _TelaGuiaCulturasState extends State<TelaGuiaCulturas> {
  final _search = TextEditingController();
  String? _cat;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categorias = listarCategorias();
    final resultados = buscarCulturas(_search.text, categoria: _cat);

    return PageContainer(
      title: 'Guia de Culturas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'Pesquisar',
            subtitle: 'Filtro por categoria + busca por nome.',
            child: Column(
              children: [
                AppTextField(
                  controller: _search,
                  label: 'Buscar cultura',
                  hint: 'Ex: Tomate, Alface, Berinjela...',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _search.clear();
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _cat,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    prefixIcon: Icon(Icons.filter_list),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todas')),
                    ...categorias.map(
                      (c) => DropdownMenuItem(value: c, child: Text(c)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _cat = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          SectionCard(
            title: 'Resultados (${resultados.length})',
            child: Column(
              children: resultados.map((nome) {
                final info = getCulturaInfo(nome)!;

                return ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 10),
                  title: Text(
                    info.nome,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text('${info.categoria} • ciclo ${info.cicloDias} dias'),
                  children: [
                    _linha('Categoria', info.categoria),
                    _linha('Ciclo', '${info.cicloDias} dias'),
                    _linha('Espaçamento (linhas)', '${info.espacamentoLinhaM} m'),
                    _linha('Espaçamento (plantas)', '${info.espacamentoPlantaM} m'),
                    _linha('Área/Planta (estimada)', '${info.areaPorPlantaM2.toStringAsFixed(2)} m²'),
                    _linha(
                      'Companheiras',
                      info.companheiras.isEmpty ? '—' : info.companheiras.join(', '),
                    ),
                    _linha(
                      'Evitar',
                      info.evitar.isEmpty ? '—' : info.evitar.join(', '),
                    ),
                    const Divider(),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linha(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(k, style: TextStyle(color: Colors.grey.shade700))),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
