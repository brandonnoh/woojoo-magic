# Experiment Designer

Design evaluation that reproduces the real deployment problem.

## Workflow

1. Define the claim being tested.
2. Define the unit of prediction and unit of independence.
3. Identify leakage paths.
4. Choose the split strategy.
5. Establish baseline(s).
6. Choose model metrics.
7. Choose product/business metrics.
8. Define failure slices:
   - time
   - region
   - user cohort
   - rare event
   - extreme regime
9. Add calibration/coverage tests when probabilistic.
10. Define ablation tests.
11. Define acceptance criteria before seeing results.
12. If online deployment is possible, design staged rollout / A-B test / shadow test.

## Output

- hypothesis
- split design
- baseline
- metrics
- slices
- ablations
- acceptance thresholds
- online validation plan
- what result would falsify the approach

Never default to random split without checking temporal, spatial, or entity dependence.

## Mode handoff

This skill owns evaluation design only.

- If there is no concrete target/system to evaluate yet, return to ARCHITECT mode.
- If the evaluation requires a different model family or probabilistic layer, route to MODEL mode.
- If evaluation needs domain-grounded failure slices or realistic regimes, consult DOMAIN mode.
- If the user wants the existing design actively attacked for hidden flaws (not just measured), that is CRITIC mode.
