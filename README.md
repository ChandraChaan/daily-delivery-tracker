# Daily Delivery Tracker

A monthly account book for what comes to your door every day: milk, curd packets, a water can, the newspaper. Mark the days it didn't come or came extra, and the app adds up the bill. Everything stays on your device, and there is no account.

For the end-of-month "how much do I owe the milkman?" conversation.

## What it does

- Add an item with its unit (litre, packet, can, paper), the usual quantity per day, the price per unit and the date it started.
- Each item shows its month as a calendar. Tap a day to mark **Did not come**, **Extra**, or any other amount (half litres are fine).
- **Price changes** take effect from a date you choose, so a rise in the middle of the month bills each day at its own price.
- The current month is counted **only up to today**, so you see what is due so far.
- **Copy bill as text** puts a plain bill on the clipboard, ready to paste into WhatsApp or SMS:

  ```
  Bill for November 2026

  Milk: 29 litre x Rs 56 = Rs 1,624
    (1 day skipped)
  Newspaper: 30 paper x Rs 6.50 = Rs 195

  Total: Rs 1,819
  ```

- Money is kept in paise and rounded per day, so totals don't drift.

## What it does not do

- No reminders or notifications.
- No sync or backup. The data lives in this app on this device (or in this browser for the web version). Clearing app data or browser storage deletes it.
- It does not take payments. Pay the way you already do.

## Run it

```bash
flutter pub get
flutter run -d chrome        # web
flutter run                  # Android device or emulator
flutter test
```

Web version: https://chandrachaan.github.io/daily-delivery-tracker/ (needs a connection to load the page; your entries are stored only in this browser).

Android: APKs are attached to [Releases](https://github.com/ChandraChaan/daily-delivery-tracker/releases) when a `v*` tag is pushed. They are signed with the debug key, so Android will ask you to allow installing from outside the Play Store. The release build asks for no permissions: no internet, no storage, no contacts.

## Project layout

| Path | What it holds |
|---|---|
| `lib/src/ledger.dart` | Items, daily quantities, price history, monthly bill and bill text. Pure Dart. |
| `lib/src/store.dart` | Saves items as JSON on the device. |
| `lib/src/home_page.dart` | Month view with every item and the total. |
| `lib/src/item_page.dart` | One item's calendar. |
| `test/` | Skips, extras, mid-month price change, half packets, start date, saving and the full tap-through flow. |

## License

MIT. Copyright (c) 2026 Chandra ObulaReddy.
