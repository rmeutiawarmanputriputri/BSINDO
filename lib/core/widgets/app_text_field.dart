import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/tokens.dart';

/// Kolom input dengan label tebal di atas, isi terisi tanpa border,
/// error berupa ikon + teks (DESIGN_SYSTEM.md §5–6, AUTH spec §6).
///
/// Validasi tampil setelah kolom kehilangan fokus (blur) atau setelah
/// `Form.validate()` dipanggil saat submit — tidak saat mengetik pertama kali.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.helperText,
    this.focusNode,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.enabled = true,
    this.suffix,
    this.onSubmitted,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final String? helperText;
  final FocusNode? focusNode;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final bool enabled;

  /// Widget di kanan isian (mis. toggle kata sandi). Harus punya label
  /// semantik sendiri.
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final _fieldKey = GlobalKey<FormFieldState<String>>();
  FocusNode? _ownFocusNode;
  bool _touched = false;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(
        _handleFocusChange,
      );
      _focusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && mounted) {
      // Blur: tandai disentuh dan validasi kolom ini saja.
      setState(() => _touched = true);
      _fieldKey.currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FormField<String>(
      key: _fieldKey,
      initialValue: widget.controller.text,
      validator: widget.validator,
      enabled: widget.enabled,
      autovalidateMode: _touched
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      builder: (field) {
        final errorText = field.errorText;
        final hasError = errorText != null;
        const errorBorder = OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.input)),
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        );
        const errorFocusedBorder = OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.input)),
          borderSide: BorderSide(color: AppColors.error, width: 2),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label visual; untuk pembaca layar label digabung ke kolom
            // lewat Semantics(label:) di bawah agar tidak dibaca dua kali.
            ExcludeSemantics(
              child: Text(widget.label, style: theme.textTheme.labelLarge),
            ),
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              label: widget.label,
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                autofillHints: widget.enabled ? widget.autofillHints : null,
                textCapitalization: widget.textCapitalization,
                autocorrect: widget.autocorrect,
                enableSuggestions: widget.enableSuggestions,
                inputFormatters: widget.inputFormatters,
                style: theme.textTheme.bodyMedium,
                // Ruang ekstra agar kolom aktif + tombol tetap terlihat di
                // atas keyboard.
                scrollPadding: const EdgeInsets.only(
                  top: 120,
                  bottom: 160,
                  left: 20,
                  right: 20,
                ),
                onChanged: field.didChange,
                onSubmitted: widget.onSubmitted,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintMaxLines: 2,
                  suffixIcon: widget.suffix,
                  // Teks error dirender sendiri (ikon + teks) di bawah;
                  // di sini hanya garis tepi merah.
                  enabledBorder: hasError ? errorBorder : null,
                  focusedBorder: hasError ? errorFocusedBorder : null,
                ),
              ),
            ),
            if (errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm - 2),
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: ExcludeSemantics(
                          child: Icon(
                            Icons.error_outline,
                            size: 16,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs + 2),
                      Expanded(
                        child: Text(
                          errorText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (widget.helperText != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm - 2),
                child: Text(
                  widget.helperText!,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        );
      },
    );
  }
}
