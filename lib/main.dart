import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
// Import necessário para deixar o Android/iOS em Português
import 'package:flutter_localizations/flutter_localizations.dart'; 

import 'modules/auth/tela_login.dart';
// import 'modules/home/tela_home.dart'; // <-- ANTIGO
import 'modules/home/tela_trilha.dart'; // <-- NOVO: Importamos a Trilha Gamificada

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const VerdeEnsinaApp());
}

class VerdeEnsinaApp extends StatelessWidget {
  const VerdeEnsinaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Verde Ensina Pro',
      debugShowCheckedModeBanner: false,

      // --- CONFIGURAÇÃO DE IDIOMA (PT-BR) ---
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'), // Português do Brasil
      ],

      // --- TEMA VISUAL ---
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // Verde Planta
          secondary: const Color(0xFF795548), // Marrom Terra
          surface: const Color(0xFFF1F8E9),   // Fundo Claro
        ),
        useMaterial3: true,
        
        // Estilo Global dos Botões
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        
        // Estilo Global dos Inputs
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),

      // --- ROTA INTELIGENTE ---
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. Carregando
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // 2. Logado -> Vai para a TRILHA (Gamificação)
          if (snapshot.hasData) {
            return const TelaTrilha(); // <--- MUDANÇA AQUI
          }

          // 3. Deslogado -> Vai para Login
          return const TelaLogin();
        },
      ),
    );
  }
}