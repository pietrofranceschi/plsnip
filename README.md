# plsnip

<!-- badges: start -->
[![R-CMD-check](https://github.com/pietrofranceschi/plsnip/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/pietrofranceschi/plsnip/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

A [pls](https://cran.r-project.org/package=pls) engine for the partial least
squares model `parsnip::pls()`, so that PLS regression and PLS-DA can be used
in [tidymodels](https://www.tidymodels.org/) workflows without mixOmics.

* **Regression**: PLS regression via `pls::mvr()` (kernel PLS by default),
  identical to `pls::plsr()`.
* **Classification**: PLS-DA (one dummy column per class, one PLS2 model).
  Class probabilities from LDA on the PLS scores (default) or from a softmax of
  the predicted dummies.
* **Cheap tuning**: `num_comp` is a submodel parameter. One fit with the
  largest number of components serves all smaller ones, so tuning costs one
  fit per resample.
* The fitted engine object is a regular `mvr` object: `coef()`, `scores()`,
  `loadings()`, `R2()`, `RMSEP()` and the pls plots work on it.

## Installation

```r
# install.packages("pak")
pak::pak("pietrofranceschi/plsnip")
```

## Usage

```r
library(plsnip)   # registers the engine; attaches parsnip
library(tidymodels)

data(gasoline, package = "pls")
gas <- data.frame(octane = gasoline$octane, unclass(gasoline$NIR))

spec <- pls(num_comp = tune()) |>
  set_engine("pls") |>             # needed: pls() defaults to "mixOmics"
  set_mode("regression")

res <- tune_grid(
  workflow(recipe(octane ~ ., data = gas), spec),
  resamples = vfold_cv(gas, v = 5),
  grid = grid_regular(num_comp(range = c(1, 15)), levels = 15)
)
show_best(res, metric = "rmse")
```

PLS-DA:

```r
data(mayonnaise, package = "pls")
mayo <- data.frame(oil = factor(mayonnaise$oil.type), unclass(mayonnaise$NIR))

pls(num_comp = 8) |>
  set_engine("pls", prob_method = "lda") |>   # or "softmax"
  set_mode("classification") |>
  fit(oil ~ ., data = mayo) |>
  predict(mayo[1:3, ], type = "prob")
```

## Engine arguments

| Argument      | Default       | Meaning                                                      |
|---------------|---------------|--------------------------------------------------------------|
| `method`      | `"kernelpls"` | PLS algorithm (`"widekernelpls"`, `"simpls"`, `"oscorespls"`) |
| `scale`       | `FALSE`       | Scale predictors to unit variance (they are always centred)  |
| `prob_method` | `"lda"`       | PLS-DA probabilities: `"lda"` or `"softmax"`                 |
| ...           |               | Any other argument of `pls::mvr()`                           |

`num_comp` is clamped to `min(num_comp, n - 1, p)`. `predictor_prop` (sparse
PLS) is not supported; use the mixOmics engine for that.

## A note on Q²

`tune::collect_metrics()` averages each metric over the folds, and yardstick's
`rsq` is a squared correlation. The cross-validated Q² of `pls::R2()` is pooled
over all held-out predictions (`1 - PRESS / SS`). To compare the two, compute
Q² from `collect_predictions()`; see the vignette.

See `vignette("plsnip")` and `?details_pls_pls` for details.

## License

MIT
