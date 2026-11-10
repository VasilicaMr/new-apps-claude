# Publishing DriveCap in App Store Connect

Every step from an empty App Store Connect account to "Ready for Distribution", in order. The project is called
FleetCheck; the store name is **DriveCap**. Details that already have their own page are linked, not repeated:

- [`InAppPurchases.md`](InAppPurchases.md): subscription group, the three products, review notes
- [`README.md`](README.md): screenshots, header and search results art, store text limits
- `metadata/<locale>/`: name, subtitle, promotional text, keywords, description (en-US, ro, fr-FR)

`TODO` marks values that don't exist yet and must be decided before submitting.

## 0. Once per developer account

| Step | Where |
|---|---|
| Apple Developer Program membership active (team `J5WZTVZJ44`) | developer.apple.com → Account |
| **Paid Applications agreement** signed, with bank account and tax forms | App Store Connect → Business |
| Optional, for automation later: an API key (role App Manager), keep the `.p8`, Key ID and Issuer ID outside the repo | Users and Access → Integrations → App Store Connect API |

Without the Paid Applications agreement the in-app purchases stay "Missing Metadata" and can't be submitted.

## 1. Identifiers

| Target | Bundle ID |
|---|---|
| App | `com.adaptiveservices.drivo` |
| Widgets (Live Activity) | `com.adaptiveservices.drivo.widgets` |

Signing is automatic, so Xcode registers both IDs the first time you archive. No extra capabilities are needed:
Live Activities, Apple Intelligence (Foundation Models), Vision and StoreKit work without entitlements.

The product IDs use `com.adaptiveservices.drivecap.pro.*`, which doesn't need to match the bundle ID. Don't change
them after creating the products: product IDs can never be reused, even after deletion.

## 2. Create the app record

**App Store Connect → Apps → + → New App**

| Field | Value |
|---|---|
| Platform | iOS |
| Name | DriveCap (if taken, App Store Connect says so; pick a variant and update `metadata/*/name.txt`) |
| Primary language | English (U.S.) |
| Bundle ID | `com.adaptiveservices.drivo` |
| SKU | `drivecap-ios` (internal only, any unique string) |
| User access | Full access |

## 3. App Information

| Field | Value |
|---|---|
| Localizations | Add **Romanian** and **French (France)** next to English (U.S.) |
| Name / Subtitle | From `metadata/<locale>/name.txt` and `subtitle.txt`, per language |
| Category | Primary **Finance** (matches `LSApplicationCategoryType`), secondary **Productivity** |
| Content rights | Does not contain, show or access third-party content |
| Age rating | Answer "None" / "No" to every question → 4+ |
| Privacy policy URL | `https://adaptivebyte.com/privacy-policy/` (same link as in the paywall), every language |

## 4. Pricing and availability

| Field | Value |
|---|---|
| Price | Free (Pro is sold through in-app purchases) |
| Availability | All countries, or at least Romania, France and the U.S. |
| Pre-order | Off |

## 5. App Privacy

**App Privacy → Get Started**

Answer **"No, we do not collect data from this app"**. Apple counts data as collected only when it leaves the device:
DriveCap keeps shifts, earnings, expenses, screenshots and receipts on the iPhone (SwiftData, on-device Apple
Intelligence and Vision), makes no network requests and has no analytics or ads. Purchases go through Apple and
don't count.

If analytics, crash reporting, iCloud sync or a server is ever added, update this section **before** that version
ships.

## 6. In-app purchases and subscriptions

Follow [`InAppPurchases.md`](InAppPurchases.md) step by step: the "DriveCap Pro" group, Pro Yearly, Pro Monthly,
Pro Lifetime, their localizations, prices (Romania as base), the 1-week free trials and the review screenshot
`AppReview/iap_paywall.png`.

**Check before entering the levels:** `InAppPurchases.md` puts Yearly and Monthly both at Level 1, but
`FleetCheck.storekit` has Yearly at level 1 and Monthly at level 2. Pick one and make both files match. Same level
means switching plans counts as a crossgrade. Different levels make it an upgrade or downgrade.

## 7. Upload a build

1. Bump `CURRENT_PROJECT_VERSION` in `project.yml` (every upload needs a new build number; `MARKETING_VERSION`
   stays `1.0` for the first release), then regenerate the project:
   ```bash
   xcodegen generate
   ```
2. In Xcode: scheme **FleetCheck**, destination **Any iOS Device (arm64)** → **Product → Archive**.
3. Organizer → **Distribute App → App Store Connect → Upload**. Keep "Manage version and build number" off, since
   `project.yml` controls it.
4. Wait for the email "has completed processing" (5–30 minutes). The build then appears under TestFlight.
5. **Export compliance:** answer that the app uses no encryption beyond what's exempt (it makes no network calls).
   To skip this question on every upload, add `ITSAppUsesNonExemptEncryption: false` to the app's `info.properties`
   in `project.yml`.

## 8. TestFlight

1. TestFlight → Internal Testing → create a group and add yourself.
2. Install from the TestFlight app on a device that supports **Apple Intelligence** (iPhone 15 Pro or later) and on
   one that doesn't, to check the fallback parsers.
3. Test the purchases with a **Sandbox account** (Users and Access → Sandbox → Test Accounts): buy each plan, check the
   free trial, **Restore purchases**, and that the free tier stops at 10 screenshot reads a month.
4. Check Romanian, French and English by switching the device language.

## 9. Version page (1.0)

**Apps → DriveCap → iOS App → 1.0 Prepare for Submission**, for each language:

| Field | Source |
|---|---|
| iPhone 6.9" screenshots | `<locale>/iphone/1_home.png` … `7_car.png`, in order |
| iPad 13" screenshots | `<locale>/ipad/1_home.png` … `7_car.png` |
| Header / Search results (iOS 27) | `header.png`, `<locale>/search_results.png` (see `README.md`) |
| Promotional text | `metadata/<locale>/promotional_text.txt` |
| Description | `metadata/<locale>/description.txt` |
| Keywords | `metadata/<locale>/keywords.txt` |
| Support URL | `TODO`, required: a page with a contact email is enough |
| Marketing URL | Optional |

Locale folders map as: `en-US` → English (U.S.), `ro` → Romanian, `fr-FR` → French (France).

Once for the version:

| Field | Value |
|---|---|
| Build | The build from step 7 |
| **In-App Purchases and Subscriptions** | Add all three Pro products. They must ship with this first version. |
| Copyright | `TODO`, e.g. `2026 <company name>` |
| Routing app coverage file | Not needed |
| Version release | Manually release (so you can check the IAPs are live first) |

**App Review Information**

| Field | Value |
|---|---|
| Sign-in required | No (no account in the app) |
| Contact | `TODO`: first name, last name, phone, email |
| Attachment | `Source/scan_en.png`, a sample earnings screenshot the reviewer can save to Photos and read |
| Notes | See below |

> DriveCap is a logbook for ride-hailing drivers. Everything runs on the device; there is no account or server.
> To try the main feature: save the attached earnings screenshot to Photos, open DriveCap, tap Start shift, then
> End shift, and choose "Read from screenshot". On devices with Apple Intelligence the numbers are read by the
> on-device model; on other devices a built-in text parser does it. The free version reads 10 screenshots a month;
> DriveCap Pro (yearly, monthly or lifetime) unlocks unlimited reading, Earn smarter and CSV export. The paywall is
> the last tutorial page and is in Settings → Upgrade to DriveCap Pro. Purchases restore in Settings → Restore
> purchases. DriveCap is not affiliated with Uber, Bolt or FREENOW.

## 10. Submit

1. **Add for Review** on the version page, then **Submit to App Review**. The version and the three products go in
   one submission.
2. Review usually takes 24–48 hours. If rejected, answer in **App Review → Messages**, fix, upload a new build (step
   7, new build number) and resubmit.
   - The screenshots and the search results art show the Home screen naming Uber and Bolt. If review objects,
     retake them on a screen without the names (see `README.md`).

## 11. After approval

1. **Release this version** (manual release from step 9).
2. Once live, check on a real device with a normal Apple Account that the paywall loads all three prices.
3. Later: custom product pages, product page tests and campaigns are set up from the live app.

## Each later update

1. Raise `MARKETING_VERSION` (e.g. `1.1`) and `CURRENT_PROJECT_VERSION` in `project.yml`, then `xcodegen generate`.
2. Archive and upload (step 7).
3. App Store Connect → **+ Version**: fill in "What's New" in all three languages, update screenshots and description
   if features or plans changed, select the build.
4. If data handling changed, update App Privacy (step 5) first.
5. Submit (step 10).
