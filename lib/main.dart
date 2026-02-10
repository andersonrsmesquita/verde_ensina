import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Importa o Firebase
import 'firebase_options.dart'; // Importa as configurações que você gerou

void main() async {
  // 1. Garante que o Flutter está pronto antes de iniciar
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Conecta no Firebase usando o arquivo gerado
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. Inicia o App
  runApp(const VerdeEnsinaApp());
}

class VerdeEnsinaApp extends StatelessWidget {
  const VerdeEnsinaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Verde Ensina Pro',
      debugShowCheckedModeBanner: false,
      
      // TEMA (Mantivemos o mesmo verde do Blueprint)
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          secondary: const Color(0xFF795548),
          surface: const Color(0xFFF1F8E9),
        ),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      
      home: const TelaInicial(),
    );
  }
}

class TelaInicial extends StatelessWidget {
  const TelaInicial({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Verde Ensina Pro', style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Feedback visual de sucesso
            const Icon(Icons.cloud_done, size: 80, color: Colors.blue), 
            const SizedBox(height: 20),
            
            const Text(
              'Conectado ao Firebase!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('Banco de Dados Pronto para Uso'),
            
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                // Ação futura
              },
              child: const Text('ENTRAR NO SISTEMA'),
            ),
          ],
        ),
      ),
    );
  }
}