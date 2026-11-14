import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'item_page.dart';
import 'look.dart';
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

  Future<void> _open(MonthBill b) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ItemPage(
          item: b.item,
          year: year,
          month: month,
          today: today,
          onChanged: _changed,
        ),
      ),
    );
    if (deleted == true) {
      items.remove(b.item);
      _changed();
    }
  }

  Future<void> _copy(List<MonthBill> bills) async {
    await Clipboard.setData(ClipboardData(text: billText(bills, upTo: upTo)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bill copied. Paste it in WhatsApp or SMS.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = Look.of(context);
    final bills = [for (final i in items) billFor(i, year, month, upTo: upTo)];
    final total = bills.fold(0, (s, b) => s + b.total);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DELIVERY CARD', style: l.label()),
                          Text(
                            '${monthNames[month - 1]} $year',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: l.ink,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: () => _shiftMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: isCurrentMonth ? null : () => _shiftMonth(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (loaded && items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Add what comes to your door every day: milk, a water can, the newspaper. '
                      'Mark the days it did not come or came extra, and the bill adds itself up. '
                      'Everything stays on this phone.',
                      style: TextStyle(color: l.muted, height: 1.45),
                    ),
                  ),
                for (final b in bills) ...[
                  _MilkCard(bill: b, upTo: upTo, onTap: () => _open(b)),
                  const SizedBox(height: 12),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add),
                    label: const Text('Add item'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: bills.isEmpty
          ? null
          : Material(
              color: l.card,
              child: SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: l.grid)),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCurrentMonth ? 'Due so far' : 'Total',
                              style: TextStyle(color: l.muted, fontSize: 12.5),
                            ),
                            Text(
                              '\u20B9${formatPaise(total)}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: l.ink,
                                fontFeatures: Look.figures,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _copy(bills),
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy bill as text'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// One item as its paper card: the month grid with the day's quantity,
/// struck through when it did not come, circled when it came extra.
class _MilkCard extends StatelessWidget {
  const _MilkCard({
    required this.bill,
    required this.upTo,
    required this.onTap,
  });

  final MonthBill bill;
  final DateTime? upTo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = Look.of(context);
    final item = bill.item;
    final days = DateTime(bill.year, bill.month + 1, 0).day;
    final lead = DateTime(bill.year, bill.month, 1).weekday - 1;
    final rate = item.rateOn(upTo ?? DateTime(bill.year, bill.month, days));
    return Material(
      color: l.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: l.grid),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: l.ink,
                          ),
                        ),
                        Text(
                          '${formatQty(item.defaultQty)} ${item.unit} a day \u00b7 \u20B9${formatPaise(rate)} per ${item.unit}',
                          style: TextStyle(color: l.muted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '\u20B9${formatPaise(bill.total)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: l.ink,
                      fontFeatures: Look.figures,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final w in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                    Expanded(
                      child: Text(
                        w,
                        textAlign: TextAlign.center,
                        style: l.label().copyWith(fontSize: 10),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: l.grid),
                    left: BorderSide(color: l.grid),
                  ),
                ),
                child: GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.25,
                  children: [
                    for (var i = 0; i < lead; i++) _cell(l, null),
                    for (var d = 1; d <= days; d++)
                      _cell(
                        l,
                        DayMark(
                          day: d,
                          qty: item.qtyOn(DateTime(bill.year, bill.month, d)),
                          usual: item.defaultQty,
                          active:
                              !DateTime(
                                bill.year,
                                bill.month,
                                d,
                              ).isBefore(item.startDate) &&
                              (upTo == null ||
                                  !DateTime(
                                    bill.year,
                                    bill.month,
                                    d,
                                  ).isAfter(upTo!)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${formatQty(bill.totalQty)} ${item.unit} so far'
                '${bill.skippedDays > 0 ? ' · ${bill.skippedDays} skipped' : ''}'
                '${bill.extraDays > 0 ? ' · ${bill.extraDays} extra' : ''}',
                style: TextStyle(
                  color: l.muted,
                  fontSize: 12.5,
                  fontFeatures: Look.figures,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(Look l, Widget? child) => Container(
    decoration: BoxDecoration(
      border: Border(
        right: BorderSide(color: l.grid),
        bottom: BorderSide(color: l.grid),
      ),
    ),
    child: child,
  );
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
      setState(
        () => error = 'Enter the usual quantity and the price per unit.',
      );
      return;
    }
    Navigator.of(context).pop(
      Item(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.text.trim(),
        unit: unit.text.trim(),
        defaultQty: q,
        startDate: start,
        rates: [RateChange(start, (p * 100).round())],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget f(TextEditingController c, String label, {bool number = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: c,
            keyboardType: number
                ? const TextInputType.numberWithOptions(decimal: true)
                : null,
            inputFormatters: number
                ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                : null,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
          ),
        );
    return AlertDialog(
      title: const Text('Add item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            f(name, 'Name (Milk, Water can, Newspaper)'),
            f(unit, 'Unit (litre, packet, can, paper)'),
            f(qty, 'Usual quantity per day', number: true),
            f(price, 'Price per unit (₹)', number: true),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Comes from'),
              subtitle: Text(
                '${start.day} ${monthNames[start.month - 1]} ${start.year}',
              ),
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
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
