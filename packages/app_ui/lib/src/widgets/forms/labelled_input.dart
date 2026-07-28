import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

class LabelledInput extends StatefulWidget {
  const LabelledInput({
    required this.label,
    this.placeholder,
    this.controller,
    this.obscureText,
    this.keyboardType,
    super.key,
    this.value,
    this.onChanged,
    this.errorText,
    this.showPasswordToggle = false,
    this.autofillHints,
  });

  final String label;
  final String? placeholder;
  final String? value;
  final TextInputType? keyboardType;
  final bool? obscureText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final bool showPasswordToggle;
  final Iterable<String>? autofillHints;

  @override
  State<LabelledInput> createState() => _LabelledInputState();
}

class _LabelledInputState extends State<LabelledInput> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          textAlign: TextAlign.left,
          style: AppTextStyle.chip.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        TextField(
          controller: widget.controller,
          autofillHints: widget.autofillHints,
          style: AppTextStyle.title.copyWith(
            color: colorScheme.onSurface,
          ),
          cursorColor: colorScheme.primary,
          onTap: () {},
          keyboardType: widget.keyboardType,
          obscureText: widget.obscureText == true && !_showPassword,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            suffixIcon: widget.showPasswordToggle && widget.obscureText == true
                ? IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility : Icons.visibility_off,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      setState(() {
                        _showPassword = !_showPassword;
                      });
                    },
                  )
                : widget.controller?.text.isNotEmpty == true
                    ? IconButton(
                        icon: Icon(
                          Icons.cancel,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          widget.controller?.clear();
                        },
                      )
                    : null,
            hintText: widget.placeholder,
            hintStyle: AppTextStyle.titleM.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
            ),
            errorText: widget.errorText,
            errorStyle: AppTextStyle.captionL.copyWith(
              color: colorScheme.error,
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colorScheme.primary),
            ),
            filled: false,
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: colorScheme.outlineVariant,
              ),
            ),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: colorScheme.primary),
            ),
          ),
        ),
      ],
    );
  }
}
