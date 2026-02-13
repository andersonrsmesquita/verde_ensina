import 'package:flutter/material.dart';

/// Workaround para um bug do Flutter que pode estourar o assert
/// `_dependents.isEmpty` em alguns cenários quando se usa os construtores
/// `*.icon(...)` dos botões.
///
/// Em vez de `ElevatedButton.icon`, a gente usa `ElevatedButton` e monta
/// o conteúdo com `Row`.
class AppButtons {
  AppButtons._();

  static Widget elevatedIcon({
    Key? key,
    required VoidCallback? onPressed,
    required Widget icon,
    required Widget label,
    ButtonStyle? style,
  }) {
    return ElevatedButton(
      key: key,
      onPressed: onPressed,
      style: style,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 8),
          Flexible(child: label),
        ],
      ),
    );
  }

  static Widget outlinedIcon({
    Key? key,
    required VoidCallback? onPressed,
    required Widget icon,
    required Widget label,
    ButtonStyle? style,
  }) {
    return OutlinedButton(
      key: key,
      onPressed: onPressed,
      style: style,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 8),
          Flexible(child: label),
        ],
      ),
    );
  }

  static Widget textIcon({
    Key? key,
    required VoidCallback? onPressed,
    required Widget icon,
    required Widget label,
    ButtonStyle? style,
  }) {
    return TextButton(
      key: key,
      onPressed: onPressed,
      style: style,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 8),
          Flexible(child: label),
        ],
      ),
    );
  }
}
