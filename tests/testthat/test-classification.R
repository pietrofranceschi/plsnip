for (pm in c("lda", "softmax")) {
  test_that(paste("classification works with prob_method =", pm), {
    s <- sim_data()
    f <- pls(num_comp = 3) |> set_engine("pls", prob_method = pm) |>
      set_mode("classification") |> fit(cls ~ ., data = cbind(cls = s$d$cls, xcols(s$d)))
    pr <- predict(f, s$d, type = "prob")
    expect_named(pr, c(".pred_pos", ".pred_neg"))
    expect_equal(rowSums(pr), rep(1, nrow(s$d)), ignore_attr = TRUE)
    expect_true(all(pr > 0 & pr < 1))
    cl <- predict(f, s$d)$.pred_class
    expect_identical(levels(cl), c("pos", "neg"))
    expect_equal(nrow(predict(f, s$d[1, ], type = "prob")), 1)
    if (pm == "lda") {   # class = most probable class
      expect_identical(as.character(cl),
                       c("pos", "neg")[max.col(as.matrix(pr), ties.method = "first")])
    }
    expect_gt(mean(cl == s$d$cls), 0.7)   # fitted accuracy on easy data
  })
}

test_that("three-class PLS-DA and multi_predict", {
  s <- sim_data()
  f <- pls(num_comp = 4) |> set_engine("pls") |> set_mode("classification") |>
    fit_xy(x = xcols(s$d), y = s$d$cls3)
  mp <- multi_predict(f, s$d[1:2, ], type = "prob", num_comp = 2:4)
  expect_named(mp$.pred[[1]], c("num_comp", ".pred_a", ".pred_b", ".pred_c"))
  f2 <- pls(num_comp = 2) |> set_engine("pls") |> set_mode("classification") |>
    fit_xy(x = xcols(s$d), y = s$d$cls3)
  expect_equal(unlist(mp$.pred[[1]][1, -1]),
               unlist(predict(f2, s$d[1, ], type = "prob")), ignore_attr = TRUE)
  mc <- multi_predict(f, s$d[1:2, ], num_comp = 1:4)
  expect_s3_class(mc$.pred[[1]]$.pred_class, "factor")
})
