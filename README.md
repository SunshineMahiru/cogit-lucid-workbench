<h1 align="center">cogit-lucid-workbench</h1>

<p align="center">An externalized-metacognition workbench for personal review on HarmonyOS.</p>

<p align="center">
  <a href="./README.md">English</a> | <a href="./README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-AGPL--3.0-blue.svg" alt="License: AGPL-3.0"></a>
</p>

The app gives the loop people usually run in their head — record, analyze, calibrate, check against values — a local place to live. It is built for one person on one device, not for social sharing or team dashboards.

This repository contains the course build. Core flows are implemented and have been run on a HarmonyOS emulator. AppGallery publishing is outside this repository.

## Highlights

| Highlight | What it does |
|---|---|
| Capture without ceremony | Four note templates plus free-form capture, tags, security levels, and optional relation links. |
| Predictions with a due date | A judgment is written down before the outcome, locked after saving, settled on the due date, and counted into a hit rate. |
| Review in four steps | Facts, interpretation, contradiction, action. Selected value anchors travel with the saved review. |
| Three review-agent modes | Offline template, local mock endpoint, or an OpenAI-compatible model. A failed call falls back to the template. |
| Relations with boundaries | Trust levels, interaction logs, reverse links from notes and decisions, and an egocentric star map. |
| Local records, portable output | `relationalStore` is the source of truth; Markdown export covers seven record types. |

## Status

- Course build, feature-complete for FR1–FR8.
- Verified on a HarmonyOS phone emulator: HAP build, install, launch, navigation, local mock, charts, and Markdown export.
- The Chinese product name is not final; the launcher label is still the repository name.
- No dark mode, no full relation-network graph, and no store package in this repository.

## What is implemented

| Area | Behavior |
|---|---|
| Notes | Decision, interpersonal, emotion, and body templates; free-form notes; tags; security level; relation selection. |
| Predictions | Target, judgment, confidence, due date, reason; edit lock after saving; settlement, hit rate, line and ring charts. |
| Review | Four-step form, anchor selection, agent hints with insert action, weekly settlement card, history and detail. |
| Relations | Friendly / sincere / transparent trust levels, interaction log, boundary hint, linked notes and decisions, star map. |
| Status | Sleep, exercise, and alert readings; seven-record summary; history. |
| Settings and export | Provider, endpoint, model, monthly budget ledger, default security level, Markdown export. |

## Project layout

```text
entry/src/main/ets/
  pages/          Navigation destinations
  views/          Dashboard composition
  components/     Cards, charts, star map, shared UI
  note/           Capture, templates, draft, validation
  prediction/     Prediction rules and statistics
  review/         Review form, agent, history, weekly settlement
  relation/       Trust rules and relation views
  status/         Readings and history
  anchor/         Read-only value anchors
  analysis/       Pure analysis rules and LLM adapters
  db/             relationalStore schema and DAOs
  export/         Markdown filter, render, and file writer
  settings/       Preferences, budget ledger, sanitized settings
mock-server/      Local review-prompt endpoint
docs/             UI freeze record and debug images
```

## Quick Start

### Requirements

- DevEco Studio with the HarmonyOS SDK. The project targets `26.0.0` and is compatible with `6.1.1` (API 24).
- A HarmonyOS phone emulator or a HarmonyOS device.

### Run

1. Open this repository in DevEco Studio.
2. Wait for the project sync to finish.
3. Select the `entry` module, choose the emulator or device, and run.

The first screen is the dashboard. The module grid opens notes, predictions, review, anchors, relations, status, and settings. The weekly settlement card opens this week's summary.

## Optional local model mock

The default review provider is the offline template, so the app works without a server. To exercise the local mock:

```bash
node mock-server/server.js
hdc rport tcp:4523 tcp:4523
```

The reverse port is needed on an emulator because `127.0.0.1` inside the emulator points to the emulator itself, not the host. Then open Settings → Review Agent → Local mock.

Model mode uses the same OpenAI-compatible base URL (`http://127.0.0.1:4523/v1` by default). The API key stays in local Preferences and is not included in Markdown exports. Monthly spend is estimated from character counts and checked against the configured budget before a model call.

## Debugging and verification

### Environment used

| Item | Value |
|---|---|
| IDE | DevEco Studio 26.0 |
| Device | Mate 70 Pro emulator, 1260 × 2720 |
| SDK | target 26.0.0, compatible 6.1.1 (API 24) |
| Local server | Node.js mock on port 4523 |

### Build and install

From the project root, with `DEVECO_SDK_HOME` and `JAVA_HOME` configured:

```bash
node "<DevEco Studio>/tools/hvigor/bin/hvigorw.js" assembleHap --mode module -p product=default --no-daemon
hdc install -r entry/build/default/outputs/default/entry-default-unsigned.hap
```

The unsigned HAP is for the emulator and developer-mode devices. It is not a store package.

### Current verification record

| Check | Result |
|---|---|
| HAP build | Passed |
| Emulator install and launch | Passed |
| UI walk-through | Dashboard, weekly settlement, notes, predictions, charts, review, agent, relations, star map, anchors, status, settings, export |
| Markdown export | 24 records, 2580 characters, including the review section |
| Local regression harness | 46 + 17 + 22 + 4 assertions passed; TypeScript strict check passed |

The regression harness lives outside the committed tree, so these are recorded results rather than a public test command.

### Dashboard

<img src="./docs/images/debug/home.jpeg" width="300" alt="Dashboard with weekly settlement card, module counts, and recent notes">

*Dashboard after first run: weekly settlement, module counts, and recent notes.*

### Prediction statistics

<img src="./docs/images/debug/prediction-stats.jpeg" width="300" alt="Prediction statistics with hit-rate trend and settled share chart">

*Prediction statistics: hit-rate trend and settled share. The charts use MPChart on a native canvas.*

### Relation star map

<img src="./docs/images/debug/relation-graph.jpeg" width="300" alt="Relation star map with the self at the center and trust-colored nodes">

*Relation star map: the self at the center, relations around it, trust level by color. This is an egocentric view, not a full network graph.*

### Settings and export

<img src="./docs/images/debug/settings-model.jpeg" width="300" alt="Settings page with model endpoint, key field, and monthly budget">

*Model mode: endpoint, key field, monthly budget, and the current spend line.*

<img src="./docs/images/debug/export-result.jpeg" width="300" alt="Markdown export result with file name, character count, and record count">

*Export result: file name, character count, and record count. The exported file includes the review section.*

### Failure and fix: anchor seed

<img src="./docs/images/debug/anchor-error.jpeg" width="300" alt="Anchor page showing a load failure toast">

*Before the fix: seeding anchors failed on the emulator with a generic load error.*

<img src="./docs/images/debug/anchor-fixed.jpeg" width="300" alt="Anchor page with two demo anchors after the fix">

*After the fix: the anchor table no longer uses the reserved column name `order`; two demo anchors load normally.*

The toast only said “load failed”. The device log showed a SQLite `Generic error`; the column was renamed to `sort_order` and an `ALTER TABLE` migration handles older installs. The review table had the same problem with `action`, now stored as `next_action`.

### Review save

<img src="./docs/images/debug/review-saved.jpeg" width="300" alt="Review completion screen showing the saved action">

*A completed weekly review. The save path writes the four steps, selected anchor IDs, and the period range.*

### Debug notes

- Short scroll pages were vertically centered when content was smaller than the viewport. The affected pages now use `Alignment.Top`.
- The first star-map implementation used `Path` edges; on the emulator the lines were offset. The final version draws edges on a `Canvas`.
- The local mock is reached through an `hdc rport` reverse tunnel on the emulator. Without it, the review prompt panel correctly falls back to its error state.
- Prediction settlement was not exercised in the final visual pass because the seeded predictions were not yet due. The settlement page compiles and is covered by the local rules tests.
- A real external model endpoint was not exercised; template and local mock modes were.

## Documentation

| Topic | What it covers | Link |
|---|---|---|
| UI freeze record | Palette, type scale, component rules, visual checklist | [docs/UI_FREEZE.md](docs/UI_FREEZE.md) |
| Debug images | Screenshots used in this README | [docs/images/debug](docs/images/debug) |

## License

[AGPL-3.0](LICENSE)
