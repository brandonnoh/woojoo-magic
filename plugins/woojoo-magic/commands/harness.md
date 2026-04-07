---
description: woojoo-magic 하네스 건강 상태 진단
---

현재 프로젝트에 적용된 woojoo-magic 하네스(스킬/에이전트/MCP/Ralph)의 건강 상태를 진단한다.

점검 항목:

1. **스킬 로드 상태**
   - 플러그인 `skills/` 디렉터리 존재 여부
   - 각 스킬 `SKILL.md` 프론트매터 유효성
   - 미로드/손상 스킬 목록

2. **에이전트 정의 검증**
   - `agents/*.md` 프론트매터에 `name`, `model`, `description` 존재
   - `name` 중복 없음
   - 설명이 투입 조건을 명시하는지

3. **MCP 연결 상태**
   - 프로젝트 `.mcp.json` / 전역 `~/.claude.json` 에서 플러그인 MCP 10종 확인
   - 누락된 MCP 목록 + 설치 안내 (`install-mcp.sh` 재실행)

4. **tests.json 정합성**
   - `tests.json` 존재 시 JSON 유효성
   - 각 task가 `id`, `status`, `acceptance_criteria` 보유하는지
   - 중복 id 없음
   - 완료 비율

5. **Ralph 루프 설정**
   - `prd.md`, `progress.md` 존재 여부
   - `.ralph-state/` 디렉터리 여부
   - 필수 템플릿 동기화 상태

출력:

```
## woojoo-magic 하네스 진단

### 요약
- 스킬: OK / 이슈 N개
- 에이전트: OK / 이슈 N개
- MCP: OK / 누락 N개
- tests.json: OK / 이슈 N개
- Ralph: OK / 미설치

### 권장 조치
- ...
```

---

## ⚡ 즉시 실행

**대기하지 마라. 이 프롬프트를 받는 즉시 위 절차대로 실행하라.**
