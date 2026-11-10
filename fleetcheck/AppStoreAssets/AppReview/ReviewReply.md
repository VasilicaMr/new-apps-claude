# Reply to App Review (information request)

Paste the reply below into **App Store Connect → App Review → Messages**, attach the screen recording, and paste the
same text into **App Review Information → Notes** on the version page.

**Paste [`reply.txt`](reply.txt), not the text below:** it is the plain-text version under the 4000-character
limit of the Notes field (about 3150 characters). The longer version below is kept for reference.

---

Hello,

Thank you for reviewing DriveCap. Below is the requested information. A screen recording made on a physical iPhone
running the latest iOS is attached.

**1. Screen recording**

The attached recording starts at app launch and shows: the welcome tutorial; starting and ending a shift; reading
earnings from a sample earnings screenshot; photographing a fuel receipt; the Stats and Diary tabs; the Car papers
reminders; the Ask assistant; and the paid features: the DriveCap Pro paywall, a sandbox purchase, the unlocked Pro
features (Earn smarter, CSV export) and Restore purchases.

DriveCap has no account registration or login, so there is no account creation or account deletion flow. It has no
user-generated content shared with other users: everything a user logs stays on their own iPhone. All data can be
erased at any time in Settings → Delete all data.

**2. Purpose and target audience**

DriveCap is a personal logbook for individual ride-hailing and taxi drivers (Uber, Bolt, FREENOW and similar
platforms). These drivers usually see only their gross fares in the platform app and don't know what they really
keep after fuel, the car and the platform's commission.

DriveCap solves this by:
- reading the driver's own earnings screenshots (fares, tips, bonus, trips, kilometers) so they don't have to type
  them;
- reading fuel and service receipts from a photo;
- timing shifts with one tap (with a Live Activity on the Lock Screen);
- showing the real net after costs per day, week and month, and per hour and per km;
- reminding them of car paperwork (technical inspection, insurance, road vignette, oil change).

The app is meant for the general public: any individual who drives for a ride-hailing platform. It is not made for a
specific company, fleet or organization, and it is not affiliated with Uber, Bolt or any other platform.

**3. How to set up and access the main features**

No login, account or credentials are needed. A sample earnings screenshot is attached in App Review Information.

1. Save the attached sample earnings screenshot to Photos.
2. Open DriveCap and swipe through the short tutorial (the last page shows the DriveCap Pro offer; it can be closed).
3. On Home, tap **Start shift**, then **End shift**. The screenshot picker opens: choose the sample screenshot. The
   fares, tips, trips and kilometers are filled in; tap **Save**.
4. Tap **Scan receipt** on Home to photograph any fuel or shop receipt; the expense is filled in.
5. See the results in **Stats** and **Diary**; add car paperwork dates in **Car**.
6. Tap the sparkles button (**Ask**) and ask "How much did I make this week?" or type "fuel 40 38 L".
7. Paid features: **Settings (gear on Home) → Upgrade to DriveCap Pro**. Pro is offered as a monthly or yearly
   auto-renewable subscription (each with a 1-week free trial) or a one-time Lifetime purchase. Pro unlocks unlimited
   screenshot reading (the free version reads 10 a month), screenshots found automatically in Photos, Earn smarter
   (minimum fare, weekly goal, best times) and CSV export. Purchases are restored in **Settings → Restore purchases**.

On devices with Apple Intelligence, screenshots and questions are handled by the on-device model; on other devices
the app uses built-in text parsers, so every feature works on all supported iPhones and iPads.

**4. External services**

DriveCap does not use any server, account system, analytics, advertising or third-party SDK, and makes no network
requests of its own. It uses only Apple frameworks on the device:
- Apple Intelligence (Foundation Models framework), on-device, to read screenshots and answer questions;
- Vision, on-device text recognition for screenshots and receipts;
- StoreKit / In-App Purchase for DriveCap Pro;
- Photos (with the user's permission) to find earnings screenshots, and the Camera for receipts;
- ActivityKit (Live Activity), App Intents (Siri) and local notifications for reminders.

Screenshots and receipts are read on the device and never uploaded.

**5. Regional differences**

The app works the same in all regions. It is localized in English, French and Romanian, and the user picks their
currency in Settings. The only difference is outside the app's control: where Apple Intelligence is not available
(device, region or language), the built-in on-device parsers are used instead, with the same features.

**6. Regulated industry / third-party material**

DriveCap does not operate in a regulated industry. It is a personal record-keeping tool: it does not provide
transport services, process payments other than Apple In-App Purchase, or give tax, legal or financial advice. It
does not contain or access third-party content: it only reads screenshots the user took of their own earnings.
Platform names such as Uber and Bolt are used only to describe compatibility, and the app states that it is
independent and not affiliated with them.

Contact for any question: Marin Vasilica, vasilica.pirlitu@gmail.com.

Thank you,
Marin Vasilica

---

## Recording checklist (do this on a real iPhone, latest iOS)

Control Center → Screen Recording. Delete the app first so the recording starts from a fresh install.

1. Start recording on the Home Screen, then **tap the DriveCap icon** (the recording must begin with the launch).
2. Tutorial pages → close the paywall page.
3. Start shift → End shift → pick the sample screenshot → numbers fill in → Save.
4. Scan receipt with the camera → Save.
5. Stats, Diary, Car (add an inspection date), Ask ("How much did I make this week?").
6. Settings → Upgrade to DriveCap Pro → buy Monthly with a **Sandbox account** (sign in under Settings → Developer →
   Sandbox Apple Account on the iPhone) → show Earn smarter and CSV export unlocked.
7. Settings → Restore purchases.
8. Settings → Delete all data (shows the user can erase everything).

Keep it under about 3 minutes; trim with Photos if needed. Upload the `.mp4`/`.mov` as an attachment to the reply.
