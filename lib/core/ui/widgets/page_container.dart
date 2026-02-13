import 'package:flutter/material.dart';

class PageContainer extends StatelessWidget {
  final String? title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool center;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final bool safeArea;

  const PageContainer({
    super.key,
    this.title,
    required this.child,
    this.actions,
    this.floatingActionButton,
    this.center = true,
    this.maxWidth = 980,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 24),
    this.safeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final body = Container(
      width: double.infinity,
      color: scheme.surface,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: title == null
          ? null
          : AppBar(
              title: Text(title!),
              actions: actions,
            ),
      floatingActionButton: floatingActionButton,
      body: safeArea ? SafeArea(child: body) : body,
    );
  }
}
