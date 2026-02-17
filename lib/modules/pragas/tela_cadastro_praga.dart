import 'package:flutter/material.dart';
import '../../core/models/praga_model.dart';
import '../../core/repositories/pragas_repository.dart';
import '../../core/session/session_scope.dart';
import '../../core/ui/app_ui.dart';

class TelaCadastroPraga extends StatefulWidget {
  const TelaCadastroPraga({super.key});

  @override
  State<TelaCadastroPraga> createState() => _TelaCadastroPragaState();
}

class _TelaCadastroPragaState extends State<TelaCadastroPraga> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _canteiroCtrl = TextEditingController();

  String _intensidade = 'Leve';
  bool _salvando = false;

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);
    final tenantId = SessionScope.of(context).session!.tenantId;

    try {
      final praga = PragaModel(
        nome: _nomeCtrl.text,
        canteiroId: 'manual', // No futuro, pegaremos de um select
        canteiroNome: _canteiroCtrl.text,
        intensidade: _intensidade,
        dataIdentificacao: DateTime.now(),
      );

      await PragasRepository().adicionarPraga(tenantId, praga);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Registrado com sucesso!")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erro: $e")));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nova Praga / Doença")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(
                  labelText: "O que você encontrou?",
                  hintText: "Ex: Pulgão, Ferrugem...",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
                validator: (v) => v!.isEmpty ? "Campo obrigatório" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _canteiroCtrl,
                decoration: const InputDecoration(
                  labelText: "Em qual canteiro?",
                  hintText: "Ex: Canteiro A1",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.grass),
                ),
                validator: (v) => v!.isEmpty ? "Campo obrigatório" : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _intensidade,
                decoration: const InputDecoration(
                  labelText: "Intensidade / Gravidade",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.bar_chart),
                ),
                items: ['Leve', 'Média', 'Alta']
                    .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                    .toList(),
                onChanged: (v) => setState(() => _intensidade = v!),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: AppButtons.elevatedIcon(
                  onPressed: _salvando ? null : _salvar,
                  icon: const Icon(Icons.save),
                  label: Text(_salvando ? "SALVANDO..." : "REGISTRAR"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
