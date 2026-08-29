import 'package:flutter/material.dart';

/// Represents one selectable option inside a [ConectaSegmentedSelector].
class ConectaSegmentedItem<T> {
  /// Creates a segmented selector item.
  const ConectaSegmentedItem({
    required this.value,
    required this.label,
  });

  /// Value returned when this item is selected.
  final T value;

  /// Visible label for this item.
  final String label;
}

/// Displays a compact tonal segmented selector using Conecta ITT styling.
class ConectaSegmentedSelector<T> extends StatefulWidget {
  /// Creates a Conecta ITT segmented selector.
  const ConectaSegmentedSelector({
    required this.items,
    required this.selectedValue,
    required this.onChanged,
    this.height = 46,
    super.key,
  });

  /// Options displayed by the selector.
  final List<ConectaSegmentedItem<T>> items;

  /// Currently selected option value.
  final T selectedValue;

  /// Called when the user selects a different option.
  ///
  /// When null, the selector is disabled.
  final ValueChanged<T>? onChanged;

  /// Total height of the selector.
  final double height;

  @override
  State<ConectaSegmentedSelector<T>> createState() =>
      _ConectaSegmentedSelectorState<T>();
}

class _ConectaSegmentedSelectorState<T>
    extends State<ConectaSegmentedSelector<T>> {
  late T _visualSelectedValue;

  @override
  void initState() {
    super.initState();
    _visualSelectedValue = widget.selectedValue;
  }

  @override
  void didUpdateWidget(
    covariant ConectaSegmentedSelector<T> oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (widget.selectedValue != oldWidget.selectedValue &&
        widget.selectedValue != _visualSelectedValue) {
      _visualSelectedValue = widget.selectedValue;
    }
  }

  void _select(T value) {
    if (widget.onChanged == null || value == _visualSelectedValue) {
      return;
    }

    setState(() {
      _visualSelectedValue = value;
    });

    widget.onChanged!(value);
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.items.isNotEmpty,
      'ConectaSegmentedSelector requires at least one item.',
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final rawIndex = widget.items.indexWhere(
      (item) => item.value == _visualSelectedValue,
    );
    final selectedIndex = rawIndex < 0 ? 0 : rawIndex;

    final selectedAlignment = widget.items.length == 1
        ? Alignment.center
        : Alignment(
            -1 + (2 * selectedIndex / (widget.items.length - 1)),
            0,
          );

    return Container(
      height: widget.height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.46,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / widget.items.length;

          return Stack(
            children: [
              AnimatedAlign(
                alignment: selectedAlignment,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: SizedBox(
                  width: itemWidth,
                  height: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colorScheme.surface.withValues(
                              alpha: 0.94,
                            ),
                            colorScheme.surface.withValues(
                              alpha: 0.82,
                            ),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: 0.045,
                            ),
                            blurRadius: 7,
                            offset: const Offset(0, 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final item in widget.items)
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onChanged == null
                              ? null
                              : () => _select(item.value),
                          borderRadius: BorderRadius.circular(12),
                          splashColor: colorScheme.primary.withValues(
                            alpha: 0.04,
                          ),
                          highlightColor: colorScheme.primary.withValues(
                            alpha: 0.025,
                          ),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(
                                milliseconds: 180,
                              ),
                              curve: Curves.easeOutCubic,
                              style: (theme.textTheme.labelLarge ??
                                      const TextStyle())
                                  .copyWith(
                                fontWeight: item.value == _visualSelectedValue
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: item.value == _visualSelectedValue
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant.withValues(
                                        alpha: 0.82,
                                      ),
                              ),
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
