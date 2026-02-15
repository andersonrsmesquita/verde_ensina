import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_tokens.dart';
import '../app_context_ext.dart';

enum AppFieldVariant { outline, filled }

/// Campo de texto altamente customizável e integrado ao Design System.
/// ✅ Compatível com chamadas antigas:
/// - labelText / hintText / suffixText
/// - AppTextField.search(...)
/// - AppTextField.dropdown<T>(...)
class AppTextField extends StatefulWidget {
  final TextEditingController controller;

  /// ✅ Padrão novo
  final String? label;
  final String? hint;

  /// ✅ Compatibilidade (mantido como propriedades finais)
  final String? helperText;
  final String? suffixText;

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
    Key? key,
    required this.controller,

    /// ✅ novos
    String? label,
    String? hint,

    /// ✅ antigos (compat)
    String? labelText,
    String? hintText,
    this.helperText,
    this.suffixText,
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
  })  : label = label ?? labelText,
        hint = hint ?? hintText,
        super(key: key);

  // ==========================================
  // FACTORY (mantidos)
  // ==========================================

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
      hint: hint ?? 'ex: contato@verdeensina.com',
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

  // ==========================================
  // ✅ HELPERS ESTÁTICOS (compat com TelaCanteiros)
  // ==========================================

  static Widget search({
    Key? key,
    required TextEditingController controller,
    String? hintText,
    ValueChanged<String>? onChanged,
    VoidCallback? onClear,
    bool enabled = true,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      hintText: hintText ?? 'Buscar...',
      prefixIcon: Icons.search,
      enabled: enabled,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.search,
      showClearButton: true,
      onChanged: onChanged,
      onClear: onClear,
      variant: AppFieldVariant.filled,
    );
  }

  static Widget dropdown<T>({
    Key? key,
    required String labelText,
    required T value,
    required List<DropdownMenuItem<T>> items,
    ValueChanged<T?>? onChanged,
    bool enabled = true,
    String? helperText,
  }) {
    return Builder(
      builder: (context) {
        final colors = context.colors;

        OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTokens.rMd),
              borderSide: BorderSide(color: c, width: w),
            );

        final baseBorderColor = colors.outlineVariant.withOpacity(0.5);

        return DropdownButtonFormField<T>(
          key: key,
          value: value,
          items: items,
          onChanged: enabled ? onChanged : null,
          decoration: InputDecoration(
            labelText: labelText,
            helperText: helperText,
            isDense: true,
            filled: true,
            fillColor: colors.surfaceContainerHighest.withOpacity(0.35),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTokens.md,
              vertical: 16,
            ),
            border: border(baseBorderColor, 1),
            enabledBorder: border(baseBorderColor, 1),
            focusedBorder: border(colors.primary, 1.5),
          ),
          icon: Icon(Icons.expand_more, color: colors.onSurfaceVariant),
        );
      },
    );
  }

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscure;
  bool _hasText = false;
  late FocusNode _innerFocusNode;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
    _hasText = widget.controller.text.trim().isNotEmpty;
    _innerFocusNode = widget.focusNode ?? FocusNode();

    widget.controller.addListener(_handleTextChanged);
    _innerFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    if (widget.focusNode == null) _innerFocusNode.dispose();
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
    final colors = context.colors;

    final Widget? prefixWidget = widget.prefix ??
        (widget.prefixIcon != null
            ? Icon(widget.prefixIcon, size: AppTokens.iconMd)
            : null);

    final List<Widget> suffixWidgets = [];

    if (widget.showPasswordToggle) {
      suffixWidgets.add(
        IconButton(
          tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
          onPressed: widget.enabled
              ? () => setState(() => _obscure = !_obscure)
              : null,
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: AppTokens.iconMd,
          ),
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
          icon: const Icon(Icons.close_rounded, size: AppTokens.iconMd),
        ),
      );
    }

    if (widget.suffix != null) {
      suffixWidgets.add(widget.suffix!);
    } else if (widget.suffixIcon != null) {
      suffixWidgets.add(Icon(widget.suffixIcon, size: AppTokens.iconMd));
    }

    final Widget? suffixWidget = suffixWidgets.isEmpty
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: suffixWidgets
                .map((w) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: w,
                    ))
                .toList(),
          );

    final bool isFilled = widget.variant == AppFieldVariant.filled;
    final bool isFocused = _innerFocusNode.hasFocus;

    OutlineInputBorder border(Color c, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          borderSide: BorderSide(color: c, width: width),
        );

    final baseBorderColor = colors.outlineVariant.withOpacity(0.5);

    return InputDecoration(
      labelText: widget.label,
      hintText: widget.hint,
      helperText: widget.helperText,

      /// ✅ compat com TelaCanteiros (m, L etc)
      suffixText: widget.suffixText,
      suffixStyle: TextStyle(
        color: colors.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),

      prefixIcon: prefixWidget,
      suffixIcon: suffixWidget,
      isDense: true,
      filled: true,
      fillColor: isFocused
          ? colors.primary.withOpacity(0.03)
          : (isFilled
              ? colors.surfaceContainerHighest.withOpacity(0.4)
              : Colors.transparent),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTokens.md,
        vertical: 16,
      ),
      border: border(baseBorderColor, 1),
      enabledBorder: border(baseBorderColor, 1),
      focusedBorder: border(colors.primary, 1.5),
      errorBorder: border(colors.error, 1),
      focusedErrorBorder: border(colors.error, 1.5),
      labelStyle: TextStyle(
        color: isFocused ? colors.primary : colors.onSurfaceVariant,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.text;

    final style = textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: widget.enabled ? null : context.colors.onSurface.withOpacity(0.4),
    );

    return TextFormField(
      controller: widget.controller,
      focusNode: _innerFocusNode,
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
      cursorColor: context.colors.primary,
    );
  }
}
