# Validation & Decision Reference

## Validation patterns

### Time
- rolling origin
- expanding window
- walk-forward
- hold out the latest period

### Geography
- spatial blocks
- leave-one-region-out
- hold out a physically distinct region

### Users / accounts / devices
- group split by identity
- avoid same entity appearing in train and test when deployment sees new entities

## Metrics

Regression:
- MAE
- RMSE
- MAPE/SMAPE with care around zero

Classification:
- precision
- recall
- ROC-AUC
- PR-AUC
- calibration

Probabilistic:
- pinball loss
- CRPS
- interval coverage
- calibration

Ranking:
- NDCG
- MAP
- Precision@K

Business:
- expected profit
- avoided loss
- conversion lift
- time saved
- cost per successful decision

## Decision layer patterns

### Threshold
Take action if `P(event) > threshold`.

### Ranking
Act on top-K under resource limits.

### Expected utility
Choose action maximizing expected value across outcomes.

### Constrained optimization
Maximize utility subject to cost, capacity, risk, fairness, or operational constraints.

### Multi-objective
Expose Pareto-efficient options rather than hiding tradeoffs in one arbitrary score.
