# Devpost paste sheet

Paste these into the RevenueCat Shipaton submission. Spoken name is OpenCane. Do not add a funding dollar amount. Do not attribute the Landuyt Center naming gift to this project.

**Project name:** OpenCane

**Tagline:** A white cane that warns you about what is at waist and head height, with safety always free.

**Built with:** Swift, SwiftUI, ARKit, LiDAR, Core Haptics, RevenueCat, StoreKit, WatchKit, MapKit

**Try it:** https://github.com/TCYTseven/OpenCane

## About the project

A white cane finds what is on the ground. It misses a low branch, a truck mirror, or a sign at face level. OpenCane clips an iPhone Pro to the cane you already own. The phone's LiDAR watches waist and head height, the Taptic Engine shakes the cane, and "Head height." is spoken before you reach an overhang. AirPods play a spatial beacon toward the next turn. An Apple Watch taps crossings onto the wrist. "Where am I" describes the scene on the phone when there is no network.

Obstacle detection, haptics, spatial audio, speech, walking navigation, and emergency calling stay free. OpenCane Premium is $49.99 a year, with the first month free for an Apple Account that can still redeem the introductory offer. Premium adds Hazard watch (cones, barriers, and scooters on the route), people counting, and family alerts through the Grok Bot. The paywall does not open during a walk. Turn Hazard watch on mid-route and the cane says to finish the walk first. Stop, then the paywall appears. RevenueCat is the only third-party package. The purchase unlocks the feature the moment StoreKit returns.

The mount is 3D-printed. Nothing else has to be bought beyond the phone. The app is MIT licensed.

## Inspiration

Blind and low-vision walkers already trust a white cane. The cane cannot see what is coming at the chest or the face. The team built the computer onto the cane people already carry, instead of asking them to buy a new one.

## How we built it

Native iOS 26 app in Swift 6. Depth, haptics, speech, and the Premium gate are tested as pure rules in CaneKitLogic. RevenueCat `purchases-ios` lives in one file, `EntitlementManager.swift`. The local StoreKit file `opencane_premium_annual` is the annual product at $49.99 with a one-month free intro, entitlement `premium`, offering `default`. The paywall is custom SwiftUI so VoiceOver reads the price as sentences, including "The first month is free" only when that account is eligible.

## Challenges

A paywall during a walk is a safety problem, so the gate refuses Premium switches while a route is active and closes the sheet if a walk starts. The product's introductory offer still exists after someone has used it, so the paywall asks RevenueCat whether this Apple Account is eligible before it promises a free month. Returning customers see the charge-at-subscribe terms instead.

## Accomplishments

- First place overall at 54FoundersHack, 1st of 250.
- Third place on the SpaceX track. SpaceXAI ambassadors are working with the team.
- Launch posts passed 100,000 impressions on LinkedIn.
- More than 100 schools across the country have written in.
- The team is at the University of Illinois Urbana-Champaign and is working with the university and the Landuyt Center for Entrepreneurship (https://landuyt.illinois.edu/).
- Funding is in place to keep building.

## What we learned

Safety features cannot sit behind a purchase. The subscription has to be the extra awareness and the family loop, and it has to wait until the person is standing still.

## What's next

Cane-mounted walks that tune the head-height and drop-off thresholds, then the same kit in more hands through the schools that have already written in.

## Demo beats

Follow `docs/DEMO_SCRIPT.md`. The cut judges should see:

1. Splash and onboarding.
2. A walk. The cane buzzes and says "Head height." Obstacle detection stays free.
3. Hazard watch during the walk. No paywall. A voice notice says to finish the walk first.
4. Stop. Hazard watch opens the paywall. "The first month is free." Then $49.99/year.
5. StoreKit test purchase. Hazard watch turns on.
6. The unlocked feature: a cone or barrier on the route, or Settings → Send a test alert.

## Images already in the repo

- `docs/images/devpost-1179x2556.png` (1179×2556, no device chrome)
- `docs/images/splash.png`
- `docs/images/onboarding.png`
- `docs/images/guide.png`
- `docs/images/navigating.png`
- `docs/images/paywall.png`
- `docs/images/settings-premium.png`
- `docs/images/hazard-watch.png`
- `docs/images/opencane-icon-1024.png`

**Team:** Aritro, Aarav, Tejas (software). Sagar, Tommy (hardware).
