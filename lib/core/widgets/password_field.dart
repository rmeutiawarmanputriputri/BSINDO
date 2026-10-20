import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import 'app_text_field.dart';

/// Bentuk kontrol visibilitas kata sandi.
///
/// K-02: gambar Login memakai **switch**, Register memakai **ikon mata**.
/// Default sementara: [eyeIcon] di keduanya. Untuk mengembalikan desain asli
/// Login cukup ubah [kLoginPasswordToggleStyle] menjadi [switchToggle].
enum PasswordToggleStyle { eyeIcon, switchToggle }

/// Gaya toggle untuk layar Login (K-02, menunggu keputusan).
const PasswordToggleStyle kLoginPasswordToggleStyle =
    PasswordToggleStyle.eyeIcon;

/// [AppTextField] + toggle tampil/sembunyikan kata sandi.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.focusNode,
    this.validator,
    this.textInputAction,
    this.autofillHints = const [AutofillHints.password],
    this.enabled = true,
    this.onSubmitted,
    this.toggleStyle = PasswordToggleStyle.eyeIcon,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final FocusNode? focusNode;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final PasswordToggleStyle toggleStyle;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  void _toggle() => setState(() => _obscured = !_obscured);

  @override
  Widget build(BuildContext context) {
    final tooltip =
        _obscured ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi';

    final Widget toggle = switch (widget.toggleStyle) {
      PasswordToggleStyle.eyeIcon => IconButton(
          tooltip: tooltip,
          onPressed: widget.enabled ? _toggle : null,
          icon: Icon(
            _obscured
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 22,
          ),
        ),
      PasswordToggleStyle.switchToggle => Padding(
          padding: const EdgeInsets.only(right: AppSpacing.xs),
          child: Tooltip(
            message: tooltip,
            child: Semantics(
              label: 'Tampilkan kata sandi',
              child: Switch(
                value: !_obscured,
                onChanged: widget.enabled ? (_) => _toggle() : null,
              ),
            ),
          ),
        ),
    };

    return AppTextField(
      label: widget.label,
      controller: widget.controller,
      hintText: widget.hintText,
      focusNode: widget.focusNode,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      keyboardType: TextInputType.visiblePassword,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      enabled: widget.enabled,
      onSubmitted: widget.onSubmitted,
      suffix: toggle,
    );
  }
}
