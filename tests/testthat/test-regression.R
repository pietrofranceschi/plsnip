test_that("engine is registered", {
  expect_true("pls" %in% parsnip::show_engines("pls")$engine)
  expect_false(register_pls_engine())
})

test_that("regression predictions equal pls::plsr()", {
  s <- sim_data()
  f <- pls(num_comp = 4) |> set_engine("pls") |> set_mode("regression") |>
    fit(y ~ ., data = cbind(y = s$y, xcols(s$d)))
  ref <- pls::plsr(y ~ X, ncomp = 4, data = data.frame(y = s$y, X = I(s$X)))
  expect_equal(predict(f, s$d)$.pred, unname(drop(predict(ref, ncomp = 4))))
  expect_s3_class(parsnip::extract_fit_engine(f), "mvr")
})

test_that("fit_xy and one-row prediction work", {
  s <- sim_data()
  f <- pls(num_comp = 3) |> set_engine("pls") |> set_mode("regression") |>
    fit_xy(x = xcols(s$d), y = s$y)
  p <- predict(f, s$d[1, ])
  expect_equal(nrow(p), 1)
  expect_named(p, ".pred")
})

test_that("engine arguments are passed on", {
  s <- sim_data()
  f <- pls(num_comp = 3) |> set_engine("pls", method = "simpls", scale = TRUE) |>
    set_mode("regression") |> fit_xy(x = xcols(s$d), y = s$y)
  ref <- pls::mvr(y ~ X, ncomp = 3, method = "simpls", scale = TRUE,
                  data = data.frame(y = s$y, X = I(s$X)))
  expect_equal(predict(f, s$d)$.pred, unname(drop(predict(ref, ncomp = 3))))
})

test_that("num_comp is clamped and has a default", {
  s <- sim_data(n = 8, p = 30)
  f <- pls(num_comp = 20) |> set_engine("pls") |> set_mode("regression") |>
    fit_xy(x = xcols(s$d), y = s$y)
  expect_equal(parsnip::extract_fit_engine(f)$ncomp, 7)
  f0 <- pls() |> set_engine("pls") |> set_mode("regression") |>
    fit_xy(x = xcols(s$d), y = s$y)
  expect_equal(parsnip::extract_fit_engine(f0)$ncomp, 7)
})

test_that("predictor_prop raises an error", {
  s <- sim_data()
  expect_error(
    pls(num_comp = 2, predictor_prop = 0.5) |> set_engine("pls") |>
      set_mode("regression") |> fit_xy(x = xcols(s$d), y = s$y),
    "not supported"
  )
})

test_that("multi_predict matches separate fits", {
  s <- sim_data()
  f <- pls(num_comp = 5) |> set_engine("pls") |> set_mode("regression") |>
    fit_xy(x = xcols(s$d), y = s$y)
  mp <- multi_predict(f, s$d[1:3, ], num_comp = 1:5)
  expect_equal(nrow(mp), 3)
  expect_equal(mp$.pred[[1]]$num_comp, 1:5)
  for (k in 1:5) {
    fk <- pls(num_comp = k) |> set_engine("pls") |> set_mode("regression") |>
      fit_xy(x = xcols(s$d), y = s$y)
    expect_equal(vapply(mp$.pred, function(t) t$.pred[k], numeric(1)),
                 predict(fk, s$d[1:3, ])$.pred)
  }
})
