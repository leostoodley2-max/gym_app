# Monetisation setup

LiftBros makes money from two products. Neither paywalls the core loop: logging, gym leaderboards, the national top 100 and privacy controls stay free for everyone.

## 1. LiftBros Pro (consumer subscription)

| | Free | Pro |
|---|---|---|
| Log workouts, gym leaderboards, national board | ✅ | ✅ |
| Evidence uploads for the national board | 3 / month | Unlimited |
| Evidence review | Standard queue | **Priority** (mock: 3× faster) |
| Progress charts | Last 8 weeks | All-time |
| Head-to-head compare on lifter profiles | — | ✅ |
| CSV export of every set | — | ✅ |
| Custom default rest timer | 2 min | 1–5 min |
| Pro badge on leaderboards | — | ✅ |

- **Prices (provisional):** £3.99/month or £29.99/year with a 2-week free trial on yearly. Product IDs: `com.liftbros.pro.monthly` and `com.liftbros.pro.yearly` (`ProProduct`).
- **Code:** limits and feature list are in `Core/Models/Plans.swift` (`ProFeature`, `PlanLimits`). StoreKit 2 purchase, restore and entitlements are in `App/SubscriptionManager.swift`. The paywall is `Features/Pro/PaywallView.swift`.
- **Testing in Xcode:** Product ▸ Scheme ▸ Edit Scheme ▸ Run ▸ Options ▸ StoreKit Configuration ▸ `LiftBros.storekit`.
- **Sideloaded or test builds** can't reach the App Store, so the paywall offers *Preview Pro (testing only)*. It only appears when no products load, so App Store builds always go through a real purchase.
- **Before launch:** create the subscription group and products in App Store Connect, add a privacy policy and terms URL to the paywall, and enable the Small Business Program (15% commission).

## 2. LiftBros for Gyms (B2B leaderboard screens)

Gyms subscribe to show their honour-system leaderboard live on the gym's TVs.

| Tier | Price (provisional, per site, ex VAT) | Includes |
|---|---|---|
| **Screen** | £99/mo | 1 screen, rotating boards for the big lifts, QR code to join |
| **Screen+** | £199/mo | Up to 4 screens, gym branding and colours, monthly challenges with prizes, engagement analytics |
| **Network** | Custom | Multi-site chains, gym-vs-gym competitions, group analytics |

**What's built:**
- **Data model:** `GymPartnership` (tier, status, pairing code, `ScreenConfig`, `GymChallenge`) and `GymPartnerTier` (pricing and entitlements), in `Core/Models/Plans.swift`.
- **Backend calls:** `BackendService.fetchPartnership(gymID:)` and `pairScreen(code:)`. The mock has three sample partners: PureGym Worcester (`WORC-2026`), Abbey Stadium Redditch (`ABBY-7788`) and Wyreside Barbell (`WYRE-0001`, Screen tier, so no challenge).
- **Screen app:** `Features/GymScreen/GymScreenView.swift`, opened from Profile ▸ Gym screen mode. You pair with a code, and the screen then shows a full-screen board that rotates exercises and metrics every 12 s. It also shows the gym's challenge (Screen+ only), the clock and a join QR code, and keeps the device awake. Landscape suits TVs and iPads; Apple TV can mirror it over AirPlay.
- **In-app:** the gym's Rankings tab shows an *ON SCREEN* badge, and Profile ▸ LiftBros for gyms explains the tiers.

**Next steps:**
1. A partner dashboard (web) where gym staff manage screens, codes, branding and challenges, and see analytics.
2. A browser-based screen (`liftbros.app/screen/<code>`) so any smart TV works without an iPad.
3. Stripe billing for gyms with monthly invoicing, and `PartnershipStatus` driven by webhooks.
4. A data-sharing agreement: gyms only see aggregate stats plus members who opted in to leaderboards (UK GDPR).
