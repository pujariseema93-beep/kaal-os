#!/usr/bin/env python3
"""Build script for the Linux distro specification HTML page."""

HTML = r'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>KAAL OS — Custom Linux Distribution Specification</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
<style>
/* ============ THEME ============ */
:root {
  --font-body: 'DM Sans', system-ui, sans-serif;
  --font-mono: 'JetBrains Mono', 'SF Mono', Consolas, monospace;

  /* Dark-first — Ayu-inspired palette */
  --bg: #0b0e14;
  --surface: #131822;
  --surface2: #1a2030;
  --surface-elevated: #20283a;
  --border: rgba(255, 255, 255, 0.06);
  --border-bright: rgba(255, 255, 255, 0.12);
  --text: #e6e9ef;
  --text-dim: #7c8794;

  --accent: #39bae6;
  --accent-dim: rgba(57, 186, 230, 0.1);
  --green: #7fd962;
  --green-dim: rgba(127, 217, 98, 0.1);
  --amber: #f9b54a;
  --amber-dim: rgba(249, 181, 74, 0.1);
  --rose: #f07178;
  --rose-dim: rgba(240, 113, 120, 0.1);
  --blue: #59c2ff;
  --blue-dim: rgba(89, 194, 255, 0.1);
  --orange: #ff8f40;
  --orange-dim: rgba(255, 143, 64, 0.1);
  --red: #e6506c;
  --red-dim: rgba(230, 80, 108, 0.1);
}

@media (prefers-color-scheme: light) {
  :root {
    --bg: #f5f6f8;
    --surface: #ffffff;
    --surface2: #eef0f3;
    --surface-elevated: #f8f9fb;
    --border: rgba(0, 0, 0, 0.08);
    --border-bright: rgba(0, 0, 0, 0.14);
    --text: #1a2030;
    --text-dim: #6b7280;

    --accent: #1e90b8;
    --accent-dim: rgba(30, 144, 184, 0.08);
    --green: #4d9b3e;
    --green-dim: rgba(77, 155, 62, 0.08);
    --amber: #d48806;
    --amber-dim: rgba(212, 136, 6, 0.08);
    --rose: #d4506a;
    --rose-dim: rgba(212, 80, 106, 0.08);
    --blue: #2b7bc4;
    --blue-dim: rgba(43, 123, 196, 0.08);
    --orange: #e5741c;
    --orange-dim: rgba(229, 116, 28, 0.08);
    --red: #dc3545;
    --red-dim: rgba(220, 53, 69, 0.08);
  }
}

/* ============ RESET + BASE ============ */
* { margin: 0; padding: 0; box-sizing: border-box; }

body {
  background: var(--bg);
  background-image:
    radial-gradient(ellipse at 15% 0%, var(--accent-dim) 0%, transparent 50%),
    radial-gradient(ellipse at 85% 30%, var(--green-dim) 0%, transparent 40%),
    radial-gradient(ellipse at 50% 90%, var(--amber-dim) 0%, transparent 45%);
  color: var(--text);
  font-family: var(--font-body);
  padding: 40px;
  min-height: 100vh;
  overflow-wrap: break-word;
}

/* ============ ANIMATION ============ */
@keyframes fadeUp {
  from { opacity: 0; transform: translateY(14px); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes fadeScale {
  from { opacity: 0; transform: scale(0.94); }
  to { opacity: 1; transform: scale(1); }
}

.ve-card, .sec-head, .flow-arrow, .kpi-card, .timeline-item {
  animation: fadeUp 0.4s ease-out both;
  animation-delay: calc(var(--i, 0) * 0.05s);
}

.kpi-card {
  animation: fadeScale 0.35s ease-out both;
  animation-delay: calc(var(--i, 0) * 0.07s);
}

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-delay: 0ms !important;
    transition-duration: 0.01ms !important;
  }
}

/* ============ LAYOUT ============ */
.wrap {
  max-width: 1200px;
  margin: 0 auto;
  display: grid;
  grid-template-columns: 180px 1fr;
  gap: 0 40px;
}

.main { min-width: 0; }

/* ============ TOC NAV ============ */
.toc {
  position: sticky;
  top: 24px;
  align-self: start;
  padding: 14px 0;
  grid-row: 1 / -1;
  max-height: calc(100dvh - 48px);
  overflow-y: auto;
}
.toc::-webkit-scrollbar { width: 3px; }
.toc::-webkit-scrollbar-thumb { background: var(--surface2); border-radius: 2px; }

.toc-title {
  font-family: var(--font-mono);
  font-size: 9px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 2px;
  color: var(--text-dim);
  padding: 0 0 10px;
  margin-bottom: 8px;
  border-bottom: 1px solid var(--border);
}

.toc a {
  display: block;
  font-size: 11px;
  color: var(--text-dim);
  text-decoration: none;
  padding: 4px 8px;
  border-radius: 5px;
  border-left: 2px solid transparent;
  transition: all 0.15s;
  line-height: 1.4;
  margin-bottom: 1px;
}
.toc a:hover { color: var(--text); background: var(--surface2); }
.toc a.active { color: var(--text); border-left-color: var(--accent); }

/* ============ TYPOGRAPHY ============ */
h1 {
  font-size: 42px;
  font-weight: 700;
  letter-spacing: -1.5px;
  margin-bottom: 8px;
  text-wrap: balance;
}

.subtitle {
  color: var(--text-dim);
  font-size: 14px;
  margin-bottom: 40px;
  font-family: var(--font-mono);
}

h2 {
  font-size: 22px;
  font-weight: 700;
  letter-spacing: -0.5px;
  margin-bottom: 16px;
}

/* ============ SECTION HEAD ============ */
.sec-head {
  font-family: var(--font-mono);
  font-size: 13px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 1.5px;
  margin-top: 56px;
  margin-bottom: 20px;
  padding-bottom: 10px;
  border-bottom: 1px solid var(--border);
  display: flex;
  align-items: center;
  gap: 10px;
  color: var(--text);
  scroll-margin-top: 24px;
}

.sec-head .dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
}

.sec-num {
  font-family: var(--font-mono);
  font-size: 11px;
  font-weight: 600;
  color: var(--text-dim);
  margin-right: 4px;
}

/* ============ CARD COMPONENT ============ */
.ve-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 18px 22px;
  position: relative;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.ve-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12);
}

.ve-card--hero {
  background: color-mix(in srgb, var(--surface) 88%, var(--accent) 12%);
  box-shadow: 0 4px 24px rgba(0, 0, 0, 0.1);
  border-color: color-mix(in srgb, var(--border) 50%, var(--accent) 50%);
  padding: 28px 32px;
}

.ve-card--elevated {
  background: var(--surface-elevated);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08), 0 1px 2px rgba(0, 0, 0, 0.04);
}

.ve-card--recessed {
  background: var(--surface2);
  box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.06);
}

.ve-card__label {
  font-family: var(--font-mono);
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 1.5px;
  margin-bottom: 10px;
  display: flex;
  align-items: center;
  gap: 8px;
}

.ve-card__label::before {
  content: '';
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: currentColor;
}

.ve-card__title {
  font-size: 15px;
  font-weight: 600;
  margin-bottom: 6px;
}

.ve-card__desc {
  color: var(--text-dim);
  font-size: 13px;
  line-height: 1.6;
}

/* Color variants */
.ve-card--accent { border-left: 3px solid var(--accent); }
.ve-card--accent .ve-card__label { color: var(--accent); }

.ve-card--green { border-left: 3px solid var(--green); }
.ve-card--green .ve-card__label { color: var(--green); }

.ve-card--amber { border-left: 3px solid var(--amber); }
.ve-card--amber .ve-card__label { color: var(--amber); }

.ve-card--rose { border-left: 3px solid var(--rose); }
.ve-card--rose .ve-card__label { color: var(--rose); }

.ve-card--blue { border-left: 3px solid var(--blue); }
.ve-card--blue .ve-card__label { color: var(--blue); }

.ve-card--orange { border-left: 3px solid var(--orange); }
.ve-card--orange .ve-card__label { color: var(--orange); }

/* ============ GRID ============ */
.card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: 16px;
}

.card-grid--2 {
  grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
}

.card-grid > * { min-width: 0; }

/* ============ KPI CARDS ============ */
.kpi-row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 16px;
  margin-bottom: 32px;
}

.kpi-card {
  background: var(--surface-elevated);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 20px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
}

.kpi-card__value {
  font-size: 32px;
  font-weight: 700;
  letter-spacing: -1px;
  line-height: 1.1;
  font-variant-numeric: tabular-nums;
}

.kpi-card__label {
  font-family: var(--font-mono);
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 1.5px;
  color: var(--text-dim);
  margin-top: 6px;
}

/* ============ TABLE ============ */
.table-wrap {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 12px;
  overflow: hidden;
}

.table-scroll {
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}

.data-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
  line-height: 1.5;
}

.data-table thead {
  position: sticky;
  top: 0;
  z-index: 2;
}

.data-table th {
  background: var(--surface-elevated);
  font-family: var(--font-mono);
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 1px;
  color: var(--text-dim);
  text-align: left;
  padding: 12px 16px;
  border-bottom: 2px solid var(--border-bright);
  white-space: nowrap;
}

.data-table td {
  padding: 12px 16px;
  border-bottom: 1px solid var(--border);
  vertical-align: top;
  color: var(--text);
}

.data-table tbody tr:nth-child(even) {
  background: color-mix(in srgb, var(--surface) 96%, var(--accent) 4%);
}

.data-table tbody tr {
  transition: background 0.15s ease;
}

.data-table tbody tr:hover {
  background: var(--surface2);
}

.data-table tbody tr:last-child td {
  border-bottom: none;
}

.data-table code {
  font-family: var(--font-mono);
  font-size: 11px;
  background: var(--accent-dim);
  color: var(--accent);
  padding: 1px 5px;
  border-radius: 3px;
}

.data-table .wide {
  min-width: 200px;
}

/* ============ STATUS BADGES ============ */
.status {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-family: var(--font-mono);
  font-size: 11px;
  font-weight: 500;
  padding: 3px 10px;
  border-radius: 6px;
  white-space: nowrap;
}

.status--full { background: var(--green-dim); color: var(--green); }
.status--partial { background: var(--amber-dim); color: var(--amber); }
.status--community { background: var(--blue-dim); color: var(--blue); }
.status--planned { background: var(--accent-dim); color: var(--accent); }

/* ============ PIPELINE ============ */
.pipeline {
  display: flex;
  gap: 0;
  align-items: stretch;
  overflow-x: auto;
  padding-bottom: 8px;
}

.pipeline-step {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 12px 16px;
  min-width: 140px;
  flex-shrink: 0;
  text-align: center;
}

.pipeline-step .step-num {
  font-family: var(--font-mono);
  font-size: 10px;
  font-weight: 600;
  margin-bottom: 6px;
}

.pipeline-step .step-name {
  font-size: 13px;
  font-weight: 600;
  margin-bottom: 4px;
}

.pipeline-step .step-detail {
  font-size: 11px;
  color: var(--text-dim);
  line-height: 1.4;
}

.pipeline-step--accent { border-color: var(--accent-dim); }
.pipeline-step--accent .step-num { color: var(--accent); }
.pipeline-step--green { border-color: var(--green-dim); }
.pipeline-step--green .step-num { color: var(--green); }
.pipeline-step--amber { border-color: var(--amber-dim); }
.pipeline-step--amber .step-num { color: var(--amber); }
.pipeline-step--orange { border-color: var(--orange-dim); }
.pipeline-step--orange .step-num { color: var(--orange); }

.pipeline-arrow {
  display: flex;
  align-items: center;
  padding: 0 4px;
  color: var(--border-bright);
  font-size: 18px;
  flex-shrink: 0;
}

/* ============ FLOW ARROW ============ */
.flow-arrow {
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 8px;
  color: var(--text-dim);
  font-family: var(--font-mono);
  font-size: 12px;
  padding: 6px 0;
}

.flow-arrow svg {
  width: 20px;
  height: 20px;
  fill: none;
  stroke: var(--border-bright);
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
}

/* ============ ARCHITECTURE LAYERS ============ */
.arch-stack {
  display: grid;
  gap: 12px;
}

.arch-layer {
  display: grid;
  grid-template-columns: 160px 1fr;
  gap: 16px;
  align-items: center;
}

.arch-layer__label {
  font-family: var(--font-mono);
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 1px;
  color: var(--text-dim);
  text-align: right;
}

.arch-layer__content {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.arch-chip {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 8px 14px;
  font-size: 12px;
  font-weight: 500;
  white-space: nowrap;
}

.arch-chip code {
  font-family: var(--font-mono);
  font-size: 11px;
  color: var(--text-dim);
}

/* ============ CALLOUT ============ */
.callout {
  background: var(--surface2);
  border: 1px solid var(--border);
  border-left: 4px solid var(--accent);
  border-radius: 0 8px 8px 0;
  padding: 16px 20px;
  font-size: 13px;
  line-height: 1.7;
  color: var(--text-dim);
  margin-top: 20px;
}

.callout strong { color: var(--text); font-weight: 600; }
.callout code {
  font-family: var(--font-mono);
  font-size: 11px;
  background: var(--accent-dim);
  color: var(--accent);
  padding: 1px 5px;
  border-radius: 3px;
}

/* ============ TAGS ============ */
.tag {
  font-family: var(--font-mono);
  font-size: 10px;
  font-weight: 500;
  padding: 2px 8px;
  border-radius: 4px;
  background: var(--accent-dim);
  color: var(--accent);
  white-space: nowrap;
}

.tag--green { background: var(--green-dim); color: var(--green); }
.tag--amber { background: var(--amber-dim); color: var(--amber); }
.tag--rose { background: var(--rose-dim); color: var(--rose); }
.tag--blue { background: var(--blue-dim); color: var(--blue); }
.tag--orange { background: var(--orange-dim); color: var(--orange); }

/* ============ AUDIENCE BADGES ============ */
.audience-row {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
  margin-bottom: 24px;
}

.audience-badge {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 8px 16px;
  font-family: var(--font-mono);
  font-size: 12px;
  font-weight: 500;
  display: flex;
  align-items: center;
  gap: 8px;
}

.audience-badge .dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}

/* ============ NODE LIST ============ */
.node-list {
  list-style: none;
  font-size: 12px;
  line-height: 1.9;
  padding: 0;
  margin-top: 8px;
}

.node-list li {
  padding-left: 14px;
  position: relative;
}

.node-list li::before {
  content: '\203A';
  color: var(--text-dim);
  font-weight: 600;
  position: absolute;
  left: 0;
}

.node-list code {
  font-family: var(--font-mono);
  font-size: 11px;
  background: var(--accent-dim);
  color: var(--accent);
  padding: 1px 5px;
  border-radius: 3px;
}

/* ============ TIMELINE ============ */
.timeline {
  display: grid;
  gap: 20px;
  position: relative;
}

.timeline::before {
  content: '';
  position: absolute;
  left: 8px;
  top: 0;
  bottom: 0;
  width: 2px;
  background: var(--border-bright);
}

.timeline-item {
  padding-left: 30px;
  position: relative;
}

.timeline-item::before {
  content: '';
  position: absolute;
  left: 3px;
  top: 6px;
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: var(--surface);
  border: 2px solid var(--accent);
}

.timeline-item--done::before { background: var(--green); border-color: var(--green); }
.timeline-item--active::before { background: var(--accent); border-color: var(--accent); }

.timeline-item__phase {
  font-family: var(--font-mono);
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 1.5px;
  color: var(--text-dim);
  margin-bottom: 4px;
}

.timeline-item__title {
  font-size: 15px;
  font-weight: 600;
  margin-bottom: 4px;
}

.timeline-item__desc {
  font-size: 13px;
  color: var(--text-dim);
  line-height: 1.6;
}

/* ============ TWO COLUMN ============ */
.two-col {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}

.two-col > * { min-width: 0; }

/* ============ RESPONSIVE ============ */
@media (max-width: 1000px) {
  .wrap { grid-template-columns: 1fr; padding-top: 0; gap: 0; }
  body { padding-top: 0; }

  .toc {
    position: sticky;
    top: 0;
    z-index: 200;
    max-height: none;
    display: flex;
    gap: 4px;
    align-items: center;
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
    background: var(--bg);
    border-bottom: 1px solid var(--border);
    padding: 10px 0;
    margin: 0 -40px;
    padding-left: 40px;
    padding-right: 40px;
    grid-row: auto;
  }
  .toc::-webkit-scrollbar { display: none; }
  .toc-title { display: none; }

  .toc a {
    white-space: nowrap;
    flex-shrink: 0;
    border-left: none;
    border-bottom: 2px solid transparent;
    border-radius: 4px 4px 0 0;
    padding: 6px 10px;
    font-size: 10px;
  }
  .toc a.active {
    border-left: none;
    border-bottom-color: var(--accent);
    background: var(--surface);
  }

  .main { padding-top: 24px; padding-left: 0; }
  .sec-head { scroll-margin-top: 52px; }
  body { padding: 0 40px; }
}

@media (max-width: 768px) {
  body { padding: 0 20px; }
  .toc { margin: 0 -20px; padding-left: 20px; padding-right: 20px; }
  .two-col { grid-template-columns: 1fr; }
  .arch-layer { grid-template-columns: 1fr; }
  .arch-layer__label { text-align: left; }
  .pipeline { flex-wrap: wrap; gap: 6px; }
  .pipeline-arrow { display: none; }
  h1 { font-size: 32px; }
}
</style>
</head>
<body>

<div class="wrap">

<!-- ============ TOC NAV ============ -->
<nav class="toc" id="toc">
  <div class="toc-title">Spec Contents</div>
  <a href="#s1">1. Overview</a>
  <a href="#s2">2. Hardware Support</a>
  <a href="#s3">3. System Architecture</a>
  <a href="#s4">4. GPU Driver Stack</a>
  <a href="#s5">5. Desktop Environments</a>
  <a href="#s6">6. Gaming Stack</a>
  <a href="#s7">7. Developer Tools</a>
  <a href="#s8">8. Daily Life</a>
  <a href="#s9">9. Package Management</a>
  <a href="#s10">10. Customization</a>
  <a href="#s11">11. System Requirements</a>
  <a href="#s12">12. Installation</a>
  <a href="#s13">13. Roadmap</a>
  <a href="#s14">14. Boot &amp; Theme</a>
</nav>

<!-- ============ MAIN CONTENT ============ -->
<div class="main">

<h1>KAAL OS</h1>
<p class="subtitle">Custom Linux Distribution Specification &middot; v0.1 Draft &middot; 2026-09-08</p>

<!-- ============ HERO ============ -->
<div class="ve-card ve-card--hero" style="--i:0; margin-bottom: 32px;">
  <div class="ve-card__label" style="color: var(--accent);">Project Overview</div>
  <p style="font-size: 16px; line-height: 1.7; margin-bottom: 16px;">
    A fully customizable, Fedora-based Linux distribution built for <strong>gamers, power users, developers, and everyday computing</strong>.
    Combines bleeding-edge hardware support with a user-selectable desktop experience at install time. Every layer &mdash; from kernel to theme &mdash; is modular and swappable.
  </p>
  <div class="audience-row">
    <div class="audience-badge"><span class="dot" style="background:var(--green)"></span> Gamers</div>
    <div class="audience-badge"><span class="dot" style="background:var(--amber)"></span> Power Users</div>
    <div class="audience-badge"><span class="dot" style="background:var(--accent)"></span> Developers</div>
    <div class="audience-badge"><span class="dot" style="background:var(--rose)"></span> Daily Life</div>
  </div>
</div>

<!-- KPI ROW -->
<div class="kpi-row">
  <div class="kpi-card" style="--i:0">
    <div class="kpi-card__value" style="color: var(--accent);">6</div>
    <div class="kpi-card__label">Desktop Environments</div>
  </div>
  <div class="kpi-card" style="--i:1">
    <div class="kpi-card__value" style="color: var(--green);">2</div>
    <div class="kpi-card__label">GPU Vendors Supported</div>
  </div>
  <div class="kpi-card" style="--i:2">
    <div class="kpi-card__value" style="color: var(--amber);">4</div>
    <div class="kpi-card__label">Package Sources</div>
  </div>
  <div class="kpi-card" style="--i:3">
    <div class="kpi-card__value" style="color: var(--rose);">4</div>
    <div class="kpi-card__label">Target Audiences</div>
  </div>
</div>

<!-- ============ 1. OVERVIEW ============ -->
<div id="s1" class="sec-head" style="--i:1">
  <span class="dot" style="background:var(--accent)"></span>
  <span class="sec-num">01</span> Overview &amp; Philosophy
</div>

<div class="two-col">
  <div class="ve-card ve-card--accent" style="--i:2">
    <div class="ve-card__label">Design Principles</div>
    <div class="ve-card__desc">
      <strong>Modularity first.</strong> Every component &mdash; kernel, init, display server, DE, package manager &mdash; is a replaceable building block. The base system runs independently of the desktop layer.
      <br><br>
      <strong>Hardware-forward.</strong> Day-one support for NVIDIA RTX 40-series+ and AMD RDNA2+ GPUs, plus all Intel CPUs from Skylake (2015) onward. No legacy baggage.
      <br><br>
      <strong>Choice at install.</strong> The installer presents a curated menu of desktop environments, software profiles, and kernel flavors &mdash; not a one-size-fits-all image.
    </div>
  </div>
  <div class="ve-card ve-card--green" style="--i:3">
    <div class="ve-card__label">Why Fedora?</div>
    <div class="ve-card__desc">
      Fedora provides a modern, well-maintained upstream with rapid adoption of new technologies (Wayland, PipeWire, latest kernels, mesa). It balances bleeding-edge with reasonable stability better than Arch (which breaks) or Debian (which lags).
      <br><br>
      Key advantages:
      <ul class="node-list">
        <li>6-month release cycle, 13-month support per release</li>
        <li>Native <code>dnf</code> package management with delta RPMs</li>
        <li>First-class Wayland and PipeWire support</li>
        <li>RPM Fusion for proprietary drivers and multimedia codecs</li>
        <li>SELinux enabled by default (can be tuned/disabled)</li>
        <li>Active community + Red Hat backing for security patches</li>
      </ul>
    </div>
  </div>
</div>

<!-- ============ 2. HARDWARE SUPPORT ============ -->
<div id="s2" class="sec-head" style="--i:4">
  <span class="dot" style="background:var(--blue)"></span>
  <span class="sec-num">02</span> Hardware Support Matrix
</div>

<div class="table-wrap" style="--i:5">
  <div class="table-scroll">
    <table class="data-table">
      <thead>
        <tr>
          <th>Component</th>
          <th>Family / Generation</th>
          <th>Release Era</th>
          <th>Support Level</th>
          <th>Driver / Module</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><strong>NVIDIA GPU</strong></td>
          <td>RTX 40-series (Ada Lovelace)</td>
          <td>2022+</td>
          <td><span class="status status--full">Full</span></td>
          <td><code>nvidia</code> 555+ proprietary + open kernel modules</td>
        </tr>
        <tr>
          <td><strong>NVIDIA GPU</strong></td>
          <td>RTX 50-series (Blackwell)</td>
          <td>2025+</td>
          <td><span class="status status--full">Full</span></td>
          <td><code>nvidia</code> 570+ proprietary + open kernel modules</td>
        </tr>
        <tr>
          <td><strong>NVIDIA GPU</strong></td>
          <td>RTX 30-series (Ampere)</td>
          <td>2020+</td>
          <td><span class="status status--partial">Best-effort</span></td>
          <td><code>nvidia</code> proprietary (open modules available, Turing+)</td>
        </tr>
        <tr>
          <td><strong>NVIDIA GPU</strong></td>
          <td>GTX 16-series and older</td>
          <td>Pre-2020</td>
          <td><span class="status status--community">Community</span></td>
          <td>Proprietary driver via RPM Fusion, no official guarantee</td>
        </tr>
        <tr>
          <td><strong>AMD GPU</strong></td>
          <td>RDNA 3 (RX 7000-series)</td>
          <td>2022+</td>
          <td><span class="status status--full">Full</span></td>
          <td><code>amdgpu</code> kernel + Mesa RADV Vulkan</td>
        </tr>
        <tr>
          <td><strong>AMD GPU</strong></td>
          <td>RDNA 2 (RX 6000-series)</td>
          <td>2020+</td>
          <td><span class="status status--full">Full</span></td>
          <td><code>amdgpu</code> kernel + Mesa RADV Vulkan</td>
        </tr>
        <tr>
          <td><strong>AMD GPU</strong></td>
          <td>RDNA 1 (RX 5000-series)</td>
          <td>2019</td>
          <td><span class="status status--partial">Best-effort</span></td>
          <td><code>amdgpu</code> kernel + Mesa RADV (limited features)</td>
        </tr>
        <tr>
          <td><strong>AMD GPU</strong></td>
          <td>Vega / Polaris and older</td>
          <td>Pre-2019</td>
          <td><span class="status status--community">Community</span></td>
          <td><code>amdgpu</code> / <code>radeon</code> fallback, no official guarantee</td>
        </tr>
        <tr>
          <td><strong>Intel CPU</strong></td>
          <td>Core Ultra (Meteor Lake, Arrow Lake)</td>
          <td>2023+</td>
          <td><span class="status status--full">Full</span></td>
          <td>Full platform + Arc/Xe iGPU via Mesa (<code>anv</code>)</td>
        </tr>
        <tr>
          <td><strong>Intel CPU</strong></td>
          <td>Raptor Lake (13th/14th gen)</td>
          <td>2022+</td>
          <td><span class="status status--full">Full</span></td>
          <td>Full platform + iGPU via Mesa</td>
        </tr>
        <tr>
          <td><strong>Intel CPU</strong></td>
          <td>Alder Lake (12th gen) &mdash; Gracemont</td>
          <td>2021</td>
          <td><span class="status status--full">Full</span></td>
          <td>Full platform + iGPU via Mesa</td>
        </tr>
        <tr>
          <td><strong>Intel CPU</strong></td>
          <td>Skylake through Tiger Lake (6th&ndash;11th gen)</td>
          <td>2015&ndash;2020</td>
          <td><span class="status status--full">Full</span></td>
          <td>Full platform + iGPU via Mesa</td>
        </tr>
        <tr>
          <td><strong>Intel CPU</strong></td>
          <td>Pre-Skylake (Broadwell and earlier)</td>
          <td>Pre-2015</td>
          <td><span class="status status--community">Community</span></td>
          <td>May boot, but no official support or testing</td>
        </tr>
      </tbody>
    </table>
  </div>
</div>

<div class="callout" style="--i:6">
  <strong>Scope note:</strong> This distro targets modern hardware (2015+). Older GPUs and CPUs may work but receive no guaranteed support, testing, or optimized builds. The installer will detect hardware and warn if it falls outside the supported matrix.
</div>

<!-- ============ 3. SYSTEM ARCHITECTURE ============ -->
<div id="s3" class="sec-head" style="--i:7">
  <span class="dot" style="background:var(--orange)"></span>
  <span class="sec-num">03</span> System Architecture
</div>

<div class="ve-card" style="--i:8; margin-bottom: 16px;">
  <div class="ve-card__label" style="color: var(--orange);">Layered Stack &mdash; Bottom to Top</div>
  <div class="arch-stack" style="margin-top: 16px;">

    <div class="arch-layer">
      <div class="arch-layer__label">Bootloader</div>
      <div class="arch-layer__content">
        <div class="arch-chip">systemd-boot <code>(default)</code></div>
        <div class="arch-chip">GRUB 2 <code>(fallback)</code></div>
        <div class="arch-chip">rEFInd <code>(optional)</code></div>
      </div>
    </div>

    <div class="arch-layer">
      <div class="arch-layer__label">Kernel</div>
      <div class="arch-layer__content">
        <div class="arch-chip">Linux 6.x+ <code>(vanilla Fedora)</code></div>
        <div class="arch-chip">Custom kernel <code>(gaming-optimized)</code></div>
        <div class="arch-chip">LTS kernel <code>(optional)</code></div>
      </div>
    </div>

    <div class="arch-layer">
      <div class="arch-layer__label">Init System</div>
      <div class="arch-layer__content">
        <div class="arch-chip">systemd <code>(default)</code></div>
        <div class="arch-chip">OpenRC <code>(optional, via overlay)</code></div>
      </div>
    </div>

    <div class="arch-layer">
      <div class="arch-layer__label">GPU Drivers</div>
      <div class="arch-layer__content">
        <div class="arch-chip">NVIDIA proprietary + open modules</div>
        <div class="arch-chip">AMDGPU + Mesa RADV</div>
        <div class="arch-chip">Intel iGPU + Mesa ANV</div>
      </div>
    </div>

    <div class="arch-layer">
      <div class="arch-layer__label">Display Server</div>
      <div class="arch-layer__content">
        <div class="arch-chip">Wayland <code>(default)</code></div>
        <div class="arch-chip">Xorg X11 <code>(fallback/legacy)</code></div>
      </div>
    </div>

    <div class="arch-layer">
      <div class="arch-layer__label">Audio</div>
      <div class="arch-layer__content">
        <div class="arch-chip">PipeWire <code>(server)</code></div>
        <div class="arch-chip">WirePlumber <code>(session mgr)</code></div>
        <div class="arch-chip">PulseAudio compat <code>(via PipeWire)</code></div>
      </div>
    </div>

    <div class="arch-layer">
      <div class="arch-layer__label">Desktop Layer</div>
      <div class="arch-layer__content">
        <div class="arch-chip">User-selected at install</div>
        <div class="arch-chip">6 DE/WM options</div>
        <div class="arch-chip">Switchable post-install</div>
      </div>
    </div>

    <div class="arch-layer">
      <div class="arch-layer__label">App Layer</div>
      <div class="arch-layer__content">
        <div class="arch-chip">DNF (system packages)</div>
        <div class="arch-chip">Flatpak (sandboxed apps)</div>
        <div class="arch-chip">AppImage (portable)</div>
        <div class="arch-chip">Distrobox <code>(containerized)</code></div>
      </div>
    </div>

  </div>
</div>

<div class="two-col">
  <div class="ve-card ve-card--accent" style="--i:9">
    <div class="ve-card__label">Kernel Configuration</div>
    <div class="ve-card__desc">
      The default kernel is a lightly patched Fedora kernel with the following additions:
      <ul class="node-list">
        <li>Preempt full tickless for lower latency</li>
        <li><code>CONFIG_HZ_1000</code> for gaming responsiveness</li>
        <li>BMQ or BORE CPU scheduler (optional)</li>
        <li><code>ntsync</code> / <code>futex2</code> for Wine/Proton performance</li>
        <li>NTFS3 kernel driver for Windows partition access</li>
        <li>Btrfs + ZSTD compression enabled by default</li>
        <li>Disabled: unnecessary legacy drivers, reducing boot time</li>
      </ul>
    </div>
  </div>
  <div class="ve-card ve-card--orange" style="--i:10">
    <div class="ve-card__label">File System Layout</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><code>/</code> &mdash; Btrfs with snapshots (Timeshift/snapper)</li>
        <li><code>/home</code> &mdash; Btrfs (separate subvolume)</li>
        <li><code>/boot/efi</code> &mdash; FAT32 (ESP, 512MB+)</li>
        <li><code>/var</code> &mdash; separate subvolume for system data</li>
        <li>Swap &mdash; zram (default) or swapfile (optional)</li>
        <li>LUKS full-disk encryption available at install</li>
        <li>LVM-on-Btrfs optional for advanced setups</li>
      </ul>
    </div>
  </div>
</div>

<!-- ============ 4. GPU DRIVER STACK ============ -->
<div id="s4" class="sec-head" style="--i:11">
  <span class="dot" style="background:var(--green)"></span>
  <span class="sec-num">04</span> GPU Driver Stack
</div>

<div class="two-col">
  <div class="ve-card ve-card--green" style="--i:12">
    <div class="ve-card__label">NVIDIA (RTX 40-series+)</div>
    <div class="ve-card__title">Proprietary + Open Kernel Modules</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li>Driver version 555+ (RPM Fusion <code>akmod-nvidia</code>)</li>
        <li>Open kernel modules (<code>nvidia-open</code>) for Turing+ &mdash; built into the distro by default for 40-series and newer</li>
        <li>Wayland support via <code>nvidia-drm.modeset=1</code> enabled at boot</li>
        <li>NVENC/NVDEC hardware encoding for OBS, ffmpeg</li>
        <li>CUDA 12+ toolkit available as optional package</li>
        <li>DLSS / Frame Gen working via Proton DXVK-NVAPI</li>
        <li>Vulkan 1.3+ support for native Linux games</li>
        <li>Prime Offload for hybrid GPU laptops (Optimus)</li>
      </ul>
      <div style="margin-top:12px;">
        <span class="tag tag--green">Wayland Native</span>
        <span class="tag tag--green">Vulkan 1.3</span>
        <span class="tag tag--green">CUDA 12+</span>
        <span class="tag tag--green">DLSS</span>
      </div>
    </div>
  </div>
  <div class="ve-card ve-card--accent" style="--i:13">
    <div class="ve-card__label">AMD (RDNA2+)</div>
    <div class="ve-card__title">Open-Source: AMDGPU + Mesa RADV</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><code>amdgpu</code> kernel driver (built into kernel)</li>
        <li>Mesa RADV Vulkan driver (latest stable from Fedora)</li>
        <li>ACO shader compiler for fast compilation</li>
        <li>FSR / FSR 2 / FSR 3 support via Proton</li>
        <li>ROCm 6+ for GPU compute (optional install)</li>
        <li>Hardware video decode via <code>mesa-va-drivers</code></li>
        <li>Vulkan 1.3+ with ray tracing (RDNA2+ via <code>radv-perftest=rt</code>)</li>
        <li>No proprietary driver needed &mdash; fully open source</li>
      </ul>
      <div style="margin-top:12px;">
        <span class="tag">Wayland Native</span>
        <span class="tag">Vulkan 1.3</span>
        <span class="tag">Ray Tracing</span>
        <span class="tag">ROCm 6+</span>
        <span class="tag">Open Source</span>
      </div>
    </div>
  </div>
</div>

<div class="callout" style="--i:14">
  <strong>Driver installation:</strong> The installer auto-detects the GPU and installs the appropriate driver stack. NVIDIA users get the proprietary + open kernel module package from RPM Fusion. AMD users get the open-source stack (already in the kernel). A post-install tool (<code>kaal-gpu-config</code>) can switch driver modes, enable/disable Wayland, and tune settings.
</div>

<!-- ============ 5. DESKTOP ENVIRONMENTS ============ -->
<div id="s5" class="sec-head" style="--i:15">
  <span class="dot" style="background:var(--accent)"></span>
  <span class="sec-num">05</span> Desktop Environments &mdash; Selectable at Install
</div>

<div class="card-grid card-grid--2" style="--i:16">
  <div class="ve-card ve-card--accent">
    <div class="ve-card__label">Recommended for Gamers</div>
    <div class="ve-card__title">KDE Plasma 6</div>
    <div class="ve-card__desc">
      The most customizable full-featured DE. Excellent Wayland support, VRR (FreeSync/G-Sync), HDR support, fractional scaling, and gaming-friendly features built in. Default recommendation for the gaming audience.
    </div>
    <div style="margin-top:10px;">
      <span class="tag">Wayland</span>
      <span class="tag tag--green">VRR</span>
      <span class="tag tag--green">HDR</span>
      <span class="tag">Qt6</span>
    </div>
  </div>
  <div class="ve-card ve-card--rose">
    <div class="ve-card__label">Recommended for Daily Life</div>
    <div class="ve-card__title">GNOME 47</div>
    <div class="ve-card__desc">
      Polished, distraction-free, and minimal setup. First-class Wayland support, gesture integration, and a clean app ecosystem. Best for users who want a ready-to-use desktop without configuration overhead.
    </div>
    <div style="margin-top:10px;">
      <span class="tag">Wayland</span>
      <span class="tag">GTK4/libadwaita</span>
      <span class="tag tag--rose">Touch-friendly</span>
    </div>
  </div>
  <div class="ve-card ve-card--amber">
    <div class="ve-card__label">Recommended for Power Users</div>
    <div class="ve-card__title">Hyprland</div>
    <div class="ve-card__desc">
      Dynamic tiling Wayland compositor with eye-catching animations, blur, and extreme customizability. For users who want a riced, keyboard-driven workflow. Requires some configuration knowledge.
    </div>
    <div style="margin-top:10px;">
      <span class="tag tag--amber">Wayland</span>
      <span class="tag tag--amber">Tiling</span>
      <span class="tag tag--amber">Animations</span>
      <span class="tag tag--amber">Config-heavy</span>
    </div>
  </div>
  <div class="ve-card ve-card--amber">
    <div class="ve-card__label">Power User Alternative</div>
    <div class="ve-card__title">Sway</div>
    <div class="ve-card__desc">
      i3-compatible Wayland tiling compositor. Stable, minimal, and rock-solid. For users who want a tiling WM without the flashiness of Hyprland. Great for development workflows.
    </div>
    <div style="margin-top:10px;">
      <span class="tag tag--amber">Wayland</span>
      <span class="tag tag--amber">Tiling</span>
      <span class="tag tag--amber">i3-compatible</span>
      <span class="tag">Stable</span>
    </div>
  </div>
  <div class="ve-card ve-card--green">
    <div class="ve-card__label">Lightweight Option</div>
    <div class="ve-card__title">XFCE 4.20</div>
    <div class="ve-card__desc">
      Lightweight, stable, and traditional desktop. Low resource usage makes it ideal for older hardware or users who want maximum performance headroom. X11 native, experimental Wayland support.
    </div>
    <div style="margin-top:10px;">
      <span class="tag">X11</span>
      <span class="tag">Low RAM</span>
      <span class="tag">Stable</span>
      <span class="tag">Traditional</span>
    </div>
  </div>
  <div class="ve-card ve-card--orange">
    <div class="ve-card__label">Windows-Like Option</div>
    <div class="ve-card__title">Cinnamon</div>
    <div class="ve-card__desc">
      Familiar Windows-like layout with a traditional panel, menu, and taskbar. Good for users transitioning from Windows. Wayland support is improving but X11 is the primary session.
    </div>
    <div style="margin-top:10px;">
      <span class="tag">X11</span>
      <span class="tag tag--orange">Windows-like</span>
      <span class="tag">Beginner-friendly</span>
    </div>
  </div>
</div>

<div class="callout" style="--i:17">
  <strong>Install-time selection:</strong> The installer presents all six options with screenshots, resource usage estimates, and audience recommendations. Users can switch DEs post-install via <code>kaal-de-install kde|gnome|hyprland|...</code>. Multiple DEs can coexist &mdash; selected at the login screen (SDDM/GDM).
</div>

<!-- ============ 6. GAMING STACK ============ -->
<div id="s6" class="sec-head" style="--i:18">
  <span class="dot" style="background:var(--green)"></span>
  <span class="sec-num">06</span> Gaming Stack
</div>

<div class="card-grid" style="--i:19">
  <div class="ve-card ve-card--green">
    <div class="ve-card__label">Game Launchers</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><strong>Steam</strong> &mdash; with Proton, Steam Play, and compatibility tools pre-configured</li>
        <li><strong>Lutris</strong> &mdash; for non-Steam games, emulators, and GOG/ Epic / Battle.net</li>
        <li><strong>Heroic Games Launcher</strong> &mdash; Epic and GOG integration</li>
        <li><strong>Bottles</strong> &mdash; easy Wine prefix manager for Windows apps</li>
        <li><strong>itch</strong> &mdash; indie game launcher</li>
        <li><strong>GameHub</strong> &mdash; unified game library (optional)</li>
      </ul>
    </div>
  </div>
  <div class="ve-card ve-card--green">
    <div class="ve-card__label">Compatibility &amp; Runtime</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><strong>Proton</strong> &mdash; latest GE-Proton auto-installed via ProtonUp-Qt</li>
        <li><strong>Wine</strong> &mdash; system Wine + wine-staging for advanced users</li>
        <li><strong>DXVK</strong> &mdash; DirectX 9/10/11 to Vulkan translation</li>
        <li><strong>VKD3D-Proton</strong> &mdash; DirectX 12 to Vulkan translation</li>
        <li><strong>Protontricks</strong> &mdash; winetricks for Proton prefixes</li>
        <li><strong>GameMode</strong> &mdash; CPU governor + GPU performance on demand</li>
      </ul>
    </div>
  </div>
  <div class="ve-card ve-card--green">
    <div class="ve-card__label">Performance &amp; Overlay</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><strong>MangoHud</strong> &mdash; Vulkan/OpenGL overlay with FPS, frametime, CPU/GPU usage</li>
        <li><strong>Gamescope</strong> &mdash; micro-compositor for game isolation, FSR, and scaling</li>
        <li><strong>vkBasalt</strong> &mdash; post-processing effects (CAS sharpening, FXAA)</li>
        <li><strong>CoreCtrl</strong> &mdash; AMD GPU/CPU power profile and overclocking</li>
        <li><strong>GreenWithEnvy</strong> &mdash; NVIDIA GPU overclocking and fan control</li>
        <li><strong>ReplaySorcery</strong> &mdash; instant replay capture (ShadowPlay alternative)</li>
      </ul>
    </div>
  </div>
  <div class="ve-card ve-card--green">
    <div class="ve-card__label">Streaming &amp; Capture</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><strong>OBS Studio</strong> &mdash; with NVENC/VAAPI hardware encoding pre-configured</li>
        <li><strong>gpu-screen-recorder</strong> &mdash; lightweight replay buffer and streaming</li>
        <li><strong>OBS StreamFX</strong> &mdash; advanced filters and source dock</li>
        <li><strong>Streamlink</strong> &mdash; watch Twitch/YouTube in any player</li>
      </ul>
    </div>
  </div>
  <div class="ve-card ve-card--green">
    <div class="ve-card__label">Emulation</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><strong>RetroArch</strong> &mdash; all-in-one retro emulator frontend</li>
        <li><strong>Dolphin</strong> &mdash; GameCube / Wii</li>
        <li><strong>RPCS3</strong> &mdash; PlayStation 3</li>
        <li><strong>PPSSPP</strong> &mdash; PlayStation Portable</li>
        <li><strong>Ryujinx / Yuzu</strong> &mdash; Nintendo Switch</li>
        <li><strong>melonDS</strong> &mdash; Nintendo DS</li>
        <li><strong>PCSX2</strong> &mdash; PlayStation 2</li>
      </ul>
    </div>
  </div>
  <div class="ve-card ve-card--green">
    <div class="ve-card__label">Game Development</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><strong>Godot Engine</strong> &mdash; open-source game engine</li>
        <li><strong>Unity Hub</strong> &mdash; via Flatpak</li>
        <li><strong>Unreal Engine</strong> &mdash; via Epic Games Launcher</li>
        <li><strong>Blender</strong> &mdash; 3D modeling, animation, rendering</li>
        <li><strong>Krita</strong> &mdash; digital painting and concept art</li>
        <li><strong>Aseprite</strong> &mdash; pixel art editor</li>
      </ul>
    </div>
  </div>
</div>

<!-- ============ 7. DEVELOPER TOOLS ============ -->
<div id="s7" class="sec-head" style="--i:20">
  <span class="dot" style="background:var(--amber)"></span>
  <span class="sec-num">07</span> Developer Tools
</div>

<div class="card-grid" style="--i:21">
  <div class="ve-card ve-card--amber">
    <div class="ve-card__label">Languages &amp; Runtimes</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><strong>Python 3.12+</strong> &mdash; with pip, venv, uv</li>
        <li><strong>Node.js 20 LTS / 22</strong> &mdash; via nvm or fnm</li>
        <li><strong>Rust</strong> &mdash; via rustup, cargo, rust-analyzer</li>
        <li><strong>Go</strong> &mdash; latest stable</li>
        <li><strong>Java 21 LTS</strong> &mdash; OpenJDK</li>
        <li><strong>C/C++</strong> &mdash; GCC 14, Clang 18, CMake, Make</li>
        <li><strong>Ruby, PHP, Elixir</strong> &mdash; available via DNF</li>
      </ul>
    </div>
  </div>
  <div class="ve-card ve-card--amber">
    <div class="ve-card__label">IDEs &amp; Editors</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><strong>VS Code</strong> &mdash; via Flatpak or DNF</li>
        <li><strong>JetBrains Toolbox</strong> &mdash; IntelliJ, PyCharm, CLion, WebStorm</li>
        <li><strong>Neovim</strong> &mdash; pre-configured with LSP, Treesitter</li>
        <li><strong>Helix</strong> &mdash; modal editor, no config needed</li>
        <li><strong>Zed</strong> &mdash; high-performance editor</li>
        <li><strong>Vim / Emacs</strong> &mdash; available via DNF</li>
      </ul>
    </div>
  </div>
  <div class="ve-card ve-card--amber">
    <div class="ve-card__label">Containers &amp; Virtualization</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><strong>Podman</strong> &mdash; rootless containers (Docker-compatible)</li>
        <li><strong>Docker</strong> &mdash; with docker-compose</li>
        <li><strong>Distrobox</strong> &mdash; run any distro in a container</li>
        <li><strong>Toolbx</strong> &mdash; Fedora's dev container system</li>
        <li><strong>KVM/QEMU</strong> &mdash; full virtualization with virt-manager</li>
        <li><strong>Boxes</strong> &mdash; GNOME virtual machine manager</li>
      </ul>
    </div>
  </div>
  <div class="ve-card ve-card--amber">
    <div class="ve-card__label">Terminal &amp; Shell</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><strong>Kitty / Alacritty / WezTerm</strong> &mdash; GPU-accelerated terminals</li>
        <li><strong>Starship</strong> &mdash; cross-shell prompt</li>
        <li><strong>Zsh + Oh My Zsh</strong> &mdash; or Fish with Fisher</li>
        <li><strong>Tmux / Zellij</strong> &mdash; terminal multiplexers</li>
        <li><strong>fzf, ripgrep, fd, bat, eza</strong> &mdash; modern CLI tools</li>
        <li><strong>lazygit / lazydocker</strong> &mdash; TUI for git and Docker</li>
      </ul>
    </div>
  </div>
  <div class="ve-card ve-card--amber">
    <div class="ve-card__label">Version Control &amp; CI</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><strong>Git</strong> &mdash; with GitHub CLI (<code>gh</code>)</li>
        <li><strong>GitLab CLI</strong> &mdash; <code>glab</code></li>
        <li><strong>lazygit</strong> &mdash; terminal git UI</li>
        <li><strong>Subversion, Mercurial</strong> &mdash; available via DNF</li>
        <li><strong>act</strong> &mdash; run GitHub Actions locally</li>
        <li><strong>pre-commit</strong> &mdash; git hook framework</li>
      </ul>
    </div>
  </div>
  <div class="ve-card ve-card--amber">
    <div class="ve-card__label">Databases &amp; Backend</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><strong>PostgreSQL 16</strong> &mdash; with pgAdmin</li>
        <li><strong>Redis / Valkey</strong> &mdash; in-memory cache</li>
        <li><strong>SQLite</strong> &mdash; with DB Browser for SQLite</li>
        <li><strong>DBeaver</strong> &mdash; universal database GUI</li>
        <li><strong>MinIO</strong> &mdash; S3-compatible object storage</li>
        <li><strong>nginx / Caddy</strong> &mdash; web servers / reverse proxy</li>
      </ul>
    </div>
  </div>
</div>

<!-- ============ 8. DAILY LIFE ============ -->
<div id="s8" class="sec-head" style="--i:22">
  <span class="dot" style="background:var(--rose)"></span>
  <span class="sec-num">08</span> Daily Life Applications
</div>

<div class="card-grid" style="--i:23">
  <div class="ve-card ve-card--rose">
    <div class="ve-card__label">Web &amp; Communication</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><strong>Firefox</strong> &mdash; default browser, Wayland-native</li>
        <li><strong>Chromium / Brave / Vivaldi</strong> &mdash; alternatives</li>
        <li><strong>Thunderbird</strong> &mdash; email client</li>
        <li><strong>Discord</strong> &mdash; via Flatpak or DNF</li>
        <li><strong>Telegram Desktop</strong></li>
        <li><strong>Signal Desktop</strong></li>
        <li><strong>WhatsApp Web</strong> &mdash; as web app wrapper</li>
      </ul>
    </div>
  </div>
  <div class="ve-card ve-card--rose">
    <div class="ve-card__label">Office &amp; Productivity</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><strong>LibreOffice</strong> &mdash; full office suite (Writer, Calc, Impress)</li>
        <li><strong>OnlyOffice</strong> &mdash; MS Office-compatible alternative</li>
        <li><strong>Obsidian</strong> &mdash; markdown note-taking</li>
        <li><strong>Logseq</strong> &mdash; outliner and knowledge graph</li>
        <li><strong>PDF Arranger</strong> &mdash; PDF manipulation</li>
        <li><strong>Evince / Okular</strong> &mdash; PDF readers</li>
      </ul>
    </div>
  </div>
  <div class="ve-card ve-card--rose">
    <div class="ve-card__label">Media &amp; Entertainment</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><strong>mpv</strong> &mdash; lightweight, powerful video player</li>
        <li><strong>VLC</strong> &mdash; universal media player</li>
        <li><strong>Spotify</strong> &mdash; via Flatpak</li>
        <li><strong>Celluloid</strong> &mdash; GNOME mpv frontend</li>
        <li><strong>EasyEffects</strong> &mdash; audio equalizer and effects</li>
        <li><strong>Kdenlive / DaVinci Resolve</strong> &mdash; video editing</li>
      </ul>
    </div>
  </div>
  <div class="ve-card ve-card--rose">
    <div class="ve-card__label">Creative &amp; Design</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><strong>GIMP</strong> &mdash; image editing</li>
        <li><strong>Inkscape</strong> &mdash; vector graphics</li>
        <li><strong>Blender</strong> &mdash; 3D modeling and animation</li>
        <li><strong>Krita</strong> &mdash; digital painting</li>
        <li><strong>Audacity</strong> &mdash; audio editing</li>
        <li><strong> OBS Studio</strong> &mdash; screen recording and streaming</li>
      </ul>
    </div>
  </div>
  <div class="ve-card ve-card--rose">
    <div class="ve-card__label">System &amp; Utilities</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><strong>GNOME Software / Discover</strong> &mdash; GUI app store (Flatpak + DNF)</li>
        <li><strong>Bauh</strong> &mdash; unified package manager GUI</li>
        <li><strong>Timeshift</strong> &mdash; system snapshots and rollback</li>
        <li><strong>GParted</strong> &mdash; partition manager</li>
        <li><strong>Flameshot</strong> &mdash; screenshot tool</li>
        <li><strong>KeePassXC</strong> &mdash; password manager</li>
      </ul>
    </div>
  </div>
  <div class="ve-card ve-card--rose">
    <div class="ve-card__label">File Management &amp; Cloud</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><strong>Dolphin / Nautilus / Thunar</strong> &mdash; DE-dependent file managers</li>
        <li><strong>rclone</strong> &mdash; cloud storage sync (Google Drive, S3, etc.)</li>
        <li><strong>Syncthing</strong> &mdash; peer-to-peer file sync</li>
        <li><strong>Timeshift</strong> &mdash; system backup snapshots</li>
        <li><strong>FileZilla</strong> &mdash; FTP/SFTP client</li>
        <li><strong>deja-dup</strong> &mdash; simple backup tool</li>
      </ul>
    </div>
  </div>
</div>

<!-- ============ 9. PACKAGE MANAGEMENT ============ -->
<div id="s9" class="sec-head" style="--i:24">
  <span class="dot" style="background:var(--orange)"></span>
  <span class="sec-num">09</span> Package Management
</div>

<div class="table-wrap" style="--i:25">
  <div class="table-scroll">
    <table class="data-table">
      <thead>
        <tr>
          <th>Layer</th>
          <th>Tool</th>
          <th>Purpose</th>
          <th>Scope</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><strong>System</strong></td>
          <td><code>dnf5</code></td>
          <td>Core system packages, libraries, command-line tools</td>
          <td>Fedora repos + custom distro repos</td>
        </tr>
        <tr>
          <td><strong>Apps</strong></td>
          <td><code>flatpak</code></td>
          <td>Sandboxed GUI applications with automatic updates</td>
          <td>Flathub (primary app store)</td>
        </tr>
        <tr>
          <td><strong>Codecs &amp; Drivers</strong></td>
          <td><code>dnf</code> + RPM Fusion</td>
          <td>Proprietary drivers (NVIDIA), multimedia codecs, patent-encumbered software</td>
          <td>RPM Fusion Free + Nonfree</td>
        </tr>
        <tr>
          <td><strong>Portable</strong></td>
          <td><code>appimage</code></td>
          <td>Single-file portable applications, no installation needed</td>
          <td>AppImageHub + direct downloads</td>
        </tr>
        <tr>
          <td><strong>Containerized</strong></td>
          <td><code>distrobox</code> / <code>toolbx</code></td>
          <td>Run apps from any Linux distro in isolated containers</td>
          <td>Any distro image (Arch, Ubuntu, Alpine, etc.)</td>
        </tr>
        <tr>
          <td><strong>Snap</strong></td>
          <td><code>snap</code> (optional)</td>
          <td>Canonical's package format &mdash; available but not pre-installed</td>
          <td>Snap Store (opt-in only)</td>
        </tr>
      </tbody>
    </table>
  </div>
</div>

<div class="callout" style="--i:26">
  <strong>Flatpak-first philosophy:</strong> GUI applications default to Flatpak from Flathub. This ensures sandboxing, automatic updates, and distro-agnostic app availability. System-level packages (drivers, libraries, CLI tools) use DNF. The app store GUI (GNOME Software or Discover) integrates both Flatpak and DNF into a single browseable interface.
</div>

<!-- ============ 10. CUSTOMIZATION ============ -->
<div id="s10" class="sec-head" style="--i:27">
  <span class="dot" style="background:var(--accent)"></span>
  <span class="sec-num">10</span> Customization Framework
</div>

<div class="card-grid card-grid--2" style="--i:28">
  <div class="ve-card ve-card--accent">
    <div class="ve-card__label">Theming System</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><strong>kaal-theme-manager</strong> &mdash; unified theme switcher for GTK, Qt, icons, cursors, SDDM/GDM, GRUB, Plymouth</li>
        <li><strong>KDE Plasma themes</strong> &mdash; full Plasma, Kvantum, color schemes</li>
        <li><strong>GNOME extensions</strong> &mdash; Extension Manager app pre-installed</li>
        <li><strong>Waybar / Hyprland configs</strong> &mdash; dotfile templates included</li>
        <li><strong> Plymouth boot splash</strong> &mdash; custom or community themes</li>
      </ul>
    </div>
  </div>
  <div class="ve-card ve-card--accent">
    <div class="ve-card__label">Dotfile Management</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><strong>GNU Stow</strong> &mdash; symlink farm for dotfile management</li>
        <li><strong>ChezMoi</strong> &mdash; declarative dotfile manager with encryption</li>
        <li><strong>yadm</strong> &mdash; Yet Another Dotfile Manager (git-based)</li>
        <li>Pre-built dotfile profiles for each DE (gaming, dev, minimal)</li>
        <li><code>kaal-apply-profile</code> &mdash; one-command profile switching</li>
      </ul>
    </div>
  </div>
  <div class="ve-card ve-card--accent">
    <div class="ve-card__label">Ricing Tools</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><strong>Kvantum</strong> &mdash; SVG-based Qt theme engine</li>
        <li><strong>oomox / themix</strong> &mdash; generate themes from color schemes</li>
        <li><strong>Pywal</strong> &mdash; color scheme generation from wallpapers</li>
        <li><strong>Waybar modules</strong> &mdash; custom status bar widgets</li>
        <li><strong>Rofi / Wofi / Fuzzel</strong> &mdash; customizable app launchers</li>
        <li><strong>SDDM themes</strong> &mdash; animated login screen themes</li>
      </ul>
    </div>
  </div>
  <div class="ve-card ve-card--accent">
    <div class="ve-card__label">System Tuning</div>
    <div class="ve-card__desc">
      <ul class="node-list">
        <li><strong>kaal-tweak-tool</strong> &mdash; GUI for kernel parameters, CPU governor, I/O scheduler</li>
        <li><strong>Governor profiles</strong> &mdash; performance, balanced, powersave (auto-switch on AC/battery)</li>
        <li><strong>I/O scheduler</strong> &mdash; BFQ (desktop), Kyber (NVMe), or mq-deadline</li>
        <li><strong>zram configuration</strong> &mdash; adjustable compression and size</li>
        <li><strong>systemd services</strong> &mdash; granular enable/disable via GUI</li>
      </ul>
    </div>
  </div>
</div>

<!-- ============ 11. SYSTEM REQUIREMENTS ============ -->
<div id="s11" class="sec-head" style="--i:29">
  <span class="dot" style="background:var(--orange)"></span>
  <span class="sec-num">11</span> System Requirements
</div>

<div class="table-wrap" style="--i:30">
  <div class="table-scroll">
    <table class="data-table">
      <thead>
        <tr>
          <th>Requirement</th>
          <th>Minimum</th>
          <th>Recommended</th>
          <th>Enthusiast / Gaming</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><strong>CPU</strong></td>
          <td>Intel Skylake (6th gen, 2015) dual-core</td>
          <td>Intel 8th gen+ quad-core or better</td>
          <td>Intel 12th gen+ / AMD Ryzen 5000+ 6-core+</td>
        </tr>
        <tr>
          <td><strong>RAM</strong></td>
          <td>4 GB (XFCE/Cinnamon only)</td>
          <td>8 GB (KDE/GNOME)</td>
          <td>16&ndash;32 GB</td>
        </tr>
        <tr>
          <td><strong>Storage</strong></td>
          <td>20 GB (minimal, no snapshots)</td>
          <td>60 GB SSD</td>
          <td>250 GB+ NVMe SSD</td>
        </tr>
        <tr>
          <td><strong>GPU</strong></td>
          <td>Intel iGPU (Skylake+)</td>
          <td>Any supported NVIDIA 40+ / AMD RDNA2+</td>
          <td>NVIDIA RTX 4070+ / AMD RX 7800 XT+</td>
        </tr>
        <tr>
          <td><strong>VRAM</strong></td>
          <td>Shared (iGPU)</td>
          <td>6 GB+</td>
          <td>12 GB+</td>
        </tr>
        <tr>
          <td><strong>Boot Mode</strong></td>
          <td>UEFI (Legacy BIOS not supported)</td>
          <td>UEFI with Secure Boot (optional)</td>
          <td>UEFI with Secure Boot (optional)</td>
        </tr>
        <tr>
          <td><strong>Display</strong></td>
          <td>1024&times;768</td>
          <td>1920&times;1080</td>
          <td>2560&times;1440+ with VRR / HDR</td>
        </tr>
      </tbody>
    </table>
  </div>
</div>

<!-- ============ 12. INSTALLATION ============ -->
<div id="s12" class="sec-head" style="--i:31">
  <span class="dot" style="background:var(--blue)"></span>
  <span class="sec-num">12</span> Installation Process
</div>

<div class="ve-card" style="--i:32; margin-bottom: 16px;">
  <div class="ve-card__label" style="color: var(--blue);">Installer Pipeline</div>
  <div class="pipeline" style="margin-top: 16px;">
    <div class="pipeline-step pipeline-step--blue">
      <div class="step-num">STEP 1</div>
      <div class="step-name">Boot Live ISO</div>
      <div class="step-detail">USB / DVD boot<br>Live environment</div>
    </div>
    <div class="pipeline-arrow">&rarr;</div>
    <div class="pipeline-step pipeline-step--blue">
      <div class="step-num">STEP 2</div>
      <div class="step-name">Hardware Detect</div>
      <div class="step-detail">GPU, CPU, NPU<br>Driver selection</div>
    </div>
    <div class="pipeline-arrow">&rarr;</div>
    <div class="pipeline-step pipeline-step--accent">
      <div class="step-num">STEP 3</div>
      <div class="step-name">Choose Profile</div>
      <div class="step-detail">Gaming / Dev /<br>Power / Daily</div>
    </div>
    <div class="pipeline-arrow">&rarr;</div>
    <div class="pipeline-step pipeline-step--accent">
      <div class="step-num">STEP 4</div>
      <div class="step-name">Select Desktop</div>
      <div class="step-detail">KDE / GNOME /<br>Hyprland / etc.</div>
    </div>
    <div class="pipeline-arrow">&rarr;</div>
    <div class="pipeline-step pipeline-step--orange">
      <div class="step-num">STEP 5</div>
      <div class="step-name">Disk &amp; Security</div>
      <div class="step-detail">Partitioning, LUKS,<br>swap/zram config</div>
    </div>
    <div class="pipeline-arrow">&rarr;</div>
    <div class="pipeline-step pipeline-step--orange">
      <div class="step-num">STEP 6</div>
      <div class="step-name">Install</div>
      <div class="step-detail">Package download<br>+ system build</div>
    </div>
    <div class="pipeline-arrow">&rarr;</div>
    <div class="pipeline-step pipeline-step--green">
      <div class="step-num">STEP 7</div>
      <div class="step-name">Post-Install</div>
      <div class="step-detail">First-boot setup,<br>theme, updates</div>
    </div>
  </div>
</div>

<div class="two-col">
  <div class="ve-card ve-card--blue" style="--i:33">
    <div class="ve-card__label">Installer: Calamares</div>
    <div class="ve-card__desc">
      The distro uses <strong>Calamares</strong> as the installer framework &mdash; a modern, modular, Qt-based installer used by many independent distros. Custom branding and theme can be applied to Calamares slides and UI.
      <br><br>
      Key features:
      <ul class="node-list">
        <li>Modular design &mdash; add/remove installation steps as needed</li>
        <li>Custom branding (slides, logo, colors) &mdash; to be configured</li>
        <li>Automated partitioning with Btrfs + snapshots</li>
        <li>LUKS encryption support</li>
        <li>Post-install script execution</li>
      </ul>
    </div>
  </div>
  <div class="ve-card ve-card--blue" style="--i:34">
    <div class="ve-card__label">Install Profiles</div>
    <div class="ve-card__desc">
      Pre-configured software bundles selectable at install:
      <ul class="node-list">
        <li><span class="tag tag--green">Gaming</span> Steam, Proton, Lutris, GameMode, MangoHud, OBS</li>
        <li><span class="tag tag--amber">Developer</span> VS Code, Podman, Rust, Python, Neovim, Git</li>
        <li><span class="tag">Power User</span> Hyprland, Waybar, Rofi, CLI tools, system utilities</li>
        <li><span class="tag tag--rose">Daily Life</span> Firefox, LibreOffice, Discord, Spotify, media apps</li>
        <li><span class="tag">Minimal</span> Base system + DE only, no extra apps</li>
        <li><span class="tag">Custom</span> Cherry-pick individual packages</li>
      </ul>
    </div>
  </div>
</div>

<!-- ============ 13. ROADMAP ============ -->
<div id="s13" class="sec-head" style="--i:35">
  <span class="dot" style="background:var(--amber)"></span>
  <span class="sec-num">13</span> Development Roadmap
</div>

<div class="timeline" style="--i:36">
  <div class="timeline-item timeline-item--done">
    <div class="timeline-item__phase">Phase 0 &mdash; Complete</div>
    <div class="timeline-item__title">Specification &amp; Planning</div>
    <div class="timeline-item__desc">Define scope, hardware matrix, architecture, target audiences, and feature set. (This document.)</div>
  </div>
  <div class="timeline-item timeline-item--active">
    <div class="timeline-item__phase">Phase 1 &mdash; In Progress</div>
    <div class="timeline-item__title">Base Image &amp; Kickstart</div>
    <div class="timeline-item__desc">Create a Fedora-based kickstart file. Build a minimal live ISO with custom repos. Verify hardware detection and driver installation on supported GPU/CPU combinations.</div>
  </div>
  <div class="timeline-item">
    <div class="timeline-item__phase">Phase 2</div>
    <div class="timeline-item__title">Installer Integration</div>
    <div class="timeline-item__desc">Integrate Calamares with custom branding, profile selection, and DE selection screens. Build post-install scripts for driver auto-detection and software profile application.</div>
  </div>
  <div class="timeline-item">
    <div class="timeline-item__phase">Phase 3</div>
    <div class="timeline-item__title">Gaming &amp; Dev Stack Curation</div>
    <div class="timeline-item__desc">Package and pre-configure the gaming stack (Steam, Proton, GameMode, MangoHud) and developer stack (Podman, VS Code, language toolchains). Create custom DNF copr repos for distro-specific tools.</div>
  </div>
  <div class="timeline-item">
    <div class="timeline-item__phase">Phase 4</div>
    <div class="timeline-item__title">Customization Tools</div>
    <div class="timeline-item__desc">Build <code>kaal-theme-manager</code>, <code>kaal-tweak-tool</code>, and profile switching utilities. Create dotfile templates and ricing presets for each DE.</div>
  </div>
  <div class="timeline-item">
    <div class="timeline-item__phase">Phase 5</div>
    <div class="timeline-item__title">Boot Logo &amp; Theme</div>
    <div class="timeline-item__desc">Design custom boot logo, Plymouth splash screen, GRUB/systemd-boot theme, SDDM/GDM login screen, and base icon/cursor theme. (Deferred &mdash; to be set up later.)</div>
  </div>
  <div class="timeline-item">
    <div class="timeline-item__phase">Phase 6</div>
    <div class="timeline-item__title">Testing &amp; QA</div>
    <div class="timeline-item__desc">Test on all supported GPU/CPU combinations. Verify gaming performance, DE stability, driver installation, and update paths. Create automated test suites.</div>
  </div>
  <div class="timeline-item">
    <div class="timeline-item__phase">Phase 7</div>
    <div class="timeline-item__title">Release &amp; Community</div>
    <div class="timeline-item__desc">Publish first stable release. Set up documentation site, community forums, bug tracker, and contribution guidelines. Establish update cadence aligned with Fedora releases.</div>
  </div>
</div>

<!-- ============ 14. BOOT & THEME ============ -->
<div id="s14" class="sec-head" style="--i:37">
  <span class="dot" style="background:var(--text-dim)"></span>
  <span class="sec-num">14</span> Boot Logo &amp; Theme &mdash; Deferred
</div>

<div class="ve-card ve-card--recessed" style="--i:38">
  <div class="ve-card__label" style="color: var(--text-dim);">To Be Configured Later</div>
  <div class="ve-card__desc" style="font-size: 14px; line-height: 1.7;">
    The following visual identity elements are intentionally deferred and will be designed in Phase 5 of the roadmap:
    <ul class="node-list" style="margin-top: 12px; font-size: 13px;">
      <li><strong>Boot logo</strong> &mdash; custom UEFI/GRUB/systemd-boot splash image</li>
      <li><strong>Plymouth theme</strong> &mdash; animated boot splash screen</li>
      <li><strong>GRUB / systemd-boot theme</strong> &mdash; bootloader menu styling</li>
      <li><strong>Login screen (SDDM/GDM)</strong> &mdash; themed login manager</li>
      <li><strong>Default icon theme</strong> &mdash; distro-branded icon set</li>
      <li><strong>Default cursor theme</strong> &mdash; custom cursor set</li>
      <li><strong>Default wallpaper</strong> &mdash; distro branding wallpaper</li>
      <li><strong>Calamares branding</strong> &mdash; installer slides and UI styling</li>
      <li><strong>Color palette</strong> &mdash; distro accent colors for GTK/Qt themes</li>
    </ul>
    <br>
    All theming infrastructure (the <code>kaal-theme-manager</code> tool, Plymouth integration, SDDM theme support) will be built in Phase 4 so that applying the final visual identity in Phase 5 is a drop-in process.
  </div>
</div>

<div class="callout" style="--i:39; margin-top: 32px; border-left-color: var(--text-dim);">
  <strong>Distro name:</strong> Currently using the placeholder <code>KAAL OS</code>. A name should be chosen before Phase 2 (Installer Integration) begins, as it affects package naming (<code>kaal-theme-manager</code>, repo URLs, etc.). Suggested naming directions: mythological/celestial references, tech-forward portmanteaus, or abstract evocative names.
</div>

<div style="text-align: center; margin-top: 60px; padding-top: 24px; border-top: 1px solid var(--border); font-family: var(--font-mono); font-size: 11px; color: var(--text-dim);">
  KAAL OS Specification v0.1 &middot; Drafted 2026-09-08 &middot; Fedora-based &middot; For Gamers, Power Users, Developers &amp; Daily Life
</div>

</div><!-- /main -->
</div><!-- /wrap -->

<script>
(function() {
  const toc = document.getElementById('toc');
  const links = toc.querySelectorAll('a');
  const sections = [];

  links.forEach(link => {
    const id = link.getAttribute('href').slice(1);
    const el = document.getElementById(id);
    if (el) sections.push({ id, el, link });
  });

  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        links.forEach(l => l.classList.remove('active'));
        const match = sections.find(s => s.el === entry.target);
        if (match) {
          match.link.classList.add('active');
          if (window.innerWidth <= 1000) {
            match.link.scrollIntoView({
              behavior: 'smooth', block: 'nearest', inline: 'center'
            });
          }
        }
      }
    });
  }, { rootMargin: '-10% 0px -80% 0px' });

  sections.forEach(s => observer.observe(s.el));

  links.forEach(link => {
    link.addEventListener('click', e => {
      e.preventDefault();
      const id = link.getAttribute('href').slice(1);
      const el = document.getElementById(id);
      if (el) {
        el.scrollIntoView({ behavior: 'smooth', block: 'start' });
        history.replaceState(null, '', '#' + id);
      }
    });
  });
})();
</script>

</body>
</html>'''

with open('/scratch/work/distro-spec.html', 'w', encoding='utf-8') as f:
    f.write(HTML)

print("Written /scratch/work/distro-spec.html")
print(f"File size: {len(HTML)} bytes")
