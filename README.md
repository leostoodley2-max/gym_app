# LiftBros 🏋️

An iOS app for UK gym-goers to log lifts, climb their gym's leaderboard and see how they rank across the United Kingdom.

## Features

- **Workout logging**: 26 commercial-gym exercises, including bench press, squat, deadlift, lat pulldown, leg press, cable rows, machines, dumbbells and weighted pull-ups/dips. Log weight × reps, warm-ups and RPE. It includes a rest timer and PR celebrations, and pre-fills from your last set.
- **Leaderboards**: **My Gym** and **United Kingdom** boards for every exercise. Filter by division (Open, Men, Women), all time or this month's season, and verified-only.
- **Pound-for-pound board**: a separate ranking by estimated 1RM ÷ bodyweight at the time of the lift.
- **Proof and verification**: attach a video or photo of a set from your library. Sets with proof go *Pending → Verified*; sets without proof still rank, marked *Unverified*. Anyone can flag a suspicious lift.
- **Strength tiers**: Bronze → Silver → Gold → Platinum → Diamond → Elite per lift, from bodyweight-ratio standards adjusted by sex.
- **Progress tracking**: e1RM charts with next-tier target lines, personal bests, weekly volume, streaks and a bodyweight trend.
- **Privacy controls**: choose who sees your progress and your body stats (Everyone / My gym / Only me), and whether you appear on leaderboards.
- **Body profile**: bodyweight, body fat, lean mass, height, BMI, age, years lifting, training days and goal.
- **Tools**: a plate calculator (UK plates) and a 1RM calculator with rep targets.
- Works offline: everything is saved on the device as you log.

## Running it

Requires **Xcode 16+** and iOS 17+.

1. Open `LiftBros.xcodeproj`.
2. Pick an iPhone simulator and press **Run**.
3. To run on your own phone, choose your team under *Signing & Capabilities* and change the bundle ID from `com.liftbros.app`.

The app runs against `MockBackendService`, a generated community of ~300 lifters across 13 (fictional) UK gyms, so the leaderboards are populated straight away. Proof uploads are "reviewed" automatically after about 6 seconds so you can see the verification flow end to end. See [docs/BACKEND.md](docs/BACKEND.md) for connecting a real backend.

## Tests

The platform-independent core (models, scoring, leaderboard ranking, progress analysis, mock data and persistence) is a Swift package:

```sh
swift test
```

CI (`.github/workflows/ci.yml`) runs those tests and builds the iOS app on every push.

## Project layout

```
LiftBros/
  App/          App entry point and AppStore (state, persistence, sync)
  Core/         Platform-independent code, also built as the LiftBrosCore package
    Models/     Exercise library, profile, workouts, leaderboard types
    Logic/      StrengthCalculator, LeaderboardEngine, ProgressAnalyzer, PlateCalculator
    Services/   BackendService protocol, MockBackendService, LocalStore
    Data/       Deterministic UK mock community
  Features/     SwiftUI screens: Onboarding, Workout, Leaderboard, Progress, Profile, Tools
  Components/   Theme, badges and inputs
Tests/LiftBrosCoreTests/
docs/
  RESEARCH.md   Competitor, monetisation and feature research
  BACKEND.md    Backend schema and verification pipeline plan
```

## Roadmap

See [docs/RESEARCH.md](docs/RESEARCH.md). In short: a real backend with Sign in with Apple, gym join by QR code, a friends feed, gym-vs-gym challenges, Apple Health/Watch, a LiftBros Pro subscription (never paywalling logging or leaderboards) and gym B2B partnerships.
