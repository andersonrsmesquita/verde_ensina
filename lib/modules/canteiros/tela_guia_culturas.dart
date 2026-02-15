import 'package:flutter/material.dart';

import 'package:verde_ensina/core/ui/app_ui.dart';
import 'package:verde_ensina/core/ui/widgets/app_text_field.dart';

import 'guia_culturas.dart';

class TelaGuiaCulturas extends StatefulWidget {
  const TelaGuiaCulturas({super.key});

  @override
  State<TelaGuiaCulturas> createState() => _TelaGuiaCulturasState();
}

class _TelaGuiaCulturasState extends State<TelaGuiaCulturas> {
  final TextEditingController _search = TextEditingController();
  String? _cat;

  late final VoidCallback _searchListener;

  @override
  void initState() {
    super.initState();
    _searchListener = () {
      if (!mounted) return;
      setState(() {}); // atualiza resultados enquanto digita
    };
    _search.addListener(_searchListener);
  }

  @override
  void dispose() {
    _search.removeListener(_searchListener);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final categorias = listarCategorias();
    final resultados = buscarCulturas(_search.text, categoria: _cat);

    return PageContainer(
      title: 'Guia de Culturas',
      subtitle: 'Filtro por categoria + busca por nome.',
      scroll: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'Pesquisar',
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
                      // listener já chama setState, mas aqui garante resposta imediata
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  value: _cat,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    prefixIcon: Icon(Icons.filter_list),
                  ),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todas'),
                    ),
                    ...categorias.map(
                      (c) => DropdownMenuItem<String?>(
                        value: c,
                        child: Text(c),
                      ),
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
            child: resultados.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Column(
                      children: [
                        Icon(Icons.search_off,
                            size: 48, color: cs.outlineVariant),
                        const SizedBox(height: 10),
                        Text(
                          'Nada por aqui.',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tenta outro nome ou remove os filtros.',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: resultados.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final nome = resultados[i];
                      final info = getCulturaInfo(nome);

                      if (info == null) {
                        return ListTile(
                          title: Text(nome,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text('Informações indisponíveis',
                              style: TextStyle(color: cs.onSurfaceVariant)),
                        );
                      }

                      return ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 10),
                        title: Text(
                          info.nome,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                            '${info.categoria} • ciclo ${info.cicloDias} dias'),
                        children: [
                          _linha(cs, 'Categoria', info.categoria),
                          _linha(cs, 'Ciclo', '${info.cicloDias} dias'),
                          _linha(cs, 'Espaçamento (linhas)',
                              '${info.espacamentoLinhaM} m'),
                          _linha(cs, 'Espaçamento (plantas)',
                              '${info.espacamentoPlantaM} m'),
                          _linha(cs, 'Área/Planta (estimada)',
                              '${info.areaPorPlantaM2.toStringAsFixed(2)} m²'),
                          _linha(
                            cs,
                            'Companheiras',
                            info.companheiras.isEmpty
                                ? '—'
                                : info.companheiras.join(', '),
                          ),
                          _linha(
                            cs,
                            'Evitar',
                            info.evitar.isEmpty ? '—' : info.evitar.join(', '),
                          ),
                          const SizedBox(height: 6),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _linha(ColorScheme cs, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
