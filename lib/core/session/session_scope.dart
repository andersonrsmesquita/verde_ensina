import 'package:flutter/widgets.dart';
import 'session_controller.dart';

class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({
    super.key,
    required SessionController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  // Esse é o que tu já usas (e que deve ser mantido)
  static SessionController of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(w != null, 'ERRO: SessionScope não encontrado. Verifique se envolveu o app com SessionScope.');
    return w!.notifier!;
  }

  // ✅ (Opcional) Útil se precisares verificar se o controller existe sem gerar erro
  static SessionController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SessionScope>()?.notifier;
  }
}