/// Daily deliveries (milk, water cans, newspaper) and the monthly bill.
/// Money is kept in paise so totals never drift.
library;

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

class RateChange {
  const RateChange(this.from, this.paisePerUnit);
  final DateTime from;
  final int paisePerUnit;

  Map<String, Object> toJson() => {'from': dayKey(from), 'rate': paisePerUnit};
  static RateChange fromJson(Map<String, dynamic> j) =>
      RateChange(DateTime.parse(j['from'] as String), j['rate'] as int);
}

class Item {
  Item({
    required this.id,
    required this.name,
    required this.unit,
    required this.defaultQty,
    required DateTime startDate,
    List<RateChange>? rates,
    Map<String, double>? overrides,
  }) : startDate = _day(startDate),
       rates = rates ?? [],
       overrides = overrides ?? {};

  final String id;
  String name;

  /// What one unit is: litre, packet, can, paper.
  String unit;

  /// Delivered every day unless a day says otherwise.
  double defaultQty;

  /// Nothing is counted before this day.
  DateTime startDate;

  /// Price per unit over time, so a price rise mid-month bills correctly.
  final List<RateChange> rates;

  /// Days that differ from [defaultQty], keyed by [dayKey]. 0 means skipped.
  final Map<String, double> overrides;

  double qtyOn(DateTime d) {
    final day = _day(d);
    if (day.isBefore(startDate)) return 0;
    return overrides[dayKey(day)] ?? defaultQty;
  }

  /// Sets the quantity for one day. Setting it back to the default removes
  /// the override.
  void setQty(DateTime d, double qty) {
    final k = dayKey(d);
    if (qty == defaultQty) {
      overrides.remove(k);
    } else {
      overrides[k] = qty;
    }
  }

  int rateOn(DateTime d) {
    final day = _day(d);
    RateChange? best;
    for (final r in rates) {
      if (!r.from.isAfter(day) && (best == null || r.from.isAfter(best.from))) {
        best = r;
      }
    }
    return best?.paisePerUnit ?? 0;
  }

  /// Adds a price from [from] onwards, replacing one on the same day.
  void setRate(DateTime from, int paisePerUnit) {
    final day = _day(from);
    rates.removeWhere((r) => r.from == day);
    rates.add(RateChange(day, paisePerUnit));
    rates.sort((a, b) => a.from.compareTo(b.from));
  }

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'unit': unit,
    'qty': defaultQty,
    'start': dayKey(startDate),
    'rates': [for (final r in rates) r.toJson()],
    'overrides': overrides,
  };

  static Item fromJson(Map<String, dynamic> j) => Item(
    id: j['id'] as String,
    name: j['name'] as String,
    unit: j['unit'] as String,
    defaultQty: (j['qty'] as num).toDouble(),
    startDate: DateTime.parse(j['start'] as String),
    rates: [
      for (final r in j['rates'] as List)
        RateChange.fromJson(r as Map<String, dynamic>),
    ],
    overrides: {
      for (final e in (j['overrides'] as Map<String, dynamic>).entries)
        e.key: (e.value as num).toDouble(),
    },
  );
}

class DayLine {
  const DayLine(this.date, this.qty, this.rate, this.amount);
  final DateTime date;
  final double qty;
  final int rate;
  final int amount;
}

class MonthBill {
  const MonthBill({
    required this.item,
    required this.year,
    required this.month,
    required this.days,
  });

  final Item item;
  final int year;
  final int month;
  final List<DayLine> days;

  double get totalQty => days.fold(0, (s, d) => s + d.qty);
  int get total => days.fold(0, (s, d) => s + d.amount);

  /// Days on or after the start date with nothing delivered.
  int get skippedDays =>
      days.where((d) => d.qty == 0 && !d.date.isBefore(item.startDate)).length;

  /// Days with more than the usual quantity.
  int get extraDays => days.where((d) => d.qty > item.defaultQty).length;

  /// Distinct prices used this month, in order.
  List<int> get ratesUsed => {
    for (final d in days)
      if (d.qty > 0) d.rate,
  }.toList();
}

/// The bill for one item and month. Days after [upTo] (usually today) are
/// not counted, so the current month shows the amount due so far.
MonthBill billFor(Item item, int year, int month, {DateTime? upTo}) {
  final last = DateTime(year, month + 1, 0).day;
  final limit = upTo == null ? null : _day(upTo);
  final days = <DayLine>[];
  for (var d = 1; d <= last; d++) {
    final date = DateTime(year, month, d);
    if (limit != null && date.isAfter(limit)) break;
    final q = item.qtyOn(date);
    final r = item.rateOn(date);
    days.add(DayLine(date, q, r, (q * r).round()));
  }
  return MonthBill(item: item, year: year, month: month, days: days);
}

String formatPaise(int p) {
  final rupees = p ~/ 100;
  final paise = p % 100;
  final s = rupees.toString();
  String grouped;
  if (s.length <= 3) {
    grouped = s;
  } else {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    grouped = '${parts.join(',')},$last3';
  }
  return paise == 0 ? grouped : '$grouped.${paise.toString().padLeft(2, '0')}';
}

String formatQty(double q) => q == q.roundToDouble()
    ? q.toInt().toString()
    : q.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');

const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Plain text to paste into WhatsApp or SMS.
String billText(List<MonthBill> bills, {DateTime? upTo}) {
  if (bills.isEmpty) return '';
  final b0 = bills.first;
  final title = '${monthNames[b0.month - 1]} ${b0.year}';
  final partial =
      upTo != null && b0.days.length < DateTime(b0.year, b0.month + 1, 0).day;
  final lines = <String>[
    'Bill for $title${partial ? ' (up to ${upTo.day} ${monthNames[upTo.month - 1]})' : ''}',
    '',
  ];
  var grand = 0;
  for (final b in bills) {
    final rates = b.ratesUsed.map((r) => 'Rs ${formatPaise(r)}').join(' / ');
    lines.add(
      '${b.item.name}: ${formatQty(b.totalQty)} ${b.item.unit} x $rates = Rs ${formatPaise(b.total)}',
    );
    final notes = [
      if (b.skippedDays > 0)
        '${b.skippedDays} day${b.skippedDays == 1 ? '' : 's'} skipped',
      if (b.extraDays > 0)
        '${b.extraDays} day${b.extraDays == 1 ? '' : 's'} extra',
    ];
    if (notes.isNotEmpty) lines.add('  (${notes.join(', ')})');
    grand += b.total;
  }
  if (bills.length > 1) {
    lines
      ..add('')
      ..add('Total: Rs ${formatPaise(grand)}');
  }
  return lines.join('\n');
}
