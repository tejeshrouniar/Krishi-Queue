# Krishi Queue

A Flutter farmer-assistance app focused on Chhattisgarh, with Hindi/English access and a separate lightweight browser experience for poor connections.

## What works locally

- Guest access without OTP, sign-in or an internet connection after installation.
- Hindi/English home, login, help, settings, visit planner and assistance screens; larger text and low-data defaults.
- Saved personal visit plans, preparation checklists, copyable summaries and owner-scoped deletion. These are preparation notes, never official reservations.
- Offline help for registration, weighing, payment tracing, complaints, fraud and finding agricultural experts.
- A private offline follow-up notebook for payment, weighing, token and registration issues: evidence checklists, dated updates, your own follow-up date and a copyable summary. It does not submit a complaint or send reminders to an office. No phone alarms are scheduled.
- A deterministic offline chat helper; it does not invent live prices, queues or payment status.
- Clearly labelled practice booking, queue, procurement, staff and payment workflows.
- Browser light version: about 23 KB of HTML, CSS, JavaScript and service worker before compression. It saves a plan/checklist in that browser, supports print/PDF, and can reopen offline after successful initial caching. It does not sync with Flutter's saved plans.

The browser landing page lets the user choose the light version before downloading Flutter. The native app remains the preferred installed experience. Neither first-time installation nor first-time browser loading can happen without a connection.

## Run and test

```sh
flutter pub get
flutter run
flutter analyze
flutter test
flutter build web --release
flutter build apk --debug
flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64
```

The web build is in `build/web`; serve it through HTTP(S), not `file://`. Service workers require HTTPS except on localhost. Android packages are in `build/app/outputs/flutter-apk`. The split ARM packages are about 18–20 MB for test installation. All current APKs use test signing, including files named `release.apk`; the existing release configuration still needs a private production signing key before distribution.

## Sign-in and government verification

Firebase configuration exists for the project, and the app implements phone OTP plus Google sign-in on supported platforms. Firebase's trusted custom role claim chooses staff/driver/admin access; users cannot select an elevated role. Missing role claims mean farmer, while unknown claims are rejected.

**Provider setup is not proven by the checked-in Firebase config.** See [auth setup](docs/AUTH_SETUP.md) for Google OAuth clients, Android signing fingerprints, web domains and Apple prerequisites. Live OTP/Google sign-in must be tested with the project's configured providers.

App sign-in does not verify procurement registration or eligibility. No authorised Chhattisgarh procurement API is connected. Practice tokens are invalid for procurement; simulated payment is not a bank transfer. Use the official society/department workflow for actual bookings and decisions.

## Optional online services

[Firebase gateway setup](functions/README.md) explains BHASHINI translation, online AI, Chhattisgarh mandi reports and farmer news. Provider credentials stay on the server. The only service value supplied to Flutter is the public gateway URL:

```sh
flutter run --dart-define=KRISHI_API_BASE_URL=https://YOUR_FUNCTION_HOST/krishiApi
```

No provider keys should be embedded in Dart defines. The old direct-provider key settings are no longer used. Rotate any secret distributed in an older app build.

The gateway requires Firebase authentication, explicit allowed web origins and server secrets; deployment may require a paid Firebase plan. Offline help and plans have no provider usage cost. No cloud deployment was performed. BHASHINI currently implements Hindi/English text translation, not voice or reviewed Chhattisgarhi translation.

Prices/news load saved reports first and refresh on request. They keep observation/retrieval dates visible and report failed refreshes. News images are disabled by default. Online chat/translation asks before sending text and omits booking identifiers and conversation history.

Online errors distinguish missing service configuration, sign-in, usage limits and connection problems. Personal follow-up notes never enter online chat or translation automatically. They are stored separately for the current account or guest and can be deleted without removing visit plans.

## Browser verification

Optional local test tooling is kept out of app dependencies:

```powershell
npm install --prefix .test-tools --no-save playwright
$env:PLAYWRIGHT_BROWSERS_PATH = Join-Path $PWD '.test-tools\browsers'
node .test-tools/node_modules/playwright/cli.js install chromium --only-shell
$env:KRISHI_CHECK_FULL = '1'
node test/web_check.cjs
```

This serves the built app locally, checks a simulated 64 kbit/s connection, offline reload, stored checklist, offline help, deletion and 320px/2x text layout, then captures the Flutter screen for review. Screenshots are written to ignored `test-results/`.

Gateway checks:

```sh
cd functions
npm ci
npm test
npm run check
```

## Product and launch decisions

The detailed farmer problems, adoption evidence, proposed solutions, connectivity design and potential developer revenue models are in [the Chhattisgarh research report](RESEARCH_CHHATTISGARH.md). Launch gaps and implementation evidence are recorded in [implementation status](docs/IMPLEMENTATION_STATUS.md). A real field pilot with farmers and procurement staff is still needed; automated tests cannot establish rural adoption or government acceptance.
