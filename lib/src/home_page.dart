import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'item_page.dart';
import 'ledger.dart';
import 'store.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.store, this.today});

  final Store? store;

  /// For tests. Defaults to now.
  final DateTime? today;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Store store = widget.store ?? Store();
  List<Item> items = [];
  bool loaded = false;
  late DateTime today = widget.today ?? DateTime.now();
  late int year = today.year;
  late int month = today.month;

  bool get isCurrentMonth => year == today.year && month == today.month;
  DateTime? get upTo => isCurrentMonth ? today : null;

  @override
  void initState() {
    super.initState();
    store.load().then((v) {
      if (mounted) {
        setState(() {
          items = v;
          loaded = true;
        });
      }
    });
  }

  void _changed() {
    setState(() {});
    store.save(items);
  }

  void _shiftMonth(int delta) {
    setState(() {
      final d = DateTime(year, month + delta);
      year = d.year;
      month = d.month;
    });
  }

  Future<void> _add() async {
    final item = await showDialog<Item>(
      context: context,
      builder: (_) => _AddItemDialog(today: today),
    );
    if (item == null) return;
    items.add(item);
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bills = [for (final i in items) billFor(i, year, month, upTo: upTo)];
    final total = bills.fold(0, (s, b) => s + b.total);

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Delivery Tracker')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Row(children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => _shiftMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '${monthNames[month - 1]} $year',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: isCurrentMonth ? null : () => _shiftMonth(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ]),
                if (loaded && items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'Add what comes to your door every day, such as milk, a '
                      'water can or the newspaper. Then mark the days it did '
                      'not come, or came extra, and the bill adds itself up. '
                      'Everything stays on this device.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final b in bills)
                  Card(
                    child: ListTile(
                      title: Text(b.item.name),
                      subtitle: Text(
                        '${formatQty(b.totalQty)} ${b.item.unit}'
                        '${b.skippedDays > 0 ? ' · ${b.skippedDays} skipped' : ''}'
                        '${b.extraDays > 0 ? ' · ${b.extraDays} extra' : ''}',
                      ),
                      trailing: Text('₹${formatPaise(b.total)}', style: theme.textTheme.titleMedium),
                      onTap: () async {
                        final deleted = await Navigator.of(context).push<bool>(MaterialPageRoute(
                          builder: (_) => ItemPage(
                            item: b.item,
                            year: year,
                            month: month,
                            today: today,
                            onChanged: _changed,
                          ),
                        ));
                        if (deleted == true) {
                          items.remove(b.item);
                          _changed();
                        }
                      },
                    ),
                  ),
                if (bills.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: Text(
                        isCurrentMonth ? 'Due so far' : 'Total',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text('₹${formatPaise(total)}', style: theme.textTheme.titleLarge),
                  ]),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy bill as text'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: billText(bills, upTo: upTo)));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bill copied. Paste it in WhatsApp or SMS.')),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddItemDialog extends StatefulWidget {
  const _AddItemDialog({required this.today});
  final DateTime today;

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final name = TextEditingController(text: 'Milk');
  final unit = TextEditingController(text: 'litre');
  final qty = TextEditingController(text: '1');
  final price = TextEditingController();
  late DateTime start = DateTime(widget.today.year, widget.today.month, 1);
  String? error;

  @override
  void dispose() {
    for (final c in [name, unit, qty, price]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final q = double.tryParse(qty.text.trim());
    final p = double.tryParse(price.text.trim());
    if (name.text.trim().isEmpty || unit.text.trim().isEmpty) {
      setState(() => error = 'Enter a name and a unit.');
      return;
    }
    if (q == null || q < 0 || p == null || p < 0) {
      setState(() => error = 'Enter the usual quantity and the price per unit.');
      return;
    }
    Navigator.of(context).pop(Item(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.text.trim(),
      unit: unit.text.trim(),
      defaultQty: q,
      startDate: start,
      rates: [RateChange(start, (p * 100).round())],
    ));
  }

  @override
  Widget build(BuildContext context) {
    Widget f(TextEditingController c, String label, {bool number = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: c,
            keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
            inputFormatters: number ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          ),
        );
    return AlertDialog(
      title: const Text('Add item'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          f(name, 'Name (Milk, Water can, Newspaper)'),
          f(unit, 'Unit (litre, packet, can, paper)'),
          f(qty, 'Usual quantity per day', number: true),
          f(price, 'Price per unit (₹)', number: true),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Comes from'),
            subtitle: Text('${start.day} ${monthNames[start.month - 1]} ${start.year}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: start,
                firstDate: DateTime(widget.today.year - 2),
                lastDate: widget.today,
              );
              if (d != null) setState(() => start = d);
            },
          ),
          if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
