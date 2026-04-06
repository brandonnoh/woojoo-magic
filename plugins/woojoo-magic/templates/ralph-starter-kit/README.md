# Ralph v2 — Autonomous Development Loop

실리콘밸리 수준의 다단계 자율 개발 파이프라인. 단순 `claude -p` 루프가 아닌 **5-stage pipeline** + **품질 게이트** + **자동 롤백**.

## 설치

```bash
# woojoo-magic 플러그인 경유
/woojoo:init-ralph

# 또는 수동 복사
cp -r <plugin>/templates/ralph-starter-kit/ ./
chmod +x ralph.sh lib/*.sh
```

필수 파일(프로젝트 루트):
- `CLAUDE.md` — 프로젝트 규칙
- `prd.md` — task 목록 (`templates/prd.template.md` 참조)
- `tests.json` — acceptance criteria (`templates/tests.template.json`)
- `progress.md` — 진행 로그 (`templates/progress.template.md`)
- `LESSONS.md` — 교훈 기록 (비어있어도 됨)
- `specs/` — task별 상세 기획 (`specs/{task-id}.md`, 선택)
- `smoke-test.sh` — E2E smoke test (선택, `templates/smoke-test.template.sh` 참조)

## 기본 실행

```bash
bash ralph.sh                   # 10 iteration, single worker
bash ralph.sh --iter 30         # 30 iteration
bash ralph.sh --parallel 3      # 3 worker 병렬
bash ralph.sh --strict          # 품질 회귀 시 즉시 중단
bash ralph.sh --no-reviewer     # reviewer stage 생략 (비용 절감)
bash ralph.sh --task engine-005 # 단일 task
bash ralph.sh --dry-run         # 파이프라인만 출력
bash ralph.sh --help
```

권장:
```bash
tmux new -s ralph "bash ralph.sh --iter 30 --parallel 2"
```

## 5-Stage Pipeline

| Stage | 이름 | 수행자 | 모델 | 역할 |
|-------|------|--------|------|------|
| 0 | Pre-Iteration Gate | bash | — | git clean, 체크포인트, 품질 스냅샷, 임시 파일 자동 정리 |
| 1 | Planner | claude -p | haiku | eligible task 선별, 병렬 그룹, cross-package 분석 |
| 2 | Workers | claude -p | sonnet | TDD 구현, review-feedback/last-failure 참조, 자가 검증 |
| 3 | Quality Gate | bash | — | build/test, smoke test, high-risk 전체 검증, 300줄/any/!. 델타 |
| 4 | Reviewer | claude -p | opus | diff 리뷰, HIGH_QUALITY 체크, 회귀 위험 평가, APPROVE/CHANGES_REQUESTED |
| 5 | Post-Iteration | bash | — | commit 검증, metrics.jsonl, progress.md |

각 stage 실패 시 → **자동 rollback** (`git reset --hard` to checkpoint) + `last-failure.log` 기록 → 다음 iteration Worker가 참조. 연속 3회 실패 시 전체 중단.

### Reviewer 피드백 자동 전달 (v1.7.5+)
Reviewer가 `CHANGES_REQUESTED`를 출력하면 → `review-feedback.log`에 저장 → 다음 iteration Worker가 피드백을 우선 수정.

### Smoke Test (v1.8.0+)
프로젝트 루트에 `smoke-test.sh`가 있으면 Quality Gate에서 빌드+테스트 후 자동 실행.
```bash
/wj:smoke-init    # 프로젝트 스택 감지 → smoke-test.sh 자동 생성
```

### High-Risk 변경 감지 (v1.8.0+)
auth/middleware/guard/route/session 파일 변경 시 scope 제한 무시, 전체 빌드+테스트 강제 실행.

### Spec 상세 기획 시스템 (v1.6.0+)
`tests.json`의 각 task에 `spec` 필드로 상세 기획 문서를 연결. Worker는 구현 전 반드시 spec을 읽고, Reviewer는 spec 대비 구현 일치를 검증.
```
specs/
├── auth-guard-001.md    # task별 상세 설계
├── auth-guard-002.md
└── ...
```
- `/wj:init-prd`, `/wj:feedback-to-prd`에서 spec 파일 동시 생성
- Planner가 eligible task의 spec 유무 표시
- Worker: `[worker] ✅ spec 로드: specs/{task-id}.md`
- Reviewer: spec 대비 구현 일치 검증

## 상태 파일

```
.ralph-state/
├── logs/                     # iter-{N}-{stage}.log
├── stack.json                # 감지된 스택 (pm, turbo, build_cmd, test_cmd)
├── checkpoint-{N}.sha        # iteration 시작 SHA
├── quality-pre-{N}.json      # Stage 0 스냅샷
├── quality-{N}.json          # Stage 3 스냅샷
├── plan-{N}.json             # Planner 출력
├── prev-metrics.json         # 비교 기준 (직전 성공 iteration)
├── last-failure.log          # 롤백 시 실패 원인 (다음 Worker 참조)
├── review-feedback.log       # Reviewer CHANGES_REQUESTED 피드백 (Worker 소비 후 삭제)
└── metrics.jsonl             # append-only (iter, duration, 품질, rollback)
```

## 메트릭 확인

```bash
# 최근 10개 iteration
tail -10 .ralph-state/metrics.jsonl | jq .

# 품질 추세
cat .ralph-state/metrics.jsonl | jq -s 'map({iter, any_count, files_over_300})'

# rollback 이력
grep '"rollback":true' .ralph-state/metrics.jsonl | jq .
```

## 문제 해결

### 품질 게이트가 계속 실패
```bash
# prev-metrics 리셋 (새 baseline)
rm .ralph-state/prev-metrics.json
```

### 특정 iteration 수동 rollback
```bash
git reset --hard "$(cat .ralph-state/checkpoint-05.sha)"
```

### Planner가 eligible task를 못 찾음
- `tests.json`의 `depends_on` 순환 의존 확인
- `prd.md`의 `[ ]` 형식 확인 (정확히 대괄호 + 공백)

### 개별 lib 디버깅
```bash
bash lib/detect-stack.sh
bash lib/pre-gate.sh manual
bash lib/quality-gate.sh manual
```

## 튜닝 가이드

| 목표 | 옵션 |
|------|------|
| 속도 | `--no-reviewer --parallel 3` |
| 품질 | `--strict --parallel 1` (reviewer 포함) |
| 비용 절감 | `--no-reviewer`, planner/worker 모델 downgrade |
| 단일 task 집중 | `--task TASK_ID --iter 3` |

## 디자인 철학

1. **Context rot 방지** — 매 iteration 새 `claude -p` 인스턴스
2. **역할 분리** — Planner/Worker/Reviewer를 다른 모델로 운용 (haiku/sonnet/opus)
3. **품질 델타 추적** — 빌드 통과만으로 부족. `any`, `!.`, 300줄 등 정량 델타
4. **자동 롤백** — 실패 시 즉시 git reset → 다음 iteration 깨끗한 상태
5. **Append-only 메트릭** — 장기 추세 분석 가능
6. **Cross-package 분석 강제** — 단일 패키지 유닛 통과의 함정 방지
