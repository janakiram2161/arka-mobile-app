# ARKA Schmuck – Mobile App (Flutter)

Shop app for **arkaschmuck.de** on Android and iOS.

## How it stays up to date

The app keeps no product data of its own. Every screen reads products,
prices, stock, categories and images live from the shop through WooCommerce's
public Store API (`https://arkaschmuck.de/wp-json/wc/store/v1`). When a product is
published, changed or sold out on the website, the app shows it the next time
a list is opened or pulled down to refresh. No keys or passwords are built
into the app.

## Features

- Start page: newest product as the hero image, categories, "Neu eingetroffen" and "Im Angebot"
- Shop: all categories with pictures from the website, endless product lists, sorting
- Search
- Product page: image gallery with zoom, price and sale price, stock, variants, description, similar products
- Wishlist and cart, both saved on the phone
- Checkout: the app cart is handed to the website and the website's own checkout opens in the app, so PayPal, WooPayments, coupons and the legal checkout texts work as on the site
- My account, order tracking, shipping, withdrawal policy, terms (AGB), privacy policy and imprint pages from the website

## Project layout

| Path | What it is |
|---|---|
| `lib/config.dart` | Shop URL, page paths, brand colours |
| `lib/api/store_api.dart` | Live connection to the WooCommerce Store API |
| `lib/models/models.dart` | Product, category and price models |
| `lib/state/stores.dart` | Cart and wishlist (saved on the device) |
| `lib/screens/` | All screens |
| `tool/setup.sh` | Creates the android/ios folders, adds packages, sets name, permission and app icon |
| `tool/make_icon.py` | Builds the app icon from the logo on arkaschmuck.de |
| `.github/workflows/build.yml` | GitHub build: Android APK + unsigned iOS build |

## Building

Every push to `main` builds the app on GitHub (tab **Actions**). The finished files
are under **Releases** as "ARKA Schmuck Test-Build N":

- `ARKA-Schmuck.apk`: open it on an Android phone to install (allow installing from unknown sources)
- `ARKA-Schmuck-iOS-unsigned.ipa`: an iOS build that compiled successfully; it has to be signed with an Apple Developer account before it runs on an iPhone

Build it yourself (Flutter installed; for iOS, a Mac with Xcode):

```bash
pip install pillow
bash tool/setup.sh
flutter run                 # on a connected phone
flutter build apk --release # Android
flutter build ipa           # iOS, needs signing set up in Xcode
```

## Before going to the App Store and Google Play

1. **Android:** create your own signing key (upload key) and change the
   `applicationId` if needed (currently `de.arkaschmuck.arka_schmuck`).
   Google Play account: 25 USD, one-off.
2. **iOS:** Apple Developer Program (99 USD/year), set up signing in Xcode or
   Codemagic, upload to TestFlight.
3. Push notifications for new products: Firebase plus a WooCommerce webhook
   (planned as the next step).
