import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_tokens.dart';
import '../app_context_ext.dart';

enum AppFieldVariant { outline, filled }

class AppTextField extends StatefulWidget {
  final TextEditingController controller;

  final String? label;
  final String? hint;
  final String? helperText;

  final IconData? prefixIcon;
  final Widget? prefix;
  final IconData? suffixIcon;
  final Widget? suffix;

  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  final int maxLines;
  final int? minLines;
  final int? maxLength;

  final bool enabled;
  final bool readOnly;

  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;

  final AppFieldVariant variant;
  final bool showClearButton;
  final bool showPasswordToggle;

  final FocusNode? focusNode;
  final bool autofocus;

  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.prefixIcon,
    this.prefix,
    this.suffixIcon,
    this.suffix,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onTap,
    this.onClear,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.variant = AppFieldVariant.outline,
    this.showClearButton = true,
    this.showPasswordToggle = false,
    this.focusNode,
    this.autofocus = false,
  });

  factory AppTextField.email({
    Key? key,
    required TextEditingController controller,
    String? label,
    String? hint,
    IconData? prefixIcon = Icons.email_outlined,
    String? helperText,
    String? Function(String?)? validator,
    bool enabled = true,
    ValueChanged<String>? onChanged,
    TextInputAction? textInputAction,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      label: label ?? 'E-mail',
      hint: hint ?? 'ex: contato@empresa.com',
      helperText: helperText,
      prefixIcon: prefixIcon,
      keyboardType: TextInputType.emailAddress,
      textCapitalization: TextCapitalization.none,
      autocorrect: false,
      enableSuggestions: false,
      validator: validator,
      enabled: enabled,
      onChanged: onChanged,
      textInputAction: textInputAction ?? TextInputAction.next,
    );
  }

  factory AppTextField.password({
    Key? key,
    required TextEditingController controller,
    String? label,
    String? hint,
    IconData? prefixIcon = Icons.lock_outline,
    String? helperText,
    String? Function(String?)? validator,
    bool enabled = true,
    ValueChanged<String>? onChanged,
    TextInputAction? textInputAction,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      label: label ?? 'Senha',
      hint: hint ?? 'Digite sua senha',
      helperText: helperText,
      prefixIcon: prefixIcon,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      validator: validator,
      enabled: enabled,
      onChanged: onChanged,
      showPasswordToggle: true,
      textInputAction: textInputAction ?? TextInputAction.done,
    );
  }

  factory AppTextField.number({
    Key? key,
    required TextEditingController controller,
    String? label,
    String? hint,
    IconData? prefixIcon = Icons.numbers_outlined,
    String? helperText,
    String? Function(String?)? validator,
    bool enabled = true,
    ValueChanged<String>? onChanged,
    int maxDigits = 12,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      label: label,
      hint: hint,
      helperText: helperText,
      prefixIcon: prefixIcon,
      validator: validator,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
        LengthLimitingTextInputFormatter(maxDigits),
      ],
      onChanged: onChanged,
      textInputAction: TextInputAction.next,
    );
  }

  factory AppTextField.phoneBR({
    Key? key,
    required TextEditingController controller,
    String? label,
    String? hint,
    IconData? prefixIcon = Icons.phone_outlined,
    String? helperText,
    String? Function(String?)? validator,
    bool enabled = true,
    ValueChanged<String>? onChanged,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      label: label ?? 'Telefone',
      hint: hint ?? '(00) 00000-0000',
      helperText: helperText,
      prefixIcon: prefixIcon,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(11),
      ],
      validator: validator,
      enabled: enabled,
      onChanged: onChanged,
      textInputAction: TextInputAction.next,
    );
  }

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscure;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    super.dispose();
  }

  void _handleTextChanged() {
    final nowHasText = widget.controller.text.trim().isNotEmpty;
    if (nowHasText != _hasText) {
      setState(() => _hasText = nowHasText);
    }
  }

  void _clear() {
    widget.controller.clear();
    widget.onClear?.call();
    widget.onChanged?.call('');
    setState(() => _hasText = false);
  }

  InputDecoration _decoration(BuildContext context) {
    final cs = context.cs;

    final Widget? prefixWidget = widget.prefix ??
        (widget.prefixIcon != null ? Icon(widget.prefixIcon) : null);

    final List<Widget> suffixWidgets = [];

    if (widget.showPasswordToggle) {
      suffixWidgets.add(
        IconButton(
          tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
          onPressed: widget.enabled
              ? () => setState(() => _obscure = !_obscure)
              : null,
          icon: Icon(_obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
        ),
      );
    }

    if (widget.showClearButton &&
        widget.enabled &&
        !widget.readOnly &&
        _hasText &&
        !widget.showPasswordToggle) {
      suffixWidgets.add(
        IconButton(
          tooltip: 'Limpar',
          onPressed: _clear,
          icon: const Icon(Icons.close_rounded),
        ),
      );
    }

    if (widget.suffix != null) {
      suffixWidgets.add(widget.suffix!);
    } else if (widget.suffixIcon != null) {
      suffixWidgets.add(Icon(widget.suffixIcon));
    }

    final Widget? suffixWidget = suffixWidgets.isEmpty
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: suffixWidgets
                .map((w) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: w,
                    ))
                .toList(),
          );

    final bool filled = widget.variant == AppFieldVariant.filled;

    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          borderSide: BorderSide(color: c, width: 1),
        );

    final baseBorderColor = cs.outlineVariant.withOpacity(0.55);

    return InputDecoration(
      labelText: widget.label,
      hintText: widget.hint,
      helperText: widget.helperText,
      prefixIcon: prefixWidget,
      suffixIcon: suffixWidget,
      isDense: true,
      filled: filled,
      fillColor: filled ? cs.surfaceContainerHighest.withOpacity(0.55) : null,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTokens.md,
        vertical: 14,
      ),
      border: border(baseBorderColor),
      enabledBorder: border(baseBorderColor),
      focusedBorder: border(cs.primary),
      errorBorder: border(cs.error),
      focusedErrorBorder: border(cs.error),
      helperMaxLines: 2,
      errorMaxLines: 3,
      counterText: widget.maxLength == null ? '' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;

    final style = tt.bodyLarge?.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.15,
    );

    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      decoration: _decoration(context),
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      validator: widget.validator,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText: _obscure,
      autocorrect: widget.autocorrect,
      enableSuggestions: widget.enableSuggestions,
      textCapitalization: widget.textCapitalization,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onTap: widget.onTap,
      style: style,
    );
  }
}
