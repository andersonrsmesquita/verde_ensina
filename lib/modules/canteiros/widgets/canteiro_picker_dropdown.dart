import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/firebase/firebase_paths.dart';

class CanteiroPickerDropdown extends StatelessWidget {
  final String tenantId;
  final String? selectedId;
  final void Function(String id) onSelect;

  const CanteiroPickerDropdown({
    super.key,
    required this.tenantId,
    required this.onSelect,
    this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebasePaths.canteirosCol(tenantId).where('ativo', isEqualTo: true).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Text('Nenhum lote ativo encontrado.');

        final validSelectedId = docs.any((doc) => doc.id == selectedId) ? selectedId : null;

        return DropdownButtonFormField<String>(
          isExpanded: true,
          value: validSelectedId,
          decoration: InputDecoration(
            labelText: 'Selecione o Lote',
            prefixIcon: const Icon(Icons.place_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
          ),
          items: docs.map((d) {
            final data = d.data();
            final nome = (data['nome'] ?? 'Canteiro').toString();
            final areaM2 = (double.tryParse(data['area_m2']?.toString() ?? '0') ?? 0).toStringAsFixed(1);
            return DropdownMenuItem(value: d.id, child: Text('$nome ($areaM2 m²)'));
          }).toList(),
          onChanged: (id) {
            if (id != null) onSelect(id);
          },
        );
      },
    );
  }
}