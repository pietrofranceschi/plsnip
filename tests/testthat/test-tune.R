test_that("tune_grid uses one fit per resample and matches manual CV", {
  skip_if_not_installed("tune")
  skip_if_not_installed("workflows")
  skip_if_not_installed("recipes")
  skip_if_not_installed("rsample")
  skip_if_not_installed("yardstick")
  s <- sim_data()
  d <- cbind(y = s$y, grp = s$d$grp, xcols(s$d))
  set.seed(2)
  folds <- rsample::group_vfold_cv(d, group = grp, v = 5)
  rec <- recipes::recipe(y ~ ., data = d) |> recipes::update_role(grp, new_role = "id")
  wf <- workflows::workflow(rec, pls(num_comp = tune::tune()) |>
                              set_engine("pls") |> set_mode("regression"))

  # count calls to pls::mvr() through a global option
  options(plsnip.n_fit = 0)
  suppressMessages(trace("mvr", quote(options(plsnip.n_fit = getOption("plsnip.n_fit") + 1)),
                         print = FALSE, where = asNamespace("pls")))
  on.exit(suppressMessages(untrace("mvr", where = asNamespace("pls"))), add = TRUE)
  res <- tune::tune_grid(wf, folds, grid = data.frame(num_comp = 1:6),
                         metrics = yardstick::metric_set(yardstick::rmse))
  expect_equal(getOption("plsnip.n_fit"), 5)

  tuned <- tune::collect_metrics(res)$mean[c(2, 5)]
  manual <- vapply(c(2, 5), function(k) mean(vapply(folds$splits, function(sp) {
    tr <- rsample::analysis(sp); te <- rsample::assessment(sp)
    m <- pls::plsr(y ~ X, ncomp = k,
                   data = data.frame(y = tr$y, X = I(as.matrix(xcols(tr)))))
    pr <- drop(predict(m, newdata = data.frame(X = I(as.matrix(xcols(te)))), ncomp = k))
    sqrt(mean((te$y - pr)^2))
  }, numeric(1))), numeric(1))
  expect_equal(tuned, manual)
})

test_that("classification tuning runs without notes", {
  skip_if_not_installed("tune")
  skip_if_not_installed("rsample")
  s <- sim_data()
  d <- cbind(cls = s$d$cls, xcols(s$d))
  set.seed(3)
  folds <- rsample::vfold_cv(d, v = 4)
  res <- tune::tune_grid(pls(num_comp = tune::tune()) |> set_engine("pls") |>
                           set_mode("classification"),
                         cls ~ ., resamples = folds, grid = data.frame(num_comp = 1:4))
  expect_equal(nrow(tune::collect_notes(res)), 0)
  expect_true(all(c("roc_auc", "accuracy", "brier_class") %in%
                    tune::collect_metrics(res)$.metric))
})
