import 'package:flutter/material.dart';
import 'tela_gerador_canteiros.dart'; // Certifique-se de que este arquivo existe

class TelaPlanejamentoConsumo extends StatefulWidget {
  const TelaPlanejamentoConsumo({super.key});

  @override
  State<TelaPlanejamentoConsumo> createState() =>
      _TelaPlanejamentoConsumoState();
}

class _TelaPlanejamentoConsumoState extends State<TelaPlanejamentoConsumo> {
  // --- BASE DE DADOS ENRIQUECIDA (COM INFO E BENEFÍCIOS) ---
  final Map<String, Map<String, dynamic>> _dadosProdutividade = {
    'Abobrinha italiana': {
      'yield': 2.0,
      'unit': 'kg',
      'espaco': 0.8,
      'cat': 'Frutos',
      'par': ['Milho', 'Feijão'],
      'evitar': ['Batata'],
      'info': 'Rica em vitaminas do complexo B.'
    },
    'Abóboras': {
      'yield': 4.0,
      'unit': 'kg',
      'espaco': 2.0,
      'cat': 'Frutos',
      'par': ['Milho'],
      'evitar': ['Batata'],
      'info': 'Fonte de betacaroteno e fibras.'
    },
    'Acelga': {
      'yield': 1.0,
      'unit': 'maço',
      'espaco': 0.15,
      'cat': 'Folhas',
      'par': ['Couve'],
      'evitar': [],
      'info': 'Ajuda no controle da diabetes.'
    },
    'Alface': {
      'yield': 1.0,
      'unit': 'un',
      'espaco': 0.09,
      'cat': 'Folhas',
      'par': ['Cenoura', 'Rúcula'],
      'evitar': ['Salsa'],
      'info': 'Calmante natural e rico em fibras.'
    },
    'Alho': {
      'yield': 0.05,
      'unit': 'kg',
      'espaco': 0.02,
      'cat': 'Bulbos',
      'par': ['Tomate'],
      'evitar': ['Feijão'],
      'info': 'Antibiótico natural e anti-inflamatório.'
    },
    'Batata doce': {
      'yield': 1.0,
      'unit': 'kg',
      'espaco': 0.3,
      'cat': 'Raízes',
      'par': ['Abóbora'],
      'evitar': ['Tomate'],
      'info': 'Carboidrato complexo de baixo índice glicêmico.'
    },
    'Berinjela': {
      'yield': 2.5,
      'unit': 'kg',
      'espaco': 0.8,
      'cat': 'Frutos',
      'par': ['Feijão'],
      'evitar': [],
      'info': 'Rica em antioxidantes e saúde do coração.'
    },
    'Beterraba': {
      'yield': 0.2,
      'unit': 'un',
      'espaco': 0.025,
      'cat': 'Raízes',
      'par': ['Cebola'],
      'evitar': ['Milho'],
      'info': 'Melhora o fluxo sanguíneo e pressão arterial.'
    },
    'Brócolis': {
      'yield': 0.6,
      'unit': 'un',
      'espaco': 0.4,
      'cat': 'Flores',
      'par': ['Cebola'],
      'evitar': ['Morango'],
      'info': 'Alto teor de cálcio e combate radicais livres.'
    },
    'Cebola': {
      'yield': 0.15,
      'unit': 'kg',
      'espaco': 0.03,
      'cat': 'Bulbos',
      'par': ['Tomate'],
      'evitar': ['Feijão'],
      'info': 'Melhora a circulação e imunidade.'
    },
    'Cebolinha': {
      'yield': 0.3,
      'unit': 'maço',
      'espaco': 0.02,
      'cat': 'Temperos',
      'par': ['Cenoura'],
      'evitar': ['Feijão'],
      'info': 'Rica em vitamina A e C.'
    },
    'Cenoura': {
      'yield': 0.12,
      'unit': 'kg',
      'espaco': 0.02,
      'cat': 'Raízes',
      'par': ['Tomate', 'Ervilha'],
      'evitar': ['Salsa'],
      'info': 'Essencial para a visão e pele.'
    },
    'Coentro': {
      'yield': 0.2,
      'unit': 'maço',
      'espaco': 0.02,
      'cat': 'Temperos',
      'par': ['Tomate'],
      'evitar': ['Cenoura'],
      'info': 'Desintoxicante de metais pesados.'
    },
    'Couve': {
      'yield': 2.0,
      'unit': 'maços',
      'espaco': 0.4,
      'cat': 'Folhas',
      'par': ['Alecrim'],
      'evitar': ['Tomate'],
      'info': 'Desintoxicante e rica em ferro.'
    },
    'Mandioca': {
      'yield': 3.0,
      'unit': 'kg',
      'espaco': 1.0,
      'cat': 'Raízes',
      'par': ['Feijão'],
      'evitar': [],
      'info': 'Fonte de energia glúten-free.'
    },
    'Pimentão': {
      'yield': 1.5,
      'unit': 'kg',
      'espaco': 0.5,
      'cat': 'Frutos',
      'par': ['Cebola'],
      'evitar': ['Feijão'],
      'info': 'Termogênico e rico em vitamina C.'
    },
    'Quiabo': {
      'yield': 0.8,
      'unit': 'kg',
      'espaco': 0.4,
      'cat': 'Frutos',
      'par': ['Pimentão'],
      'evitar': [],
      'info': 'Excelente para digestão e flora intestinal.'
    },
    'Rúcula': {
      'yield': 1.0,
      'unit': 'maço',
      'espaco': 0.05,
      'cat': 'Folhas',
      'par': ['Alface'],
      'evitar': ['Repolho'],
      'info': 'Picante, digestiva e rica em ômega-3.'
    },
    'Tomate': {
      'yield': 3.5,
      'unit': 'kg',
      'espaco': 0.6,
      'cat': 'Frutos',
      'par': ['Manjericão'],
      'evitar': ['Batata', 'Couve'],
      'info': 'Rico em licopeno, previne câncer.'
    },
  };

  final List<Map<String, dynamic>> _listaDesejos = [];

  // Controladores e Estados
  String? _culturaSelecionada;
  final _qtdController = TextEditingController();
  final _customNameController = TextEditingController();

  bool _modoPersonalizado = false; // Se true, usuário digita o nome
  int? _editandoIndex; // Se não nulo, estamos editando este item

  // --- FORMATAÇÃO DE TEXTO (Title Case) ---
  String _formatarTexto(String texto) {
    if (texto.isEmpty) return "";
    return texto.trim().split(' ').map((word) {
      if (word.isEmpty) return "";
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // --- LÓGICA DE ADICIONAR / ATUALIZAR ---
  void _salvarItem() {
    String nomeFinal;

    if (_modoPersonalizado) {
      if (_customNameController.text.isEmpty) return;
      nomeFinal = _formatarTexto(_customNameController.text);
    } else {
      if (_culturaSelecionada == null) return;
      nomeFinal = _culturaSelecionada!;
    }

    if (_qtdController.text.isEmpty) return;
    double qtd =
        double.tryParse(_qtdController.text.replaceAll(',', '.')) ?? 0.0;
    if (qtd <= 0) return;

    setState(() {
      Map<String, dynamic> novoItem = {
        'planta': nomeFinal,
        'meta': qtd,
        'isCustom': _modoPersonalizado
      };

      if (_editandoIndex != null) {
        // Atualiza item existente
        _listaDesejos[_editandoIndex!] = novoItem;
        _editandoIndex = null;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Item atualizado!')));
      } else {
        // Adiciona novo
        _listaDesejos.add(novoItem);
      }

      // Limpa formulário
      _culturaSelecionada = null;
      _qtdController.clear();
      _customNameController.clear();
      _modoPersonalizado = false;
      FocusScope.of(context).unfocus(); // Fecha teclado
    });
  }

  // --- LÓGICA DE EDITAR ---
  void _iniciarEdicao(int index) {
    final item = _listaDesejos[index];
    setState(() {
      _editandoIndex = index;
      _qtdController.text = item['meta'].toString();

      // Verifica se é item do banco ou personalizado
      if (_dadosProdutividade.containsKey(item['planta'])) {
        _modoPersonalizado = false;
        _culturaSelecionada = item['planta'];
      } else {
        _modoPersonalizado = true;
        _customNameController.text = item['planta'];
        _culturaSelecionada = null;
      }
    });
  }

  void _removerItem(int index) {
    setState(() {
      _listaDesejos.removeAt(index);
      if (_editandoIndex == index) {
        _cancelarEdicao(); // Se deletar o que está editando, limpa os inputs
      }
    });
  }

  void _cancelarEdicao() {
    setState(() {
      _editandoIndex = null;
      _culturaSelecionada = null;
      _qtdController.clear();
      _customNameController.clear();
      _modoPersonalizado = false;
      FocusScope.of(context).unfocus();
    });
  }

  // --- NAVEGAÇÃO PARA O GERADOR INTELIGENTE ---
  void _irParaGerador() {
    if (_listaDesejos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adicione itens primeiro!')));
      return;
    }

    // Prepara a lista com dados técnicos para o algoritmo
    List<Map<String, dynamic>> itensProcessados = _listaDesejos.map((item) {
      String nome = item['planta'];
      double meta = item['meta'];
      // Pega dados ou usa padrão seguro
      var info = _dadosProdutividade[nome] ??
          {
            'yield': 1.0,
            'espaco': 0.5,
            'evitar': [],
            'par': [],
            'cat': 'Geral'
          };

      double yieldVal = (info['yield'] as num).toDouble();
      double espacoVal = (info['espaco'] as num).toDouble();

      // Calcula quantas mudas e área
      double mudasCalc = meta / yieldVal;
      int mudasReais = (mudasCalc * 1.2).ceil(); // +20% margem
      double areaNecessaria = mudasReais * espacoVal;

      return {
        'planta': nome,
        'mudas': mudasReais,
        'area': areaNecessaria,
        'evitar': info['evitar'],
        'par': info['par'],
        'cat': info['cat']
      };
    }).toList();

    // Navega!
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                TelaGeradorCanteiros(itensPlanejados: itensProcessados)));
  }

  @override
  Widget build(BuildContext context) {
    // Ordena lista para o dropdown
    List<String> listaCulturasOrdenada = _dadosProdutividade.keys.toList()
      ..sort();

    // Cálculos
    double areaTotal = 0;
    double aguaTotal = 0;
    double aduboTotal = 0;

    List<Widget> cards = _listaDesejos.asMap().entries.map((entry) {
      int idx = entry.key;
      Map item = entry.value;
      String nome = item['planta'];
      double meta = item['meta'];

      // Recupera dados ou usa Genérico
      Map<String, dynamic> info = _dadosProdutividade[nome] ??
          {
            'yield': 1.0,
            'unit': 'kg',
            'espaco': 0.5,
            'info': 'Cultura personalizada (Cálculo estimado).'
          };

      double yieldVal = (info['yield'] as num).toDouble();
      double espacoVal = (info['espaco'] as num).toDouble();

      double plantasExatas = meta / yieldVal;
      int plantasReais = (plantasExatas * 1.2).ceil(); // +20% margem
      double areaItem = plantasReais * espacoVal;

      areaTotal += areaItem;

      return Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    radius: 22,
                    child: Text('${plantasReais}x',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.green)),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nome,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                            '${meta.toStringAsFixed(1)} ${info['unit']} desejados',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                  // AÇÕES: EDITAR E EXCLUIR
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                    onPressed: () => _iniciarEdicao(idx),
                    tooltip: 'Editar',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _removerItem(idx),
                    tooltip: 'Excluir',
                  ),
                ],
              ),
              const Divider(),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.green),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(info['info'],
                        style: const TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Colors.green)),
                  ),
                  Text('Ocupa: ${areaItem.toStringAsFixed(2)} m²',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
        ),
      );
    }).toList();

    aguaTotal = areaTotal * 4;
    aduboTotal = areaTotal * 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculadora de Autossuficiência'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- ÁREA DE INPUT (FORMULÁRIO) ---
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        _editandoIndex != null
                            ? 'Editando Item...'
                            : 'O que você quer comer?',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _editandoIndex != null
                                ? Colors.blue
                                : Colors.black87)),
                    if (_editandoIndex != null)
                      TextButton.icon(
                        onPressed: _cancelarEdicao,
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Cancelar Edição'),
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: EdgeInsets.zero),
                      )
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Campo de Nome (Dropdown ou Texto)
                    Expanded(
                      flex: 3,
                      child: _modoPersonalizado
                          ? TextField(
                              controller: _customNameController,
                              decoration: const InputDecoration(
                                  labelText: 'Nome da Cultura',
                                  hintText: 'Ex: Jiló',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 0),
                                  isDense: true),
                            )
                          : DropdownButtonFormField<String>(
                              value: _culturaSelecionada,
                              hint: const Text('Selecione...'),
                              isExpanded: true,
                              items: listaCulturasOrdenada.map((String key) {
                                return DropdownMenuItem(
                                    value: key,
                                    child: Text(key,
                                        style: const TextStyle(fontSize: 14)));
                              }).toList(),
                              onChanged: (v) =>
                                  setState(() => _culturaSelecionada = v),
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 0),
                                  isDense: true),
                            ),
                    ),

                    // Botão Toggle (Lista vs Manual)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _modoPersonalizado = !_modoPersonalizado;
                          _culturaSelecionada = null;
                          _customNameController.clear();
                        });
                      },
                      tooltip: _modoPersonalizado
                          ? 'Voltar para Lista'
                          : 'Digitar outro',
                      icon: Icon(
                          _modoPersonalizado ? Icons.list : Icons.keyboard,
                          color: Colors.green),
                    ),

                    const SizedBox(width: 5),

                    // Campo Quantidade
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _qtdController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: 'Qtd',
                            // Tenta adivinhar a unidade
                            suffixText: !_modoPersonalizado &&
                                    _culturaSelecionada != null
                                ? _dadosProdutividade[_culturaSelecionada]![
                                    'unit']
                                : 'kg/un',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 0),
                            isDense: true),
                      ),
                    ),
                    const SizedBox(width: 5),

                    // Botão Salvar
                    CircleAvatar(
                      backgroundColor:
                          _editandoIndex != null ? Colors.blue : Colors.green,
                      child: IconButton(
                        onPressed: _salvarItem,
                        icon: Icon(
                            _editandoIndex != null ? Icons.save : Icons.add,
                            color: Colors.white),
                        tooltip: _editandoIndex != null
                            ? 'Salvar Alteração'
                            : 'Adicionar',
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),

          // --- LISTA ---
          Expanded(
            child: _listaDesejos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.eco_outlined,
                            size: 60, color: Colors.green.withOpacity(0.3)),
                        const SizedBox(height: 10),
                        const Text('Sua lista está vazia.',
                            style: TextStyle(color: Colors.grey)),
                        const Text('Adicione o que deseja plantar.',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(15),
                    children: [
                      ...cards,
                      const SizedBox(height: 20),

                      // --- PAINEL DE TOTAIS ---
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.green.shade800,
                              Colors.green.shade600
                            ]),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.green.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6))
                            ]),
                        child: Column(
                          children: [
                            const Text('NECESSIDADE TOTAL DO SISTEMA',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                            const SizedBox(height: 15),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _InfoResumo(
                                    icon: Icons.aspect_ratio,
                                    valor: areaTotal.toStringAsFixed(1),
                                    unidade: 'm²',
                                    label: 'Área Mínima'),
                                _InfoResumo(
                                    icon: Icons.water_drop,
                                    valor: aguaTotal.toStringAsFixed(0),
                                    unidade: 'L/dia',
                                    label: 'Água Aprox.'),
                                _InfoResumo(
                                    icon: Icons.landscape,
                                    valor: aduboTotal.toStringAsFixed(1),
                                    unidade: 'kg',
                                    label: 'Adubo/Ciclo'),
                              ],
                            ),
                            const SizedBox(height: 15),
                            const Text(
                                '⚠️ Cálculo inclui +20% de margem de segurança.',
                                style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic)),
                          ],
                        ),
                      )
                    ],
                  ),
          ),
        ],
      ),

      // BOTÃO DE AÇÃO NO FINAL (GATILHO PARA A INTELIGÊNCIA)
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: const Offset(0, -5))
        ]),
        child: ElevatedButton.icon(
          onPressed: _irParaGerador, // Chama a função que processa os dados
          icon: const Icon(Icons.auto_awesome),
          label: const Text('GERAR PLANO DE CANTEIROS'),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
        ),
      ),
    );
  }
}

class _InfoResumo extends StatelessWidget {
  final IconData icon;
  final String valor;
  final String unidade;
  final String label;

  const _InfoResumo(
      {required this.icon,
      required this.valor,
      required this.unidade,
      required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(valor,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 2),
              child: Text(unidade,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          ],
        ),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}
