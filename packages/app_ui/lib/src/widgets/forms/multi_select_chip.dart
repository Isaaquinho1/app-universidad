import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class MultiSelectChip<T> extends StatelessWidget {
  const MultiSelectChip({
    required this.items,
    required this.selectedItems,
    required this.onSelectionChanged,
    required this.labelBuilder,
    super.key,
    this.chipColorBuilder,
    this.selectedColor,
    this.unselectedColor,
    this.borderRadius = 12.0,
    this.spacing = 8.0,
    this.runSpacing = 8.0,
    this.maxItems,
    this.direction = Axis.horizontal,
    this.icon,
    this.isSingleSelect = false,
    this.label,
  });

  /// Lista de elementos disponibles.
  final List<T> items;

  /// Lista de elementos seleccionados.
  final List<T> selectedItems;

  /// Se ejecuta cuando cambia la selección.
  final void Function(List<T>) onSelectionChanged;

  /// Genera el texto de cada chip.
  final String Function(T item) labelBuilder;

  /// Genera el color de cada chip (opcional).
  final Color? Function(T item)? chipColorBuilder;

  /// Color del chip seleccionado.
  final Color? selectedColor;

  /// Color del chip no seleccionado.
  final Color? unselectedColor;

  /// Radio de las esquinas de los chips.
  final double borderRadius;

  /// Espacio horizontal entre chips.
  final double spacing;

  /// Espacio vertical entre filas de chips.
  final double runSpacing;

  /// Número máximo de chips visibles.
  final int? maxItems;

  /// Dirección de distribución de los chips.
  final Axis direction;

  /// Ícono de los chips (opcional).
  final dynamic icon;

  /// Si es true, permite seleccionar solo un elemento.
  final bool isSingleSelect;

  /// Título del grupo de chips (opcional).
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final defaultSelectedColor = colors.primary;
    final defaultUnselectedColor = colors.background03;

    // Limitamos la cantidad de elementos si corresponde.
    final displayedItems = maxItems != null && items.length > maxItems!
        ? items.sublist(0, maxItems)
        : items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTextStyle.titleS.copyWith(
              color: colors.active,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          direction: direction,
          children: displayedItems.map((item) {
            final isSelected = selectedItems.contains(item);
            final itemColor = chipColorBuilder?.call(item);

            // Usamos el color configurado, el del elemento o el predeterminado.
            final activeColor =
                selectedColor ?? itemColor ?? defaultSelectedColor;
            // Usamos el color configurado o el predeterminado.
            final inactiveColor = unselectedColor ?? defaultUnselectedColor;

            return ChoiceChip(
              label: Text(
                labelBuilder(item),
                style: AppTextStyle.captionL.copyWith(
                  color: isSelected ? activeColor : colors.deactive,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              avatar: icon != null
                  ? (icon is IconData
                      ? Icon(
                          icon as IconData,
                          size: 16,
                          color: isSelected ? activeColor : colors.deactive,
                        )
                      : HugeIcon(
                          icon: icon as List<List<dynamic>>,
                          size: 16,
                          color: isSelected ? activeColor : colors.deactive,
                        ))
                  : null,
              selected: isSelected,
              selectedColor: activeColor.withOpacity(0.15),
              backgroundColor: inactiveColor.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
                side: BorderSide(
                  color: isSelected ? activeColor : Colors.transparent,
                  width: 1.5,
                ),
              ),
              onSelected: (selected) {
                var newSelectedItems = <T>[...selectedItems];

                // Modo de selección única.
                if (isSingleSelect) {
                  if (selected) {
                    newSelectedItems = [item];
                  } else {
                    newSelectedItems = [];
                  }
                } else {
                  // Modo de selección múltiple.
                  if (selected) {
                    newSelectedItems.add(item);
                  } else {
                    newSelectedItems.remove(item);
                  }
                }

                onSelectionChanged(newSelectedItems);
              },
            );
          }).toList(),
        ),

        // Indicamos los elementos adicionales cuando existe un límite.
        if (maxItems != null && items.length > maxItems!) ...[
          const SizedBox(height: 8),
          Text(
            '${items.length - maxItems!} elementos más',
            style: AppTextStyle.captionL.copyWith(
              color: colors.deactive,
            ),
          ),
        ],
      ],
    );
  }
}
