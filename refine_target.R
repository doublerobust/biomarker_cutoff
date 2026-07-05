library(parallel)
source("biomarker_cutoff_bench.R")
source("sample_size_calculator.R")

scenario_grid <- data.frame(
  auc = c(.60, .60, .60, .65, .65, .65, .70, .70, .70, .75, .75, .75),
  orr = c(.10, .18, .25, .10, .18, .25, .10, .18, .25, .10, .18, .25),
  low_orr = c(.08, .13, .20, .07, .12, .17, .06, .11, .15, .04, .08, .12),
  high_orr = c(.20, .30, .45, .25, .40, .50, .30, .50, .65, .30, .55, .70),
  target_orr = c(.15, .23, .34, .17, .28, .36, .20, .33, .43, .19, .35, .45)
)

interp_param <- function(name, auc, orr) {
  by_auc <- tapply(seq_len(nrow(scenario_grid)), scenario_grid$auc, function(ii) {
    approx(scenario_grid$orr[ii], scenario_grid[[name]][ii], xout = orr)$y
  })
  approx(as.numeric(names(by_auc)), as.numeric(by_auc), xout = auc)$y
}

target_params <- function(auc, orr) {
  if (orr > 1) orr <- orr / 100
  if (auc < min(scenario_grid$auc) || auc > max(scenario_grid$auc)) {
    stop("AUC is outside the scenario grid")
  }
  if (orr < min(scenario_grid$orr) || orr > max(scenario_grid$orr)) {
    stop("ORR is outside the scenario grid")
  }
  list(
    low_orr = interp_param("low_orr", auc, orr),
    high_orr = interp_param("high_orr", auc, orr),
    target_orr = interp_param("target_orr", auc, orr)
  )
}

run_target <- function(ns, sims, auc = 0.65, orr = 0.15, seed = 20260703,
                       min_enriched = 5, min_fraction = 0.20) {
  p <- target_params(auc, orr)
  true_cutoff <- population_cutoff(p$target_orr, min_enriched, min_fraction,
                                   60, seed + 1, low_orr = p$low_orr,
                                   high_orr = p$high_orr)
  rows <- vector("list", length(ns))
  for (i in seq_along(ns)) {
    n <- ns[i]
    set.seed(seed + n)
    ok <- replicate(sims, {
      dat <- simulate_trial(n, cutoff = 60, low_orr = p$low_orr,
                            high_orr = p$high_orr)
      cutoff_hat <- estimate_cutoff(dat$observed_marker, dat$response,
                                    p$target_orr, min_enriched, min_fraction)
      !is.na(cutoff_hat) && abs(cutoff_hat - true_cutoff) <= 10
    })
    rows[[i]] <- data.frame(n = n, success_rate = mean(ok), sims = sims)
  }
  do.call(rbind, rows)
}

parse_refine_args <- function(args) {
  cores <- detectCores()
  if (is.na(cores)) cores <- 1
  out <- list(auc = 0.65, orr = 0.15, success = 0.60, sims = 100000,
              window = 40, step = 5, cores = max(1, cores - 1),
              seed = 20260703)
  if (length(args) == 0) return(out)
  if ("--help" %in% args || length(args) %% 2 == 1) {
    stop("Usage: Rscript refine_target.R --auc 0.65 --orr 0.15 --success 0.60 --sims 100000")
  }
  for (i in seq(1, length(args), by = 2)) {
    key <- sub("^--", "", args[i])
    if (!key %in% names(out)) stop("Unknown argument: ", args[i])
    out[[key]] <- as.numeric(args[i + 1])
  }
  if (out$orr > 1) out$orr <- out$orr / 100
  if (out$success > 1) out$success <- out$success / 100
  out
}

if (sys.nframe() == 0) {
  args <- parse_refine_args(commandArgs(trailingOnly = TRUE))
  coarse <- needed_n(args$success, args$auc, args$orr)$n
  if (!is.numeric(coarse)) stop("Coarse N is outside the saved simulation range: ", coarse)
  ns <- seq(max(40, coarse - args$window), coarse + args$window, by = args$step)
  chunks <- split(ns, seq_along(ns) %% args$cores)
  out <- do.call(rbind, mclapply(chunks, run_target, sims = args$sims,
                                 auc = args$auc, orr = args$orr,
                                 seed = args$seed,
                                 mc.cores = min(args$cores, length(chunks))))
  out <- out[order(out$n), ]
  out$success_rate <- cummax(out$success_rate)
  hit <- which(out$success_rate >= args$success)[1]
  n_hat <- if (is.na(hit)) {
    paste0(">", max(out$n))
  } else if (hit == 1) {
    paste0("<=", out$n[hit])
  } else {
    ceiling(approx(out$success_rate[c(hit - 1, hit)],
                   out$n[c(hit - 1, hit)],
                   xout = args$success)$y)
  }
  print(out)
  cat(sprintf("Refined N: %s for AUC %.2f, ORR %.0f%%, %.0f%% success\n",
              n_hat, args$auc, 100 * args$orr, 100 * args$success))
}
