import 'package:flutter/material.dart';
import '../app_context_ext.dart';

class AppDivider extends StatelessWidget {
  final double height;
  const AppDivider({super.key, this.height = 1});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: height,
      thickness: 1,
      color: context.cs.outlineVariant.withOpacity(0.40),
    );
  }
}
