# Simulation Methodology

## Goal

Estimate how many patients are needed to reliably identify a biomarker cutoff
that enriches for responders in a single-arm oncology trial.

## Data-generating process

### Biomarker

A latent "true" biomarker is drawn from a scaled Beta distribution:

```
true_marker ~ 100 × Beta(α=1.4, β=2.2)
```

Right-skewed (mean ~39, range 0–100), mimicking IHC H-scores where most
patients have low-to-moderate expression. The enriched subgroup (above the
estimated cutoff) is consistently ~35% of the population.

The observed assay value adds Gaussian measurement noise:

```
observed_marker = clamp(true_marker + N(0, σ=7), 0, 100)
```

### Response probability

```
p_response = clamp(inv_logit(midpoint + 0.18 × (true_marker - 60)),
                   low_orr, high_orr)
response ~ Bernoulli(p_response)
```

`low_orr` and `high_orr` vary by scenario to produce different overall ORRs
and AUCs while keeping the underlying biomarker distribution fixed.

## Scenarios tested

4 AUC levels × 3 ORR levels = 12 scenarios, 14 N values (40–240), **50000
simulations per scenario** (8,400,000 total, parallelized on 12 cores).

AUC and ORR labels are approximate calibrated targets. Actual population
values may differ slightly (e.g., a labeled "AUC=0.75" scenario may have
population AUC ≈ 0.74; a labeled "ORR=18%" scenario may have population
ORR ≈ 16.4%).

| AUC (label) | low_orr → high_orr | ORR (label) | Target ORR |
|-------------|-------------------|-------------|-----------|
| 0.60 | 8% → 20% | 10% | 15% |
| 0.60 | 13% → 30% | 18% | 23% |
| 0.60 | 20% → 45% | 25% | 34% |
| 0.65 | 7% → 25% | 10% | 17% |
| 0.65 | 12% → 40% | 18% | 28% |
| 0.65 | 17% → 50% | 25% | 36% |
| 0.70 | 6% → 30% | 10% | 20% |
| 0.70 | 11% → 50% | 18% | 33% |
| 0.70 | 15% → 65% | 25% | 43% |
| 0.75 | 4% → 30% | 10% | 19% |
| 0.75 | 8% → 55% | 18% | 35% |
| 0.75 | 12% → 70% | 25% | 45% |

## Cutoff estimation rule

The lowest observed biomarker threshold where the enriched subgroup (patients
at or above that threshold) simultaneously meets:

1. **Size ≥ max(5, 20% × N)**
2. **Observed ORR ≥ target_orr**

If no threshold satisfies both, the cutoff is undefined (NA).

## Population truth

The "true" cutoff is computed once per scenario from 200,000 patients using
the continuous response *probability* (not binary outcomes), with the same
rule parameters (min_enriched=5, min_fraction=0.20).

## Success rate definition

**Success** = the estimated cutoff is within ±10 biomarker points of the
population truth. The true cutoff is the biomarker value where enrichment
"kicks in" — the smallest threshold where the enriched subgroup hits the
target ORR.

## Results

### N needed for 50% success (first N where success rate ≥ 50%)

| AUC | ORR ≈10% | ORR ≈18% | ORR ≈25% |
|-----|---------|---------|---------|
| 0.60 | >240 | 220 | 140 |
| 0.65 | 160 | 100 | 80 |
| 0.70 | 100 | 60 | 50 |
| 0.75 | 90 | 40 | 40 |

### N needed for 65% success (first N where success rate ≥ 65%)

| AUC | ORR ≈10% | ORR ≈18% | ORR ≈25% |
|-----|---------|---------|---------|
| 0.60 | >240 | >240 | >240 |
| 0.65 | >240 | 200 | 160 |
| 0.70 | 200 | 120 | 80 |
| 0.75 | 180 | 80 | 60 |

## Key finding

In these calibrated scenarios, lower ORR generally required larger N to
reach the same success rate. Responder scarcity is a likely contributor,
but cutoff precision also depends on AUC, target ORR, the enriched-subgroup
constraint (min_n = max(5, 20% × N)), and total N.

## Alternative approaches considered

A GLM-based cutoff estimator (`glm(response ~ marker, family = binomial)`)
was considered as an alternative to reduce Bernoulli sampling noise. However,
the true response curve is clamped at `low_orr` and `high_orr`, creating flat
floor and ceiling regions that a linear-logistic model cannot capture. The
IHC measurement error (SD=7) further attenuates the logistic coefficient via
regression dilution. An exploratory run confirmed that the GLM approach
produced lower success rates than the raw-data approach and was not pursued
further.

The raw-data approach — counting observed responders above each threshold —
makes no shape assumptions and was retained for the final benchmark.

## Limitations

- Single-arm design (no control arm, no PFS/OS endpoint).
- IHC-like biomarker scale and noise; other assays may differ.
- ORR-enrichment rule only; Youden-optimal or maximally selected rank
  statistics may behave differently.
- Assumes monotonic biomarker–response relationship.
- AUC and ORR labels are approximate calibrated targets, not exact values.
