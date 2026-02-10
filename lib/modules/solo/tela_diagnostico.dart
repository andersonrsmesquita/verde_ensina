import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TelaDiagnostico extends StatefulWidget {
  final String? canteiroIdOrigem; // Novo parâmetro para saber de onde veio

  const TelaDiagnostico({super.key, this.canteiroIdOrigem});

  @override
  State<TelaDiagnostico> createState() => _TelaDiagnosticoState();
}

class _TelaDiagnosticoState extends State<TelaDiagnostico> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  bool _salvando = false;

  String? _resultadoManual;

  final _phController = TextEditingController();
  final _vPercentController = TextEditingController();
  final _moController = TextEditingController();
  final _fosforoController = TextEditingController();
  final _potassioController = TextEditingController();
  final _calcioController = TextEditingController();
  final _magnesioController = TextEditingController();

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

  Future<void> _salvarDados() async {
    FocusScope.of(context).unfocus(); // Fecha o teclado
    setState(() => _salvando = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      // 1. Prepara os dados base
      Map<String, dynamic> dados = {
        'uid_usuario': user?.uid,
        'data': FieldValue.serverTimestamp(),
        'metodo': _tabController.index == 0 ? 'manual' : 'laboratorial',
        'canteiro_id': widget.canteiroIdOrigem, // Vínculo importante!
      };

      // 2. Valida e completa com dados específicos
      if (_tabController.index == 0) {
        if (_resultadoManual == null) throw Exception("Selecione o tipo de solo na lista.");
        dados['textura_estimada'] = _resultadoManual;
        dados['precisao'] = 'baixa';
      } else {
        if (!_formKey.currentState!.validate()) throw Exception("Preencha os campos obrigatórios (marcados com *).");

        double? parser(TextEditingController c) {
          if (c.text.isEmpty) return 0.0;
          return double.tryParse(c.text.replaceAll(',', '.'));
        }

        dados['ph'] = parser(_phController);
        dados['v_percent'] = parser(_vPercentController);
        dados['mo'] = parser(_moController);
        dados['fosforo'] = parser(_fosforoController);
        dados['potassio'] = parser(_potassioController);
        dados['calcio'] = parser(_calcioController);
        dados['magnesio'] = parser(_magnesioController);
        dados['precisao'] = 'alta';
      }

      // 3. Salva na coleção de Análises Técnicas
      await FirebaseFirestore.instance.collection('analises_solo').add(dados);

      // 4. Salva TAMBÉM no Histórico do Canteiro (Caderno de Campo)
      // Isso garante que apareça na lista da tela de detalhes
      if (widget.canteiroIdOrigem != null) {
        String resumo = _tabController.index == 0 
            ? 'Textura: $_resultadoManual' 
            : 'pH: ${_phController.text} | V%: ${_vPercentController.text}%';

        await FirebaseFirestore.instance.collection('historico_manejo').add({
          'uid_usuario': user?.uid,
          'canteiro_id': widget.canteiroIdOrigem,
          'data': FieldValue.serverTimestamp(),
          'tipo_manejo': 'Análise de Solo',
          'produto': _tabController.index == 0 ? 'Teste Manual' : 'Laudo Laboratorial',
          'quantidade_g': 0, // Análise não gasta insumo
          'detalhes': resumo,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: const [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10), Text('Diagnóstico salvo com sucesso!')]),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context); // Volta para a tela do canteiro
      }
    } catch (e) {
      if (mounted) {
        String erro = e.toString().replaceAll("Exception: ", "");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(erro), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Nova Análise de Solo', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Teste de Mão', icon: Icon(Icons.back_hand)),
            Tab(text: 'Laudo Técnico', icon: Icon(Icons.science)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAbaManual(),
                _buildAbaLaboratorio(),
              ],
            ),
          ),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white, 
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))]
            ),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvarDados,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _salvando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SALVAR DIAGNÓSTICO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbaManual() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
            child: Row(children: const [
              Icon(Icons.lightbulb, color: Colors.orange),
              SizedBox(width: 10),
              Expanded(child: Text('Sem laudo? Faça o teste da "minhoquinha" com terra úmida para descobrir a textura.', style: TextStyle(color: Colors.brown, fontSize: 13))),
            ]),
          ),
          const SizedBox(height: 20),
          _OpcaoManual(titulo: 'Arenoso (Areia)', descricao: 'Esfarela, não forma rolinho e suja pouco a mão.', valor: 'Arenoso', grupo: _resultadoManual, onChanged: (v) => setState(() => _resultadoManual = v), icon: Icons.grain),
          _OpcaoManual(titulo: 'Médio (Franco)', descricao: 'Forma rolinho, mas ele racha ou quebra fácil.', valor: 'Médio', grupo: _resultadoManual, onChanged: (v) => setState(() => _resultadoManual = v), icon: Icons.thumbs_up_down),
          _OpcaoManual(titulo: 'Argiloso (Barro)', descricao: 'Forma rolinho perfeito, flexível (igual massinha).', valor: 'Argiloso', grupo: _resultadoManual, onChanged: (v) => setState(() => _resultadoManual = v), icon: Icons.layers),
        ],
      ),
    );
  }

  Widget _buildAbaLaboratorio() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Copie os números do papel do laboratório:', style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 15),

            _CardGrupo(
              titulo: 'Saúde do Solo',
              cor: Colors.blue,
              icone: Icons.health_and_safety,
              children: [
                Row(children: [
                  Expanded(child: _InputEducativo(
                    controller: _phController, label: 'pH', obrigatorio: true,
                    info: 'Nível de Acidez.\n\n• 0 a 6: Ácido (Precisa corrigir)\n• 7: Neutro\n• Acima de 7: Alcalino'
                  )),
                  const SizedBox(width: 15),
                  Expanded(child: _InputEducativo(
                    controller: _vPercentController, label: 'V% (Saturação)', suffix: '%', obrigatorio: true,
                    info: 'Índice de Fertilidade.\nMostra o quanto o "estômago" do solo está cheio de comida boa.'
                  )),
                ]),
                const SizedBox(height: 15),
                _InputEducativo(
                  controller: _moController, label: 'Matéria Orgânica (M.O.)', suffix: 'g/dm³',
                  info: 'Vida no solo.\nRestos de plantas e organismos. Ajuda a reter água e nutrientes.'
                ),
              ],
            ),

            const SizedBox(height: 20),

            _CardGrupo(
              titulo: 'Nutrientes (Comida)',
              cor: Colors.green,
              icone: Icons.restaurant,
              children: [
                Row(children: [
                  Expanded(child: _InputEducativo(
                    controller: _fosforoController, label: 'Fósforo (P)', suffix: 'mg',
                    info: 'Energia da planta.\nResponsável pelo enraizamento e floração.'
                  )),
                  const SizedBox(width: 15),
                  Expanded(child: _InputEducativo(
                    controller: _potassioController, label: 'Potássio (K)', suffix: 'mmol',
                    info: 'Qualidade do fruto.\nAjuda no tamanho, sabor e resistência a doenças.'
                  )),
                ]),
                const SizedBox(height: 15),
                Row(children: [
                  Expanded(child: _InputEducativo(
                    controller: _calcioController, label: 'Cálcio (Ca)', suffix: 'mmol',
                    info: 'Estrutura.\nForma as "paredes" das células da planta.'
                  )),
                  const SizedBox(width: 15),
                  Expanded(child: _InputEducativo(
                    controller: _magnesioController, label: 'Magnésio (Mg)', suffix: 'mmol',
                    info: 'Fotossíntese.\nFundamental para a cor verde (clorofila).'
                  )),
                ]),
              ],
            ),
             const SizedBox(height: 60), 
          ],
        ),
      ),
    );
  }
}

// WIDGETS AUXILIARES

class _CardGrupo extends StatelessWidget {
  final String titulo;
  final Color cor;
  final IconData icone;
  final List<Widget> children;

  const _CardGrupo({required this.titulo, required this.cor, required this.icone, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: cor.withValues(alpha: 0.05), // Flutter moderno
            blurRadius: 10, 
            offset: const Offset(0, 4)
          )
        ],
      ),
      child: Column(
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cor.withValues(alpha: 0.1), 
                borderRadius: BorderRadius.circular(8)
              ),
              child: Icon(icone, color: cor),
            ),
            const SizedBox(width: 10),
            Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const Divider(height: 30),
          ...children,
        ],
      ),
    );
  }
}

class _InputEducativo extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String info; 
  final String? suffix;
  final bool obrigatorio;

  const _InputEducativo({required this.controller, required this.label, required this.info, this.suffix, this.obrigatorio = false});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: obrigatorio ? '$label *' : label,
        suffixText: suffix,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.fromLTRB(15, 15, 5, 15),
        
        suffixIcon: Tooltip(
          message: info,
          triggerMode: TooltipTriggerMode.tap,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          showDuration: const Duration(seconds: 5),
          decoration: BoxDecoration(color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(color: Colors.white, fontSize: 14),
          child: const Icon(Icons.help_outline, color: Colors.grey),
        ),
      ),
      validator: (value) => (obrigatorio && (value == null || value.isEmpty)) ? 'Obrigatório' : null,
    );
  }
}

class _OpcaoManual extends StatelessWidget {
  final String titulo;
  final String descricao;
  final String valor;
  final String? grupo;
  final IconData icon;
  final ValueChanged<String?> onChanged;

  const _OpcaoManual({required this.titulo, required this.descricao, required this.valor, required this.grupo, required this.icon, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    bool selecionado = valor == grupo;
    return GestureDetector(
      onTap: () => onChanged(valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selecionado ? Colors.green.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selecionado ? Colors.green : Colors.grey.shade300, width: selecionado ? 2 : 1),
          boxShadow: [if (!selecionado) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))], 
        ),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: selecionado ? Colors.green : Colors.grey.shade100, child: Icon(icon, color: selecionado ? Colors.white : Colors.grey)),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: selecionado ? Colors.green.shade800 : Colors.black87)),
                  const SizedBox(height: 4),
                  Text(descricao, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
            ),
            if (selecionado) const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
      ),
    );
  }
}