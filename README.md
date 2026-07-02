# Biomarker Cutoff Precision Simulator

Simulates single-arm oncology trials to answer: **how many patients do you need
to reliably estimate a biomarker enrichment cutoff?**

## Summary

In these calibrated scenarios, lower ORR generally required larger N to
reach the same cutoff precision. Responder scarcity is a likely contributor,
but precision also depends on AUC, target ORR, the enriched-subgroup
constraint, and total N. See `app.html` for the interactive results.

## Interactive webapp

Open **`app.html`** in a browser. Four tabs (AUC ≈ 0.60 / 0.65 / 0.70 / 0.75),
each showing success rate vs N for three ORR levels (≈10%, ≈18%, ≈25%).
50000 simulations per scenario. AUC and ORR labels are approximate calibrated
targets.

## Quick reference

N needed for 50% success (first N where success rate ≥ 50%):

| AUC | ORR ≈10% | ORR ≈18% | ORR ≈25% |
|-----|---------|---------|---------|
| 0.60 | >240 | 220 | 140 |
| 0.65 | 160 | 100 | 80 |
| 0.70 | 100 | 60 | 50 |
| 0.75 | 90 | 40 | 40 |

## Reproduce

```sh
Rscript gen_data.R          # 8,400,000 simulations, parallelized
Rscript gen_app.R           # builds app.html from plot_data.rds
```

Requires R ≥ 4.0 with packages `jsonlite`, `parallel`. Local packages in
`.Rlib/`.

## Methodology note: model-based approach considered

A logistic regression-based cutoff estimator (`glm(response ~ marker)`) was
considered but performed worse in an exploratory run — the clamped response
curve and IHC measurement error create features a linear-logistic model
cannot capture. The raw approach (counting observed responders above each
threshold) was retained. See `METHODS.md` for details.

## Files

| File | Purpose |
|------|---------|
| `app.html` | Interactive webapp (open in browser) |
| `biomarker_cutoff_bench.R` | Core simulation engine |
| `gen_data.R` | Data generation (50000 sims, 12 scenarios, 14 N levels) |
| `gen_app.R` | Builds HTML from aggregated data |
| `plot_data.rds` | Aggregated simulation results |
| `METHODS.md` | Full simulation methodology |
