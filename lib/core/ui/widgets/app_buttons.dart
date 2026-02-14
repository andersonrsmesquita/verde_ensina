import 'package:flutter/material.dart';

class AppButtons {
  AppButtons._();

  static Widget elevatedIcon({
    required Widget icon,
    required Widget label,
    VoidCallback? onPressed,
    bool loading = false,
    bool fullWidth = false,
    ButtonStyle? style,
  }) {
    final baseStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );

    final mergedStyle = style == null ? baseStyle : baseStyle.merge(style);

    final btn = ElevatedButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : icon,
      label: DefaultTextStyle.merge(
        style: const TextStyle(fontWeight: FontWeight.w800),
        child: label,
      ),
      style: mergedStyle,
    );

    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }

  static Widget outlinedIcon({
    required Widget icon,
    required Widget label,
    VoidCallback? onPressed,
    bool loading = false,
    bool fullWidth = false,
    ButtonStyle? style,
  }) {
    final baseStyle = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );

    final mergedStyle = style == null ? baseStyle : baseStyle.merge(style);

    final btn = OutlinedButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : icon,
      label: DefaultTextStyle.merge(
        style: const TextStyle(fontWeight: FontWeight.w800),
        child: label,
      ),
      style: mergedStyle,
    );

    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }

  static Widget textIcon({
    required Widget icon,
    required Widget label,
    VoidCallback? onPressed,
    bool loading = false,
    bool fullWidth = false,
    ButtonStyle? style,
  }) {
    final baseStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );

    final mergedStyle = style == null ? baseStyle : baseStyle.merge(style);

    final btn = TextButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : icon,
      label: DefaultTextStyle.merge(
        style: const TextStyle(fontWeight: FontWeight.w800),
        child: label,
      ),
      style: mergedStyle,
    );

    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}
