# LoopAware

> Break the loop. Reclaim your focus.

LoopAware is a Flutter-based digital-wellness companion that turns raw
Android screen-time into clear, actionable scores: addiction risk, focus,
sleep impact and digital burnout. It detects dopamine loops, surfaces
prioritised insights, and provides a personalised on-device wellness coach.

## Features

- **Live Android usage tracking** via the `app_usage` plugin plus a native
  Kotlin MethodChannel that opens the system Usage Access settings.
- **Seeded demo data** so the app is fully functional on emulators,
  desktop and any device where usage access hasn't been granted.
- **On-device scoring engine** (heuristic model) computing four wellness
  metrics with deltas, severity bands and prioritised insights.
- **Wellness coach** — a rule-based chatbot that personalises advice from
  the user's current scores and screen-time profile (no LLM required).
- **Light & dark themes**, calm indigo/teal palette, animated score rings,
  charts (line, bar, donut, hourly heatmap) powered by `fl_chart`.
- **Firebase Auth + Firestore** for sign-up, sign-in, password reset and
  optional daily wellness snapshot sync.

## Project layout

```
lib/
├── main.dart                   # Entry point + MaterialApp + routes
├── firebase_options.dart       # FlutterFire configuration
└── src/
    ├── config/                 # Theme, routes, constants
    ├── models/                 # UsageLog, Prediction, Severity, Insight
    ├── services/               # Auth, Firestore, Usage, Demo, Scoring, Prefs
    ├── state/                  # AppState (ChangeNotifier)
    ├── utils/                  # Validators, formatters, snackbar
    ├── widgets/                # Cards, charts, common widgets
    └── screens/
        ├── splash/             # SplashScreen
        ├── onboarding/         # OnboardingScreen
        ├── auth/               # Login, Signup, Reset password
        ├── main/               # Home shell + Dashboard, Analytics,
        │                       # Insights, Settings
        └── coach/              # Wellness coach chatbot
```

## Development roadmap

The full multi-phase plan that shaped this app lives in
`DEVELOPMENT_ROADMAP.md` on the original author's desktop. The current
codebase covers Phases 1–6 with the optional FastAPI ML backend
substituted by the on-device `ScoringEngine`.
