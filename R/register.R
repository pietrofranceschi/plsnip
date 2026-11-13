#' Register the `"pls"` engine
#'
#' Adds the engine `"pls"` to [parsnip::pls()] for the regression and
#' classification modes. Called automatically when the package is loaded;
#' calling it again does nothing.
#'
#' @return Invisibly, `TRUE` if the engine was registered, `FALSE` if it was
#'   already registered.
#' @keywords internal
#' @export
register_pls_engine <- function() {
  env <- parsnip::get_model_env()
  if (any(env$pls_fit$engine == "pls")) {
    return(invisible(FALSE))
  }

  parsnip::set_model_arg(
    model = "pls", eng = "pls", parsnip = "num_comp", original = "ncomp",
    func = list(pkg = "dials", fun = "num_comp"), has_submodel = TRUE
  )
  # Registered only so that a non-NULL value reaches pls_engine_fit() and raises
  # an error (unregistered arguments are silently dropped by parsnip)
  parsnip::set_model_arg(
    model = "pls", eng = "pls", parsnip = "predictor_prop", original = "predictor_prop",
    func = list(pkg = "dials", fun = "predictor_prop"), has_submodel = FALSE
  )

  for (mode in c("regression", "classification")) {
    parsnip::set_model_engine("pls", mode = mode, eng = "pls")
    parsnip::set_dependency("pls", eng = "pls", pkg = "pls", mode = mode)
    parsnip::set_dependency("pls", eng = "pls", pkg = "plsnip", mode = mode)
    if (mode == "classification") {
      parsnip::set_dependency("pls", eng = "pls", pkg = "MASS", mode = mode)
    }
    parsnip::set_fit(
      model = "pls", eng = "pls", mode = mode,
      value = list(
        interface = "matrix",
        protect   = c("x", "y"),
        func      = c(pkg = "plsnip", fun = "pls_engine_fit"),
        defaults  = list()
      )
    )
    parsnip::set_encoding(
      model = "pls", eng = "pls", mode = mode,
      options = list(predictor_indicators = "traditional", compute_intercept = FALSE,
                     remove_intercept = TRUE, allow_sparse_x = FALSE)
    )
  }

  pred_value <- function(fun) {
    list(
      pre = NULL, post = NULL, func = c(pkg = "plsnip", fun = fun),
      args = list(object = rlang::expr(object$fit), new_data = rlang::expr(new_data))
    )
  }
  parsnip::set_pred("pls", eng = "pls", mode = "regression", type = "numeric",
                    value = pred_value("pls_engine_predict_numeric"))
  parsnip::set_pred("pls", eng = "pls", mode = "classification", type = "class",
                    value = pred_value("pls_engine_predict_class"))
  parsnip::set_pred("pls", eng = "pls", mode = "classification", type = "prob",
                    value = pred_value("pls_engine_predict_prob"))
  invisible(TRUE)
}

# `object` and `new_data` appear in quoted prediction calls evaluated by parsnip
utils::globalVariables(c("object", "new_data"))

.onLoad <- function(libname, pkgname) {
  register_pls_engine()
}
