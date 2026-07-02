library(parallel)
source("biomarker_cutoff_bench.R")

run_bench2 <- function(sample_sizes, sims, target_orr, low_orr, high_orr,
                       min_enriched, min_fraction, seed) {
  set.seed(seed)
  true_cutoff <- population_cutoff(target_orr, min_enriched, min_fraction,
                                   60, seed + 1,
                                   low_orr = low_orr, high_orr = high_orr)
  rows <- vector("list", length(sample_sizes) * sims)
  row <- 0
  for (n in sample_sizes) {
    for (sim in seq_len(sims)) {
      dat <- simulate_trial(n, cutoff = 60, low_orr = low_orr, high_orr = high_orr)
      cutoff_hat <- estimate_cutoff(dat$observed_marker, dat$response,
                                    target_orr, min_enriched, min_fraction)
      row <- row + 1
      rows[[row]] <- data.frame(
        n = n,
        n_resp = sum(dat$response == 1),
        cutoff_hat = cutoff_hat,
        true_cutoff = true_cutoff,
        cutoff_abs_error = abs(cutoff_hat - true_cutoff)
      )
    }
  }
  do.call(rbind, rows)
}

ns <- c(seq(20, 100, 10), seq(120, 250, 20))

scenarios <- list(
  list(auc="0.60", orr="10%", lo=0.08, hi=0.20, t=0.15),
  list(auc="0.60", orr="18%", lo=0.13, hi=0.30, t=0.23),
  list(auc="0.60", orr="25%", lo=0.20, hi=0.45, t=0.34),
  list(auc="0.65", orr="10%", lo=0.07, hi=0.25, t=0.17),
  list(auc="0.65", orr="18%", lo=0.12, hi=0.40, t=0.28),
  list(auc="0.65", orr="25%", lo=0.17, hi=0.50, t=0.36),
  list(auc="0.70", orr="10%", lo=0.06, hi=0.30, t=0.20),
  list(auc="0.70", orr="18%", lo=0.11, hi=0.50, t=0.33),
  list(auc="0.70", orr="25%", lo=0.15, hi=0.65, t=0.43),
  list(auc="0.75", orr="10%", lo=0.04, hi=0.30, t=0.19),
  list(auc="0.75", orr="18%", lo=0.08, hi=0.55, t=0.35),
  list(auc="0.75", orr="25%", lo=0.12, hi=0.70, t=0.45)
)

cat(sprintf("Running %d scenarios on %d cores, %d sims each...\n",
    length(scenarios), detectCores(), 5000))

results <- mclapply(scenarios, function(sc) {
  cat(sprintf("[pid %d] AUC=%s ORR=%s ...\n", Sys.getpid(), sc$auc, sc$orr))
  d <- run_bench2(ns, 5000, sc$t, sc$lo, sc$hi, 20, 0.15, 20260701)
  d$auc_group <- sc$auc
  d$orr_label <- sc$orr
  d$combo_label <- sprintf("AUC=%s ORR=%s", sc$auc, sc$orr)
  d
}, mc.cores = 12)

all <- do.call(rbind, results)
all$success <- !is.na(all$cutoff_hat) & all$cutoff_abs_error <= 10

# Aggregate by N
agg_n <- do.call(rbind, lapply(split(all, list(all$combo_label, all$n)), function(d) {
  data.frame(
    auc_group = d$auc_group[1],
    orr_label = d$orr_label[1],
    combo_label = d$combo_label[1],
    n = d$n[1],
    exp_resp = round(mean(d$n_resp), 1),
    success_rate = round(mean(d$success) * 100, 1),
    n_sims = nrow(d)
  )
}))

# Aggregate by responder bins
bin_breaks <- seq(0, 100, 2)
all$resp_bin <- cut(all$n_resp, bin_breaks, right=FALSE, include.lowest=TRUE)
agg_resp <- do.call(rbind, lapply(split(all, list(all$combo_label, all$resp_bin)), function(d) {
  if (nrow(d) < 20) return(NULL)
  data.frame(
    auc_group = d$auc_group[1],
    orr_label = d$orr_label[1],
    combo_label = d$combo_label[1],
    resp_mid = round(mean(d$n_resp), 1),
    success_rate = round(mean(d$success) * 100, 1),
    n_sims = nrow(d)
  )
}))

saveRDS(list(by_n = agg_n, by_resp = agg_resp), "plot_data.rds")
cat(sprintf("\nDone. %d N-rows, %d resp-rows\n", nrow(agg_n), nrow(agg_resp)))
