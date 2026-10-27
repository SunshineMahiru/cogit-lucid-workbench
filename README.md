<h1 align="center">cogit-lucid-workbench</h1>

<p align="center">Metacognition Workbench</p>

<p align="center">Turn the self-analysis loop — record, analyze, calibrate, check against anchors — into a local-first mobile tool.</p>

<p align="center">
  <a href="./README.md">English</a> | <a href="./README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-AGPL--3.0-blue.svg" alt="License: AGPL-3.0"></a>
  <img src="https://img.shields.io/badge/HarmonyOS-ArkTS-4A6FA5" alt="HarmonyOS ArkTS">
  <img src="https://img.shields.io/badge/API-24-4A6FA5" alt="API 24">
  <img src="https://img.shields.io/badge/version-1.0.0-4A6FA5" alt="Version 1.0.0">
</p>

## Highlights

- **Metacognition externalized** — move the manual record → analyze → calibrate → anchor-check loop into software.
- **Prediction log** — write a judgment before the outcome, lock it against later edits, settle on the due date, and track the hit rate.
- **Local-first** — raw records stay on the device; LLM calls are opt-in and transient.

## Quick Start

### Requirements

- DevEco Studio with the HarmonyOS SDK configured. The project targets `26.0.0` and is compatible with `6.1.1` (API 24).
- A HarmonyOS phone emulator or a HarmonyOS device.

### Run

1. Open this repository in DevEco Studio.
2. Wait for the project sync to finish.
3. Select the `entry` module, choose the emulator or device, and run.

The first screen is the dashboard. The module grid opens notes, predictions, review, anchors, relations, status, and settings. The weekly settlement card opens this week's summary.

## Tech Stack

- HarmonyOS / ArkTS
- State management V2, Navigation routing, relationalStore

## License

[AGPL-3.0](LICENSE)
