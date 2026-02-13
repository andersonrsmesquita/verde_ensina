import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final String? hint;

  /// Aceita IconData (ex: Icons.person) OU Widget (ex: Icon(Icons.search))
  final dynamic prefixIcon;

  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool enabled;
  final bool obscureText;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.maxLines = 1,
    this.enabled = true,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
  });

  factory AppTextField.number({
    Key? key,
    required TextEditingController controller,
    String? label,
    String? hint,
    dynamic prefixIcon,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    bool enabled = true,
    ValueChanged<String>? onChanged,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      label: label,
      hint: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      validator: validator,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
        LengthLimitingTextInputFormatter(12),
      ],
      onChanged: onChanged,
    );
  }

  InputDecoration _decoration(BuildContext context) {
    Widget? prefix;
    if (prefixIcon is IconData) {
      prefix = Icon(prefixIcon as IconData);
    } else if (prefixIcon is Widget) {
      prefix = prefixIcon as Widget;
    }

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
      suffixIcon: suffixIcon,
      border: const OutlineInputBorder(),
      isDense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: _decoration(context),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,
      enabled: enabled,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
    );
  }
}
