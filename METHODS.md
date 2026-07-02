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
estimated cutoff) is consistently ~35% of the population — matching real
oncology biomarkers like PD-L1 TPS at the 50% threshold.

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

4 AUC levels × 3 ORR levels = 12 scenarios, 16 N values each, **5000
simulations per scenario** (960,000 total, parallelized on 12 cores).

| AUC | Discrimination | low_orr → high_orr | ORR | Target ORR |
|-----|---------------|-------------------|-----|-----------|
| 0.60 | Weak | 8% → 20% | 10% | 15% |
| 0.60 | Weak | 13% → 30% | 18% | 23% |
| 0.60 | Weak | 20% → 45% | 25% | 34% |
| 0.65 | Moderate | 7% → 25% | 10% | 17% |
| 0.65 | Moderate | 12% → 40% | 18% | 28% |
| 0.65 | Moderate | 17% → 50% | 25% | 36% |
| 0.70 | Good | 6% → 30% | 10% | 20% |
| 0.70 | Good | 11% → 50% | 18% | 33% |
| 0.70 | Good | 15% → 65% | 25% | 43% |
| 0.75 | Strong | 4% → 30% | 10% | 19% |
| 0.75 | Strong | 8% → 55% | 18% | 35% |
| 0.75 | Strong | 12% → 70% | 25% | 45% |

## Cutoff estimation rule

The lowest observed biomarker threshold where the enriched subgroup (patients
at or above that threshold) simultaneously meets:

1. **Size ≥ max(20, 15% × N)**
2. **Observed ORR ≥ target_orr**

If no threshold satisfies both, the cutoff is undefined (NA).

## Population truth

The "true" cutoff is computed once per scenario from 200,000 patients using
the continuous response *probability* (not binary outcomes). This is the
threshold the rule would converge to with infinite data.

## Success rate definition

**Success** = the estimated cutoff is within ±10 biomarker points of the
population truth. The true cutoff is the biomarker value where enrichment
"kicks in" — the smallest threshold where the enriched subgroup hits the
target ORR.

## Results

### N needed for 50% success

| AUC | ORR 10% | ORR 18% | ORR 25% |
|-----|---------|---------|---------|
| 0.60 | >250 | 220 | 140 |
| 0.65 | 160 | 100 | 90 |
| 0.70 | 100 | 80 | 70 |
| 0.75 | 90 | 70 | 70 |

### N needed for 65% success

| AUC | ORR 10% | ORR 18% | ORR 25% |
|-----|---------|---------|---------|
| 0.60 | >250 | >250 | 240 |
| 0.65 | >250 | 180 | 140 |
| 0.70 | 180 | 100 | 80 |
| 0.75 | 160 | 80 | 70 |

## Key finding

At the same AUC, the N needed for a given success rate varies substantially
with ORR. Lower ORR → fewer responders at the same N → worse precision. The
responder heuristic (plan for expected responders = ORR × N) is robust across
ORR levels; the N heuristic is not.

## Limitations

- Single-arm design (no control arm, no PFS/OS endpoint).
- IHC-like biomarker scale and noise; other assays may differ.
- ORR-enrichment rule only; Youden-optimal or maximally selected rank
  statistics may behave differently.
- Assumes monotonic biomarker–response relationship.
