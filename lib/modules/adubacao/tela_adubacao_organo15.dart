import 'package:flutter/material.dart';
import '../../core/logic/base_agronomica.dart';

class TelaAdubacaoOrgano15 extends StatefulWidget {
  const TelaAdubacaoOrgano15({Key? key}) : super(key: key);

  @override
  _TelaAdubacaoOrgano15State createState() => _TelaAdubacaoOrgano15State();
}

class _TelaAdubacaoOrgano15State extends State<TelaAdubacaoOrgano15> {
  // Controladores
  final _inputController = TextEditingController();

  // Estado
  bool _isCanteiro = true; // Toggle: true = Canteiro, false = Vaso
  String _tipoAdubo = 'bovino';
  bool _isSoloArgiloso = false;

  // Opções de Dropdown
  final Map<String, String> _opcoesAdubo = {
    'bovino': 'Esterco Bovino / Composto',
    'galinha': 'Esterco de Galinha',
    'bokashi': 'Bokashi',
    'mamona': 'Torta de Mamona',
  };

  void _calcular() {
    if (_inputController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, preencha o valor principal.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    double valorInput =
        double.tryParse(_inputController.text.replaceAll(',', '.')) ?? 0;
    Map<String, double> resultado;

    if (_isCanteiro) {
      resultado = BaseAgronomica.calcularAdubacaoCanteiro(
        areaM2: valorInput,
        isSoloArgiloso: _isSoloArgiloso,
        tipoAduboOrganico: _tipoAdubo,
      );
      _mostrarResultadoCanteiro(resultado);
    } else {
      // CORREÇÃO 1: Nome do parâmetro ajustado para 'volumeVasoLitros'
      resultado = BaseAgronomica.calcularMisturaVaso(
        volumeVasoLitros: valorInput,
        tipoAdubo: _tipoAdubo,
      );
      _mostrarResultadoVaso(resultado);
    }
  }

  void _mostrarResultadoCanteiro(Map<String, double> res) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: Colors.white,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // CORREÇÃO 2: CrossAxisAlignment correto
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.eco, color: Color(0xFF2E7D32)),
                  SizedBox(width: 10),
                  Text("Receita Organo15 (Canteiro)",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32))),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              _ItemResultado(
                  titulo: "Adubo Orgânico",
                  valor:
                      "${(res['adubo_organico']! / 1000).toStringAsFixed(2)} kg"),
              _ItemResultado(
                  titulo: "Calcário (Calagem)",
                  valor: "${res['calcario']!.toStringAsFixed(0)} g"),
              _ItemResultado(
                  titulo: "Termofosfato (Yoorin)",
                  valor: "${res['termofosfato']!.toStringAsFixed(0)} g"),
              _ItemResultado(
                  titulo: "Gesso Agrícola (Opcional)",
                  valor: "${res['gesso']!.toStringAsFixed(0)} g"),
              const SizedBox(height: 20),
              const Text(
                "* Aplique o calcário 30 dias antes do plantio se possível.\n* Misture bem nos primeiros 20cm de solo.",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarResultadoVaso(Map<String, double> res) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: Colors.white,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // CORREÇÃO 3: CrossAxisAlignment correto
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.local_florist, color: Color(0xFF2E7D32)),
                  SizedBox(width: 10),
                  Text("Mistura para Vaso",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32))),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              _ItemResultado(
                  titulo: "Terra/Substrato",
                  valor: "${res['terra_litros']!.toStringAsFixed(1)} Litros"),
              _ItemResultado(
                  titulo: "Adubo Orgânico",
                  valor: "${res['adubo_litros']!.toStringAsFixed(1)} Litros"),
              _ItemResultado(
                  titulo: "Calcário",
                  valor: "${res['calcario_gramas']!.toStringAsFixed(1)} g"),
              _ItemResultado(
                  titulo: "Termofosfato",
                  valor: "${res['termofosfato_gramas']!.toStringAsFixed(1)} g"),
              const SizedBox(height: 20),
              const Text(
                "* Misture tudo em uma bacia/lona antes de encher o vaso.\n* Importante: As medidas de Terra e Adubo são em LITROS (Volume).",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Fundo Clean/Pro
      appBar: AppBar(
        title: const Text("Calculadora Organo15"),
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
        foregroundColor: Colors.white, // Garante texto branco no AppBar
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SELETOR DE MODO (CANTEIRO vs VASO)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isCanteiro = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: _isCanteiro
                              ? const Color(0xFF2E7D32)
                              : Colors.white,
                          borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(15)),
                        ),
                        child: Text(
                          "Canteiro (m²)",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _isCanteiro ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isCanteiro = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: !_isCanteiro
                              ? const Color(0xFF2E7D32)
                              : Colors.white,
                          borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(15)),
                        ),
                        child: Text(
                          "Vaso (Litros)",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: !_isCanteiro ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // CARD DE INPUTS
            _CardPersonalizado(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isCanteiro ? "Tamanho da Área" : "Volume do Vaso",
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _inputController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText:
                          _isCanteiro ? "Ex: 5.5 (m²)" : "Ex: 20 (Litros)",
                      suffixText: _isCanteiro ? "m²" : "L",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // TEXTURA DO SOLO (APENAS CANTEIRO)
                  if (_isCanteiro) ...[
                    const Text(
                      "Textura do Solo (Teste da Minhoquinha)",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Solo Argiloso?"),
                      subtitle: const Text(
                          "Ative se a terra forma 'minhoquinha' firme."),
                      value: _isSoloArgiloso,
                      activeColor: const Color(0xFF2E7D32),
                      onChanged: (val) => setState(() => _isSoloArgiloso = val),
                    ),
                    const Divider(),
                    const SizedBox(height: 10),
                  ],

                  // SELETOR DE ADUBO
                  const Text(
                    "Adubo Disponível",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[50],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _tipoAdubo,
                        isExpanded: true,
                        items: _opcoesAdubo.entries.map((e) {
                          return DropdownMenuItem(
                              value: e.key, child: Text(e.value));
                        }).toList(),
                        onChanged: (val) => setState(() => _tipoAdubo = val!),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // BOTÃO CALCULAR
            ElevatedButton(
              onPressed: _calcular,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                elevation: 5,
                shadowColor: const Color(0xFF2E7D32).withOpacity(0.4),
                foregroundColor: Colors.white, // Garante texto branco
              ),
              child: const Text(
                "GERAR RECEITA",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget auxiliar privado para padronizar os Cards (Componentização)
class _CardPersonalizado extends StatelessWidget {
  final Widget child;
  const _CardPersonalizado({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: child,
    );
  }
}

// Widget auxiliar para itens do resultado
class _ItemResultado extends StatelessWidget {
  final String titulo;
  final String valor;

  const _ItemResultado({required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(titulo,
              style: const TextStyle(fontSize: 16, color: Colors.black54)),
          Text(valor,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
        ],
      ),
    );
  }
}
