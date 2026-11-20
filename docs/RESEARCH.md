# LiftBros market research

Researched November 2026 by background research agents. App Store pages couldn't be reached directly, so review
themes come from aggregator sites and are indicative only. Prices are mostly US figures unless marked GBP.
**Check UK App Store listings before committing to pricing.**

## 1. Competitors

| App | What it does | Ranking / verification | Lesson for LiftBros |
|---|---|---|---|
| **Liftoff** (GymBros Inc.) | Free ranked workout logger, 400–600 exercises, ~1M lifters, ~4.8★ | Ranking is the core hook; exact maths unclear. Reviews call it "odd/buggy" | Ranking hooks people. **Crashes during set logging** and **features moved behind a paywall** are the top complaints |
| **Gym Rank / WeLift / IronRank / HitBosss** | Ranking-first clones | ELO and Bronze→Diamond tiers (Gym Rank). Monthly seasons and "Proofs" (IronRank). Video-verified lifts (HitBosss) | Crowded and **mostly global**. A UK gym-first identity is a gap |
| **Strong** | Clean logger, 1RM graphs, body stats; ~$30/yr Pro | None | Copy the simplicity and 1RM charts. Users want **rep targets from a 1RM** |
| **Hevy** | Best-in-class logging UX plus a social feed; ~$24/yr Pro | None | Free core and paid depth works. Follow friends |
| **JEFIT** | Big library, planner; ~$7/mo Elite, ads on free | Buddies only | Dated UI; cancellation complaints |
| **Fitbod** | AI-generated workouts; ~$96/yr | None | **Billing and cancellation pain** is a major trust killer |
| **Strava** | Segment leaderboards (KOM/QOM, Local Legend) | Automated anomaly detection plus community flagging | Multiple boards let more people "win". **Flagging plus appeals** is the realistic anti-cheat model |
| **StrengthLevel.com** | Strength standards from 195M lifts | Percentile tiers by sex, bodyweight and age | Best model for bodyweight-relative scoring |
| **OpenPowerlifting** | Meet results | Wilks / DOTS / IPF GL | DOTS is the federation standard for cross-bodyweight comparison |

No UK-specific gym leaderboard app was found. Brawn ran UK boards in 2020; its current status is unknown.

## 2. Ideas taken into the app

| Idea | Source | Status in this build |
|---|---|---|
| Offline-first logging that never loses a set | Liftoff complaints | ✅ Every change is saved to disk immediately and synced afterwards |
| Tiers (Bronze → Elite) from bodyweight ratio standards | StrengthLevel, Gym Rank | ✅ Per exercise and sex |
| Gym board **and** UK board | Strava segments, gap analysis | ✅ |
| Pound-for-pound board | StrengthLevel, DOTS | ✅ e1RM ÷ bodyweight on the day of the lift |
| Monthly seasons | IronRank | ✅ "This month" timeframe filter |
| Verified badge via video proof | IronRank, HitBosss | ✅ Unverified, Pending, Verified, Rejected |
| Community flagging | Strava | ✅ Swipe to flag; unverified lifts with 3+ flags are hidden |
| Body stats private by default | UK GDPR (special category data) | ✅ Separate audience settings for progress and body stats |
| 1RM graphs plus rep targets from 1RM | Strong | ✅ Progress charts and 1RM calculator |
| Plate calculator, rest timer, streaks, PR alerts | Feature research | ✅ |
| QR / geofenced gym join | Onboarding research | ⏳ Needs backend |
| Friends / follow feed | Hevy | ⏳ Needs backend |
| Most-frequent ("Local Legend") board | Strava | ⏳ Next |
| Age-band divisions, DOTS scoring | StrengthLevel, OpenPowerlifting | ⏳ Next |

## 3. Monetisation

Ranked by fit:

1. **Freemium Pro subscription.** Suggested at about **£3.99/mo, £29.99/yr or £79.99 lifetime**. Comparables: Hevy ~$24/yr, Strong ~$30/yr, Strava £54.99/yr (UK, 2023).
2. **Verification credits.** Video review costs money, so it is a natural metered feature: 1 free verification a month, unlimited and priority in Pro, or £1.99 per extra.
3. **Gym B2B licences.** Branded gym leaderboards, staff sign-off on verification, member challenges and aggregate analytics. Estimated at **£150–£400/mo per gym** or £1–£2 per active member. Start with independent gyms, then chains.
4. **Sponsored challenges.** Supplement, apparel and equipment brands fund monthly challenges and badges; an estimated £500–£3k per campaign at small scale.
5. **Affiliate links** (supplements and equipment): low margin, but an on-audience fit.
6. **Merch**: good for community, low revenue.
7. **Ads**: avoid. They undermine trust in a leaderboard product.

Benchmarks (RevenueCat 2025/26): median download-to-trial is 6.2%. Trial-to-paid is 42.5% on 17–32 day trials against 25.5% on trials of four days or less. The Apple Small Business Program commission is 15%.

### Recommended free vs Pro split

| Feature | Free | Pro |
|---|---|---|
| Logging, history, gym and UK leaderboards, pound-for-pound board | ✅ Unlimited | ✅ |
| Public or private progress, body stats | ✅ | ✅ plus body-composition trends |
| Friends, streaks, rest timer, plate calculator, 1RM tools | ✅ | ✅ |
| Video verification | 1 / month | Unlimited, priority queue |
| CSV export | Last 3 months | Full |
| Advanced charts, programme templates, AI form check | — | ✅ |
| Gym-vs-gym challenges | Join | Create |

**Rule: never paywall logging or the leaderboard.** That was Liftoff's backlash. Keep cancellation one tap and refunds simple; billing was Fitbod's and JEFIT's backlash.

## 4. Additional feature backlog

| Feature | Tier | Effort |
|---|---|---|
| PR push notifications | Free | S |
| Friend system and follow feed | Free | M |
| Gym-vs-gym competitions | Free | M |
| Sponsored monthly challenges | Free (brand-funded) | M |
| Apple Health and Apple Watch logging | Free | M |
| Programme templates and coached plans | Pro | M |
| CSV export | Pro | S |
| Gym staff sign-off for verification (B2B) | B2B | M |
| AI form and rep check from video | Pro | L |

## 5. UK considerations

- **UK GDPR**: bodyweight, body fat and gym videos are health-adjacent. You need an Article 6 lawful basis **plus** an Article 9 condition, which in practice means explicit consent. Run a **DPIA** before launch, especially for video.
- **Video**: footage captures bystanders. Keep proof private to reviewers by default, set short retention, let users delete, and consider face blurring.
- **Gym partnerships**: share only aggregate data with gyms (and never with employers) unless members opt in.
- **Age**: set a 16+ minimum, or require parental consent for under-16s, and follow the ICO Children's Code.
- **Pricing**: show GBP prices including VAT.
