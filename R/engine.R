# Fit and prediction functions called by parsnip for the "pls" engine.
# They are exported (parsnip calls them as plsnip::<fun>) but not meant to be
# used directly.

#' Fit and predict functions for the `"pls"` engine
#'
#' Low-level functions called by \pkg{parsnip}; use [parsnip::pls()] with
#' `set_engine("pls")` instead. See [details_pls_pls].
#'
#' @param x Predictor matrix or data frame (numeric).
#' @param y Numeric vector (regression) or factor (classification).
#' @param ncomp Number of components (clamped to `min(ncomp, n - 1, p)`);
#'   `NULL` means `min(10, n - 1, p)`.
#' @param method PLS algorithm passed to [pls::mvr()].
#' @param scale Logical, scale predictors to unit variance (default `FALSE`).
#' @param prob_method Classification only: `"lda"` or `"softmax"`.
#' @param predictor_prop Not supported; must be `NULL`.
#' @param ... Further arguments for [pls::mvr()].
#' @param object A fitted `"mvr"` object returned by `pls_engine_fit()`.
#' @param new_data Predictor matrix or data frame.
#' @return `pls_engine_fit()`: an `"mvr"` object. Predict functions: a
#'   numeric vector, a factor, or a tibble of class probabilities.
#' @keywords internal
#' @export
pls_engine_fit <- function(x, y, ncomp = NULL, method = "kernelpls", scale = FALSE,
                           prob_method = c("lda", "softmax"), predictor_prop = NULL,
                           ...) {
  if (!is.null(predictor_prop)) {
    rlang::abort(c(
      "`predictor_prop` (sparse PLS) is not supported by the \"pls\" engine.",
      i = "Use `set_engine(\"mixOmics\")` for sparse PLS."
    ))
  }
  x <- as.matrix(x)
  storage.mode(x) <- "double"
  max_comp <- min(nrow(x) - 1L, ncol(x))
  ncomp <- if (is.null(ncomp)) min(10L, max_comp) else min(as.integer(ncomp), max_comp)
  if (ncomp < 1L) rlang::abort("At least 2 rows and 1 predictor are needed.")

  if (is.factor(y)) {
    prob_method <- rlang::arg_match(prob_method)
    lev <- levels(y)
    Y <- stats::model.matrix(~ y - 1)          # one-hot, one column per level
    dimnames(Y) <- list(NULL, lev)
    fit <- pls::mvr(Y ~ X, ncomp = ncomp, data = data.frame(Y = I(Y), X = I(x)),
                    method = method, scale = scale, ...)
    fit$class_levels <- lev
    fit$prob_method  <- prob_method
    if (prob_method == "lda") {
      sc <- unclass(fit$scores)
      fit$lda <- lapply(seq_len(ncomp), function(k) {
        MASS::lda(sc[, seq_len(k), drop = FALSE], grouping = y)
      })
    }
  } else {
    y <- as.numeric(y)
    fit <- pls::mvr(y ~ X, ncomp = ncomp, data = data.frame(y = y, X = I(x)),
                    method = method, scale = scale, ...)
  }
  fit$call <- NULL    # the call holds the whole training set
  fit
}

#' @rdname pls_engine_fit
#' @export
pls_engine_predict_numeric <- function(object, new_data, ncomp = object$ncomp) {
  pls_yhat(object, new_data, check_comps(object, ncomp))[[1]][, 1]
}

#' @rdname pls_engine_fit
#' @export
pls_engine_predict_class <- function(object, new_data, ncomp = object$ncomp) {
  pls_classes(object, new_data, check_comps(object, ncomp))[[1]]
}

#' @rdname pls_engine_fit
#' @export
pls_engine_predict_prob <- function(object, new_data, ncomp = object$ncomp) {
  probs_to_tibble(pls_probs(object, new_data, check_comps(object, ncomp))[[1]])
}

# ---- Helpers ------------------------------------------------------------------------
# Each returns a list with one element per number of components in `comps`, so that
# predict() and multi_predict() share the code.

new_x_frame <- function(new_data) {
  x <- as.matrix(new_data)
  storage.mode(x) <- "double"
  data.frame(X = I(x))
}

check_comps <- function(object, comps) {
  if (any(comps > object$ncomp) || any(comps < 1)) {
    rlang::abort(paste0("The model was fitted with ", object$ncomp,
                        " components; `num_comp` must be between 1 and ",
                        object$ncomp, "."))
  }
  comps
}

# Predicted y (regression) or dummy matrix (classification): n x nresp matrices
pls_yhat <- function(object, new_data, comps) {
  arr <- stats::predict(object, newdata = new_x_frame(new_data), ncomp = comps)
  lapply(seq_along(comps), function(i) {
    matrix(arr[, , i], nrow = dim(arr)[1], dimnames = list(NULL, dimnames(arr)[[2]]))
  })
}

# Class-probability matrices (n x levels)
pls_probs <- function(object, new_data, comps) {
  lev <- object$class_levels
  if (identical(object$prob_method, "lda")) {
    sc <- stats::predict(object, newdata = new_x_frame(new_data), type = "scores")
    sc <- matrix(sc, nrow = NROW(new_data))
    lapply(comps, function(k) {
      p <- stats::predict(object$lda[[k]], sc[, seq_len(k), drop = FALSE])$posterior
      p[, lev, drop = FALSE]
    })
  } else {
    lapply(pls_yhat(object, new_data, comps), function(yh) {
      e <- exp(yh - apply(yh, 1, max))
      p <- e / rowSums(e)
      colnames(p) <- lev
      p
    })
  }
}

pls_classes <- function(object, new_data, comps) {
  lev <- object$class_levels
  mats <- if (identical(object$prob_method, "lda")) {
    pls_probs(object, new_data, comps)
  } else {
    pls_yhat(object, new_data, comps)
  }
  lapply(mats, function(m) factor(lev[max.col(m, ties.method = "first")], levels = lev))
}

probs_to_tibble <- function(p) {
  tibble::as_tibble(as.data.frame(p, optional = TRUE))
}
