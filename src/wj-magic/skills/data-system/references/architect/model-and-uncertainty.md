# Model & Uncertainty Reference

## Problem type → common model families

### Regression
Linear/Ridge → tree boosting → specialized temporal/spatial models

### Classification
Logistic → tree boosting → calibrated classifier

### Ranking
Pointwise baseline → pairwise/listwise ranker → constrained re-ranking

### Time series
Seasonal naive → lag-feature boosting → dedicated sequence models when justified

### Spatial
Rule/kriging/IDW baseline → engineered tabular model → spatial/deep model if scale and labels justify it

## Uncertainty patterns

### Quantile regression
Predict Q10/Q50/Q90 directly.

### Residual distribution
Point model + empirical residual distribution.

### Conformal prediction
Construct intervals with empirical coverage guarantees under assumptions.

### Scenario ensemble
Generate multiple plausible inputs/scenarios and retain their output distribution.

### Probability calibration
Check reliability diagrams / calibration error when predicted probability drives decisions.

## Ensemble principle

Do not add models just for count.

Seek diversity in:
- data source
- horizon
- spatial scale
- feature families
- algorithm family
- physics/rules vs data-driven approach
- local vs global model

Correlated mistakes reduce ensemble value.
