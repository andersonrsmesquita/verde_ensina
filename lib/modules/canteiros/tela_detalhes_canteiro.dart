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

  // --- MATRIZ REGIONAL DE CULTIVO COMPLETA (Janeiro a Dezembro) ---
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
      ],
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
      ],
    },
    'Nordeste': {
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
      'Fevereiro': [
        'Alface',
        'Berinjela',
        'Batata doce',
        'Brócolis',
        'Cebola',
        'Almeirão',
        'Cenoura',
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
        'Couve de folha',
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
      ],
    },
    'Centro-Oeste': {
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
      ],
    },
    'Norte': {
      'Janeiro': [
        'Alface',
        'Batata doce',
        'Cenoura',
        'Quiabo',
        'Couve de folha'
      ],
      'Fevereiro': [
        'Alface',
        'Batata doce',
        'Cenoura',
        'Quiabo',
        'Couve de folha',
        'Cebola'
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
      'Dezembro': ['Alface', 'Batata doce', 'Quiabo', 'Pimenta', 'Cenoura'],
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

  // --- DIÁLOGO DE IRRIGAÇÃO INTELIGENTE (COM ALERTA DE CHUVA) ---
  void _mostrarDialogoIrrigacao() {
    String metodo = 'Gotejamento';
    final tempoController = TextEditingController(text: '30');
    final chuvaController = TextEditingController(text: '0');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 25,
            left: 20,
            right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: const [
              Icon(Icons.water_drop, color: Colors.blue, size: 28),
              SizedBox(width: 10),
              Text('Gestão de Irrigação',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))
            ]),
            const SizedBox(height: 20),

            // Pergunta sobre a chuva
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
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text(
                              '🛑 ALERTA: Chuva > 10mm! Recomendado ABORTAR a irrigação.'),
                          backgroundColor: Colors.red.shade800,
                          duration: const Duration(seconds: 5),
                        ));
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text('Configuração da Rega',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              value: metodo,
              decoration: const InputDecoration(
                  labelText: 'Sistema Utilizado', border: OutlineInputBorder()),
              items: ['Manual', 'Gotejamento', 'Aspersão', 'Microaspersão']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => metodo = v!,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: tempoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Tempo de Rega',
                  suffixText: 'minutos',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.timer)),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  double chuva = double.tryParse(chuvaController.text) ?? 0;
                  int tempo = int.tryParse(tempoController.text) ?? 0;

                  if (chuva > 10) {
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Abortar Irrigação?'),
                        content: Text(
                            'Choveu ${chuva}mm. Irrigar agora pode causar fungos. Deseja continuar?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: const Text('CANCELAR')),
                          TextButton(
                              onPressed: () {
                                Navigator.pop(c);
                                _salvarIrrigacao(metodo, tempo, chuva);
                              },
                              child: const Text('REGISTRAR',
                                  style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
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
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
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
      'quantidade_g': 0,
    });
    if (mounted) Navigator.pop(context);
  }

  // --- PLANTIO PROFISSIONAL (COM MATRIZ COMPLETA E UX PREMIUM) ---
  void _mostrarDialogoPlantio(double cCanteiro, double lCanteiro) {
    List<String> selecionadas = [];
    String regiao = 'Sudeste';
    String mes = 'Fevereiro';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          List<String> permitidas = _calendarioRegional[regiao]?[mes] ?? [];
          permitidas.sort();

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Planejamento de Plantio',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close))
                    ]),
                const Divider(),

                // Filtros
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: regiao,
                      decoration: const InputDecoration(
                          labelText: 'Região',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 0)),
                      items: _calendarioRegional.keys
                          .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setModalState(() {
                        regiao = v!;
                        selecionadas.clear();
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: mes,
                      decoration: const InputDecoration(
                          labelText: 'Mês',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 0)),
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
                          .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setModalState(() {
                        mes = v!;
                        selecionadas.clear();
                      }),
                    ),
                  ),
                ]),
                const SizedBox(height: 15),

                // Seleção de Culturas (Chips)
                Text('Culturas Aptas para $regiao em $mes:',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: permitidas.map((planta) {
                        bool isSel = selecionadas.contains(planta);
                        return FilterChip(
                          label: Text(planta),
                          selected: isSel,
                          checkmarkColor: Colors.white,
                          selectedColor: Theme.of(context).colorScheme.primary,
                          labelStyle: TextStyle(
                              color: isSel ? Colors.white : Colors.black),
                          onSelected: (v) => setModalState(() {
                            v
                                ? selecionadas.add(planta)
                                : selecionadas.remove(planta);
                          }),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Resumo Dinâmico
                if (selecionadas.isNotEmpty) ...[
                  const Divider(),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade100)),
                    child: Column(
                      children: [
                        const Row(children: [
                          Icon(Icons.analytics_outlined, color: Colors.green),
                          SizedBox(width: 10),
                          Text('Previsão do Canteiro',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16))
                        ]),
                        const SizedBox(height: 10),
                        ...selecionadas.map((p) {
                          // Se a planta não estiver no guia técnico (ex: faltou mapear), usa valores padrão
                          final info = _guiaCompleto[p] ??
                              {'ciclo': 90, 'eLinha': 0.5, 'ePlanta': 0.5};
                          double areaDisp =
                              (cCanteiro * lCanteiro) / selecionadas.length;
                          int mudas =
                              (areaDisp / (info['eLinha'] * info['ePlanta']))
                                  .floor();
                          DateTime colheita =
                              DateTime.now().add(Duration(days: info['ciclo']));

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('• $p',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500)),
                                Text(
                                    '$mudas mudas (Colheita: ${colheita.day}/${colheita.month})',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.black87)),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        String resumo = "Plantio Regional ($regiao/$mes):\n";
                        for (var p in selecionadas) {
                          final info = _guiaCompleto[p] ??
                              {'ciclo': 90, 'eLinha': 0.5, 'ePlanta': 0.5};
                          double area =
                              (cCanteiro * lCanteiro) / selecionadas.length;
                          int m = (area / (info['eLinha'] * info['ePlanta']))
                              .floor();
                          resumo +=
                              "- $p: $m mudas. Ciclo ${info['ciclo']} dias.\n";
                        }

                        await FirebaseFirestore.instance
                            .collection('historico_manejo')
                            .add({
                          'canteiro_id': widget.canteiroId,
                          'uid_usuario': FirebaseAuth.instance.currentUser?.uid,
                          'data': FieldValue.serverTimestamp(),
                          'tipo_manejo': 'Plantio',
                          'produto': selecionadas.join(' + '),
                          'detalhes': resumo,
                          'data_colheita_prevista': Timestamp.fromDate(
                              DateTime.now().add(const Duration(days: 60))),
                          'quantidade_g': 0,
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('✅ Plantio registrado com sucesso!')));
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: const Text('CONFIRMAR PLANTIO',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                ]
              ],
            ),
          );
        },
      ),
    );
  }

  // --- MENU DE OPÇÕES ---
  void _mostrarOpcoesManejo(double c, double l) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const Text('Menu de Operações',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _ItemMenu(
                icon: Icons.water_drop,
                color: Colors.blue,
                title: 'Irrigação & Chuva',
                subtitle: 'Controle hídrico diário',
                onTap: () {
                  Navigator.pop(ctx);
                  _mostrarDialogoIrrigacao();
                }),
            _ItemMenu(
                icon: Icons.spa,
                color: Colors.green,
                title: 'Novo Plantio',
                subtitle: 'Planejamento regional e mudas',
                onTap: () {
                  Navigator.pop(ctx);
                  _mostrarDialogoPlantio(c, l);
                }),
            const Divider(height: 30),
            _ItemMenu(
                icon: Icons.science,
                color: Colors.brown,
                title: 'Análise de Solo',
                subtitle: null,
                onTap: () {
                  Navigator.pop(ctx);
                  _irParaDiagnostico();
                }),
            _ItemMenu(
                icon: Icons.landscape,
                color: Colors.orange,
                title: 'Calculadora de Calagem',
                subtitle: null,
                onTap: () {
                  Navigator.pop(ctx);
                  _irParaCalagem();
                }),
          ],
        ),
      ),
    );
  }

  // --- MÉTODOS AUXILIARES (EDITAR, EXCLUIR, FORMATAR) MANTIDOS ---
  void _editarItem(
      String id, String detalheAtual, double qtdAtual, String tipoManejo) {
    final obsController = TextEditingController(text: detalheAtual);
    final qtdController = TextEditingController(
        text: qtdAtual > 0 ? qtdAtual.toStringAsFixed(0) : '');
    bool bloqueiaQtd = tipoManejo.contains('Análise') ||
        tipoManejo == 'Plantio' ||
        tipoManejo == 'Irrigação';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Registro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: obsController,
                decoration: const InputDecoration(
                    labelText: 'Observação', border: OutlineInputBorder()),
                maxLines: 2),
            if (!bloqueiaQtd) ...[
              const SizedBox(height: 15),
              TextField(
                  controller: qtdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Quantidade',
                      suffixText: 'g',
                      border: OutlineInputBorder()))
            ]
          ],
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
                  if (!bloqueiaQtd)
                    'quantidade_g': double.tryParse(qtdController.text) ?? 0
                });
                Navigator.pop(ctx);
              },
              child: const Text('SALVAR'))
        ],
      ),
    );
  }

  void _confirmarExclusaoItem(String idItem) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar registro?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCELAR')),
          ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('historico_manejo')
                    .doc(idItem)
                    .delete();
                if (mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('APAGAR')),
        ],
      ),
    );
  }

  void _mostrarDialogoEditarCanteiro(Map<String, dynamic> dadosAtuais) {
    _nomeController.text = dadosAtuais['nome'];
    _compController.text = dadosAtuais['comprimento'].toString();
    _largController.text = dadosAtuais['largura'].toString();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Configurar Canteiro'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: _nomeController,
                      decoration: const InputDecoration(labelText: 'Nome')),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: _compController,
                            decoration:
                                const InputDecoration(labelText: 'Comp.'),
                            keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextField(
                            controller: _largController,
                            decoration:
                                const InputDecoration(labelText: 'Larg.'),
                            keyboardType: TextInputType.number))
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
                      child: const Text('SALVAR'))
                ]));
  }

  void _alternarStatus(bool s) => FirebaseFirestore.instance
      .collection('canteiros')
      .doc(widget.canteiroId)
      .update({'ativo': !s});
  void _confirmarExclusaoCanteiro() {
    showDialog(
        context: context,
        builder: (ctx) =>
            AlertDialog(title: const Text('Excluir Canteiro?'), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar')),
              ElevatedButton(
                  onPressed: () {
                    FirebaseFirestore.instance
                        .collection('canteiros')
                        .doc(widget.canteiroId)
                        .delete();
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('EXCLUIR'))
            ]));
  }

  String _formatarData(Timestamp? t) {
    if (t == null) return '-';
    DateTime d = t.toDate();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} às ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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
        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
              title: Text(dados['nome'],
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: (dados['ativo'] ?? true)
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
              foregroundColor: Colors.white,
              actions: [
                PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'e') _mostrarDialogoEditarCanteiro(dados);
                      if (v == 's') _alternarStatus(dados['ativo'] ?? true);
                      if (v == 'x') _confirmarExclusaoCanteiro();
                    },
                    itemBuilder: (context) => [
                          const PopupMenuItem(
                              value: 'e', child: Text('Editar')),
                          PopupMenuItem(
                              value: 's',
                              child: Text((dados['ativo'] ?? true)
                                  ? 'Arquivar'
                                  : 'Reativar')),
                          const PopupMenuItem(
                              value: 'x',
                              child: Text('Excluir',
                                  style: TextStyle(color: Colors.red)))
                        ])
              ]),
          floatingActionButton: (dados['ativo'] ?? true)
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
                                        child:
                                            Icon(e['tipo_manejo'] == 'Irrigação' ? Icons.water_drop : Icons.agriculture,
                                                color: Colors.black54)),
                                    title: Text(e['produto'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(e['detalhes'] ?? ''),
                                          Text(_formatarData(e['data']),
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey))
                                        ]),
                                    trailing: IconButton(
                                        icon: const Icon(Icons.more_vert),
                                        onPressed: () => _editarItem(
                                            list[i].id,
                                            e['detalhes'],
                                            (e['quantidade_g'] ?? 0).toDouble(),
                                            e['tipo_manejo']))));
                          });
                    }))
          ]),
        );
      },
    );
  }
}

class _ItemMenu extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _ItemMenu(
      {required this.icon,
      required this.color,
      required this.title,
      this.subtitle,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
        leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        onTap: onTap);
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
