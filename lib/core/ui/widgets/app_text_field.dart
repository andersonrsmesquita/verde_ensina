import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;
  final String? errorText;

  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;
  final bool enabled;
  final int maxLines;
  final int? maxLength;

  final IconData? prefixIcon;
  final Widget? suffix;

  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.suffix,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      enabled: enabled,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        errorText: errorText,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(0.7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
