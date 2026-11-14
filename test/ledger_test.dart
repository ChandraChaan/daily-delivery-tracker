import 'dart:convert';

import 'package:daily_delivery_tracker/src/ledger.dart';
import 'package:flutter_test/flutter_test.dart';

Item milk() => Item(
      id: 'm',
      name: 'Milk',
      unit: 'litre',
      defaultQty: 1,
      startDate: DateTime(2026, 1, 1),
      rates: [RateChange(DateTime(2026, 1, 1), 5600)],
    );

void main() {
  test('a full month at the default quantity', () {
    final b = billFor(milk(), 2026, 11);
    expect(b.days.length, 30);
    expect(b.totalQty, 30);
    expect(b.total, 30 * 5600);
    expect(b.skippedDays, 0);
  });

  test('skipped and extra days change the bill', () {
    final m = milk()
      ..setQty(DateTime(2026, 11, 3), 0)
      ..setQty(DateTime(2026, 11, 4), 0)
      ..setQty(DateTime(2026, 11, 10), 2.5);
    final b = billFor(m, 2026, 11);
    expect(b.totalQty, 30 - 2 + 1.5);
    expect(b.total, (29.5 * 5600).round());
    expect(b.skippedDays, 2);
    expect(b.extraDays, 1);
  });

  test('setting a day back to the default removes the override', () {
    final m = milk()..setQty(DateTime(2026, 11, 3), 0);
    expect(m.overrides, isNotEmpty);
    m.setQty(DateTime(2026, 11, 3), 1);
    expect(m.overrides, isEmpty);
  });

  test('a price rise mid-month bills each day at its own price', () {
    final m = milk()..setRate(DateTime(2026, 11, 16), 6000);
    final b = billFor(m, 2026, 11);
    expect(b.total, 15 * 5600 + 15 * 6000);
    expect(b.ratesUsed, [5600, 6000]);
  });

  test('nothing is billed before the start date', () {
    final m = milk()..startDate = DateTime(2026, 11, 21);
    final b = billFor(m, 2026, 11);
    expect(b.totalQty, 10);
    expect(b.skippedDays, 0, reason: 'days before the start are not skips');
  });

  test('current month is billed only up to today', () {
    final b = billFor(milk(), 2026, 11, upTo: DateTime(2026, 11, 15, 20, 30));
    expect(b.days.length, 15);
    expect(b.total, 15 * 5600);
  });

  test('half-litre packets and paise round per day', () {
    final m = Item(
      id: 'p',
      name: 'Curd',
      unit: 'packet',
      defaultQty: 0.5,
      startDate: DateTime(2026, 2, 1),
      rates: [RateChange(DateTime(2026, 2, 1), 2725)],
    );
    final b = billFor(m, 2026, 2);
    expect(b.days.length, 28);
    expect(b.total, 28 * 1363); // 1362.5 rounds to 1363 each day
  });

  test('survives a JSON round trip', () {
    final m = milk()
      ..setQty(DateTime(2026, 11, 3), 0)
      ..setRate(DateTime(2026, 11, 16), 6000);
    final back = Item.fromJson(jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>);
    expect(billFor(back, 2026, 11).total, billFor(m, 2026, 11).total);
    expect(back.overrides, m.overrides);
  });

  test('bill text is ready to paste', () {
    final m = milk()..setQty(DateTime(2026, 11, 3), 0);
    final paper = Item(
      id: 'n',
      name: 'Newspaper',
      unit: 'paper',
      defaultQty: 1,
      startDate: DateTime(2026, 1, 1),
      rates: [RateChange(DateTime(2026, 1, 1), 650)],
    );
    final text = billText([billFor(m, 2026, 11), billFor(paper, 2026, 11)]);
    expect(text, '''Bill for November 2026

Milk: 29 litre x Rs 56 = Rs 1,624
  (1 day skipped)
Newspaper: 30 paper x Rs 6.50 = Rs 195

Total: Rs 1,819''');
  });

  test('money formatting', () {
    expect(formatPaise(12345678), '1,23,456.78');
    expect(formatPaise(5600), '56');
    expect(formatQty(1.5), '1.5');
    expect(formatQty(2), '2');
  });
}
