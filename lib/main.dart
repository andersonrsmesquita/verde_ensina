import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'core/routing/app_router.dart';
import 'core/ui/app_ui.dart';

import 'core/session/session_controller.dart';
import 'core/session/session_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('🔥 Firebase init error: $e');
  }

  final sessionController = SessionController();
  await sessionController.init();

  runApp(VerdeEnsinaApp(sessionController: sessionController));
}

class VerdeEnsinaApp extends StatefulWidget {
  final SessionController sessionController;
  const VerdeEnsinaApp({super.key, required this.sessionController});

  @override
  State<VerdeEnsinaApp> createState() => _VerdeEnsinaAppState();
}

class _VerdeEnsinaAppState extends State<VerdeEnsinaApp> {
  late final router = AppRouter.buildRouter(widget.sessionController);

  @override
  void dispose() {
    widget.sessionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      controller: widget.sessionController,
      child: MaterialApp.router(
        title: 'Verde Ensina Pro',
        debugShowCheckedModeBanner: false,

        scaffoldMessengerKey: AppMessenger.key,
        routerConfig: router,

        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('pt', 'BR'),
        ],

        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
      ),
    );
  }
}
