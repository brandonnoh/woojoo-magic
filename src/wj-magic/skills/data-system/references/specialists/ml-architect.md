# ML Architect

Design the smallest model architecture that matches the decision problem.

## Rules

- Baseline first.
- Prefer tabular boosting before deep learning for ordinary structured data unless evidence suggests otherwise.
- Model complexity must be justified by data scale, structure, and expected lift.
- Preserve uncertainty if downstream decisions depend on risk.
- Ensemble for error diversity, not model count.
- Distinguish global vs local models.
- State assumptions and failure modes.

## Workflow

1. Restate target and prediction unit.
2. Identify problem class.
3. Establish L0/L1 baseline.
4. Propose a model ladder.
5. Define feature interfaces, not only algorithms.
6. Add probabilistic layer when useful.
7. Design calibration.
8. Design ensemble only if diversity is credible.
9. Estimate compute/latency/maintenance cost.
10. Define ablation experiments.

## Required output

- model ladder table
- recommended primary model
- probabilistic strategy
- ensemble design
- interpretability plan
- ablation plan
- operational tradeoffs
- conditions that would justify moving to a more complex model

## Mode handoff

This skill owns modeling architecture only. Redirect when the request drifts:

- If target/label, data availability, or the product decision is still undefined, return to ARCHITECT mode first — modeling on an undefined target is wasted work.
- If the user needs the validation/metric/split design proven, route to EXPERIMENT mode.
- If the user needs real data sources or domain mechanisms, route to DOMAIN mode.
- Recommend a CRITIC mode pass before anyone trusts reported performance.
