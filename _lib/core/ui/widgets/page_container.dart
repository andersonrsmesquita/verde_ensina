import 'package:flutter/material.dart';

class PageContainer extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget child;
  final bool scroll;

  const PageContainer({
    super.key,
    required this.title,
    this.actions,
    required this.child,
    this.scroll = true,
  });

  @override
  Widget build(BuildContext context) {
    final body = scroll
        ? SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 950),
                child: child,
              ),
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 950),
                child: child,
              ),
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: actions,
      ),
      body: body,
    );
  }
}
