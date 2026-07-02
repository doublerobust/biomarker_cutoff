# Biomarker Cutoff Precision Simulator

Simulates single-arm oncology trials to answer: **how many patients do you need
to reliably estimate a biomarker enrichment cutoff?**

## Summary

Lower ORR generally requires larger N because responders are sparse. Cutoff
precision depends on the full trial design: total N, expected responder count,
biomarker discrimination (AUC), and the minimum enriched subgroup constraint.
See `app.html` for the interactive results.

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

## Methodology note: model-based approach explored

We tested a logistic regression-based cutoff estimator (`glm(response ~
marker)`) intending to smooth out Bernoulli noise. It performed worse than
the raw-data approach across all scenarios — the clamped response curve
(floor/ceiling effects) and IHC measurement error (SD=7) create features a
simple linear-logistic model cannot capture, introducing bias. The raw
approach (counting observed responders above each threshold) is unbiased
and was retained. See `METHODS.md` for details.

## Files

| File | Purpose |
|------|---------|
| `app.html` | Interactive webapp (open in browser) |
| `biomarker_cutoff_bench.R` | Core simulation engine |
| `gen_data.R` | Data generation (50000 sims, 12 scenarios, 14 N levels) |
| `gen_app.R` | Builds HTML from aggregated data |
| `plot_data.rds` | Aggregated simulation results |
| `METHODS.md` | Full simulation methodology |
