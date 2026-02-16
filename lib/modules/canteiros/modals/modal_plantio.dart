// FILE: lib/modules/canteiros/modals/modal_plantio.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/app_ui.dart';
import '../../../core/repositories/detalhes_canteiro_repository.dart';
import '../guia_culturas.dart';

class ModalPlantio extends StatefulWidget {
  final String canteiroId;
  final double areaCanteiro;
  final String uid;
  final DetalhesCanteiroRepository repo;
  final VoidCallback onSaved;

  const ModalPlantio({
    super.key,
    required this.canteiroId,
    required this.areaCanteiro,
    required this.uid,
    required this.repo,
    required this.onSaved,
  });

  /// Função estática para chamar o modal facilmente de qualquer tela
  static void mostrar({
    required BuildContext context,
    required String canteiroId,
    required double areaCanteiro,
    required String uid,
    required DetalhesCanteiroRepository repo,
    required VoidCallback onSaved,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ModalPlantio(
        canteiroId: canteiroId,
        areaCanteiro: areaCanteiro,
        uid: uid,
        repo: repo,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<ModalPlantio> createState() => _ModalPlantioState();
}

class _ModalPlantioState extends State<ModalPlantio> {
  final Map<String, int> _qtdPorPlanta = {};
  final TextEditingController _obsController = TextEditingController();
  final TextEditingController _custoMudasController =
      TextEditingController(text: '0,00');

  double get _areaEfetiva =>
      widget.areaCanteiro > 0 ? widget.areaCanteiro : 0.5;

  double get _areaOcupada {
    double ocupada = 0.0;
    _qtdPorPlanta.forEach((planta, qtd) {
      final info = GuiaCulturas.dados[planta] ?? {'espaco': 0.5};
      final espacoPlanta = (info['espaco'] as num).toDouble();
      ocupada += (qtd * espacoPlanta);
    });
    return ocupada;
  }

  bool get _estourou => (_areaEfetiva - _areaOcupada) < 0;
  double get _percentualOcupado =>
      (_areaOcupada / _areaEfetiva).clamp(0.0, 1.0);

  void _adicionarPlanta(String planta) {
    final info = GuiaCulturas.dados[planta] ?? {'espaco': 0.5};
    final areaUnit = (info['espaco'] as num).toDouble().clamp(0.0001, 999999.0);

    int qtdInicial =
        ((_qtdPorPlanta.isNotEmpty && (_areaEfetiva - _areaOcupada) > 0)
            ? ((_areaEfetiva - _areaOcupada) / areaUnit).floor()
            : (_areaEfetiva / areaUnit).floor());

    if (qtdInicial < 1) qtdInicial = 1;
    setState(() {
      _qtdPorPlanta[planta] = qtdInicial;
    });
  }

  Future<void> _salvarPlantio() async {
    final custo = double.tryParse(
            _custoMudasController.text.trim().replaceAll(',', '.')) ??
        0.0;
    Navigator.pop(context); // Fecha o modal primeiro

    String resumo = "Plantio Registrado:\n";
    final nomes = <String>[];
    _qtdPorPlanta.forEach((planta, qtd) {
      nomes.add(planta);
      resumo += "- $planta: $qtd mudas\n";
    });

    try {
      await widget.repo.registrarPlantio(
          uid: widget.uid,
          canteiroId: widget.canteiroId,
          qtdPorPlanta: _qtdPorPlanta,
          resumo: resumo,
          observacao: _obsController.text.trim(),
          custo: custo,
          produto: nomes.join(' + '));

      AppMessenger.success('✅ Plantio registrado! Lote em PRODUÇÃO.');
      widget.onSaved(); // Chama o refresh histórico da tela principal
    } catch (e) {
      AppMessenger.error('Erro ao salvar plantio: $e');
    }
  }

  @override
  void dispose() {
    _obsController.dispose();
    _custoMudasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recomendadas = GuiaCulturas.dados.keys.toList()..sort();

    // Agrupar por categorias para UI
    final Map<String, List<String>> categorias = {};
    for (var p in recomendadas) {
      final cat = (GuiaCulturas.dados[p]?['cat'] ?? 'Outros').toString();
      categorias.putIfAbsent(cat, () => []).add(p);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.9,
        decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Novo Plantio',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: _estourou
                      ? cs.errorContainer
                      : cs.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Ocupação do Lote',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _estourou ? cs.error : cs.primary)),
                      Text('${(_percentualOcupado * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _estourou ? cs.error : cs.primary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                        value: _percentualOcupado,
                        color: _estourou ? cs.error : cs.primary,
                        minHeight: 8,
                        backgroundColor: cs.surface),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...categorias.entries.map((entry) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 16, bottom: 8),
                              child: Text(entry.key.toUpperCase(),
                                  style: TextStyle(
                                      color: cs.outline,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      letterSpacing: 1.2)),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: entry.value.map((planta) {
                                final isSel = _qtdPorPlanta.containsKey(planta);
                                final icone = (GuiaCulturas.dados[planta]
                                            ?['icone'] ??
                                        '🌱')
                                    .toString();
                                return FilterChip(
                                  label: Text('$icone $planta'),
                                  selected: isSel,
                                  checkmarkColor: cs.onPrimary,
                                  selectedColor: cs.primary,
                                  backgroundColor: cs.surfaceContainerHighest,
                                  labelStyle: TextStyle(
                                      fontSize: 12,
                                      color:
                                          isSel ? cs.onPrimary : cs.onSurface),
                                  onSelected: (v) {
                                    if (v) {
                                      _adicionarPlanta(planta);
                                    } else {
                                      setState(
                                          () => _qtdPorPlanta.remove(planta));
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        )),
                    const SizedBox(height: 24),
                    if (_qtdPorPlanta.isNotEmpty) ...[
                      const Divider(),
                      const SizedBox(height: 16),
                      Text('Ajustar Quantidades',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: cs.onSurface)),
                      const SizedBox(height: 16),
                      ..._qtdPorPlanta.entries.map((entry) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: cs.outlineVariant),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                  child: Text(entry.key,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14))),
                              IconButton(
                                  icon: Icon(Icons.remove_circle_outline,
                                      color: cs.error),
                                  onPressed: () {
                                    if (entry.value > 1) {
                                      setState(() => _qtdPorPlanta[entry.key] =
                                          entry.value - 1);
                                    }
                                  }),
                              Text('${entry.value} un',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold)),
                              IconButton(
                                  icon: Icon(Icons.add_circle_outline,
                                      color: cs.primary),
                                  onPressed: () {
                                    setState(() => _qtdPorPlanta[entry.key] =
                                        entry.value + 1);
                                  }),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      TextField(
                          controller: _obsController,
                          decoration: const InputDecoration(
                              labelText: 'Observação do Plantio',
                              border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      TextField(
                          controller: _custoMudasController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Custo de Mudas/Sementes (R\$)',
                              prefixIcon: Icon(Icons.monetization_on),
                              border: OutlineInputBorder())),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_qtdPorPlanta.isNotEmpty)
              SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _estourou ? null : _salvarPlantio,
                  icon: Icon(_estourou ? Icons.warning : Icons.check_circle),
                  label: Text(
                      _estourou ? 'ESPAÇO INSUFICIENTE' : 'CONFIRMAR PLANTIO'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _estourou ? cs.error : cs.primary,
                      foregroundColor: _estourou ? cs.onError : cs.onPrimary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
