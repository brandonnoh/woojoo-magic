# PRD — woojoo-magic v3.1 품질 하네스 강화

> 아키텍처 리뷰에서 도출된 17개 개선점 수정. 플러그인 자체의 품질·일관성·다국어 지원 강화.

## Phase 1 — CRITICAL (문서 신뢰성 + DRY)
- [ ] c1-l2-multilang gate-l2.sh 다국어 확장 (Python/Go/Rust/Swift/Kotlin)
- [ ] c2-extract-preamble 스킬 6개의 품질 기준 블록을 공통 파일로 추출

## Phase 2 — HIGH (검증 강화 + 잔재 정리)
- [ ] h1-func-length 함수 길이 체크 로직 추가
- [ ] h2-cyclomatic-complexity CC 자동 검증 추가
- [ ] h3-session-v2-cleanup session-summary.sh v2 잔재 제거
- [ ] h4-l3-multilang gate-l3.sh 다국어 테스트 러너 확장
- [ ] h5-learn-paths learn 스킬 파일 경로 v3 업데이트

## Phase 3 — MEDIUM (중복 제거 + 보안 + 정리)
- [ ] m1-pattern-lib gate-l1과 quality-check 공통 패턴 추출
- [ ] m2-stop-loop-dedup stop-loop.sh 비루프/루프 코드 중복 제거
- [ ] m3-l1-early-exit gate-l1.sh 조기 종료 버그 수정 (다국어 누적)
- [ ] m4-block-dangerous block-dangerous.sh 정규식 우회 방지 강화
- [ ] m5-ideation-cleanup ideation 스킬에서 불필요한 코드 품질 블록 제거

## Phase 4 — LOW (마무리)
- [ ] l1-agent-model 에이전트 모델 버전 중앙 관리
- [ ] l2-journal-limit journal.sh 변경 파일 제한 상향
- [ ] l3-session-bang-fix session-summary.sh !. 카운트 부정확 수정
- [ ] l4-broken-paths 참조 경로 깨진 곳 전수 수정
- [ ] l5-help-phantom help.md 없는 스킬 참조 제거
