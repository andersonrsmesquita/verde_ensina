import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../solo/tela_diagnostico.dart';
import '../calculadoras/tela_calagem.dart';

class TelaDetalhesCanteiro extends StatefulWidget {
  final String canteiroId;
  const TelaDetalhesCanteiro({super.key, required this.canteiroId});

  @override
  State<TelaDetalhesCanteiro> createState() => _TelaDetalhesCanteiroState();
}

class _TelaDetalhesCanteiroState extends State<TelaDetalhesCanteiro> {
  final _nomeController = TextEditingController();
  final _compController = TextEditingController();
  final _largController = TextEditingController();

  // --- BASE TÉCNICA: ADICIONADA CATEGORIA 'cat' ---
  final Map<String, Map<String, dynamic>> _guiaCompleto = {
    // FRUTOS
    'Abobrinha italiana': {
      'cat': 'Frutos',
      'par': 'Milho, Feijão',
      'evitar': 'Batata',
      'ciclo': 55,
      'eLinha': 1.0,
      'ePlanta': 0.7
    },
    'Abobrinha brasileira': {
      'cat': 'Frutos',
      'par': 'Milho, Feijão',
      'evitar': 'Batata',
      'ciclo': 60,
      'eLinha': 2.0,
      'ePlanta': 2.0
    },
    'Abóboras e morangas': {
      'cat': 'Frutos',
      'par': 'Milho, Feijão',
      'evitar': 'Batata',
      'ciclo': 120,
      'eLinha': 3.0,
      'ePlanta': 2.0
    },
    'Tomate': {
      'cat': 'Frutos',
      'par': 'Manjericão, Alho',
      'evitar': 'Batata',
      'ciclo': 110,
      'eLinha': 1.0,
      'ePlanta': 0.3
    },
    'Pepino': {
      'cat': 'Frutos',
      'par': 'Feijão, Milho',
      'evitar': 'Tomate',
      'ciclo': 60,
      'eLinha': 1.0,
      'ePlanta': 0.5
    },
    'Pimenta': {
      'cat': 'Frutos',
      'par': 'Manjericão, Tomate',
      'evitar': 'Feijão',
      'ciclo': 100,
      'eLinha': 1.0,
      'ePlanta': 0.5
    },
    'Pimentão': {
      'cat': 'Frutos',
      'par': 'Manjericão, Cebola',
      'evitar': 'Feijão',
      'ciclo': 100,
      'eLinha': 1.0,
      'ePlanta': 0.5
    },
    'Quiabo': {
      'cat': 'Frutos',
      'par': 'Pimentão, Tomate',
      'evitar': 'Nenhum',
      'ciclo': 80,
      'eLinha': 1.0,
      'ePlanta': 0.3
    },
    'Jiló': {
      'cat': 'Frutos',
      'par': 'Berinjela, Pimentão',
      'evitar': 'Nenhum',
      'ciclo': 100,
      'eLinha': 1.2,
      'ePlanta': 1.0
    },
    'Berinjela': {
      'cat': 'Frutos',
      'par': 'Feijão, Alho',
      'evitar': 'Nenhum',
      'ciclo': 110,
      'eLinha': 1.0,
      'ePlanta': 0.8
    },
    'Melancia': {
      'cat': 'Frutos',
      'par': 'Milho',
      'evitar': 'Nenhum',
      'ciclo': 90,
      'eLinha': 3.0,
      'ePlanta': 2.0
    },
    'Melão': {
      'cat': 'Frutos',
      'par': 'Milho',
      'evitar': 'Nenhum',
      'ciclo': 90,
      'eLinha': 2.0,
      'ePlanta': 1.5
    },
    'Morango': {
      'cat': 'Frutos',
      'par': 'Cebola, Alho',
      'evitar': 'Couve',
      'ciclo': 80,
      'eLinha': 0.35,
      'ePlanta': 0.35
    },
    'Chuchu': {
      'cat': 'Frutos',
      'par': 'Abóbora, Milho',
      'evitar': 'Nenhum',
      'ciclo': 120,
      'eLinha': 5.0,
      'ePlanta': 5.0
    },
    'Ervilha': {
      'cat': 'Frutos',
      'par': 'Cenoura, Milho',
      'evitar': 'Alho, Cebola',
      'ciclo': 80,
      'eLinha': 1.0,
      'ePlanta': 0.5
    }, // Tecnicamente leguminosa, mas tratado como fruto verde na horta doméstica

    // FOLHOSAS E FLORES
    'Alface': {
      'cat': 'Folhosas',
      'par': 'Cenoura, Rabanete',
      'evitar': 'Salsa, Couve',
      'ciclo': 60,
      'eLinha': 0.25,
      'ePlanta': 0.3
    },
    'Acelga': {
      'cat': 'Folhosas',
      'par': 'Alface, Couve',
      'evitar': 'Nenhum',
      'ciclo': 60,
      'eLinha': 0.45,
      'ePlanta': 0.5
    },
    'Agrião': {
      'cat': 'Folhosas',
      'par': 'Nenhum',
      'evitar': 'Nenhum',
      'ciclo': 50,
      'eLinha': 0.2,
      'ePlanta': 0.3
    },
    'Almeirão': {
      'cat': 'Folhosas',
      'par': 'Alface, Cenoura',
      'evitar': 'Nenhum',
      'ciclo': 70,
      'eLinha': 0.25,
      'ePlanta': 0.25
    },
    'Brócolis': {
      'cat': 'Folhosas',
      'par': 'Beterraba, Cebola',
      'evitar': 'Morango',
      'ciclo': 100,
      'eLinha': 0.8,
      'ePlanta': 0.5
    },
    'Chicória': {
      'cat': 'Folhosas',
      'par': 'Alface, Rúcula',
      'evitar': 'Nenhum',
      'ciclo': 70,
      'eLinha': 0.3,
      'ePlanta': 0.3
    },
    'Couve de folha': {
      'cat': 'Folhosas',
      'par': 'Alecrim, Sálvia',
      'evitar': 'Morango, Tomate',
      'ciclo': 80,
      'eLinha': 0.8,
      'ePlanta': 0.5
    },
    'Repolho': {
      'cat': 'Folhosas',
      'par': 'Beterraba, Cebola',
      'evitar': 'Morango',
      'ciclo': 100,
      'eLinha': 0.8,
      'ePlanta': 0.4
    },
    'Rúcula': {
      'cat': 'Folhosas',
      'par': 'Alface, Beterraba',
      'evitar': 'Repolho',
      'ciclo': 40,
      'eLinha': 0.2,
      'ePlanta': 0.1
    },

    // RAÍZES E TUBÉRCULOS
    'Alho': {
      'cat': 'Raízes',
      'par': 'Tomate, Cenoura',
      'evitar': 'Feijão',
      'ciclo': 180,
      'eLinha': 0.25,
      'ePlanta': 0.1
    },
    'Alho poró': {
      'cat': 'Raízes',
      'par': 'Cenoura, Tomate',
      'evitar': 'Feijão',
      'ciclo': 120,
      'eLinha': 0.4,
      'ePlanta': 0.2
    },
    'Batata doce': {
      'cat': 'Raízes',
      'par': 'Abóbora',
      'evitar': 'Tomate',
      'ciclo': 120,
      'eLinha': 0.9,
      'ePlanta': 0.3
    },
    'Beterraba': {
      'cat': 'Raízes',
      'par': 'Cebola, Alface',
      'evitar': 'Milho',
      'ciclo': 70,
      'eLinha': 0.25,
      'ePlanta': 0.1
    },
    'Cará (Inhame)': {
      'cat': 'Raízes',
      'par': 'Nenhum',
      'evitar': 'Nenhum',
      'ciclo': 240,
      'eLinha': 0.8,
      'ePlanta': 0.4
    },
    'Cebola': {
      'cat': 'Raízes',
      'par': 'Beterraba, Tomate',
      'evitar': 'Feijão',
      'ciclo': 140,
      'eLinha': 0.3,
      'ePlanta': 0.1
    },
    'Cenoura': {
      'cat': 'Raízes',
      'par': 'Alface, Tomate',
      'evitar': 'Salsa',
      'ciclo': 100,
      'eLinha': 0.25,
      'ePlanta': 0.1
    },
    'Mandioca': {
      'cat': 'Raízes',
      'par': 'Feijão, Milho',
      'evitar': 'Nenhum',
      'ciclo': 300,
      'eLinha': 3.0,
      'ePlanta': 2.0
    },

    // CONDIMENTOS
    'Cebolinha': {
      'cat': 'Condimentos',
      'par': 'Cenoura, Morango',
      'evitar': 'Feijão',
      'ciclo': 60,
      'eLinha': 0.25,
      'ePlanta': 0.2
    },
    'Coentro': {
      'cat': 'Condimentos',
      'par': 'Tomate',
      'evitar': 'Cenoura',
      'ciclo': 50,
      'eLinha': 0.2,
      'ePlanta': 0.2
    },
    'Salsão (Aipo)': {
      'cat': 'Condimentos',
      'par': 'Tomate, Feijão',
      'evitar': 'Milho',
      'ciclo': 100,
      'eLinha': 0.9,
      'ePlanta': 0.4
    },
  };

  // --- MATRIZ REGIONAL (Mantida) ---
  final Map<String, Map<String, List<String>>> _calendarioRegional = {
    'Sul': {
      'Janeiro': [
        'Abobrinha italiana',
        'Alface',
        'Beterraba',
        'Berinjela',
        'Cebolinha',
        'Tomate',
        'Pimenta',
        'Pimentão',
        'Melancia'
      ],
      'Fevereiro': [
        'Alface',
        'Beterraba',
        'Cebolinha',
        'Couve de folha',
        'Cenoura',
        'Tomate',
        'Pepino',
        'Repolho'
      ],
      'Março': [
        'Abobrinha italiana',
        'Agrião',
        'Almeirão',
        'Acelga',
        'Alface',
        'Alho poró',
        'Beterraba',
        'Brócolis',
        'Cebolinha',
        'Cenoura'
      ],
      'Abril': [
        'Abobrinha italiana',
        'Agrião',
        'Almeirão',
        'Acelga',
        'Alface',
        'Alho poró',
        'Beterraba',
        'Brócolis',
        'Cebolinha',
        'Cenoura'
      ],
      'Maio': [
        'Abobrinha italiana',
        'Agrião',
        'Almeirão',
        'Acelga',
        'Alface',
        'Alho',
        'Beterraba',
        'Cebola',
        'Cenoura'
      ],
      'Junho': [
        'Agrião',
        'Almeirão',
        'Acelga',
        'Alface',
        'Alho',
        'Beterraba',
        'Cebolinha',
        'Cenoura'
      ],
      'Julho': [
        'Agrião',
        'Almeirão',
        'Acelga',
        'Alface',
        'Beterraba',
        'Brócolis',
        'Cebola',
        'Cebolinha',
        'Cenoura'
      ],
      'Agosto': [
        'Agrião',
        'Almeirão',
        'Alface',
        'Beterraba',
        'Brócolis',
        'Cebola',
        'Cebolinha',
        'Cenoura'
      ],
      'Setembro': [
        'Abobrinha italiana',
        'Agrião',
        'Almeirão',
        'Alface',
        'Berinjela',
        'Beterraba',
        'Brócolis',
        'Cebolinha',
        'Coentro'
      ],
      'Outubro': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Agrião',
        'Almeirão',
        'Alface',
        'Batata doce',
        'Berinjela',
        'Beterraba',
        'Chuchu'
      ],
      'Novembro': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Batata doce',
        'Berinjela',
        'Jiló',
        'Beterraba',
        'Brócolis',
        'Cenoura'
      ],
      'Dezembro': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Batata doce',
        'Berinjela',
        'Beterraba',
        'Brócolis',
        'Cebolinha',
        'Cenoura'
      ]
    },
    'Sudeste': {
      'Janeiro': [
        'Abobrinha italiana',
        'Alface',
        'Beterraba',
        'Berinjela',
        'Cebolinha',
        'Tomate',
        'Quiabo',
        'Melão',
        'Melancia'
      ],
      'Fevereiro': [
        'Alface',
        'Beterraba',
        'Berinjela',
        'Cebolinha',
        'Couve de folha',
        'Tomate',
        'Quiabo',
        'Pimentão'
      ],
      'Março': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Acelga',
        'Agrião',
        'Almeirão',
        'Alho',
        'Beterraba',
        'Berinjela'
      ],
      'Abril': [
        'Abobrinha italiana',
        'Alface',
        'Acelga',
        'Agrião',
        'Almeirão',
        'Alho',
        'Beterraba',
        'Cebola',
        'Cebolinha'
      ],
      'Maio': [
        'Abobrinha italiana',
        'Alface',
        'Acelga',
        'Agrião',
        'Almeirão',
        'Alho poró',
        'Beterraba',
        'Cebola',
        'Cebolinha'
      ],
      'Junho': [
        'Alface',
        'Acelga',
        'Agrião',
        'Almeirão',
        'Alho poró',
        'Beterraba',
        'Cebolinha',
        'Chicória'
      ],
      'Julho': [
        'Alface',
        'Acelga',
        'Agrião',
        'Almeirão',
        'Beterraba',
        'Cará (Inhame)',
        'Cebolinha',
        'Chicória'
      ],
      'Agosto': [
        'Abobrinha italiana',
        'Alface',
        'Almeirão',
        'Berinjela',
        'Beterraba',
        'Cará (Inhame)',
        'Cebolinha',
        'Coentro'
      ],
      'Setembro': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Berinjela',
        'Beterraba',
        'Brócolis',
        'Cará (Inhame)',
        'Coentro'
      ],
      'Outubro': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Berinjela',
        'Beterraba',
        'Batata doce',
        'Brócolis',
        'Coentro'
      ],
      'Novembro': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Berinjela',
        'Beterraba',
        'Batata doce',
        'Brócolis',
        'Coentro'
      ],
      'Dezembro': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Berinjela',
        'Beterraba',
        'Batata doce',
        'Brócolis',
        'Coentro'
      ]
    },
    'Nordeste': {
      'Fevereiro': [
        'Alface',
        'Berinjela',
        'Cenoura',
        'Quiabo',
        'Pepino',
        'Pimenta',
        'Tomate'
      ],
      'Janeiro': [
        'Alface',
        'Berinjela',
        'Batata doce',
        'Brócolis',
        'Cenoura',
        'Coentro',
        'Chuchu',
        'Quiabo',
        'Tomate'
      ],
      'Março': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Batata doce',
        'Jiló',
        'Mandioca',
        'Cebolinha',
        'Cebola'
      ],
      'Abril': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Beterraba',
        'Batata doce',
        'Jiló',
        'Couve de folha',
        'Mandioca'
      ],
      'Maio': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Batata doce',
        'Mandioca',
        'Chicória',
        'Couve-flor',
        'Cebolinha'
      ],
      'Junho': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Batata doce',
        'Jiló',
        'Tomate',
        'Cebolinha',
        'Couve de folha'
      ],
      'Julho': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Batata doce',
        'Jiló',
        'Tomate',
        'Chicória',
        'Cebolinha'
      ],
      'Agosto': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Batata doce',
        'Jiló',
        'Tomate',
        'Beterraba',
        'Coentro'
      ],
      'Setembro': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Batata doce',
        'Jiló',
        'Tomate',
        'Coentro',
        'Pimentão'
      ],
      'Outubro': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Batata doce',
        'Tomate',
        'Brócolis',
        'Quiabo',
        'Cenoura'
      ],
      'Novembro': [
        'Alface',
        'Batata doce',
        'Tomate',
        'Brócolis',
        'Quiabo',
        'Cenoura',
        'Coentro',
        'Chuchu'
      ],
      'Dezembro': [
        'Alface',
        'Batata doce',
        'Tomate',
        'Brócolis',
        'Quiabo',
        'Cenoura',
        'Coentro',
        'Chuchu'
      ]
    },
    'Centro-Oeste': {
      'Fevereiro': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Almeirão',
        'Berinjela',
        'Cebola',
        'Brócolis',
        'Couve de folha'
      ],
      'Janeiro': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Berinjela',
        'Brócolis',
        'Cenoura',
        'Coentro',
        'Quiabo'
      ],
      'Março': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Almeirão',
        'Cebola',
        'Alho',
        'Brócolis',
        'Couve de folha'
      ],
      'Abril': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Almeirão',
        'Beterraba',
        'Cebola',
        'Cebolinha',
        'Chicória'
      ],
      'Maio': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Almeirão',
        'Agrião',
        'Cebola',
        'Cebolinha',
        'Chicória'
      ],
      'Junho': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Almeirão',
        'Agrião',
        'Cebolinha',
        'Chicória',
        'Couve de folha'
      ],
      'Julho': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Almeirão',
        'Agrião',
        'Cebolinha',
        'Coentro',
        'Couve de folha'
      ],
      'Agosto': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Almeirão',
        'Berinjela',
        'Cará (Inhame)',
        'Cebolinha',
        'Coentro'
      ],
      'Setembro': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Berinjela',
        'Coentro',
        'Chuchu',
        'Melancia',
        'Melão'
      ],
      'Outubro': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Batata doce',
        'Berinjela',
        'Coentro',
        'Brócolis',
        'Cenoura'
      ],
      'Novembro': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Batata doce',
        'Berinjela',
        'Coentro',
        'Brócolis',
        'Cenoura'
      ],
      'Dezembro': [
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Alface',
        'Batata doce',
        'Berinjela',
        'Coentro',
        'Brócolis',
        'Cenoura'
      ]
    },
    'Norte': {
      'Fevereiro': [
        'Alface',
        'Batata doce',
        'Cenoura',
        'Quiabo',
        'Couve de folha',
        'Cebola'
      ],
      'Janeiro': [
        'Alface',
        'Batata doce',
        'Cenoura',
        'Quiabo',
        'Couve de folha'
      ],
      'Março': [
        'Alface',
        'Batata doce',
        'Cenoura',
        'Chicória',
        'Mandioca',
        'Quiabo',
        'Cebola'
      ],
      'Abril': [
        'Alface',
        'Batata doce',
        'Chicória',
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Almeirão',
        'Mandioca',
        'Quiabo'
      ],
      'Maio': [
        'Alface',
        'Batata doce',
        'Chicória',
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Almeirão',
        'Mandioca',
        'Quiabo'
      ],
      'Junho': [
        'Alface',
        'Batata doce',
        'Chicória',
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Almeirão',
        'Cará (Inhame)',
        'Quiabo'
      ],
      'Julho': [
        'Alface',
        'Batata doce',
        'Chicória',
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Almeirão',
        'Cará (Inhame)',
        'Quiabo'
      ],
      'Agosto': [
        'Alface',
        'Batata doce',
        'Chicória',
        'Abobrinha italiana',
        'Abóboras e morangas',
        'Almeirão',
        'Cará (Inhame)',
        'Quiabo'
      ],
      'Setembro': [
        'Alface',
        'Batata doce',
        'Cará (Inhame)',
        'Quiabo',
        'Pimenta',
        'Cebolinha',
        'Coentro'
      ],
      'Outubro': [
        'Alface',
        'Batata doce',
        'Quiabo',
        'Pimenta',
        'Cebolinha',
        'Coentro',
        'Cenoura'
      ],
      'Novembro': ['Alface', 'Batata doce', 'Quiabo', 'Pimenta', 'Cenoura'],
      'Dezembro': ['Alface', 'Batata doce', 'Quiabo', 'Pimenta', 'Cenoura']
    },
  };

  void _irParaDiagnostico() => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              TelaDiagnostico(canteiroIdOrigem: widget.canteiroId)));
  void _irParaCalagem() => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => TelaCalagem(canteiroIdOrigem: widget.canteiroId)));

  // --- DIÁLOGO DE IRRIGAÇÃO ---
  void _mostrarDialogoIrrigacao() {
    String metodo = 'Gotejamento';
    final tempoController = TextEditingController(text: '30');
    final chuvaController = TextEditingController(text: '0');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 15,
            left: 20,
            right: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Row(children: const [
                Icon(Icons.water_drop, color: Colors.blue, size: 28),
                SizedBox(width: 10),
                Text('Gestão de Irrigação',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))
              ]),
              const SizedBox(height: 20),
              Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.blue.shade100)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🌧️ Controle de Chuva',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent)),
                        const SizedBox(height: 10),
                        TextField(
                            controller: chuvaController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Choveu hoje? (mm)',
                                hintText: 'Ex: 15',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.cloud)),
                            onChanged: (val) {
                              if ((double.tryParse(val) ?? 0) > 10) {
                                ScaffoldMessenger.of(context)
                                    .hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: const Text(
                                        '🛑 ALERTA: Chuva > 10mm! Recomendado ABORTAR a irrigação.'),
                                    backgroundColor: Colors.red.shade800));
                              }
                            }),
                      ])),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                  value: metodo,
                  decoration: const InputDecoration(
                      labelText: 'Sistema Utilizado',
                      border: OutlineInputBorder()),
                  items: ['Manual', 'Gotejamento', 'Aspersão', 'Microaspersão']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => metodo = v!),
              const SizedBox(height: 15),
              TextField(
                  controller: tempoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Tempo de Rega',
                      suffixText: 'minutos',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer))),
              const SizedBox(height: 25),
              SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                      onPressed: () => _salvarIrrigacao(
                          metodo,
                          int.tryParse(tempoController.text) ?? 0,
                          double.tryParse(chuvaController.text) ?? 0),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: const Text('SALVAR DADOS',
                          style: TextStyle(fontWeight: FontWeight.bold))))
            ],
          ),
        ),
      ),
    );
  }

  void _salvarIrrigacao(String metodo, int tempo, double chuva) async {
    if (chuva > 10) {
      await showDialog(
          context: context,
          builder: (c) => AlertDialog(
                  title: const Text('Confirmar?'),
                  content:
                      const Text('Choveu muito. Irrigar pode causar fungos.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('CANCELAR')),
                    TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('REGISTRAR',
                            style: TextStyle(color: Colors.red)))
                  ]));
    }
    await FirebaseFirestore.instance.collection('historico_manejo').add({
      'canteiro_id': widget.canteiroId,
      'uid_usuario': FirebaseAuth.instance.currentUser?.uid,
      'data': FieldValue.serverTimestamp(),
      'tipo_manejo': 'Irrigação',
      'produto': metodo,
      'detalhes': 'Duração: $tempo min | Chuva: ${chuva}mm',
      'quantidade_g': 0
    });
    if (mounted) Navigator.pop(context);
  }

  // --- PLANTIO PROFISSIONAL COM CATEGORIZAÇÃO (NÚCLEO ⚛️) ---
  void _mostrarDialogoPlantio(double cCanteiro, double lCanteiro) {
    List<String> selecionadas = [];
    String regiao = 'Sudeste';
    String mes = 'Fevereiro';
    List<String> todasAsCulturas = _guiaCompleto.keys.toList()..sort();
    final obsController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          // Filtra recomendadas
          List<String> recomendadas = _calendarioRegional[regiao]?[mes] ?? [];
          List<String> outras =
              todasAsCulturas.where((c) => !recomendadas.contains(c)).toList();

          // Agrupa recomendadas por categoria
          Map<String, List<String>> porCategoria = {};
          for (var planta in recomendadas) {
            String cat = _guiaCompleto[planta]?['cat'] ?? 'Outros';
            porCategoria.putIfAbsent(cat, () => []).add(planta);
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Header
                Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2))),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Planejamento de Plantio',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close))
                    ]),
                const Divider(),

                // Filtros
                Row(children: [
                  Expanded(
                      child: DropdownButtonFormField(
                          value: regiao,
                          decoration: const InputDecoration(
                              labelText: 'Região',
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 10)),
                          items: _calendarioRegional.keys
                              .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s,
                                      style: const TextStyle(fontSize: 12))))
                              .toList(),
                          onChanged: (v) => setModalState(() {
                                regiao = v!;
                                selecionadas.clear();
                              }))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: DropdownButtonFormField(
                          value: mes,
                          decoration: const InputDecoration(
                              labelText: 'Mês',
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 10)),
                          items: [
                            'Janeiro',
                            'Fevereiro',
                            'Março',
                            'Abril',
                            'Maio',
                            'Junho',
                            'Julho',
                            'Agosto',
                            'Setembro',
                            'Outubro',
                            'Novembro',
                            'Dezembro'
                          ]
                              .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s,
                                      style: const TextStyle(fontSize: 12))))
                              .toList(),
                          onChanged: (v) => setModalState(() {
                                mes = v!;
                                selecionadas.clear();
                              }))),
                ]),
                const SizedBox(height: 10),

                // Lista de Culturas (Categorizada)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text('✅ Recomendadas para $regiao em $mes',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                      fontSize: 12))),

                          // Renderiza categorias
                          if (porCategoria.isEmpty)
                            const Text(
                                'Nenhuma recomendação específica para este filtro.',
                                style: TextStyle(color: Colors.grey)),
                          ...porCategoria.entries.map((entry) {
                            return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 5),
                                      child: Text(entry.key,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blueGrey))),
                                  Wrap(
                                      spacing: 6,
                                      children: entry.value.map((planta) {
                                        bool isSel =
                                            selecionadas.contains(planta);
                                        return FilterChip(
                                          label: Text(planta),
                                          selected: isSel,
                                          checkmarkColor: Colors.white,
                                          selectedColor: Colors.green,
                                          labelStyle: TextStyle(
                                              color: isSel
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontSize: 11),
                                          onSelected: (v) => setModalState(() =>
                                              v
                                                  ? selecionadas.add(planta)
                                                  : selecionadas
                                                      .remove(planta)),
                                        );
                                      }).toList()),
                                  const SizedBox(height: 10),
                                ]);
                          }),

                          const SizedBox(height: 15),
                          Theme(
                              data: Theme.of(context)
                                  .copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                title: const Text('⚠️ Outras (Fora de Época)',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold)),
                                children: [
                                  Wrap(
                                      spacing: 6,
                                      children: outras.map((planta) {
                                        bool isSel =
                                            selecionadas.contains(planta);
                                        return FilterChip(
                                          label: Text(planta),
                                          selected: isSel,
                                          checkmarkColor: Colors.white,
                                          selectedColor: Colors.orange,
                                          backgroundColor: Colors.grey.shade100,
                                          labelStyle: TextStyle(
                                              color: isSel
                                                  ? Colors.white
                                                  : Colors.grey.shade800,
                                              fontSize: 11),
                                          onSelected: (v) => setModalState(() {
                                            if (v) {
                                              selecionadas.add(planta);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                      content: Text(
                                                          '⚠️ $planta não é ideal agora!'),
                                                      backgroundColor:
                                                          Colors.orange));
                                            } else {
                                              selecionadas.remove(planta);
                                            }
                                          }),
                                        );
                                      }).toList())
                                ],
                              )),

                          // Resumo
                          if (selecionadas.isNotEmpty) ...[
                            const Divider(),
                            Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: Colors.blueGrey.shade50,
                                    borderRadius: BorderRadius.circular(10)),
                                child: Column(children: [
                                  const Row(children: [
                                    Icon(Icons.analytics_outlined, size: 16),
                                    SizedBox(width: 5),
                                    Text('Resumo',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))
                                  ]),
                                  const SizedBox(height: 5),
                                  ...selecionadas.map((p) {
                                    final info = _guiaCompleto[p] ??
                                        {
                                          'ciclo': 90,
                                          'eLinha': 0.5,
                                          'ePlanta': 0.5
                                        };
                                    int mudas = ((cCanteiro * lCanteiro) /
                                            selecionadas.length /
                                            (info['eLinha'] * info['ePlanta']))
                                        .floor();
                                    return Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(p,
                                              style: const TextStyle(
                                                  fontSize: 11)),
                                          Text('$mudas mudas',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11))
                                        ]);
                                  })
                                ])),
                            const SizedBox(height: 10),
                            TextField(
                                controller: obsController,
                                decoration: const InputDecoration(
                                    labelText: 'Observação',
                                    border: OutlineInputBorder(),
                                    contentPadding:
                                        EdgeInsets.symmetric(horizontal: 10))),
                          ]
                        ]),
                  ),
                ),

                if (selecionadas.isNotEmpty)
                  SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: () async {
                          String resumo = "Plantio $regiao/$mes:\n";
                          for (var p in selecionadas) {
                            final info = _guiaCompleto[p]!;
                            int m = ((cCanteiro * lCanteiro) /
                                    selecionadas.length /
                                    (info['eLinha'] * info['ePlanta']))
                                .floor();
                            resumo +=
                                "- $p: $m mudas (${info['ciclo']} dias)\n";
                          }
                          await FirebaseFirestore.instance
                              .collection('historico_manejo')
                              .add({
                            'canteiro_id': widget.canteiroId,
                            'uid_usuario':
                                FirebaseAuth.instance.currentUser?.uid,
                            'data': FieldValue.serverTimestamp(),
                            'tipo_manejo': 'Plantio',
                            'produto': selecionadas.join(' + '),
                            'detalhes': resumo,
                            'observacao_extra': obsController.text,
                            'data_colheita_prevista': Timestamp.fromDate(
                                DateTime.now().add(const Duration(days: 60))),
                            'quantidade_g': 0
                          });
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: const Text('CONFIRMAR'),
                      ))
              ],
            ),
          );
        },
      ),
    );
  }

  // --- MENU DE OPÇÕES (GRID) ---
  void _mostrarOpcoesManejo(double c, double l) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => Container(
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(25))),
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 40),
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(children: [
                Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2))),
                const Text('Menu de Operações',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Expanded(
                    child: GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 15,
                        crossAxisSpacing: 15,
                        childAspectRatio: 1.4,
                        children: [
                      _CardMenu(
                          icon: Icons.water_drop,
                          color: Colors.blue,
                          title: 'Irrigação',
                          subtitle: 'Regar',
                          onTap: () {
                            Navigator.pop(ctx);
                            _mostrarDialogoIrrigacao();
                          }),
                      _CardMenu(
                          icon: Icons.spa,
                          color: Colors.green,
                          title: 'Novo Plantio',
                          subtitle: 'Planejar',
                          onTap: () {
                            Navigator.pop(ctx);
                            _mostrarDialogoPlantio(c, l);
                          }),
                      _CardMenu(
                          icon: Icons.science,
                          color: Colors.brown,
                          title: 'Análise Solo',
                          subtitle: 'Registrar',
                          onTap: () {
                            Navigator.pop(ctx);
                            _irParaDiagnostico();
                          }),
                      _CardMenu(
                          icon: Icons.landscape,
                          color: Colors.orange,
                          title: 'Calagem',
                          subtitle: 'Calcular',
                          onTap: () {
                            Navigator.pop(ctx);
                            _irParaCalagem();
                          }),
                    ]))
              ]),
            ));
  }

  // --- MÉTODOS AUXILIARES ---
  void _editarItem(String id, String detalheAtual, double qtdAtual,
      String tipoManejo, String produtoAtual) {
    final obsController = TextEditingController(text: detalheAtual);
    final qtdController = TextEditingController(
        text: qtdAtual > 0 ? qtdAtual.toStringAsFixed(0) : '');
    bool bloqueiaQtd = tipoManejo.contains('Análise') ||
        tipoManejo == 'Plantio' ||
        tipoManejo == 'Irrigação';
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Editar'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: obsController,
                      decoration: const InputDecoration(labelText: 'Obs')),
                  if (!bloqueiaQtd)
                    TextField(
                        controller: qtdController,
                        decoration: const InputDecoration(labelText: 'Qtd'))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar')),
                  ElevatedButton(
                      onPressed: () {
                        FirebaseFirestore.instance
                            .collection('historico_manejo')
                            .doc(id)
                            .update({
                          'detalhes': obsController.text,
                          if (!bloqueiaQtd)
                            'quantidade_g':
                                double.tryParse(qtdController.text) ?? 0
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('Salvar'))
                ]));
  }

  void _confirmarExclusaoItem(String id) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(title: const Text('Apagar?'), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Não')),
              ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('historico_manejo')
                        .doc(id)
                        .delete();
                    if (mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Sim'))
            ]));
  }

  void _mostrarDialogoEditarCanteiro(Map<String, dynamic> d) {
    _nomeController.text = d['nome'];
    _compController.text = d['comprimento'].toString();
    _largController.text = d['largura'].toString();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Editar Canteiro'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: _nomeController,
                      decoration: const InputDecoration(labelText: 'Nome')),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: _compController,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Comp'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextField(
                            controller: _largController,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Larg')))
                  ])
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar')),
                  ElevatedButton(
                      onPressed: () {
                        final c = double.tryParse(_compController.text) ?? 0;
                        final l = double.tryParse(_largController.text) ?? 0;
                        FirebaseFirestore.instance
                            .collection('canteiros')
                            .doc(widget.canteiroId)
                            .update({
                          'nome': _nomeController.text,
                          'comprimento': c,
                          'largura': l,
                          'area_m2': c * l
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('Salvar'))
                ]));
  }

  void _alternarStatus(bool s) => FirebaseFirestore.instance
      .collection('canteiros')
      .doc(widget.canteiroId)
      .update({'ativo': !s});
  void _confirmarExclusaoCanteiro() {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Excluir Tudo?'),
                content: const Text('Canteiro e histórico serão apagados.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Não')),
                  ElevatedButton(
                      onPressed: () {
                        FirebaseFirestore.instance
                            .collection('canteiros')
                            .doc(widget.canteiroId)
                            .delete();
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Sim'))
                ]));
  }

  String _formatarData(Timestamp? t) {
    if (t == null) return '-';
    DateTime d = t.toDate();
    return '${d.day}/${d.month} ${d.hour}:${d.minute}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('canteiros')
          .doc(widget.canteiroId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        final dados = snapshot.data!.data() as Map<String, dynamic>;
        final bool ativo = dados['ativo'] ?? true;
        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
              title: Text(dados['nome'],
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor:
                  ativo ? Theme.of(context).colorScheme.primary : Colors.grey,
              foregroundColor: Colors.white,
              actions: [
                PopupMenuButton(
                    onSelected: (v) {
                      if (v == 'e') _mostrarDialogoEditarCanteiro(dados);
                      if (v == 's') _alternarStatus(ativo);
                      if (v == 'x') _confirmarExclusaoCanteiro();
                    },
                    itemBuilder: (context) => [
                          const PopupMenuItem(
                              value: 'e', child: Text('Editar')),
                          PopupMenuItem(
                              value: 's',
                              child: Text(ativo ? 'Arquivar' : 'Reativar')),
                          const PopupMenuItem(
                              value: 'x', child: Text('Excluir'))
                        ])
              ]),
          floatingActionButton: ativo
              ? FloatingActionButton.extended(
                  onPressed: () => _mostrarOpcoesManejo(
                      (dados['comprimento'] ?? 0).toDouble(),
                      (dados['largura'] ?? 0).toDouble()),
                  label: const Text('NOVO MANEJO'),
                  icon: const Icon(Icons.add))
              : null,
          body: Column(children: [
            Container(
                padding: const EdgeInsets.all(20),
                color: Colors.white,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _InfoBox(
                          label: 'Área',
                          valor:
                              '${(dados['area_m2'] ?? 0).toStringAsFixed(2)} m²'),
                      _InfoBox(
                          label: 'Dimensões',
                          valor: '${dados['comprimento']}x${dados['largura']}m')
                    ])),
            Expanded(
                child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('historico_manejo')
                        .where('canteiro_id', isEqualTo: widget.canteiroId)
                        .snapshots(),
                    builder: (context, snapH) {
                      if (!snapH.hasData)
                        return const Center(child: CircularProgressIndicator());
                      final list = snapH.data!.docs.toList()
                        ..sort((a, b) => ((b.data() as Map)['data']
                                as Timestamp)
                            .compareTo((a.data() as Map)['data'] as Timestamp));
                      return ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (ctx, i) {
                            final e = list[i].data() as Map<String, dynamic>;
                            return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 15, vertical: 6),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                    leading: CircleAvatar(
                                        backgroundColor:
                                            e['tipo_manejo'] == 'Irrigação'
                                                ? Colors.blue.shade100
                                                : Colors.green.shade100,
                                        child: Icon(
                                            e['tipo_manejo'] == 'Irrigação'
                                                ? Icons.water_drop
                                                : Icons.agriculture,
                                            color: Colors.black54)),
                                    title: Text(e['produto'] ?? ''),
                                    subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(e['detalhes'] ?? ''),
                                          Text(_formatarData(e['data']),
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey)),
                                          if (e['observacao_extra'] != null)
                                            Text(
                                                'Obs: ${e['observacao_extra']}',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    fontStyle:
                                                        FontStyle.italic))
                                        ]),
                                    trailing: IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () => _editarItem(
                                            list[i].id,
                                            e['detalhes'],
                                            (e['quantidade_g'] ?? 0).toDouble(),
                                            e['tipo_manejo'],
                                            e['produto'] ?? ''))));
                          });
                    }))
          ]),
        );
      },
    );
  }
}

// --- WIDGETS DE DESIGN (GRID MENU & INFO BOX) ---
class _CardMenu extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _CardMenu(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
            decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: color.withOpacity(0.2))),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color)),
              Text(subtitle,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600))
            ])));
  }
}

class _InfoBox extends StatelessWidget {
  final String label;
  final String valor;
  const _InfoBox({required this.label, required this.valor});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(valor,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))
    ]);
  }
}
