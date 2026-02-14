import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../app_context_ext.dart';

/// Widget de Esqueleto (Shimmer) para estados de carregamento.
/// Padrão de Excelência: Animado via ShaderMask para alta performance e baixo consumo de bateria.
class AppSkeleton extends StatefulWidget {
  final double height;
  final double width;
  final double radius;

  const AppSkeleton({
    super.key,
    required this.height,
    this.width = double.infinity,
    this.radius = AppTokens.rMd,
  });

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 1500), // Movimento mais suave e natural
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Cores baseadas no Material 3 para garantir suporte a Dark Mode
    final Color baseColor = colors.surfaceContainerHighest.withOpacity(0.4);
    final Color highlightColor =
        colors.surfaceContainerHighest.withOpacity(0.1);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.1, 0.5, 0.9],
              colors: [baseColor, highlightColor, baseColor],
              // Faz o brilho "correr" horizontalmente de forma infinita
              transform:
                  _SlidingGradientTransform(slidePercent: _controller.value),
            ).createShader(bounds);
          },
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color:
                  baseColor, // Cor de fundo sólida para o ShaderMask atuar por cima
              borderRadius: BorderRadius.circular(widget.radius),
            ),
          ),
        );
      },
    );
  }
}

/// Helper para realizar o cálculo matemático do deslocamento do gradiente
class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
        bounds.width * (2 * slidePercent - 1), 0, 0);
  }
}
