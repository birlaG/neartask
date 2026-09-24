# NearTask — Mobile App (Flutter)

Talks to the `neartask-backend` API. Covers the core loop end to end: register/login, browse nearby gigs, apply, select an applicant (creator), complete/cancel/no-show, and a wallet screen for top-up/withdrawal requests.

## Setup

Requires the Flutter SDK (stable channel) — this scaffold can't be compiled in the sandbox it was written in, since that has no Flutter toolchain or internet access to fetch packages. On your own machine:

```bash
flutter create . --platforms=android,ios   # generates the missing android/ and ios/ native scaffolding
flutter pub get
```

Then point the app at your backend. The base URL is compiled in via a `--dart-define`:

```bash
# Android emulator talking to a backend running on your dev machine:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000

# Physical device on the same network:
flutter run --dart-define=API_BASE_URL=http://<your-lan-ip>:3000

# Against your deployed Contabo VPS:
flutter run --dart-define=API_BASE_URL=https://api.yourdomain.com
```

If you don't pass `--dart-define`, it defaults to `http://10.0.2.2:3000` (the Android-emulator alias for your host machine's localhost) — see `lib/config/api_config.dart`.

## What's built vs. what's next

**Built:**
- Auth (register/login), session persisted via `shared_preferences`
- Location-based nearby gig feed with Chore/Social filter
- Task detail: apply (as a doer), select-applicant/complete/cancel/no-show (as a creator)
- Post-a-gig form, including the Social-only gender/age preference fields
- Wallet: balance, transaction history, top-up (simulated — see note below), withdrawal request
- Profile: trust stats, verification tier display, profile-visibility control (Full/Partial/Hidden)
- KYC: capture or pick an ID document + selfie, submit for review, see live approval/rejection status

**Not yet built — next milestones:**
- Real payment gateway checkout (Razorpay/Cashfree Flutter SDK) — `wallet_screen.dart`'s "Add money" currently calls `/wallet/topup` directly with a fake reference, which only works because the backend also doesn't verify it yet. Both need to be replaced together with real gateway integration.
- In-app chat, live location sharing, panic button (PRD §8's safety layer)
- Push notifications (Firebase Cloud Messaging)
- Proper app icons, splash screen, and platform-specific permission strings (location, camera) in `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist` once you run `flutter create .`

## Running in GitHub Codespaces — partial support only

This is the honest version, not the optimistic one: Codespaces can edit and build this app, but **cannot run an Android emulator or iOS simulator** — those need a GPU/display that a Codespace doesn't have. Three real options if you want to develop from a Codespace:

1. **Flutter Web preview** (easiest, but not a full test) — `flutter run -d web-server --dart-define=API_BASE_URL=https://<your-codespace-3000-url>`, then open the forwarded port. Good enough to click through screens, but `geolocator` and `image_picker` behave differently on web than on a real phone, so this isn't a substitute for testing the real app before launch.
2. **A physical Android device over Wi-Fi debugging** — enable Wireless Debugging on the phone, `adb connect <phone-ip>:<port>` from the codespace terminal, then `flutter run` targets the real device. This is the closest to a real test you can get from a Codespace.
3. **Just edit code in the Codespace, run it locally** — write and commit from Codespaces, then `flutter run` on your own machine (with Android Studio/Xcode) whenever you actually need to test on an emulator.

If most of your work will be on this app rather than the backend, developing locally with the full Flutter/Android Studio toolchain installed is genuinely the smoother path — Codespaces is a much better fit for the backend half of this project than for Flutter.

## Permissions you'll need to add

After running `flutter create .`, add to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.CAMERA" />
```
And to `ios/Runner/Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>NearTask uses your location to show gigs near you.</string>
<key>NSCameraUsageDescription</key>
<string>NearTask needs camera access to take your ID and selfie photos for verification.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>NearTask needs photo library access so you can choose an existing photo for verification.</string>
```
