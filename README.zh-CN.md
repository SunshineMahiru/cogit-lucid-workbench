<h1 align="center">元认知外化工作台</h1>

<p align="center">cogit-lucid-workbench</p>

<p align="center">把「记录 → 分析 → 校准 → 锚点对照」的自我分析循环，做成本地优先的移动工具。</p>

<p align="center">
  <a href="./README.md">English</a> | <a href="./README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-AGPL--3.0-blue.svg" alt="License: AGPL-3.0"></a>
  <img src="https://img.shields.io/badge/HarmonyOS-ArkTS-4A6FA5" alt="HarmonyOS ArkTS">
  <img src="https://img.shields.io/badge/API-24-4A6FA5" alt="API 24">
  <img src="https://img.shields.io/badge/version-1.0.0-4A6FA5" alt="Version 1.0.0">
</p>

## 亮点

- **元认知外化** —— 把原本手动运行的「记录 → 分析 → 校准 → 锚点对照」循环，搬到软件上。
- **预测日志** —— 判断事前落盘、禁止事后修改、到期结算、统计命中率。
- **本地优先** —— 原始记录留在设备本地；LLM 调用即时即弃、可选开启。

## 快速开始

### 环境

- DevEco Studio，已配置 HarmonyOS SDK。工程 `targetSdkVersion` 为 `26.0.0`，兼容 `6.1.1`（API 24）。
- 一台 HarmonyOS 手机模拟器或真机。

### 运行

1. 用 DevEco Studio 打开本仓库。
2. 等工程 Sync 完成。
3. 选中 `entry` 模块，选择模拟器或真机，点运行。

第一屏是首页。模块网格可以进入速记、预测、复盘、锚点、关系、状态和设置；本周结算卡进入本周汇总。

## 技术栈

- HarmonyOS / ArkTS
- 状态管理 V2、Navigation 路由、relationalStore

## 许可证

[AGPL-3.0](LICENSE)
