import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Imports das telas
import 'modules/auth/tela_login.dart';
import 'modules/home/tela_home.dart'; // A sua nova "Central de Comando"

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
      
      // Configuração de idioma (PT-BR)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],

      // Tema Visual (Verde Profissional)
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // Verde Floresta
          secondary: const Color(0xFF795548), // Marrom Terra
          surface: const Color(0xFFF1F8E9),   // Fundo Suave
        ),
        useMaterial3: true,
        
        // Estilo Padrão dos Botões
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        
        // Estilo Padrão dos Campos de Texto
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),

      // Gerenciador de Login
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. Carregando...
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // 2. Usuário Logado -> Vai para o Super App (TelaHome com Abas)
          if (snapshot.hasData) {
            return const TelaHome(); 
          }

          // 3. Usuário Deslogado -> Vai para Login
          return const TelaLogin();
        },
      ),
    );
  }
}