inv_logit <- function(x) 1 / (1 + exp(-x))

auc_rank <- function(marker, response) {
  ok <- !is.na(marker) & !is.na(response)
  marker <- marker[ok]
  response <- response[ok]
  n1 <- as.numeric(sum(response == 1))
  n0 <- as.numeric(sum(response == 0))
  if (n1 == 0 || n0 == 0) return(NA_real_)
  (sum(rank(marker)[response == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

simulate_trial <- function(n, cutoff = 40, low_orr = 0.08, high_orr = 0.35,
                           slope = 0.18, assay_sd = 7) {
  true_marker <- 100 * rbeta(n, 1.4, 2.2)
  observed_marker <- pmin(100, pmax(0, true_marker + rnorm(n, 0, assay_sd)))
  midpoint <- qlogis((low_orr + high_orr) / 2)
  p_response <- pmin(high_orr, pmax(
    low_orr,
    inv_logit(midpoint + slope * (true_marker - cutoff))
  ))
  response <- rbinom(n, 1, p_response)
  data.frame(true_marker, observed_marker, p_response, response)
}

estimate_cutoff <- function(marker, response, target_orr = 0.30,
                            min_enriched = 5, min_fraction = 0.20) {
  ord <- order(marker, decreasing = TRUE)
  marker <- marker[ord]
  response <- response[ord]
  ends <- which(!duplicated(marker, fromLast = TRUE))
  candidates <- marker[ends]
  enriched_n <- ends
  enriched_orr <- cumsum(response)[ends] / enriched_n
  min_n <- max(min_enriched, ceiling(length(marker) * min_fraction))
  keep <- enriched_n >= min_n & enriched_orr >= target_orr
  if (!any(keep)) return(NA_real_)
  min(candidates[keep])
}

bootstrap_metrics <- function(dat, target_orr, min_enriched, min_fraction,
                              boot = 200) {
  n <- nrow(dat)
  out <- replicate(boot, {
    idx <- sample.int(n, n, replace = TRUE)
    d <- dat[idx, ]
    c(
      cutoff = estimate_cutoff(d$observed_marker, d$response, target_orr,
                               min_enriched, min_fraction),
      auc = auc_rank(d$observed_marker, d$response)
    )
  })
  out <- t(out)
  c(
    cutoff_lcl = unname(quantile(out[, "cutoff"], 0.025, na.rm = TRUE)),
    cutoff_ucl = unname(quantile(out[, "cutoff"], 0.975, na.rm = TRUE)),
    auc_lcl = unname(quantile(out[, "auc"], 0.025, na.rm = TRUE)),
    auc_ucl = unname(quantile(out[, "auc"], 0.975, na.rm = TRUE))
  )
}

population_cutoff <- function(target_orr, min_enriched, min_fraction,
                              biology_cutoff, seed,
                              low_orr = 0.08, high_orr = 0.35,
                              slope = 0.18, assay_sd = 7) {
  set.seed(seed)
  pop <- simulate_trial(200000, cutoff = biology_cutoff,
                        low_orr = low_orr, high_orr = high_orr,
                        slope = slope, assay_sd = assay_sd)
  estimate_cutoff(pop$observed_marker, pop$p_response, target_orr,
                  min_enriched, min_fraction)
}

run_bench <- function(sample_sizes = c(60, 80, 100, 120, 150, 200),
                      sims = 500, boot = 200, biology_cutoff = 60,
                      cutoff_tolerance = 10, target_orr = 0.30,
                      min_enriched = 5, min_fraction = 0.20,
                      seed = 20260701, return_details = FALSE) {
  set.seed(seed)
  true_cutoff <- population_cutoff(target_orr, min_enriched, min_fraction,
                                   biology_cutoff, seed + 1)
  rows <- vector("list", length(sample_sizes) * sims)
  row <- 0

  for (n in sample_sizes) {
    for (sim in seq_len(sims)) {
      dat <- simulate_trial(n, cutoff = biology_cutoff)
      cutoff_hat <- estimate_cutoff(dat$observed_marker, dat$response,
                                    target_orr, min_enriched, min_fraction)
      auc_hat <- auc_rank(dat$observed_marker, dat$response)
      ci <- bootstrap_metrics(dat, target_orr, min_enriched, min_fraction, boot)

      row <- row + 1
      rows[[row]] <- data.frame(
        n = n,
        sim = sim,
        true_cutoff = true_cutoff,
        n_resp = sum(dat$response == 1),
        n_nonresp = sum(dat$response == 0),
        cutoff_hat = cutoff_hat,
        cutoff_abs_error = abs(cutoff_hat - true_cutoff),
        cutoff_ci_width = ci["cutoff_ucl"] - ci["cutoff_lcl"],
        auc_hat = auc_hat,
        auc_ci_width = ci["auc_ucl"] - ci["auc_lcl"]
      )
    }
  }

  details <- do.call(rbind, rows)
  if (return_details) return(details)

  do.call(rbind, lapply(split(details, details$n), function(d) {
    data.frame(
      n = d$n[1],
      true_cutoff = d$true_cutoff[1],
      cutoff_success = mean(!is.na(d$cutoff_hat) &
                              d$cutoff_abs_error <= cutoff_tolerance),
      cutoff_abs_error_median = median(d$cutoff_abs_error, na.rm = TRUE),
      cutoff_abs_error_p90 = unname(quantile(d$cutoff_abs_error, 0.90,
                                             na.rm = TRUE)),
      cutoff_ci_width_median = median(d$cutoff_ci_width, na.rm = TRUE),
      auc_median = median(d$auc_hat, na.rm = TRUE),
      auc_ci_width_median = median(d$auc_ci_width, na.rm = TRUE)
    )
  }))
}

responder_balance_check <- function(details, cutoff_tolerance = 10,
                                    resp_bins = c(0, 10, 20, 30, 40, Inf),
                                    nonresp_bins = c(0, 20, 40, 60, 80, Inf)) {
  details$resp_bin <- cut(details$n_resp, resp_bins, right = FALSE)
  details$nonresp_bin <- cut(details$n_nonresp, nonresp_bins, right = FALSE)
  do.call(rbind, lapply(split(details, list(details$resp_bin,
                                            details$nonresp_bin),
                              drop = TRUE), function(d) {
    data.frame(
      resp = d$resp_bin[1],
      nonresp = d$nonresp_bin[1],
      sims = nrow(d),
      cutoff_success = mean(!is.na(d$cutoff_hat) &
                              d$cutoff_abs_error <= cutoff_tolerance),
      cutoff_abs_error_median = median(d$cutoff_abs_error, na.rm = TRUE),
      auc_ci_width_median = median(d$auc_ci_width, na.rm = TRUE)
    )
  }))
}

if (sys.nframe() == 0) {
  stopifnot(auc_rank(c(1, 2, 3, 4), c(0, 0, 1, 1)) == 1)
  stopifnot(estimate_cutoff(1:5, c(0, 0, 1, 1, 1), 1.00, 1, 0) == 3)
  print(run_bench(sims = 100, boot = 100))
}
