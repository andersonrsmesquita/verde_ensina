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

  // --- BASE TÉCNICA: CONSÓRCIO + CICLO (REF: PDF PÁG 14-15) ---
  final Map<String, Map<String, dynamic>> _guiaCompleto = {
    'Abobrinha italiana': {
      'par': 'Milho, Feijão',
      'evitar': 'Batata',
      'ciclo': 55,
      'eLinha': 1.0,
      'ePlanta': 0.7
    },
    'Abobrinha brasileira': {
      'par': 'Milho, Feijão',
      'evitar': 'Batata',
      'ciclo': 60,
      'eLinha': 2.0,
      'ePlanta': 2.0
    },
    'Abóboras e morangas': {
      'par': 'Milho, Feijão',
      'evitar': 'Batata',
      'ciclo': 120,
      'eLinha': 3.0,
      'ePlanta': 2.0
    },
    'Acelga': {
      'par': 'Alface, Couve',
      'evitar': 'Nenhum',
      'ciclo': 60,
      'eLinha': 0.45,
      'ePlanta': 0.5
    },
    'Agrião': {
      'par': 'Nenhum',
      'evitar': 'Nenhum',
      'ciclo': 50,
      'eLinha': 0.2,
      'ePlanta': 0.3
    },
    'Salsão (Aipo)': {
      'par': 'Tomate, Feijão',
      'evitar': 'Milho',
      'ciclo': 100,
      'eLinha': 0.9,
      'ePlanta': 0.4
    },
    'Alface': {
      'par': 'Cenoura, Rabanete, Beterraba, Rúcula',
      'evitar': 'Salsa, Couve',
      'ciclo': 60,
      'eLinha': 0.25,
      'ePlanta': 0.3
    },
    'Alho': {
      'par': 'Tomate, Cenoura',
      'evitar': 'Feijão',
      'ciclo': 180,
      'eLinha': 0.25,
      'ePlanta': 0.1
    },
    'Alho poró': {
      'par': 'Cenoura, Tomate',
      'evitar': 'Feijão',
      'ciclo': 120,
      'eLinha': 0.4,
      'ePlanta': 0.2
    },
    'Almeirão': {
      'par': 'Alface, Cenoura',
      'evitar': 'Nenhum',
      'ciclo': 70,
      'eLinha': 0.25,
      'ePlanta': 0.25
    },
    'Batata doce': {
      'par': 'Abóbora',
      'evitar': 'Tomate',
      'ciclo': 120,
      'eLinha': 0.9,
      'ePlanta': 0.3
    },
    'Berinjela': {
      'par': 'Feijão, Alho',
      'evitar': 'Nenhum',
      'ciclo': 110,
      'eLinha': 1.0,
      'ePlanta': 0.8
    },
    'Beterraba': {
      'par': 'Cebola, Alface',
      'evitar': 'Milho',
      'ciclo': 70,
      'eLinha': 0.25,
      'ePlanta': 0.1
    },
    'Brócolis': {
      'par': 'Beterraba, Cebola',
      'evitar': 'Morango',
      'ciclo': 100,
      'eLinha': 0.8,
      'ePlanta': 0.5
    },
    'Cará (Inhame)': {
      'par': 'Nenhum',
      'evitar': 'Nenhum',
      'ciclo': 240,
      'eLinha': 0.8,
      'ePlanta': 0.4
    },
    'Cebola': {
      'par': 'Beterraba, Tomate',
      'evitar': 'Feijão',
      'ciclo': 140,
      'eLinha': 0.3,
      'ePlanta': 0.1
    },
    'Cebolinha': {
      'par': 'Cenoura, Morango',
      'evitar': 'Feijão',
      'ciclo': 60,
      'eLinha': 0.25,
      'ePlanta': 0.2
    },
    'Cenoura': {
      'par': 'Alface, Tomate',
      'evitar': 'Salsa',
      'ciclo': 100,
      'eLinha': 0.25,
      'ePlanta': 0.1
    },
    'Chicória': {
      'par': 'Alface, Rúcula',
      'evitar': 'Nenhum',
      'ciclo': 70,
      'eLinha': 0.3,
      'ePlanta': 0.3
    },
    'Chuchu': {
      'par': 'Abóbora, Milho',
      'evitar': 'Nenhum',
      'ciclo': 120,
      'eLinha': 5.0,
      'ePlanta': 5.0
    },
    'Coentro': {
      'par': 'Tomate',
      'evitar': 'Cenoura',
      'ciclo': 50,
      'eLinha': 0.2,
      'ePlanta': 0.2
    },
    'Couve de folha': {
      'par': 'Alecrim, Sálvia',
      'evitar': 'Morango, Tomate',
      'ciclo': 80,
      'eLinha': 0.8,
      'ePlanta': 0.5
    },
    'Ervilha': {
      'par': 'Cenoura, Milho',
      'evitar': 'Alho, Cebola',
      'ciclo': 80,
      'eLinha': 1.0,
      'ePlanta': 0.5
    },
    'Jiló': {
      'par': 'Berinjela, Pimentão',
      'evitar': 'Nenhum',
      'ciclo': 100,
      'eLinha': 1.2,
      'ePlanta': 1.0
    },
    'Mandioca': {
      'par': 'Feijão, Milho',
      'evitar': 'Nenhum',
      'ciclo': 300,
      'eLinha': 3.0,
      'ePlanta': 2.0
    },
    'Melancia': {
      'par': 'Milho',
      'evitar': 'Nenhum',
      'ciclo': 90,
      'eLinha': 3.0,
      'ePlanta': 2.0
    },
    'Melão': {
      'par': 'Milho',
      'evitar': 'Nenhum',
      'ciclo': 90,
      'eLinha': 2.0,
      'ePlanta': 1.5
    },
    'Morango': {
      'par': 'Cebola, Alho',
      'evitar': 'Couve',
      'ciclo': 80,
      'eLinha': 0.35,
      'ePlanta': 0.35
    },
    'Pepino': {
      'par': 'Feijão, Milho',
      'evitar': 'Tomate',
      'ciclo': 60,
      'eLinha': 1.0,
      'ePlanta': 0.5
    },
    'Pimenta': {
      'par': 'Manjericão, Tomate',
      'evitar': 'Feijão',
      'ciclo': 100,
      'eLinha': 1.0,
      'ePlanta': 0.5
    },
    'Pimentão': {
      'par': 'Manjericão, Cebola',
      'evitar': 'Feijão',
      'ciclo': 100,
      'eLinha': 1.0,
      'ePlanta': 0.5
    },
    'Quiabo': {
      'par': 'Pimentão, Tomate',
      'evitar': 'Nenhum',
      'ciclo': 80,
      'eLinha': 1.0,
      'ePlanta': 0.3
    },
    'Repolho': {
      'par': 'Beterraba, Cebola',
      'evitar': 'Morango',
      'ciclo': 100,
      'eLinha': 0.8,
      'ePlanta': 0.4
    },
    'Rúcula': {
      'par': 'Alface, Beterraba',
      'evitar': 'Repolho',
      'ciclo': 40,
      'eLinha': 0.2,
      'ePlanta': 0.1
    },
    'Tomate': {
      'par': 'Manjericão, Alho',
      'evitar': 'Batata',
      'ciclo': 110,
      'eLinha': 1.0,
      'ePlanta': 0.3
    },
  };

  // --- MATRIZ REGIONAL DE CULTIVO COMPLETA ---
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

  // --- MÓDULO DE IRRIGAÇÃO ---
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
            top: 20,
            left: 20,
            right: 20),
        child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: const [
                  Icon(Icons.water_drop, color: Colors.blue, size: 28),
                  SizedBox(width: 10),
                  Text('Gestão de Irrigação',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold))
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
                                double chuva = double.tryParse(val) ?? 0;
                                if (chuva > 10) {
                                  ScaffoldMessenger.of(context)
                                      .hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: const Text(
                                              '🛑 ALERTA: Chuva > 10mm! Recomendado ABORTAR a irrigação.'),
                                          backgroundColor:
                                              Colors.red.shade800));
                                }
                              }),
                        ])),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                    value: metodo,
                    decoration: const InputDecoration(
                        labelText: 'Sistema Utilizado',
                        border: OutlineInputBorder()),
                    items: [
                      'Manual',
                      'Gotejamento',
                      'Aspersão',
                      'Microaspersão'
                    ]
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
                        onPressed: () async {
                          double chuva =
                              double.tryParse(chuvaController.text) ?? 0;
                          int tempo = int.tryParse(tempoController.text) ?? 0;
                          if (chuva > 10) {
                            showDialog(
                                context: context,
                                builder: (c) => AlertDialog(
                                        title: const Text('Abortar?'),
                                        content: Text(
                                            'Choveu ${chuva}mm. Confirmar rega extra?'),
                                        actions: [
                                          TextButton(
                                              onPressed: () => Navigator.pop(c),
                                              child: const Text('CANCELAR')),
                                          TextButton(
                                              onPressed: () {
                                                Navigator.pop(c);
                                                _salvarIrrigacao(
                                                    metodo, tempo, chuva);
                                              },
                                              child: const Text('REGISTRAR',
                                                  style: TextStyle(
                                                      color: Colors.red)))
                                        ]));
                          } else {
                            _salvarIrrigacao(metodo, tempo, chuva);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: const Text('SALVAR DADOS',
                            style: TextStyle(fontWeight: FontWeight.bold))))
              ]),
        ),
      ),
    );
  }

  void _salvarIrrigacao(String metodo, int tempo, double chuva) async {
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

  // --- PLANTIO PROFISSIONAL (COM MATRIZ COMPLETA E UX PREMIUM) ---
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
          // CORREÇÃO CIRÚRGICA: Ordenação e criação de listas fora do build
          List<String> recomendadas =
              List.from(_calendarioRegional[regiao]?[mes] ?? []);
          recomendadas.sort();
          List<String> outras =
              todasAsCulturas.where((c) => !recomendadas.contains(c)).toList();
          outras.sort();

          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
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
                Row(children: [
                  Expanded(
                      child: DropdownButtonFormField(
                          value: regiao,
                          decoration: const InputDecoration(
                              labelText: 'Região',
                              border: OutlineInputBorder(),
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
                              border: OutlineInputBorder(),
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
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              color: Colors.green.shade50,
                              child: Text('✅ Ideais para $regiao em $mes:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                      fontSize: 12))),
                          Wrap(
                              spacing: 6,
                              children: recomendadas.map((planta) {
                                bool isSel = selecionadas.contains(planta);
                                return FilterChip(
                                    label: Text(planta),
                                    selected: isSel,
                                    checkmarkColor: Colors.white,
                                    selectedColor: Colors.green,
                                    labelStyle: TextStyle(
                                        color:
                                            isSel ? Colors.white : Colors.black,
                                        fontSize: 11),
                                    onSelected: (v) => setModalState(() {
                                          v
                                              ? selecionadas.add(planta)
                                              : selecionadas.remove(planta);
                                        }));
                              }).toList()),
                          const SizedBox(height: 15),
                          Theme(
                              data: Theme.of(context)
                                  .copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                title: const Text('⚠️ Outras Culturas (Risco)',
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
                                    Text('Previsão do Canteiro',
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
                                    labelText: 'Observação do Plantio',
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
                          String resumo = "Plantio ($regiao/$mes):\n";
                          for (var p in selecionadas) {
                            final info = _guiaCompleto[p] ??
                                {'ciclo': 90, 'eLinha': 0.5, 'ePlanta': 0.5};
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
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('✅ Plantio registrado!')));
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: const Text('CONFIRMAR PLANTIO'),
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

  // --- EDIÇÃO INTELIGENTE (CORRIGIDA E SEGURA) ---
  void _editarItem(String id, String detalheAtual, double qtdAtual, String tipo,
      String produtoAtual) {
    final obsController = TextEditingController(text: detalheAtual);
    final qtdController = TextEditingController(
        text: qtdAtual > 0 ? qtdAtual.toStringAsFixed(0) : '');
    List<String> culturasAtuais =
        tipo == 'Plantio' ? produtoAtual.split(' + ') : [];

    // Lista segura e ordenada fora do build
    List<String> todasPlantas = _guiaCompleto.keys.toList()..sort();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Editar Registro'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (tipo == 'Plantio') ...[
                const Text('Culturas Selecionadas:',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
                Wrap(
                  spacing: 6,
                  // Aqui usamos uma lógica segura de filtragem para não quebrar a UI com 30 chips
                  children: todasPlantas
                      .where((p) =>
                          culturasAtuais.contains(p) ||
                          todasPlantas.indexOf(p) < 5)
                      .map((planta) {
                    return ChoiceChip(
                      label: Text(planta, style: const TextStyle(fontSize: 10)),
                      selected: culturasAtuais.contains(planta),
                      onSelected: (v) {
                        setModalState(() {
                          if (v)
                            culturasAtuais.add(planta);
                          else
                            culturasAtuais.remove(planta);
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                  controller: obsController,
                  decoration: const InputDecoration(
                      labelText: 'Observação / Detalhes',
                      border: OutlineInputBorder()),
                  maxLines: 3),
              if (tipo != 'Plantio' && tipo != 'Irrigação') ...[
                const SizedBox(height: 10),
                TextField(
                    controller: qtdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Quantidade',
                        suffixText: 'g',
                        border: OutlineInputBorder()))
              ]
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCELAR')),
            ElevatedButton(
                onPressed: () {
                  FirebaseFirestore.instance
                      .collection('historico_manejo')
                      .doc(id)
                      .update({
                    'detalhes': obsController.text,
                    'produto': tipo == 'Plantio'
                        ? culturasAtuais.join(' + ')
                        : produtoAtual,
                    if (tipo != 'Plantio')
                      'quantidade_g': double.tryParse(qtdController.text) ?? 0
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('SALVAR'))
          ],
        ),
      ),
    );
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
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white),
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
                      decoration: const InputDecoration(
                          labelText: 'Nome', hintText: 'Ex: Canteiro 1')),
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
                          'nome': _nomeController.text.isEmpty
                              ? 'Canteiro 1'
                              : _nomeController.text,
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

  // --- DASHBOARD DE CUIDADOS ---
  Widget _buildDashboard(Map<String, dynamic> dados, double area) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('historico_manejo')
            .where('canteiro_id', isEqualTo: widget.canteiroId)
            .where('tipo_manejo', isEqualTo: 'Plantio')
            .orderBy('data', descending: true)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          String dicas = "Canteiro livre para plantio.";
          String colheita = "-";
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            var ultimo =
                snapshot.data!.docs.first.data() as Map<String, dynamic>;
            dicas =
                "💧 Irrigar conforme chuva.\n💩 Adubo: ${(area * 3).toStringAsFixed(1)}kg esterco (3kg/m²).";
            if (ultimo['data_colheita_prevista'] != null) {
              DateTime d =
                  (ultimo['data_colheita_prevista'] as Timestamp).toDate();
              colheita = "${d.day}/${d.month}/${d.year}";
            }
          }
          return Container(
            margin: const EdgeInsets.all(15),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)
                ]),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${area.toStringAsFixed(1)} m²',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text('Área Total',
                      style: TextStyle(color: Colors.grey, fontSize: 10))
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(colheita,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green)),
                  const Text('Previsão Colheita',
                      style: TextStyle(color: Colors.grey, fontSize: 10))
                ]),
              ]),
              const Divider(height: 20),
              const Text('PLANEJAMENTO DE CUIDADOS:',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey)),
              Text(dicas, style: const TextStyle(fontSize: 12, height: 1.4)),
            ]),
          );
        });
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
        final double comp = (dados['comprimento'] ?? 0).toDouble();
        final double larg = (dados['largura'] ?? 0).toDouble();

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
              title: Text(dados['nome']),
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
                  onPressed: () => _mostrarOpcoesManejo(comp, larg),
                  label: const Text('NOVO MANEJO'),
                  icon: const Icon(Icons.add))
              : null,
          body: Column(children: [
            _buildDashboard(dados, (dados['area_m2'] ?? 0).toDouble()),
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
                                          Text('Obs: ${e['observacao_extra']}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontStyle: FontStyle.italic))
                                      ]),
                                  trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                            icon: const Icon(Icons.edit,
                                                size: 20),
                                            onPressed: () => _editarItem(
                                                list[i].id,
                                                e['detalhes'],
                                                (e['quantidade_g'] ?? 0)
                                                    .toDouble(),
                                                e['tipo_manejo'],
                                                e['produto'] ?? '')),
                                        IconButton(
                                            icon: const Icon(Icons.delete,
                                                size: 20, color: Colors.red),
                                            onPressed: () =>
                                                _confirmarExclusaoItem(
                                                    list[i].id)),
                                      ]),
                                ));
                          });
                    }))
          ]),
        );
      },
    );
  }
}

// --- WIDGETS DE DESIGN ---
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
