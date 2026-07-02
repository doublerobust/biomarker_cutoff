# Biomarker Cutoff Precision Simulator

Simulates single-arm oncology trials to answer: **how many patients do you need
to reliably estimate a biomarker enrichment cutoff?**

## Core finding

**Responder count, not total N, drives cutoff precision.** Two trials with
different ORRs but the same expected number of responders will have similar
cutoff precision. The N heuristic is fragile (shifts with ORR). The responder
heuristic is robust.

## Interactive webapp

Open **`app.html`** in a browser. Four tabs (AUC = 0.60 / 0.65 / 0.70 / 0.75),
each showing success rate vs N for three ORR levels (10%, 18%, 25%).
5000 simulations per scenario, smooth monotonic curves.

## Quick reference

| AUC | N for 50% success (ORR 10%) | N for 50% success (ORR 25%) |
|-----|---------------------------|---------------------------|
| 0.60 | >250 | 140 |
| 0.65 | 160 | 90 |
| 0.70 | 100 | 70 |
| 0.75 | 90 | 70 |

## Reproduce

```sh
Rscript gen_data.R          # 960,000 simulations, parallelized
Rscript gen_app.R           # builds app.html from plot_data.rds
```

Requires R ≥ 4.0 with packages `jsonlite`, `parallel`. Local packages in
`.Rlib/` (pROC, cutpointr, ggplot2 — installed but unused by the benchmark).

## Files

| File | Purpose |
|------|---------|
| `app.html` | Interactive webapp (open in browser) |
| `biomarker_cutoff_bench.R` | Core simulation engine |
| `gen_data.R` | Data generation (5000 sims, 12 scenarios, 16 N levels) |
| `gen_app.R` | Builds HTML from aggregated data |
| `plot_data.rds` | Aggregated simulation results |
| `METHODS.md` | Full simulation methodology |

## Methodology

See `METHODS.md` for the data-generating process, cutoff rule, benchmark loop,
and limitations.
