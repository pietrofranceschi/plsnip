#' plsnip: a 'pls' engine for 'parsnip' partial least squares models
#'
#' Loading the package registers the engine `"pls"` for [parsnip::pls()], so
#' PLS regression and PLS-DA fitted with the \pkg{pls} package can be used in
#' tidymodels workflows, resampling and tuning.
#'
#' ```
#' library(plsnip)
#' pls(num_comp = tune()) |> set_engine("pls") |> set_mode("regression")
#' ```
#'
#' `set_engine("pls")` is always needed, because [parsnip::pls()] defaults to
#' the `"mixOmics"` engine (package \pkg{plsmod}). See [details_pls_pls] for
#' the engine details.
#'
#' @keywords internal
"_PACKAGE"

#' The `"pls"` engine for `parsnip::pls()`
#'
#' [parsnip::pls()] with `set_engine("pls")` fits partial least squares models
#' with [pls::mvr()] (by default the kernel algorithm, as [pls::plsr()]).
#'
#' @section Modes:
#' * **regression**: PLS regression of a single numeric outcome.
#' * **classification**: PLS discriminant analysis (PLS-DA). The factor outcome
#'   is coded as one dummy column per class and regressed on the predictors
#'   with a single multi-response PLS model (PLS2). Classes and class
#'   probabilities depend on the engine argument `prob_method`:
#'   - `"lda"` (default): linear discriminant analysis ([MASS::lda()], priors =
#'     training class proportions) on the first `num_comp` PLS scores. Gives
#'     proper posterior probabilities; the predicted class is the most
#'     probable one.
#'   - `"softmax"`: softmax of the predicted dummy values; the predicted class
#'     is the class with the largest predicted dummy (classic PLS-DA "max"
#'     rule). The probabilities rank observations correctly (ROC AUC is fine)
#'     but are not calibrated.
#'
#' @section Tuning parameters:
#' * `num_comp` (\pkg{dials} [dials::num_comp()]; default range 1--4, so pass
#'   e.g. `num_comp(range = c(1, 15))` to the grid) is mapped to `ncomp`.
#'   It is clamped to `min(num_comp, n - 1, p)`, so that small resamples do
#'   not break a grid. When missing, `min(10, n - 1, p)` components are used.
#'
#' `num_comp` is a *submodel* parameter: one fit with the largest value serves
#' all smaller values through [parsnip::multi_predict()], so tuning
#' `num_comp` costs a single fit per resample.
#'
#' `predictor_prop` (sparse PLS) is not supported by this engine: setting it
#' raises an error. Use the `"mixOmics"` engine for sparse PLS.
#'
#' @section Engine arguments:
#' Passed through [parsnip::set_engine()]:
#' * `method`: PLS algorithm for [pls::mvr()], one of `"kernelpls"` (default),
#'   `"widekernelpls"`, `"simpls"`, `"oscorespls"`.
#' * `scale`: if `TRUE`, predictors are scaled to unit variance before the
#'   fit. Default `FALSE` (predictors are only centred), as in [pls::plsr()];
#'   note that the `"mixOmics"` engine scales by default. Scaling can also be
#'   done in a recipe (e.g. [recipes::step_normalize()]).
#' * `prob_method`: classification only, `"lda"` or `"softmax"` (see Modes).
#' * any other argument of [pls::mvr()].
#'
#' @section Preprocessing:
#' Factor predictors are converted to dummy variables
#' (`predictor_indicators = "traditional"`); no intercept column is added.
#' Spectral preprocessing (SNV, derivatives, smoothing, ...) is best done in a
#' recipe so it is re-estimated within each resample.
#'
#' @section Fitted object:
#' [parsnip::extract_fit_engine()] returns an ordinary \pkg{pls} `"mvr"`
#' object, so [pls::scores()], [pls::loadings()], [stats::coef()],
#' [pls::R2()], [pls::RMSEP()] and the \pkg{pls} plots work on it. For
#' classification it has extra elements `class_levels`, `prob_method` and
#' `lda` (a list of LDA fits, one per number of components). The `call`
#' element is removed (it would store the whole training set).
#'
#' @section Parallel processing:
#' The engine is registered when \pkg{plsnip} is loaded, and \pkg{plsnip} is
#' declared as a dependency of the engine, so parallel workers used by
#' \pkg{tune} load it automatically.
#'
#' @references
#' Mevik, B.-H. and Wehrens, R. (2007). The pls package: principal component
#' and partial least squares regression in R. *Journal of Statistical
#' Software*, 18(2), 1--23. \doi{10.18637/jss.v018.i02}
#'
#' Barker, M. and Rayens, W. (2003). Partial least squares for
#' discrimination. *Journal of Chemometrics*, 17(3), 166--173.
#' \doi{10.1002/cem.785}
#'
#' @examples
#' library(plsnip)
#' data(gasoline, package = "pls")
#' gas <- data.frame(octane = gasoline$octane, unclass(gasoline$NIR))
#'
#' fit_reg <- pls(num_comp = 3) |>
#'   set_engine("pls") |>
#'   set_mode("regression") |>
#'   fit(octane ~ ., data = gas)
#' predict(fit_reg, gas[1:3, ])
#' multi_predict(fit_reg, gas[1:2, ], num_comp = 1:3)$.pred[[1]]
#'
#' data(mayonnaise, package = "pls")
#' mayo <- data.frame(oil = factor(mayonnaise$oil.type), unclass(mayonnaise$NIR))
#' fit_cls <- pls(num_comp = 5) |>
#'   set_engine("pls") |>
#'   set_mode("classification") |>
#'   fit(oil ~ ., data = mayo)
#' predict(fit_cls, mayo[1:3, ], type = "prob")
#' @name details_pls_pls
#' @aliases plsnip_engine
NULL
