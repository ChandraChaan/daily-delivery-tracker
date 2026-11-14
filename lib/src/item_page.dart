import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ledger.dart';
import 'look.dart';

/// One item's month as a calendar. Tap a day to change what came.
class ItemPage extends StatefulWidget {
  const ItemPage({
    super.key,
    required this.item,
    required this.year,
    required this.month,
    required this.today,
    required this.onChanged,
  });

  final Item item;
  final int year;
  final int month;
  final DateTime today;
  final VoidCallback onChanged;

  @override
  State<ItemPage> createState() => _ItemPageState();
}

class _ItemPageState extends State<ItemPage> {
  Item get item => widget.item;

  DateTime get todayDay =>
      DateTime(widget.today.year, widget.today.month, widget.today.day);

  void _set(DateTime d, double q) {
    setState(() => item.setQty(d, q));
    widget.onChanged();
  }

  Future<void> _editDay(DateTime d) async {
    final custom = TextEditingController(text: formatQty(item.qtyOn(d)));
    final q = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${d.day} ${monthNames[d.month - 1]}',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('Did not come'),
                  onPressed: () => Navigator.pop(ctx, 0.0),
                ),
                ActionChip(
                  label: Text(
                    'Usual (${formatQty(item.defaultQty)} ${item.unit})',
                  ),
                  onPressed: () => Navigator.pop(ctx, item.defaultQty),
                ),
                ActionChip(
                  label: Text(
                    'Extra: ${formatQty(item.defaultQty * 2)} ${item.unit}',
                  ),
                  onPressed: () => Navigator.pop(ctx, item.defaultQty * 2),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: custom,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Other amount (${item.unit})',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final v = double.tryParse(custom.text.trim());
                    if (v != null && v >= 0) Navigator.pop(ctx, v);
                  },
                  child: const Text('Set'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    custom.dispose();
    if (q != null) _set(d, q);
  }

  Future<void> _changePrice() async {
    final price = TextEditingController();
    var from = DateTime(widget.year, widget.month, 1);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('New price'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Price per ${item.unit} (₹)',
                  border: const OutlineInputBorder(),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('From'),
                subtitle: Text(
                  '${from.day} ${monthNames[from.month - 1]} ${from.year}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: from,
                    firstDate: item.startDate,
                    lastDate: todayDay,
                  );
                  if (d != null) setD(() => from = d);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final p = double.tryParse(price.text.trim());
    price.dispose();
    if (ok == true && p != null && p >= 0) {
      setState(() => item.setRate(from, (p * 100).round()));
      widget.onChanged();
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${item.name}?'),
        content: const Text(
          'All its days and prices are removed from this device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bill = billFor(
      item,
      widget.year,
      widget.month,
      upTo: widget.year == todayDay.year && widget.month == todayDay.month
          ? todayDay
          : null,
    );
    final first = DateTime(widget.year, widget.month, 1);
    final daysInMonth = DateTime(widget.year, widget.month + 1, 0).day;
    final lead = first.weekday - 1; // Monday first

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${item.name} · ${monthNames[widget.month - 1]} ${widget.year}',
        ),
        actions: [
          IconButton(
            tooltip: 'Change price',
            onPressed: _changePrice,
            icon: const Icon(Icons.currency_rupee),
          ),
          IconButton(
            tooltip: 'Delete item',
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Tap a day to change what came. Usual: ${formatQty(item.defaultQty)} ${item.unit} a day.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final w in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                      Center(
                        child: Text(w, style: theme.textTheme.labelMedium),
                      ),
                    for (var i = 0; i < lead; i++) const SizedBox(),
                    for (var d = 1; d <= daysInMonth; d++)
                      _dayCell(DateTime(widget.year, widget.month, d), theme),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${formatQty(bill.totalQty)} ${item.unit}',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '₹${formatPaise(bill.total)}',
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Price: ${bill.ratesUsed.isEmpty ? '₹${formatPaise(item.rateOn(todayDay))}' : bill.ratesUsed.map((r) => '₹${formatPaise(r)}').join(' then ')} per ${item.unit}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dayCell(DateTime d, ThemeData theme) {
    final l = Look.of(context);
    final active = !d.isAfter(todayDay) && !d.isBefore(item.startDate);
    return Material(
      color: l.card,
      shape: Border(
        right: BorderSide(color: l.grid),
        bottom: BorderSide(color: l.grid),
      ),
      child: InkWell(
        onTap: active ? () => _editDay(d) : null,
        child: DayMark(
          day: d.day,
          qty: item.qtyOn(d),
          usual: item.defaultQty,
          active: active,
          big: true,
        ),
      ),
    );
  }
}
