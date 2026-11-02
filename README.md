<h1 align="center">cogit-lucid-workbench</h1>

<p align="center">A local-first HarmonyOS workbench that turns the metacognition loop — record, review, calibrate, check against anchors — into a daily habit.</p>

<p align="center">
  <a href="./README.md">English</a> | <a href="./README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <a href="./LICENSE"><img src="https://img.shields.io/badge/License-AGPL--3.0-22C55E?style=flat-square" alt="License: AGPL-3.0"></a>
  <img src="https://img.shields.io/badge/HarmonyOS-ArkTS-3776AB?style=flat-square" alt="HarmonyOS ArkTS">
  <img src="https://img.shields.io/badge/API-24-4B5563?style=flat-square" alt="API 24">
  <img src="https://img.shields.io/badge/version-1.0.0-F59E0B?style=flat-square" alt="Version 1.0.0">
</p>

## Overview

cogit-lucid-workbench is a single-module HarmonyOS application, labelled **Cogit Lucid** on the device. It keeps a private record of what you noticed, what you decided, what you predicted, and how you reviewed it, then feeds those records into the next round. It is aimed at people who already keep a review habit and want their judgments to stay checkable afterwards.

Three design choices separate it from a journal:

- **A prediction is frozen when saved.** Each one carries a confidence score, a reason, and a settlement date fixed in advance. You settle it against the outcome later, so the original call cannot be quietly edited into a hit. Revisions are stored as versions.
- **The model is opt-in.** Records live in the on-device database. The review agent reads them only when you switch to a model mode, and the API key stays on the device.
- **Anchors are read-only.** A small set of statements you chose to keep acts as the reference a contradiction is checked against, instead of advice invented at review time.

The interface is Chinese only. The display name is set in `entry/src/main/ets/theme/AppIdentity.ts` and the launcher label in `AppScope/resources/base/element/string.json`.

The launch screen opens with an identity band — avatar, nickname, signature, and a hand-written title — followed by four counters: notes today, pending settlements, consecutive record days, and the latest review date. Readings, the weekly card, and the module grid sit below it.

## Project status

The current build covers notes, predictions and settlement, review and the agent, relations, anchors, status, settings with page backgrounds and surface opacity, and export. Both a light and a dark palette ship, and the interface follows the system colour mode. The home page is a normal destination on one navigation stack, so forward and back animate both pages. The project is still being refined.

## Highlights

| Highlight | What it gives you |
|---|---|
| Frozen prediction log | Target, judgment, confidence 0-100, reason, and a settlement date written once; settlement fills the outcome and marks hit or miss. |
| Hit-rate statistics | Overall rate, a monthly trend limited to the last six months, and a hit/miss donut, drawn with `@ohos/mpchart`. |
| Four-step review | Facts, interpretation, contradiction, action. The contradiction step can quote up to three anchors. |
| Three-tier trust | Each relation carries a friendly, sincere, or transparent tier and renders as a star graph centred on you. |
| Threshold readings | Sleep below 6.5 hours, zero exercise, or one late-night alert raises a flag on the status panel. |
| Markdown export | Seven record groups render into one Markdown file inside the app sandbox. |
| Home identity band | Avatar, nickname, signature, and a hand-written title sit above four counters: notes today, pending settlements, record streak, and the latest review. |
| Backgrounds and page opacity | Set one default picture or one per module, taken from the gallery, the camera or the file picker. The page surface itself takes 0-60% transparency, so the setting works with or without a picture. |

## Architecture

The code is organised as six layers with a single dependency direction, plus a shared type layer at the bottom. A layer only calls the layers below it; `analysis/` imports nothing but `model/` types, so rules stay testable without a database or a UI. The `data/` layer owns cross-entity read models such as the dashboard aggregate.

```text
┌─────────────────────────────────────────────────────────────┐
│ interaction   pages/  views/  components/  navigation/      │
│               render and route dispatch                     │
├─────────────────────────────────────────────────────────────┤
│ domain        note/  prediction/  review/  anchor/          │
│               relation/  status/                            │
│               validation, composition, projection           │
├─────────────────────────────────────────────────────────────┤
│ data/         dashboard aggregate, cross-entity reads       │
├─────────────────────────────────────────────────────────────┤
│ analysis/     contradiction  calibration  anchors/trust     │
│               status rules   llm adapter                    │
│               imports model/ only                           │
├─────────────────────────────────────────────────────────────┤
│ network/      prompt repository  OpenAI-compatible          │
│               local mock client  cleartext blocked by default│
├─────────────────────────────────────────────────────────────┤
│ records       db/  settings/  export/                       │
│               relationalStore, Preferences, Markdown        │
├─────────────────────────────────────────────────────────────┤
│ model/        seven entity types, enums, factories          │
│               no imports outside model/                     │
└─────────────────────────────────────────────────────────────┘
```

- ArkTS pages with state management V2 (`@ComponentV2`, `@Local`, `@Param`); entity models and services in plain TypeScript.
- Navigation with `NavPathStack`; 24 route names are centralised in `entry/src/main/ets/navigation/Routes.ts`, and a new page only adds a branch to `Index.pageMap`.
- `relationalStore` is the single source of truth, `Preferences` holds non-secret options, the model key is stored in the system asset service, and `fileIo` writes the Markdown export.
- `@ohos/mpchart` 3.1.0-rc.0 is the only runtime dependency. Icons come from system glyphs rather than an icon pack.
- `profile/` holds the home identity: a Preferences store for the four text fields plus a 320 px avatar pipeline.

## Usage Example

The home page opens with the identity band and four counters; today's readings, a weekly settlement card, and the grid of six modules follow below. `编辑` and `设置` sit on the right of the identity band.

<img src="./docs/images/debug/home.jpeg" width="300" alt="Dashboard with sleep, exercise and note readings, a weekly settlement card, and a grid of six modules">

### Set your identity

1. Tap `编辑` on the identity band.
2. Pick an avatar from the gallery, the camera, or the file picker; the picture is centre-cropped to a 320 px square and stored in the app sandbox.
3. Fill in a nickname (up to 12 characters), a signature (24), and a title (8).
4. Tap `保存`. The band updates at once and keeps the values after a restart.

Expected result: the header shows the new avatar and text; an empty nickname or title falls back to `记录者` and `未命名`.

### Keep one prediction

1. Open the prediction module (`预测`). Pending settlements are listed by due date first; settled ones by creation time.
2. Tap `+`. Fill in the target, the judgment, a confidence between 0 and 100, the reason, and the settlement date.
3. Save. The record is append-only from here — a later edit adds a version instead of overwriting the original.
4. On the due date, open the detail page, record the actual outcome, and mark it hit or miss.
5. Open prediction statistics (`预测统计`) for the overall rate, the trend, and the split.

Expected result: after two or three settled predictions the statistics page draws a trend line and a donut around the rate. With nothing settled yet, the rate shows a dash rather than 0 percent, and the sample count is stated next to it.

### Run one review

1. Open the review module (`复盘`) and pick the week or month tab. Each tab keeps its own draft.
2. Work through the four steps: facts, interpretation, contradiction, action. Facts and action are required.
3. In the contradiction step, tick up to three anchors to check the explanation against.
4. Optionally open the agent panel to generate contradiction candidates. Template mode is offline; mock and model modes call an endpoint.
5. Save. The period shows as complete and the session is kept in review history.

### Set a page background

1. Open settings (`设置`) and tap `更换页面背景`.
2. Pick a source: `从相册选择`, `拍一张`, or `选择文件`. The picture is converted to PNG and capped at 1080×1920.
3. On the apply page, either set it as the default for every page, or tick the modules that should carry it.
4. Adjust `页面透明度` for all pages, or only for the ticked module, then tap `完成`.

Expected result: the module you open shows the picture behind its cards. Transparency at 0% keeps the surface solid; raising it lets the system wallpaper show through, whether or not a picture is set.

### Take the records out

Settings (`设置`) writes the whole record set to `cogit-export-YYYYMMDD-HHMM.md` inside the app sandbox and reports the file name, character count, and record count. Sealed records are left out.

## Screens

Screenshots come from a Mate 70 Pro emulator. Every record in them is synthetic. They were captured before the identity band was added; the current home page carries that band above the content shown here, and the rest of the layout is unchanged.

| Prediction statistics | Review complete |
|---|---|
| <img src="./docs/images/debug/prediction-stats.jpeg" width="300" alt="Prediction statistics page showing a 63 percent hit rate, a six-month trend line and a hit or miss donut"> | <img src="./docs/images/debug/review-saved.jpeg" width="300" alt="Review page confirming this week is complete and showing the recorded action line"> |
| **Anchors** | **Relation graph** |
| <img src="./docs/images/debug/anchor-fixed.jpeg" width="300" alt="Anchor page listing two read-only sample anchors with a button to start a review"> | <img src="./docs/images/debug/relation-graph.jpeg" width="300" alt="Relation graph with the centre node labelled me and three contacts coloured by trust tier"> |
| **Settings, model mode** | **Markdown export** |
| <img src="./docs/images/debug/settings-model.jpeg" width="300" alt="Settings page in model mode with provider tabs, model choice, budget slider, endpoint field and API key field"> | <img src="./docs/images/debug/export-result.jpeg" width="300" alt="Settings page after export, reporting the written Markdown file name, character count and record count"> |

## Quick Install

### Requirements

- DevEco Studio with the HarmonyOS SDK installed. The project targets `targetSdkVersion` 26.0.0 and is compatible with 6.1.1 (API 24).
- A HarmonyOS phone emulator or a phone. `deviceTypes` declares `phone` only.
- Node.js, only if you want the local mock server.

### Get the code

```bash
git clone git@github.com:SunshineMahiru/cogit-lucid-workbench.git
cd cogit-lucid-workbench
```

A mirror is served from `git@gitee.com:theangelnextdoor/cogit-lucid-workbench.git`.

### Install dependencies

Open the project in DevEco Studio and let Sync finish. The only runtime dependency is `@ohos/mpchart` 3.1.0-rc.0, declared in `oh-package.json5`.

A command line build is possible from the project root:

```bash
node "<DevEco Studio>/tools/hvigor/bin/hvigorw.js" assembleHap --mode module -p product=default --no-daemon
```

`DEVECO_SDK_HOME`, `NODE_HOME`, and `JAVA_HOME` need to point at the DevEco toolchain first. The tracked profile has no signing config; without a local signing file the output is an unsigned HAP.

## Quick Start

1. Open the project in DevEco Studio and wait for Sync to finish.
2. Start a phone emulator or connect a phone.
3. Select the `entry` module and run.
4. On the dashboard, open notes (`速记`), write one line, and save.
5. The note appears under recent notes, and the dashboard counters move off zero.

Expected result: the dashboard reports one note today and one in total, and the weekly settlement card starts counting it.

## Configuration

### Local mock server

The review prompt panel talks to a zero-dependency Node server in `mock-server/`.

```bash
node mock-server/server.js
```

It listens on `0.0.0.0:4523`; set `PORT` to change the port.

| Method | Path | Response |
|---|---|---|
| GET | `/health` | `{ "status": "ok" }` |
| GET | `/review-prompts?period=week` | `{ "prompts": [...] }` |
| GET | `/review-prompts?period=month` | `{ "prompts": [...] }` |
| POST | `/llm/complete` | Mock completion used by the local mock client |
| POST | `/v1/chat/completions` | OpenAI-compatible `choices[0].message.content` |

### Pointing the app at the server

- DevEco previewer: `http://127.0.0.1:4523` works as is.
- Emulator: `127.0.0.1` resolves to the emulator itself. Forward the port with `hdc rport tcp:4523 tcp:4523`, or point the model base URL in settings at the host address.
- Real device: localhost is not treated as a valid host. Set the model base URL to your host's address; otherwise the app shows local fallback prompts.
- Cleartext HTTP stays off by default; only `127.0.0.1` and `localhost` are allowlisted in `entry/src/main/resources/base/profile/network_config.json`. Add your own host there locally when a real device has to reach the mock server over HTTP, and keep that edit out of commits. The client timeout is 5 seconds.

### Backgrounds and page opacity

| Item | Detail |
|---|---|
| Entry point | Settings → `页面背景` → `更换页面背景` |
| Sources | Gallery, camera, or the document picker limited to picture suffixes. Every source is normalised to PNG and capped at 1080×1920 before it is stored. |
| Scope | One default picture covers every page without a picture of its own; a module that has its own picture overrides it, and clearing that picture returns the module to the default. |
| Ranges | Picture strength 4%-30% (default 10%); page transparency 0%-60% (default 0%). |
| Storage | `${filesDir}/page-backgrounds`, named by content hash so an identical picture is stored once; files no module points at are removed at startup. |
| Dark mode | Picture strength is multiplied by 0.7 and a black scrim is added, so the picture does not glow against a dark surface. |

The transparency slider needs no picture: it lowers the alpha of the page surface itself. The window is created with a clear background colour, so a transparent page reveals what sits behind the window.

### Home identity

| Item | Detail |
|---|---|
| Entry | `编辑` on the identity band |
| Fields | Nickname up to 12 characters, signature 24, title 8; an empty nickname or title falls back to `记录者` / `未命名` |
| Avatar | Gallery, camera, or the file picker; centre-cropped to a 320×320 PNG in `${filesDir}/profile`; replacing it deletes the previous file |
| Storage | Preferences store `cogit_profile`; none of the fields is secret |
| Refresh | Settings → `数据管理` → `刷新首页数据` re-reads the four counters |

### Review agent modes

| Mode | What it calls | Notes |
|---|---|---|
| Template | Nothing | Default. Works offline. |
| Local mock | `POST /llm/complete` | No key required. |
| Model | OpenAI-compatible `/v1/chat/completions` | Needs base URL, model name, and API key. The key is stored on device and never exported. |

A monthly budget caps paid calls. Budget 0 disables them; cost is estimated from character counts and recorded in a monthly ledger; an exhausted budget or a failed request falls back to template mode.

### Security levels

| Level | Default for new records | Enters LLM context | Enters export |
|---|---|---|---|
| `analyzable` | No | Yes, once a model mode is on | Yes |
| `local_only` | Yes | No | Yes |
| `sealed` | No | No | No |

A level is set on each record. The default in settings only applies to records created after you change it.

### Signing

The tracked `build-profile.json5` intentionally keeps `signingConfigs` empty. At build time, `hvigorfile.ts` reads `signing/signing.local.json` when it exists and injects the `default` signing config. The local file and the `.p12`, `.cer`, and `.p7b` material are ignored, so a fresh clone builds an unsigned HAP.

To sign locally:

1. Copy `docs/signing.local.example.json` to `signing/signing.local.json`.
2. Fill in the certificate, profile, keystore paths and the DevEco-encrypted `keyPassword` / `storePassword` values. The documented fields are ciphertext; do not replace them with plaintext unless the local hvigor version accepts it.
3. Build again and check for `entry-default-signed.hap` under `entry/build/default/outputs/default/`.

### Export

Settings writes a single Markdown file covering events, decisions, relations, predictions, anchors, status readings, and review results. The file stays in the app sandbox, so copying it out is a manual step.

## Project Layout

```text
cogit-lucid-workbench/
├── AppScope/                     bundle name, version, launcher icon
├── entry/                        the only module
│   ├── src/main/
│       ├── ets/
│       │   ├── entryability/     ability entry
│       │   ├── pages/            24 route names, home destination, placeholder fallback
│       │   ├── views/            dashboard composition
│       │   ├── components/       27 reusable pieces
│       │   ├── navigation/       route names and parameter types
│       │   ├── model/            entity types, enums, factories, demo data
│       │   ├── data/             dashboard aggregate and cross-entity reads
│       │   ├── profile/          identity store and avatar pipeline
│       │   ├── note/ prediction/ review/ anchor/ relation/ status/
│       │   ├── analysis/         rules, analyzers, LLM adapters
│       │   ├── db/               schema, helpers, seven DAOs
│       │   ├── settings/         Preferences keys, asset-backed key, budget ledger
│       │   ├── export/           Markdown sections and file writer
│       │   ├── network/          prompt repository, HTTP, LLM clients
│       │   └── theme/            design tokens, app identity
│       └── resources/            strings, colours, icons, network config
│   └── src/test/                 Hypium unit tests
├── mock-server/                  zero-dependency Node mock server
├── signing/                      local-only signing config and material (ignored)
├── docs/                         UI freeze record, debug screenshots, signing template
├── build-profile.json5           SDK versions, product, build modes
├── oh-package.json5              dependencies
└── LICENSE                       AGPL-3.0
```

## Tests

`hvigorw test` runs the Hypium unit tests in `entry/src/test/List.test.ets`; the current suite covers prediction validation, confidence calibration, and sealed-record export filtering (4 cases).

## Documentation

| Topic | What it covers | Link |
|---|---|---|
| Visual tokens | Locked colour, type, radius, and spacing tokens, plus the per-page visual checklist and known deviations | [docs/UI_FREEZE.md](./docs/UI_FREEZE.md) |
| Local signing template | Placeholder signing config for `signing/signing.local.json` | [docs/signing.local.example.json](./docs/signing.local.example.json) |
| Mock server | Endpoints, addressing, and the previewer versus emulator note | [mock-server/README.md](./mock-server/README.md) |

## FAQ

**The previewer shows an empty dashboard or a database error.**
The DevEco previewer does not provide `relationalStore`, so data-backed pages fall back. Run on an emulator or a phone to see real records.

**The emulator cannot reach the mock server.**
`127.0.0.1` inside the emulator is the emulator itself. Run `hdc rport tcp:4523 tcp:4523` before launching, or open settings and point the model base URL at the host address.

**The built HAP will not install.**
Without a local signing file, `assembleHap` produces `entry-default-unsigned.hap`. Add `signing/signing.local.json` using `docs/signing.local.example.json`, or configure signing in DevEco Studio, then rebuild. The tracked `build-profile.json5` deliberately has no signing config.

**The launcher name does not match the title inside the app.**
The launcher label `cogit-lucid-workbench` comes from `AppScope/resources/base/element/string.json`; the in-app title `Cogit Lucid` comes from `theme/AppIdentity.ts`. The Chinese name is not finalised, so both are placeholders.

**Where did the refresh button go?**
It moved into settings, under `数据管理` → `刷新首页数据`. The identity band keeps only `编辑` and `设置`.

**Why do the screenshots differ from the running app?**
They were taken before the identity band existed. The band now sits above the content in every screenshot; the rest of the layout is unchanged.

**Why is there only one dependency?**
Charts are drawn on native canvas through `@ohos/mpchart`. No web view and no third-party icon pack are used, which keeps the HAP small and avoids asset licensing.

**The camera option closes with an error.**
The system camera picker needs a camera application on the device. Emulators usually ship without one, so use the gallery or the file picker there.

**A transparent page shows the system wallpaper, not another app.**
The window is created with a clear background colour, so lowering page transparency reveals whatever sits behind the window. No content from another application is read.

**Is dark mode supported?**
Yes. `theme/AppTheme.ts` carries both palettes; the app reads the system colour mode at launch and re-applies it when the system setting changes. Background pictures are dimmed and covered with a black scrim in dark mode.

## Contributing

- Commit messages follow Conventional Commits: an English subject in `type(scope): subject` form with a body explaining the reason.
- One logical change per commit. A larger feature is split into steps that can each be verified on their own.
- Code comments are English only.
- Before opening a pull request, run the Code Linter ruleset in `code-linter.json5` and confirm the project still builds.
- Keep signing material, install packages, and reports out of commits; `.gitignore` already covers them.
- Describe the motivation and the way you verified the change in the pull request.

## License

Released under the [GNU Affero General Public License v3.0](./LICENSE).

Copyright (c) 2026 SunshineMahiru (曦昼Sunshine).
