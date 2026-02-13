import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'core/routing/app_router.dart';
import 'package:verde_ensina/core/ui/app_ui.dart';

Future<void> main() async {
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
    return MaterialApp.router(
      title: 'Verde Ensina Pro',
      debugShowCheckedModeBanner: false,

      // ✅ SnackBar global
      scaffoldMessengerKey: AppMessenger.key,

      routerConfig: AppRouter.router,

      // PT-BR
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],

      // ✅ Tema global premium
      theme: AppTheme.light(),
    );
  }
}
