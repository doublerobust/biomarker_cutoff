parse_percent <- function(x) as.numeric(sub("%$", "", x)) / 100

load_success_grid <- function(path = "plot_data.rds") {
  d <- readRDS(path)$by_n
  data.frame(
    auc = as.numeric(d$auc_group),
    orr = parse_percent(d$orr_label),
    n = d$n,
    success = d$success_rate / 100
  )
}

interp_success <- function(grid, auc, orr) {
  ns <- sort(unique(grid$n))
  out <- numeric(length(ns))

  for (i in seq_along(ns)) {
    dn <- grid[grid$n == ns[i], ]
    by_auc <- tapply(seq_len(nrow(dn)), dn$auc, function(ii) {
      approx(dn$orr[ii], dn$success[ii], xout = orr, rule = 2)$y
    })
    out[i] <- approx(as.numeric(names(by_auc)), as.numeric(by_auc),
                     xout = auc, rule = 2)$y
  }

  data.frame(n = ns, success = out)
}

needed_n <- function(target_success = 0.60, auc = 0.65, orr = 0.15,
                     path = "plot_data.rds") {
  if (orr > 1) orr <- orr / 100
  if (target_success > 1) target_success <- target_success / 100
  grid <- load_success_grid(path)
  if (auc < min(grid$auc) || auc > max(grid$auc)) stop("AUC is outside the simulated grid")
  if (orr < min(grid$orr) || orr > max(grid$orr)) stop("ORR is outside the simulated grid")

  curve <- interp_success(grid, auc, orr)
  curve$success <- cummax(curve$success)
  if (target_success <= curve$success[1]) {
    return(list(n = paste0("<=", min(curve$n)), curve = curve))
  }
  if (target_success > max(curve$success)) {
    return(list(n = paste0(">", max(curve$n)), curve = curve))
  }

  hit <- which(curve$success >= target_success)[1]
  lo <- curve[hit - 1, ]
  hi <- curve[hit, ]
  n <- approx(c(lo$success, hi$success), c(lo$n, hi$n),
              xout = target_success)$y
  list(n = ceiling(n), curve = curve)
}

parse_args <- function(args) {
  out <- list(auc = 0.65, orr = 0.15, success = 0.60)
  if (length(args) == 0) return(out)
  if ("--help" %in% args || length(args) %% 2 == 1) {
    stop("Usage: Rscript sample_size_calculator.R --auc 0.65 --orr 0.15 --success 0.60")
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
  args <- parse_args(commandArgs(trailingOnly = TRUE))
  ans <- needed_n(target_success = args$success, auc = args$auc, orr = args$orr)
  cat(sprintf(
    "Estimated N: %s for AUC %.2f, all-comer ORR %.0f%%, %.0f%% success\n",
    ans$n, args$auc, 100 * args$orr, 100 * args$success
  ))
}
