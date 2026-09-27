# Clothsy Shop App — Phase 4: AI Virtual Try-On, Polish and Launch

## Goal
Ship the feature that makes this app different — Clothsy AI virtual try-on inside the product page — then harden, optimise and release to the Play Store and App Store.

## Depends On
Phases 1–3 complete; Clothsy AI / FabricVTON try-on API available.

## Virtual Try-On

### Entry points
- "Try It On" button beside Add to Cart on every eligible PDP.
- Dedicated Try-On tab in bottom navigation: shopper's photo plus a scrollable tray of garments to try one after another.
- "Tried on" badge on product cards the user has already tried.

### Flow
1. First use: short explainer sheet (one photo, how results work, privacy note) and consent.
2. Photo capture or gallery pick, with a framing guide overlay (full or upper body, good light, plain background).
3. On-device checks before upload: face/body present, resolution, blur, brightness. Reject bad photos early with a clear tip.
4. Upload photo once; reuse it for every garment (matches the site behaviour: "your photo stays put").
5. Request try-on for the selected garment and variant image.
6. Progress state with a shimmering "Styling…" animation and estimated time.
7. Result screen: before/after slider, save, share, pick another colour/size, "Add to Cart" directly from the result.
8. History of past try-ons in profile.

### Engineering
- Try-on requests are async jobs: submit, then poll or receive a push/websocket when done. Never block the UI.
- Cache results by (user photo + garment variant) so repeat tries are instant and free.
- Compress and resize the photo on-device before upload.
- Credits/quota per user handled on the backend; show remaining try-ons if limited.
- Graceful fallback when the API is slow or down: keep the rest of the app fully usable.
- Log latency, success rate and try-on-to-cart conversion — this is the core business metric.

### Privacy
- Explicit consent before first upload.
- User photos stored encrypted, auto-deleted after a set period, and deletable anytime from profile.
- Clear shopper privacy page linked from the flow (the site already has one — reuse it).
- Store listing data-safety forms must declare photo handling accurately.

## UI Polish
- Micro-interactions: heart pop on wishlist, add-to-cart fly-to-cart animation, button press scale, page transitions.
- Consistent empty, error and offline illustrations in brand style.
- Haptics on key actions (add to cart, order placed, try-on ready).
- Dark mode shipped using the Phase 1 dark tokens.
- Accessibility: semantic labels on all icons, minimum 44px tap targets, text scaling up to 1.3x without breaking layouts, colour contrast checked on lilac and plum combinations.
- Localisation: English and Hindi.

## Performance
- App start under 2 seconds on a mid-range Android device.
- Deferred loading for heavy features (try-on, camera).
- Image memory limits on grids; precache the next PDP image on card visibility.
- Profile builds with DevTools; remove jank on Home, listing and PDP.
- App size target: under 30 MB for Android (split per ABI).

## Testing
- Unit and widget test coverage for all repositories, providers and key screens.
- Integration tests for: onboarding → browse → try-on → add to cart → checkout.
- Manual device matrix: small and large Android, older iPhone, latest iPhone, tablet sanity check.
- Beta via Firebase App Distribution / TestFlight with 20–50 real users; collect crash and feedback data.

## Analytics and Growth
- Funnel: install → onboarding complete → product view → try-on → add to cart → purchase.
- Crashlytics with a crash-free sessions target above 99.5 percent.
- Remote Config for banners, feature flags (turn try-on on/off per category), and A/B tests on the PDP layout.
- Referral link and share-your-look from try-on results.

## Release
- App icons, splash, store screenshots in the brand style (reuse the reference-style mockups with real try-on results).
- Store listings: title, short description centred on "See yourself in every outfit", privacy policy, data-safety form, content rating.
- Android: signed app bundle, Play Console internal → closed → production track.
- iOS: App Store Connect, TestFlight, review notes explaining photo usage and Sign in with Apple.
- Staged rollout (10 → 50 → 100 percent) watching crash and payment metrics.

## Deliverables
1. Try-on on PDP and a dedicated Try-On tab, with history, caching and privacy controls.
2. Polished, accessible, dark-mode-ready UI in English and Hindi.
3. Performance targets met and test suites green.
4. Apps live on Google Play and the App Store.

## Acceptance Criteria
- Try-on result returns within the API's target time with a clear progress state; failures are recoverable without losing the photo.
- Try-on to add-to-cart conversion is tracked from day one.
- Crash-free sessions above 99.5 percent in beta.
- Both store reviews passed on first or second submission.
