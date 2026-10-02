---
name: data-system
description: >
  제품 아이디어를 end-to-end 데이터 의사결정 시스템으로 설계하는 최상위 스킬.
  모델 추천이 아니라 "현실 문제 → 결정 → target/label → 데이터 → feature → 모델 →
  불확실성 → 검증 → 결정 레이어 → 추론 → 피드백 루프" 전 과정을 설계한다.
  내부에 4개 전문 모드를 포함한다: domain-researcher(도메인 메커니즘·데이터 소스 조사),
  ml-architect(모델 계층·확률예측·앙상블), experiment-designer(검증·metric·offline/online),
  data-critic(leakage·bias·label 오류·운영 불일치 공격). 알고리즘보다 Target/Label/시점/Decision을
  먼저 잡고, 반드시 non-ML baseline과 MVP(V0)부터 설계한다.
  "이 제품을 데이터 관점에서 고도화", "ML 붙일 건데 전체 구조 짜줘",
  "데이터부터 모델 운영까지 설계", "추천/예측/위험점수 시스템 기획",
  "label과 validation까지 제대로 기획", "leakage 있는지 공격적으로 검토",
  "이 도메인 데이터 소스 조사", "어떤 모델 구조가 맞아", "검증 전략 설계" 요청에 트리거.
---

**품질 기준**: `../../references/common/SKILL_PREAMBLE.md` 참조 (반드시 Read로 로드)

# Data System — end-to-end 데이터 의사결정 시스템 설계

제품 아이디어를 **하나의 결정 시스템**으로 변환하는 스킬. 모델을 먼저 고르지 않는다.
결정(decision) → target/label → 데이터 → feature → 모델 → 불확실성 → 검증 →
결정 레이어 → 추론 → 피드백 루프 순서로 설계하고, 반드시 non-ML baseline과
최소 MVP(V0)부터 세운다.

## When to use this skill

- 새 제품/기능에 데이터·ML 시스템을 처음부터 설계할 때
- 추천/예측/위험점수/이상탐지/최적화/시뮬레이션 시스템을 기획할 때
- target/label·시점(T)·검증 전략까지 포함해 "제대로" 짜야 할 때
- 기존 설계의 leakage·bias·운영 불일치를 공격적으로 검토할 때
- 도메인 데이터 소스·메커니즘을 feature로 번역해야 할 때

**경계**: DB 스키마·인덱스·샤딩 = db-design, 코드 아키텍처 = cto-review,
보안 = audit, UI = design. 이 스킬은 **데이터→결정 시스템의 구조**만 책임진다.

## 모드 (하나의 스킬, 4개 전문 렌즈)

요청의 초점에 따라 모드를 자동 판별한다. 보통은 ARCHITECT로 전체를 설계하고,
필요한 전문 모드를 호출해 깊이를 더한 뒤 다시 통합한다.

| 모드 | 언제 | 플레이북 |
|------|------|---------|
| **ARCHITECT** (기본) | 전체 end-to-end 설계 | 아래 Workflow |
| **DOMAIN** | 도메인 메커니즘·데이터 소스·현실 제약 조사 | `references/specialists/domain-researcher.md` |
| **MODEL** | 모델 계층·확률예측·calibration·앙상블 설계 | `references/specialists/ml-architect.md` |
| **EXPERIMENT** | 검증 split·metric·baseline·online 실험 설계 | `references/specialists/experiment-designer.md` |
| **CRITIC** | leakage·label·bias·skew 공격적 검토 | `references/specialists/data-critic.md` |

전문 모드는 작업을 마치면 ARCHITECT로 복귀해 통합한다. 전문 모드가 설계 전체를
조용히 떠안지 않는다. **신뢰 전에는 항상 CRITIC 패스를 거친다.**

## Core behavior

1. 알고리즘이 아니라 **결정(decision)**에서 시작한다.
2. prediction / estimation / classification / ranking / anomaly / optimization / simulation / recommendation을 구분한다.
3. 결정 시점 `T`와 forecast/decision horizon을 명시한다.
4. 모든 입력이 `T` 시점에 실제로 존재·접근 가능한지 감사한다.
5. label 설계를 1급 문제로 다룬다.
6. 도메인 메커니즘을 feature로 번역한다.
7. 고급 모델 전에 non-ML baseline을 세운다.
8. 결정을 바꾸는 불확실성은 보존한다.
9. 실제 배포를 재현하는 방식으로 검증한다.
10. 예측과 최종 결정 규칙을 분리한다.
11. training과 inference를 분리한다.
12. 독점 데이터 flywheel과 현실적 MVP로 마무리한다.

## Workflow (ARCHITECT)

### Step 1 — 제품 결정 정의
user/operator, 정확한 결정, 결정 시점, forecast horizon,
FP/FN/magnitude error 비용, 영향받는 제품 KPI. 모호하면 최소 가정을 명시한다.

### Step 2 — 시스템 분해
큰 문제를 하위 문제로 쪼갠다. 서로 다른 메커니즘을 한 모델에 억지로 밀어넣지 않는다.

### Step 3 — 데이터 인벤토리
First-party / Public / Commercial / Derived로 분류. 각 데이터셋에:
`source | granularity | time resolution | history | update latency | cost | inference availability | key risk`.
label 품질·시점·지리/행동 데이터·공개데이터 획득이 핵심이면
`references/architect/data-and-label-design.md`를 읽는다.
**데이터 소스를 확신 없이 지어내지 말 것** (DOMAIN 모드의 anti-hallucination 규칙 적용).

### Step 4 — target·label 설계
ground truth / proxy / label timestamp / label delay / missingness /
sampling·selection bias / positive-unlabeled / survivorship / human-label noise.
"기록 없음"을 negative label로 가정하지 않는다.

### Step 5 — leakage 감사
`T`를 선언하고 모든 주요 feature에 "이 값이 T에 실제로 존재·접근 가능한가?"를 묻는다.
future aggregate, revised/final 값, target-derived, post-outcome, entity/time/location 유사도 누출 split을 거부한다.

### Step 6 — feature family 설계
static / temporal(lag·rolling·trend·seasonality) / spatial / domain-derived /
interaction / regime / historical deviation / exposure×vulnerability / missingness indicator.
핵심 feature는 (무엇·왜 중요·어떤 가설)을 설명한다.

### Step 7 — baseline 수립
rule score / historical·seasonal mean / last value / linear·logistic·ridge / simple ranker.
고급 모델은 쓸모있는 baseline을 이겨야 한다.

### Step 8 — 모델 ladder 설계
L0 rule → L1 linear → L2 tree ensemble → L3 time-series/spatial/neural → L4 hybrid/ensemble.
각 레벨에 (적합 이유·데이터 요구·해석가능성·운영비용·실패양상).
확률예측·앙상블·랭킹·geospatial·시계열이 핵심이면 MODEL 모드 →
`references/specialists/ml-architect.md` + `references/architect/model-and-uncertainty.md`.

### Step 9 — 불확실성 보존
결정을 바꾸면 probability / Q10·Q50·Q90 / prediction interval / scenario ensemble /
residual distribution / conformal interval로 출력. 유용한 분포를 성급히 평균으로 뭉개지 않는다.

### Step 10 — 검증 설계
배포를 mirror한다: time→walk-forward, geo→spatial CV/leave-one-region-out,
users→group split, 새 시장→OOD holdout. task 적합 metric + 가능하면 business metric.
EXPERIMENT 모드 → `references/specialists/experiment-designer.md` +
`references/architect/validation-and-decision.md`.

### Step 11 — 결정 레이어 설계
`prediction/distribution → policy/threshold/optimizer → action`.
threshold / ranking / expected utility / expected cost / argmax / constrained optimization /
multi-objective / Pareto. 최고의 예측이 곧 최선의 제품 결정은 아니다.

### Step 12 — training vs inference 분리
training(historical→feature pipeline→train→calibration→artifacts)과
inference(현재 가용 데이터→동일 feature 정의→model→decision layer→API/UI)를 분리하고
training-serving skew를 지적한다.

### Step 13 — 설명가능성
신뢰가 중요하면 feature contribution / SHAP / confidence / source evidence /
nearest analog / 과거 비교 / risk decomposition.

### Step 14 — 데이터 flywheel·moat
사용 후 생기는 독점 ground truth / outcome 피드백 포착 / 공개데이터만으로 재현 가능 여부 /
시간이 갈수록 비싸지는 private 데이터.

## Required output (ARCHITECT)

1. 한 줄 시스템 정의
2. 실제 내려야 할 결정
3. end-to-end 아키텍처 (ASCII)
4. 데이터 설계 (표)
5. target/label 설계
6. feature engineering 계획
7. 모델 ladder
8. 불확실성 레이어
9. 검증 설계
10. 결정 레이어
11. training vs inference
12. 설명가능성
13. 데이터 flywheel/moat
14. V0 → V3 로드맵
15. 한 사람이 먼저 만들 수 있는 것

## MVP 규율

- **V0** rule / 공개데이터 / 수동 검증
- **V1** tabular ML
- **V2** calibrated 확률예측
- **V3** ensemble + 독점 피드백 데이터

V0가 가치를 입증하지 못하면 고급 모델링을 권하지 않는다.

## Quality gate (마무리 전 필수)

- target이 측정 가능한가?
- 모든 주요 feature가 inference 시점에 존재하는가?
- 검증 split이 현실적인가?
- 유의미하게 유용하면 불확실성이 표현됐는가?
- 최종 action 규칙이 명시됐는가?
- 신뢰할 만한 피드백 루프가 있는가?
- 더 작은 MVP가 있는가?
- **CRITIC 모드로 leakage/bias/skew를 공격했는가?**

## eval

trigger 정확도는 `evals/trigger-evals.json` + `evals/run_evals.py`로 검증한다
(표준 라이브러리만, 추가 설치 불필요).

```bash
python3 evals/run_evals.py validate          # 스키마·중복·구조 검증
python3 evals/run_evals.py score --template graded.json   # 수동 채점 템플릿
python3 evals/run_evals.py score --infile graded.json     # 정확도/precision/recall/f1
```
