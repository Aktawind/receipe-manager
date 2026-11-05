import 'package:flutter/material.dart';

import '../../domain/ingredient_text.dart';
import '../../domain/shopping.dart';
import '../../l10n/app_localizations.dart';

/// Ce que la fiche d'un produit renvoie : le produit modifié, ou son retrait.
typedef ShoppingItemEdit = ({ShoppingItem? item, bool removed});

/// Modifier un produit : nom, quantité nécessaire, ce qu'on achète, format,
/// commentaire. Renvoie `null` si on ferme sans enregistrer.
Future<ShoppingItemEdit?> showShoppingItemSheet(
  BuildContext context,
  ShoppingItem item,
) => showModalBottomSheet<ShoppingItemEdit>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _ItemSheet(item: item),
);

/// « 250 g », « 2 », « » → la quantité et l'unité d'un produit.
(double?, String) parseAmount(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return (null, '');
  final line = IngredientText.parse('$trimmed x', id: '');
  if (line.quantity == null) return (null, '');
  return (line.quantity, line.unit);
}

class _ItemSheet extends StatefulWidget {
  const _ItemSheet({required this.item});

  final ShoppingItem item;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final _name = TextEditingController(text: widget.item.name);
  late final _amount = TextEditingController(text: widget.item.amount);
  late final _toBuy = TextEditingController(text: widget.item.toBuy);
  late final _format = TextEditingController(text: widget.item.format);
  late final _note = TextEditingController(text: widget.item.note);

  @override
  void dispose() {
    for (final c in [_name, _amount, _toBuy, _format, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final (quantity, unit) = parseAmount(_amount.text);
    Navigator.pop<ShoppingItemEdit>(context, (
      item: widget.item.copyWith(
        name: name,
        quantity: () => quantity,
        unit: unit,
        toBuy: _toBuy.text.trim(),
        format: _format.text.trim(),
        note: _note.text.trim(),
      ),
      removed: false,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget field(
      String key,
      TextEditingController controller,
      String label, {
      String? hint,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: ValueKey('shopping-item-$key'),
        controller: controller,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 +
            MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.editProduct,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            field('name', _name, l10n.productName),
            field(
              'amount',
              _amount,
              l10n.productAmount,
              hint: l10n.productAmountHint,
            ),
            field(
              'to-buy',
              _toBuy,
              l10n.productToBuy,
              hint: l10n.productToBuyHint,
            ),
            field(
              'format',
              _format,
              l10n.productFormat,
              hint: l10n.productFormatHint,
            ),
            field('note', _note, l10n.productNote),
            // Côte à côte, ou l'un sous l'autre si la place manque.
            OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.end,
              overflowSpacing: 8,
              children: [
                TextButton.icon(
                  key: const ValueKey('shopping-item-remove'),
                  onPressed: () => Navigator.pop<ShoppingItemEdit>(context, (
                    item: null,
                    removed: true,
                  )),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.removeProduct),
                ),
                FilledButton(
                  key: const ValueKey('shopping-item-save'),
                  onPressed: _save,
                  child: Text(l10n.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
