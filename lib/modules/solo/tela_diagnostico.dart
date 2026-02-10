import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TelaDiagnostico extends StatefulWidget {
  const TelaDiagnostico({super.key});

  @override
  State<TelaDiagnostico> createState() => _TelaDiagnosticoState();
}

class _TelaDiagnosticoState extends State<TelaDiagnostico> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _salvando = false;

  // --- VARIÁVEIS DO TESTE MANUAL ---
  String? _resultadoManual;

  // --- VARIÁVEIS DA ANÁLISE DE LABORATÓRIO (Controladores de Texto) ---
  final _phController = TextEditingController();
  final _vPercentController = TextEditingController(); // Saturação por Bases (Vital para Calagem)
  final _moController = TextEditingController(); // Matéria Orgânica
  final _fosforoController = TextEditingController(); // P (mg/dm3)
  final _potassioController = TextEditingController(); // K (mmolc/dm3)
  final _calcioController = TextEditingController(); // Ca (mmolc/dm3)
  final _magnesioController = TextEditingController(); // Mg (mmolc/dm3)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phController.dispose();
    _vPercentController.dispose();
    _moController.dispose();
    _fosforoController.dispose();
    _potassioController.dispose();
    _calcioController.dispose();
    _magnesioController.dispose();
    super.dispose();
  }

  // --- FUNÇÃO DE SALVAR INTELIGENTE ---
  Future<void> _salvarDados() async {
    setState(() => _salvando = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      // Prepara o pacote de dados (JSON)
      Map<String, dynamic> dados = {
        'uid_usuario': user?.uid,
        'data': FieldValue.serverTimestamp(),
        'metodo': _tabController.index == 0 ? 'manual' : 'laboratorial',
      };

      if (_tabController.index == 0) {
        // LÓGICA MANUAL
        if (_resultadoManual == null) throw Exception("Selecione uma textura.");
        dados['textura_estimada'] = _resultadoManual;
        dados['precisao'] = 'baixa';
      } else {
        // LÓGICA LABORATORIAL (PROFISSIONAL)
        // Convertendo texto para número (double)
        dados['ph'] = double.tryParse(_phController.text.replaceAll(',', '.'));
        dados['v_percent'] = double.tryParse(_vPercentController.text.replaceAll(',', '.'));
        dados['mo'] = double.tryParse(_moController.text.replaceAll(',', '.'));
        dados['fosforo'] = double.tryParse(_fosforoController.text.replaceAll(',', '.'));
        dados['potassio'] = double.tryParse(_potassioController.text.replaceAll(',', '.'));
        dados['calcio'] = double.tryParse(_calcioController.text.replaceAll(',', '.'));
        dados['magnesio'] = double.tryParse(_magnesioController.text.replaceAll(',', '.'));
        dados['precisao'] = 'alta';
        
        if (dados['ph'] == null || dados['v_percent'] == null) {
          throw Exception("pH e V% são obrigatórios para os cálculos.");
        }
      }

      // Envia para o Firestore
      await FirebaseFirestore.instance.collection('analises_solo').add(dados);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados salvos! Calculadora de Calagem liberada. ✅')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análise de Solo', style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.back_hand), text: 'Teste Rápido (Mão)'),
            Tab(icon: Icon(Icons.science), text: 'Laboratório (Laudo)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // --- ABA 1: TESTE MANUAL (Minhoquinha) ---
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Sem laudo técnico? Use o tato.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text('Tente fazer uma "cobrinha" com a terra úmida:'),
                const SizedBox(height: 20),
                _OpcaoManual(
                  label: 'Areia (Esfarela)',
                  valor: 'Arenoso',
                  grupo: _resultadoManual,
                  onChanged: (v) => setState(() => _resultadoManual = v),
                ),
                _OpcaoManual(
                  label: 'Médio (Racha)',
                  valor: 'Médio',
                  grupo: _resultadoManual,
                  onChanged: (v) => setState(() => _resultadoManual = v),
                ),
                _OpcaoManual(
                  label: 'Argila (Modela bem)',
                  valor: 'Argiloso',
                  grupo: _resultadoManual,
                  onChanged: (v) => setState(() => _resultadoManual = v),
                ),
              ],
            ),
          ),

          // --- ABA 2: DADOS DE LABORATÓRIO (PROFISSIONAL) ---
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Insira os dados do Laudo Técnico:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                const Text('Isso permite calcular a calagem exata.', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                
                Row(children: [
                  Expanded(child: _InputNumerico(controller: _phController, label: 'pH (H2O)')),
                  const SizedBox(width: 15),
                  Expanded(child: _InputNumerico(controller: _vPercentController, label: 'V% (Saturação)')),
                ]),
                
                const SizedBox(height: 15),
                _InputNumerico(controller: _moController, label: 'Matéria Orgânica (g/dm3 ou %)'),
                
                const SizedBox(height: 15),
                const Text('Macronutrientes:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                
                Row(children: [
                  Expanded(child: _InputNumerico(controller: _fosforoController, label: 'Fósforo (P)')),
                  const SizedBox(width: 15),
                  Expanded(child: _InputNumerico(controller: _potassioController, label: 'Potássio (K)')),
                ]),
                const SizedBox(height: 15),
                Row(children: [
                  Expanded(child: _InputNumerico(controller: _calcioController, label: 'Cálcio (Ca)')),
                  const SizedBox(width: 15),
                  Expanded(child: _InputNumerico(controller: _magnesioController, label: 'Magnésio (Mg)')),
                ]),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton(
          onPressed: _salvando ? null : _salvarDados,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
          child: _salvando 
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('SALVAR ANÁLISE', style: TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}

// --- WIDGETS AUXILIARES PARA LIMPAR O CÓDIGO ---

class _InputNumerico extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _InputNumerico({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
      ),
    );
  }
}

class _OpcaoManual extends StatelessWidget {
  final String label;
  final String valor;
  final String? grupo;
  final ValueChanged<String?> onChanged;

  const _OpcaoManual({
    required this.label,
    required this.valor,
    required this.grupo,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = valor == grupo;
    return Card(
      color: isSelected ? Colors.green.shade50 : Colors.white,
      elevation: isSelected ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? Colors.green : Colors.grey.shade300),
      ),
      child: RadioListTile<String>(
        title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        value: valor,
        groupValue: grupo,
        onChanged: onChanged,
        activeColor: Colors.green,
      ),
    );
  }
}