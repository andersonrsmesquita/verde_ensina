import 'package:flutter/widgets.dart';
import 'session_controller.dart';
import 'app_session.dart';

class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({
    super.key,
    required SessionController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static SessionController of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(w != null, 'SessionScope não encontrado.');
    return w!.notifier!;
  }

  // ✅ Adicione este método explicitamente
  static AppSession? sessionOf(BuildContext context) => of(context).session;

  static SessionController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SessionScope>()?.notifier;
  }
}
