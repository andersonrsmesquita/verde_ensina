import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importa o sistema de Auth
import 'firebase_options.dart';

// Importa as telas que criamos nas pastas (Módulos)
import 'modules/auth/tela_login.dart';
import 'modules/home/tela_home.dart';

void main() async {
  // 1. Garante que o Flutter está pronto
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Conecta no Firebase (O Cérebro)
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

      // --- IDENTIDADE VISUAL (VERDE E TERRA) ---
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // Verde Planta
          secondary: const Color(0xFF795548), // Marrom Terra
          surface: const Color(0xFFF1F8E9),   // Fundo Claro
        ),
        useMaterial3: true,
        
        // Estilo Global dos Botões (Grandes e Acessíveis)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),

      // --- O "PORTEIRO" VIRTUAL (Gerenciador de Rotas) ---
      home: StreamBuilder<User?>(
        // Fica ouvindo: "O usuário logou? O usuário saiu?"
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          
          // Se estiver carregando a conexão...
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Se tem dados (Usuário logado) -> Vai pra Home
          if (snapshot.hasData) {
            return const TelaHome();
          }

          // Se não tem dados (Deslogado) -> Vai pro Login
          return const TelaLogin();
        },
      ),
    );
  }
}