import 'package:flutter/material.dart';

/// Makes any custom (non-button) widget fully keyboard-accessible.
///
/// Wraps [child] so it is:
///  * focusable via Tab / arrow-key traversal,
///  * activatable with Enter or Space (and still tappable with a pointer),
///  * announced to screen readers as a button (via [semanticLabel]),
///  * drawn with a visible focus ring while focused **by keyboard** (pointer
///    focus does not show the ring, matching platform behaviour).
///
/// The ring is painted as a non-interactive overlay, so enabling focus never
/// shifts layout. Use this in place of a bare `GestureDetector`/`InkWell` on
/// custom tap targets (game cards, selector tiles, gradient CTAs, …).
class FocusableTapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final bool autofocus;
  final BorderRadius borderRadius;

  /// Called when keyboard-focus highlight changes; lets callers reuse their
  /// existing hover animation for focus too (e.g. the game-card scale/glow).
  final ValueChanged<bool>? onFocusChange;

  const FocusableTapper({
    super.key,
    required this.child,
    required this.onPressed,
    this.semanticLabel,
    this.autofocus = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.onFocusChange,
  });

  @override
  State<FocusableTapper> createState() => _FocusableTapperState();
}

class _FocusableTapperState extends State<FocusableTapper> {
  bool _focused = false;

  static const Color _ringColor = Color(0xFFFFF3C4); // starYellow-ish
  static const Color _glowColor = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return FocusableActionDetector(
      enabled: enabled,
      autofocus: widget.autofocus,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (highlighted) {
        if (highlighted != _focused) setState(() => _focused = highlighted);
        widget.onFocusChange?.call(highlighted);
      },
      actions: <Type, Action<Intent>>{
        // Enter / Space are mapped to ActivateIntent by the ambient app
        // shortcuts; route that to the same callback as a tap.
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed?.call();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.semanticLabel,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onPressed,
              child: widget.child,
            ),
            if (_focused)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: widget.borderRadius,
                      border: Border.all(color: _ringColor, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: _glowColor.withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
