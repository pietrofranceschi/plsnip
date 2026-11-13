#' Predictions for several numbers of components
#'
#' [parsnip::multi_predict()] method for models fitted with the `"pls"`
#' engine: predictions for every value of `num_comp` from a single fit. This
#' is what makes tuning `num_comp` cost one fit per resample.
#'
#' @param object A `model_fit` from [parsnip::pls()] with `set_engine("pls")`.
#' @param new_data A data frame of predictors.
#' @param type `"numeric"` (regression), `"class"` or `"prob"`
#'   (classification). Default: `"numeric"` or `"class"` according to the mode.
#' @param num_comp Integer vector of numbers of components (values above the
#'   fitted number are clamped to it). Default: all components fitted.
#' @param ... Not used.
#' @return A tibble with one row per row of `new_data` and a list-column
#'   `.pred`; each element is a tibble with one row per `num_comp` and the
#'   column(s) `.pred`, `.pred_class` or `.pred_<level>`.
#' @examples
#' data(gasoline, package = "pls")
#' gas <- data.frame(octane = gasoline$octane, unclass(gasoline$NIR))
#' f <- pls(num_comp = 5) |> set_engine("pls") |> set_mode("regression") |>
#'   fit(octane ~ ., data = gas)
#' multi_predict(f, gas[1:2, ], num_comp = 1:5)
#' @importFrom parsnip multi_predict
#' @export
multi_predict._mvr <- function(object, new_data, type = NULL, num_comp = NULL, ...) {
  fit <- object$fit
  prepare_data <- utils::getFromNamespace("prepare_data", "parsnip")
  new_data <- prepare_data(object, new_data)
  if (is.null(num_comp)) num_comp <- seq_len(fit$ncomp)
  num_comp <- sort(unique(pmin(as.integer(num_comp), fit$ncomp)))  # clamp, as in the fit
  check_comps(fit, num_comp)
  if (is.null(type)) {
    type <- if (object$spec$mode == "classification") "class" else "numeric"
  }
  type <- rlang::arg_match(type, c("numeric", "class", "prob"))

  n <- NROW(new_data)
  long <- switch(type,
    numeric = purrr::map2(pls_yhat(fit, new_data, num_comp), num_comp, function(m, k) {
      tibble::tibble(.row = seq_len(n), num_comp = k, .pred = m[, 1])
    }),
    class = purrr::map2(pls_classes(fit, new_data, num_comp), num_comp, function(cl, k) {
      tibble::tibble(.row = seq_len(n), num_comp = k, .pred_class = cl)
    }),
    prob = purrr::map2(pls_probs(fit, new_data, num_comp), num_comp, function(p, k) {
      colnames(p) <- paste0(".pred_", colnames(p))
      tibble::tibble(.row = seq_len(n), num_comp = k, probs_to_tibble(p))
    })
  )
  long <- purrr::list_rbind(long)
  long <- long[order(long$.row, long$num_comp), ]
  res <- split(long[, -1], long$.row)
  names(res) <- NULL
  tibble::tibble(.pred = res)
}
