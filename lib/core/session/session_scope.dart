import 'package:flutter/widgets.dart';
import 'session_controller.dart';

class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({
    super.key,
    required SessionController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static SessionController of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(w != null, 'SessionScope não encontrado. Envolva seu app com SessionScope.');
    return w!.notifier!;
  }
}
