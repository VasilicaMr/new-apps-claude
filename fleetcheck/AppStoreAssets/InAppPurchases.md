# In-app purchases for App Store Connect

Everything to enter for DriveCap Pro. The product IDs must match `FleetCheck/Core/Store/ProStore.swift` exactly.
The texts match `FleetCheck.storekit`, which the app uses when run from Xcode.

Limits: display name 30 characters, description 45 characters.

## 1. Subscription group

**App Store Connect → your app → Monetization → Subscriptions → Create subscription group**

| Field | Value |
|---|---|
| Reference name | DriveCap Pro |

Group localizations (what people see in their Apple Account subscription settings):

| Language | Subscription group display name | App name display options |
|---|---|---|
| English (U.S.) | DriveCap Pro | Use app name |
| Romanian | DriveCap Pro | Use app name |
| French | DriveCap Pro | Use app name |

## 2. Yearly subscription

| Field | Value |
|---|---|
| Reference name | Pro Yearly |
| Product ID | `com.adaptiveservices.drivecap.pro.yearly` |
| Subscription duration | 1 year |
| Subscription level | Level 1 (same as Monthly: both unlock the same features) |
| Price (Romania, base) | 149,99 lei |
| Suggested other prices | $29.99 · €29.99 (or let App Store Connect calculate them from Romania) |
| Introductory offer | Free, 1 week, new subscribers, all countries |
| Family Sharing | Off |

| Language | Display name | Description |
|---|---|---|
| English (U.S.) | DriveCap Pro Yearly | Unlimited screenshots, Earn smarter, export |
| Romanian | DriveCap Pro anual | Capturi nelimitate, tarif minim, export CSV |
| French | DriveCap Pro annuel | Captures illimitées, Gagnez mieux, export |

## 3. Monthly subscription

| Field | Value |
|---|---|
| Reference name | Pro Monthly |
| Product ID | `com.adaptiveservices.drivecap.pro.monthly` |
| Subscription duration | 1 month |
| Subscription level | Level 1 |
| Price (Romania, base) | 24,99 lei |
| Suggested other prices | $4.99 · €4.99 |
| Introductory offer | Free, 1 week, new subscribers, all countries |
| Family Sharing | Off |

| Language | Display name | Description |
|---|---|---|
| English (U.S.) | DriveCap Pro Monthly | Unlimited screenshots, Earn smarter, export |
| Romanian | DriveCap Pro lunar | Capturi nelimitate, tarif minim, export CSV |
| French | DriveCap Pro mensuel | Captures illimitées, Gagnez mieux, export |

## 4. Lifetime (non-consumable)

**App Store Connect → your app → Monetization → In-App Purchases → +**

| Field | Value |
|---|---|
| Type | Non-Consumable |
| Reference name | Pro Lifetime |
| Product ID | `com.adaptiveservices.drivecap.pro.lifetime` |
| Price (Romania, base) | 399,99 lei |
| Suggested other prices | $79.99 · €79.99 |
| Family Sharing | Off |

| Language | Display name | Description |
|---|---|---|
| English (U.S.) | DriveCap Pro Lifetime | All Pro features, paid once. |
| Romanian | DriveCap Pro pe viață | Toate funcțiile Pro, plătite o singură dată. |
| French | DriveCap Pro à vie | Toutes les fonctions Pro, payées une fois. |

## 5. Review information (each of the three products)

**Screenshot:** `AppReview/iap_paywall.png`, the paywall showing all three plans.

**Review notes** (paste for each product):

> DriveCap Pro unlocks unlimited screenshot reading (the free version reads 10 earnings screenshots a month),
> earnings screenshots found automatically on Home, the Earn smarter tools (minimum fare, weekly goal, best times)
> and CSV export. The paywall is the last page of the first-launch tutorial, and opens from Settings → Upgrade to
> DriveCap Pro, from the Earn smarter columns on Home, and from Settings → Export. Purchases can be restored in
> Settings → Restore purchases. No account or login is needed.

## 6. Before submitting

- The **Paid Applications agreement** must be active (Business → Agreements), with bank and tax details.
- The first time, the products are reviewed **with an app version**: on the version page, under
  **In-App Purchases and Subscriptions**, add all three before submitting the build.
- The App Store description already has the auto-renewal terms and links to the Terms of Use (Apple's standard EULA)
  and the privacy policy, which Apple requires for subscriptions. Also add the privacy policy URL
  (`https://adaptivebyte.com/privacy-policy/`) in App Information.
- Optional: a promotional image (1024 × 1024) per product, if you want them shown on the product page.
