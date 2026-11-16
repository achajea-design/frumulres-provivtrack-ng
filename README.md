# ProviTrack NG

Simple offline Android app for managing a Nigerian provisions store.

## Features
- **Dashboard** – Today’s sales, net profit, stock value, low-stock alerts
- **Share Today’s Summary** – One-tap button to send a clean daily report via WhatsApp, Telegram, etc.
- **Stock** – Add / edit products, categories, units, cost & selling price, reorder level
- **Sales** – Quick sales with automatic stock reduction (Cash, Transfer, POS, Credit)
- **Credit Customers** – Track outstanding balances and record payments
- **Expenses** – Record shop expenses with categories
- **Reports** – Full business summary (revenue, COGS, gross & net profit, stock value)
- **Settings** – Shop name and starting capital

All data is stored **locally on the phone** (SQLite). There is no cloud sync in this version.

## How to get the APK (No computer needed)

1. Create a free GitHub account on your phone (if you don’t have one).
2. Create a **new repository** named `provitrack-ng` (make it Public).
3. Upload these files into the repository:
   - `pubspec.yaml`
   - `lib/main.dart`
   - `.github/workflows/build-apk.yml`
4. After uploading, go to the **Actions** tab of the repository.
5. Click the latest workflow run → download the artifact named **provitrack-ng-apk**.
6. Unzip it and install `app-debug.apk` on the Android phone.
7. Allow installation from unknown sources if asked.

You can send the APK file to your wife via WhatsApp, Telegram, or Google Drive.

## Important Notes
- Data stays only on the phone where the app is installed.
- If the phone is lost or the app is uninstalled, the data is lost unless you have a backup.
- For live monitoring from another country, a cloud version (e.g. Google Sheets + Glide) is still better.
- This is a debug APK (easy to install). It is suitable for personal use.

## Credits
Built for small provision shops in Nigeria.
