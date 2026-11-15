# Frumulres ProviTrack NG

Flutter Android app for managing a Nigerian provision shop.

## Included
- Product and stock records
- Sales recording with automatic stock reduction
- Expense recording
- Dashboard and business summary
- SQLite local database
- Starting capital configured as ₦430,650

## Build
The GitHub Actions workflow in `.github/workflows/build-apk.yml` creates the Android project wrapper and builds a debug APK on each push to `main`.

The app stores its records locally on the Android device. Keep regular backups of the device/app data; cloud synchronisation is not included in this first build.
