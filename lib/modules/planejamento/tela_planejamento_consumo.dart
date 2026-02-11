import 'package:flutter/material.dart';
import 'tela_gerador_canteiros.dart'; // Certifique-se de que este arquivo existe

class TelaPlanejamentoConsumo extends StatefulWidget {
  const TelaPlanejamentoConsumo({super.key});

  @override
  State<TelaPlanejamentoConsumo> createState() =>
      _TelaPlanejamentoConsumoState();
}

class _TelaPlanejamentoConsumoState extends State<TelaPlanejamentoConsumo> {
  // --- BASE DE DADOS ENRIQUECIDA E CORRIGIDA (Material Mariana Cantoni) ---
  // Cálculo de espaço baseado em: (Distância Entre Linhas) x (Distância Entre Plantas)
  final Map<String, Map<String, dynamic>> _dadosProdutividade = {
    'Abobrinha italiana': {
      'yield': 2.0, // kg/planta (estimado)
      'unit': 'kg',
      'espaco': 1.0 * 1.0, // Mariana: 1,0 a 1,5 x 0,7 a 1,0 -> Média 1.0m²
      'cat': 'Frutos',
      'info': 'Rica em vitaminas do complexo B.'
    },
    'Abóboras': {
      'yield': 5.0,
      'unit': 'kg',
      'espaco': 3.0 * 2.0, // Mariana: 3,0m x 2,0m = 6.0m² (Ocupa muito espaço!)
      'cat': 'Frutos',
      'info': 'Fonte de betacaroteno e fibras.'
    },
    'Acelga': {
      'yield': 0.8,
      'unit': 'maço',
      'espaco': 0.5 * 0.4, // Mariana: 0,4-0,5 x 0,5 -> 0.2m²
      'cat': 'Folhas',
      'info': 'Ajuda no controle da diabetes.'
    },
    'Alface': {
      'yield': 0.3, // kg (1 pé grande)
      'unit': 'un',
      'espaco': 0.25 * 0.25, // Mariana: 0,25 x 0,25 -> 0.0625m²
      'cat': 'Folhas',
      'info': 'Calmante natural e rico em fibras.'
    },
    'Alho': {
      'yield': 0.04,
      'unit': 'kg',
      'espaco': 0.25 * 0.1, // Mariana: 0,25 x 0,10 -> 0.025m²
      'cat': 'Bulbos',
      'info': 'Antibiótico natural e anti-inflamatório.'
    },
    'Batata doce': {
      'yield': 1.0,
      'unit': 'kg',
      'espaco': 0.9 * 0.3, // Mariana: 0,8-1,0 x 0,3-0,4 -> ~0.27m²
      'cat': 'Raízes',
      'info': 'Carboidrato complexo de baixo índice glicêmico.'
    },
    'Berinjela': {
      'yield': 2.0,
      'unit': 'kg',
      'espaco': 1.0 * 0.8, // Mariana: 1,0 x 0,8 -> 0.8m²
      'cat': 'Frutos',
      'info': 'Rica em antioxidantes e saúde do coração.'
    },
    'Beterraba': {
      'yield': 0.15,
      'unit': 'un', // 1 unidade média
      'espaco': 0.25 * 0.1, // Mariana: 0,25 x 0,1 -> 0.025m²
      'cat': 'Raízes',
      'info': 'Melhora o fluxo sanguíneo e pressão arterial.'
    },
    'Brócolis': {
      'yield': 0.5, // 1 cabeça
      'unit': 'un',
      'espaco': 0.8 * 0.5, // Mariana: 0,8 x 0,5 -> 0.4m²
      'cat': 'Flores',
      'info': 'Alto teor de cálcio e combate radicais livres.'
    },
    'Cebola': {
      'yield': 0.15,
      'unit': 'kg',
      'espaco': 0.3 * 0.1, // Mariana: 0,3 x 0,1 -> 0.03m²
      'cat': 'Bulbos',
      'info': 'Melhora a circulação e imunidade.'
    },
    'Cebolinha': {
      'yield': 0.2,
      'unit': 'maço',
      'espaco': 0.25 * 0.1, // Mariana: 0,20-0,25 x 0,10 -> 0.025m²
      'cat': 'Temperos',
      'info': 'Rica em vitamina A e C.'
    },
    'Cenoura': {
      'yield': 0.1,
      'unit': 'kg',
      'espaco':
          0.25 * 0.05, // Mariana: 0,25 x 0,05 (adensado na linha) -> 0.0125m²
      'cat': 'Raízes',
      'info': 'Essencial para a visão e pele.'
    },
    'Coentro': {
      'yield': 0.2,
      'unit': 'maço',
      'espaco': 0.2 * 0.1, // Mariana: 0,20 x 0,10 -> 0.02m²
      'cat': 'Temperos',
      'info': 'Desintoxicante de metais pesados.'
    },
    'Couve': {
      'yield': 1.5, // Vários maços por ciclo
      'unit': 'maços',
      'espaco': 0.8 * 0.5, // Mariana: 0,8 x 0,5 -> 0.4m²
      'cat': 'Folhas',
      'info': 'Desintoxicante e rica em ferro.'
    },
    'Mandioca': {
      'yield': 3.0,
      'unit': 'kg',
      'espaco': 1.0 * 0.6, // Mariana: 1,0 x 0,6 -> 0.6m²
      'cat': 'Raízes',
      'info': 'Fonte de energia glúten-free.'
    },
    'Pimentão': {
      'yield': 1.0,
      'unit': 'kg',
      'espaco': 1.0 * 0.5, // Mariana: 1,0 x 0,5 -> 0.5m²
      'cat': 'Frutos',
      'info': 'Termogênico e rico em vitamina C.'
    },
    'Quiabo': {
      'yield': 0.8,
      'unit': 'kg',
      'espaco': 1.0 * 0.3, // Mariana: 1,0 x 0,3 -> 0.3m²
      'cat': 'Frutos',
      'info': 'Excelente para digestão e flora intestinal.'
    },
    'Rúcula': {
      'yield': 0.5,
      'unit': 'maço',
      'espaco': 0.2 * 0.05, // Mariana: 0,2 x 0,05 -> 0.01m² (Adensado)
      'cat': 'Folhas',
      'info': 'Picante, digestiva e rica em ômega-3.'
    },
    'Tomate': {
      'yield': 3.0,
      'unit': 'kg',
      'espaco': 1.0 * 0.5, // Mariana: 1,0 x 0,5 -> 0.5m² (Tutorado)
      'cat': 'Frutos',
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
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item atualizado com sucesso!')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Adicione pelo menos um item para planejar!'),
          backgroundColor: Colors.orange));
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
      int mudasReais = (mudasCalc * 1.1).ceil(); // +10% margem de segurança
      double areaNecessaria = mudasReais * espacoVal;

      return {
        'planta': nome,
        'mudas': mudasReais,
        'area': areaNecessaria,
        'evitar': info['evitar'] ?? [],
        'par': info['par'] ?? [],
        'cat': info['cat'] ?? 'Geral'
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

    // Cálculos em tempo real
    double areaTotal = 0;
    double aguaTotal = 0; // Estimativa: 4L/m² (Média)
    double aduboTotal = 0; // Estimativa: 3kg/m² (Média Organo15)

    List<Widget> cards = _listaDesejos.asMap().entries.map((entry) {
      int idx = entry.key;
      Map item = entry.value;
      String nome = item['planta'];
      double meta = item['meta'];

      // Recupera dados ou usa Genérico
      Map<String, dynamic> info = _dadosProdutividade[nome] ??
          {
            'yield': 1.0, // Média genérica
            'unit': 'kg',
            'espaco': 0.5, // Média genérica
            'info': 'Cultura personalizada.'
          };

      double yieldVal = (info['yield'] as num).toDouble();
      double espacoVal = (info['espaco'] as num).toDouble();

      double plantasExatas = meta / yieldVal;
      int plantasReais = (plantasExatas * 1.1).ceil(); // +10% margem
      double areaItem = plantasReais * espacoVal;

      areaTotal += areaItem;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${plantasReais}x',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.green.shade700),
              ),
            ),
          ),
          title: Text(
            nome,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${meta.toStringAsFixed(1)} ${info['unit']} desejados',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.green[300]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      info['info'],
                      style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.green[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Ocupa aprox: ${areaItem.toStringAsFixed(2)} m²',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              )
            ],
          ),
          trailing: PopupMenuButton(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit, size: 18, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Editar')
                ]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Remover')
                ]),
              ),
            ],
            onSelected: (value) {
              if (value == 'edit') _iniciarEdicao(idx);
              if (value == 'delete') _removerItem(idx);
            },
          ),
        ),
      );
    }).toList();

    aguaTotal = areaTotal * 4;
    aduboTotal = areaTotal * 3;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Fundo clean
      appBar: AppBar(
        title: const Text('Planejamento de Consumo',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.green[800],
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- PAINEL DE CONTROLE (INPUT) ---
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(25)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 5))
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
                            : 'O que vamos plantar?',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _editandoIndex != null
                                ? Colors.blue
                                : Colors.grey[800])),
                    if (_editandoIndex != null)
                      TextButton.icon(
                        onPressed: _cancelarEdicao,
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Cancelar'),
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: EdgeInsets.zero),
                      )
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    // Campo de Nome (Dropdown ou Texto)
                    Expanded(
                      flex: 4,
                      child: _modoPersonalizado
                          ? TextField(
                              controller: _customNameController,
                              decoration: InputDecoration(
                                  labelText: 'Nome da Cultura',
                                  hintText: 'Ex: Jiló',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 15, vertical: 15),
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
                              decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 15, vertical: 15),
                                  isDense: true),
                            ),
                    ),

                    // Botão Toggle
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

                    // Campo Quantidade
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _qtdController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: 'Qtd',
                            suffixText: !_modoPersonalizado &&
                                    _culturaSelecionada != null
                                ? _dadosProdutividade[_culturaSelecionada]![
                                    'unit']
                                : 'kg/un',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 15, vertical: 15),
                            isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _salvarItem,
                    icon: Icon(
                        _editandoIndex != null ? Icons.save : Icons.add_circle,
                        color: Colors.white),
                    label: Text(
                        _editandoIndex != null
                            ? 'SALVAR ALTERAÇÕES'
                            : 'ADICIONAR À LISTA',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _editandoIndex != null
                            ? Colors.blue
                            : Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                  ),
                )
              ],
            ),
          ),

          // --- LISTA DE DESEJOS ---
          Expanded(
            child: _listaDesejos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.spa_outlined,
                            size: 80, color: Colors.grey.withOpacity(0.2)),
                        const SizedBox(height: 15),
                        Text('Sua lista está vazia.',
                            style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 5),
                        Text('Adicione o que sua família consome.',
                            style: TextStyle(color: Colors.grey[400])),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      ...cards,
                      const SizedBox(height: 10),

                      // --- PAINEL DE TOTAIS (DASHBOARD) ---
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.green.shade800,
                                  Colors.green.shade600
                                ]),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.green.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8))
                            ]),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.analytics,
                                    color: Colors.white70, size: 18),
                                SizedBox(width: 8),
                                Text('ESTIMATIVA TOTAL DO SISTEMA',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                        fontSize: 12)),
                              ],
                            ),
                            const Divider(color: Colors.white24, height: 25),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _InfoResumo(
                                    icon: Icons.crop_free,
                                    valor: areaTotal.toStringAsFixed(1),
                                    unidade: 'm²',
                                    label: 'Área Útil'),
                                Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.white24),
                                _InfoResumo(
                                    icon: Icons.water_drop,
                                    valor: aguaTotal.toStringAsFixed(0),
                                    unidade: 'L/dia',
                                    label: 'Água Aprox.'),
                                Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.white24),
                                _InfoResumo(
                                    icon: Icons.compost,
                                    valor: aduboTotal.toStringAsFixed(1),
                                    unidade: 'kg',
                                    label: 'Adubo (Organo15)'),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Text(
                                  '💡 Cálculo inclui +10% de margem de segurança.',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic)),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5))
        ]),
        child: ElevatedButton.icon(
          onPressed: _irParaGerador,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('GERAR PLANO INTELIGENTE'),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 4,
              shadowColor: Colors.blue.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))),
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
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(valor,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(width: 2),
            Text(unidade,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }
}
