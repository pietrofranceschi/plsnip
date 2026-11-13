sim_data <- function(n = 60, p = 30, seed = 1) {
  set.seed(seed)
  X <- matrix(rnorm(n * p), n)
  colnames(X) <- paste0("x", seq_len(p))
  y <- drop(X[, 1:5] %*% rep(1, 5) + rnorm(n))
  d <- data.frame(y = y, X)
  d$cls  <- factor(ifelse(y > 0, "pos", "neg"), levels = c("pos", "neg"))
  d$cls3 <- cut(y, 3, labels = c("a", "b", "c"))
  d$grp  <- factor(rep(seq_len(n / 4), each = 4))
  list(d = d, X = X, y = y)
}
xcols <- function(d) d[, grepl("^x", names(d))]
