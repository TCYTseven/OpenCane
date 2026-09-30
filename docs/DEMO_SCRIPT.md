# Two-minute demo script (RevenueCat Shipaton)

The video judges watch: splash, onboarding, a real walk with obstacle detection, a tap on a
Premium feature, the paywall, a test purchase, and the unlocked feature working. Times are
targets; the whole cut should land under 2:00.

## Before you record

- [ ] Build a **Debug** build from Xcode with the `CaneKit` scheme. The scheme's Run action uses
      `ios/StoreKit/OpenCane.storekit`, so the purchase is a free local test purchase.
- [ ] `REVENUECAT_API_KEY` is in `ios/CaneKit/Resources/Secrets.plist`. The product, entitlement
      and offering exist in RevenueCat, and the StoreKit test certificate is uploaded (README →
      "Test the paywall").
- [ ] **Delete the app first**, so the take starts with the splash and onboarding.
- [ ] Phone in Dark Mode, battery above 40 %, AirPods connected, watch paired.
- [ ] Pick a safe, quiet stretch with one **head-height obstacle**, such as a low branch, a sign
      or a tape line at head height between two stands. A sighted spotter walks beside the cane
      user for the whole take.
- [ ] Two recordings at once: the phone's screen recording (Control Center) and a second camera
      on the cane and the walker. Cut between them.
- [ ] If a StoreKit test purchase will not run on the phone once it is unplugged from the Mac,
      record the paywall part (steps 4–6) tethered or in the simulator. The walk stays untethered.

## The take

| Time | Show | Say (voice-over) |
|---|---|---|
| 0:00–0:06 | Cold launch: navy launch screen, the logo, the wordmark, then onboarding. | "OpenCane turns the iPhone you already own into a smart cane." |
| 0:06–0:25 | **Onboarding.** Swipe page 1 → page 2 (LiDAR, waist and head height) → page 3. On page 4, tap **Allow** on camera, location and microphone, then **Get Started**. Optionally turn on VoiceOver for one page to show that Next is reachable and the title is read. | "A cane finds what's on the ground. It misses what's at waist and head height. That's what the LiDAR covers." |
| 0:25–1:05 | **A real walk.** Clip the phone to the cane. Guide → start a route (or type a destination and tap Go). Walk toward the head-height obstacle: the cane buzzes and you hear **"Head height."** Cut to the Details tab's lane grid turning red, and to a wrist tap on the watch at a turn. | "Obstacle detection, haptics, spatial audio and turn-by-turn guidance are free, for everyone, always." |
| 1:05–1:15 | Still walking, tap **Details → Hazard watch**. **No paywall.** You hear "Premium features can be turned on after this walk." Then **Stop route**. | "OpenCane never puts a paywall in front of someone mid-walk." |
| 1:15–1:30 | Stopped. Tap **Hazard watch** again: the **OpenCane Premium** paywall shows the two benefits, **$49.99/year** with the per-month price, the affordability note, and "navigation and obstacle detection are always free". | "Premium adds two things: advanced AI object detection, and Grok Bot Family Alerts. It may be reimbursable through insurance, an HSA or FSA, or a vision rehab program." |
| 1:30–1:42 | Tap **Subscribe**, confirm the StoreKit test sheet. The paywall closes and Hazard watch is already **on**. Flash Settings → "OpenCane Premium is on · Renews on …". | "RevenueCat handles the subscription, restore and entitlement. It unlocks the moment the purchase goes through." |
| 1:42–1:58 | **Unlocked feature working.** Start the route again and walk past a cone or barrier: Hazard watch speaks it. Or: Settings → Family alerts → **Send a test alert**, then show the family email or text arriving. | "Hazard watch spots cones, barriers and scooters, and family alerts let the people who care know if something goes wrong." |
| 1:58–2:00 | End card: logo, "OpenCane · open source · MIT". | — |

## Backup shots if something misbehaves

- **Head height does not fire:** check the tilt on Settings → Phone on cane ("Camera tilt")
  first. The head band needs a shallow mount angle.
- **Hazard watch says nothing:** it asks every 8 seconds, and only during a route. Walk past the
  cone slowly, or use the Family alerts test send as the unlocked feature instead.
- **The paywall shows "Couldn't load the price":** RevenueCat has no product in the `default`
  offering yet. Tap **Try again** after fixing the dashboard.
- **To re-run the purchase:** Xcode → Debug → StoreKit → Manage Transactions → delete the
  transaction, then relaunch.
