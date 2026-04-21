# /wj:investigate — 설계 스펙

**작성일:** 2026-04-21
**버전:** 4.3.0
**상태:** 구현 완료

---

## 배경 및 목적

`/wj:debug`는 1인 4단계 조사 방식으로 복잡한 이슈 앞에서 부족했다.
단순 버그 추적을 넘어 성능 병목, 보안 취약점, 아키텍처 설계 결함까지 통합 커버하고,
웹 리서치 + 전문가 에이전트 팀 + 최신 분석 방법론을 총동원하는 "국정조사급" 조사가 필요했다.

---

## 범위

### IN scope
- 버그 / 런타임 에러 (에러 메시지, 스택 트레이스, 예외)
- 성능 병목 (느린 응답, 메모리 누수, CPU 스파이크, 재렌더링)
- 보안 취약점 (OWASP Top 10, CVE, 하드코딩 시크릿)
- 아키텍처 설계 문제 (순환 의존성, 경계 위반, 패턴 오남용)
- 회귀 (언제 도입됐는지 특정)

### OUT scope
- 새 기능 기획 → `/wj:ideation`
- 코드베이스 전수 점검 → `/wj:cto-review`
- 단순 구현 → `/wj:devrule`

---

## 아키텍처

### 5단계 워크플로우

```
Phase 0: 트리아지 (Claude PM)
  - 이슈 타입 감지 (bug/perf/security/arch/복합)
  - 영향 범위 파악 + git 최근 변경 분석
  - 5개 에이전트 프롬프트 커스터마이징
  - investigation-utils.sh report-init 으로 리포트 초기화

Phase 1: 병렬 심층 조사 (5 agents, run_in_background: true)
  - web-researcher: Context7 + WebSearch + GitHub Issues
  - code-analyst: Serena MCP + SBFL-inspired 의심도 분석
  - security-auditor: OWASP + 취약점 스캔 (기존 에이전트)
  - perf-analyst: 코드 레벨 안티패턴 + Chrome DevTools
  - regression-hunter: investigation-utils.sh + git bisect

Phase 2: 수렴 + 근본 원인 (Sequential Thinking MCP)
  - 7단계 추론으로 근본 원인 후보 3개 도출
  - 신뢰도 = (지지 에이전트 수 / 5) × 증거 강도
  - 수정 규모 결정 (S/M/L)

Phase 3: 수정 구현 (devrule 패턴)
  - S: Claude 직접
  - M: 전문 에이전트 1개 + QA
  - L: 팀 병렬 (worktree 격리)

Phase 4: 검증
  - 테스트 + L1/L2/L3 게이트

Phase 5: 리포트 + 학습
  - investigation-report.md 완성
  - Memory MCP에 지식 그래프 저장
  - /wj:learn으로 LESSONS.md 업데이트
```

---

## 신규 구성 요소

### 에이전트 (4개 추가)

| 에이전트 | 역할 | 핵심 MCP |
|---------|------|---------|
| `web-researcher` | 웹 리서치, CVE, 유사 이슈 | Context7, WebSearch |
| `code-analyst` | 심볼 추적, SBFL, taint analysis | Serena MCP |
| `perf-analyst` | 코드 레벨 안티패턴, 실측 | Chrome DevTools, Playwright |
| `regression-hunter` | git bisect, blame, 회귀 특정 | investigation-utils.sh |

### lib 헬퍼

`lib/investigation-utils.sh` — 서브커맨드 방식 bash 헬퍼:
- `git-suspects <file> [n]` — 최근 변경 커밋 추출
- `git-recent-changes [n]` — 최근 변경 파일 목록
- `bisect-test <good> <bad> <cmd>` — git bisect 자동화
- `report-init <file> <issue>` — 리포트 스켈레톤 생성

---

## MCP 통합

| MCP | 에이전트 | 역할 |
|-----|---------|------|
| Serena | code-analyst | find_symbol, find_referencing_symbols, search_for_pattern |
| Context7 | web-researcher | 라이브러리 실시간 문서 조회 |
| Sequential Thinking | Phase 2 오케스트레이터 | 7단계 추론으로 RCA |
| Memory | Phase 5 | 조사 결과 knowledge graph 저장 |
| Chrome DevTools | perf-analyst | Core Web Vitals, 네트워크 분석 |
| Playwright | perf-analyst | 재현 + 스크린샷 |

---

## 리서치 배경

설계 시 참조한 최신 기법:

- **SBFL (Spectrum-Based Fault Localization)** — Ochiai 알고리즘 근사
- **SemLoc (LLM-based FL)** — 42.8% top-1 정확도 (SBFL 6.4% 대비)
- **ReAct + Tree of Thought** — Sequential Thinking으로 구현
- **Meta AI-Assisted RCA** — 42% 정확도의 LLM 기반 RCA 시스템
- **Git bisect 자동화** — O(log n) 커밋 검사로 회귀 특정
- **Google OSS-Fuzz + AI** — LLM 기반 취약점 발견 접근 참조

---

## 트레이드오프

| 결정 | 이유 |
|------|------|
| debug 대체 (공존 아님) | 사용자가 기억할 커맨드를 줄임 |
| 항상 5개 에이전트 (적응형 아님) | 단순함 > 최적화, 대규모 토큰 의도된 설계 |
| Sequential Thinking Phase 2 | "빠른 답"보다 "올바른 답" 우선 |
| Memory MCP 학습 | 동일 패턴 반복 방지 |

---

## 변경 파일 목록

```
신규:
  src/woojoo-magic/skills/investigate/skill.md
  src/woojoo-magic/agents/web-researcher.md
  src/woojoo-magic/agents/code-analyst.md
  src/woojoo-magic/agents/perf-analyst.md
  src/woojoo-magic/agents/regression-hunter.md
  src/woojoo-magic/lib/investigation-utils.sh
  tests/lib/investigation-utils.bats

수정:
  src/woojoo-magic/skills/debug/skill.md  (thin redirect)
  src/woojoo-magic/.claude-plugin/plugin.json  (v4.3.0, 에이전트 9→13)
```
