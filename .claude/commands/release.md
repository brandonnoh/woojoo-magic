---
name: release
description: 플러그인 버전업 + 마켓플레이스 배포. 트리거 - 배포, 릴리스, release, 버전업, 버전 올려, 마켓 배포, marketplace deploy, bump version, publish. CHANGELOG.md + marketplace.json 버전 업데이트 + 커밋 + 푸쉬를 한번에 처리.
---

# 릴리스 워크플로우

## 절차

### 1. 변경 내역 수집
- `git log --oneline` 최근 커밋 + `git diff` 확인
- 커밋 안 된 변경이 있으면 먼저 커밋 또는 사용자에게 확인

### 2. 시맨틱 버전 결정
사용자가 명시하지 않으면 변경 내용으로 추론:
- `MAJOR` — breaking change (API 변경, 호환성 깨짐)
- `MINOR` — 신규 기능 (feat), 새 스킬/커맨드 추가
- `PATCH` — 버그 수정 (fix), 문서 수정, 하우스키핑 (chore)

### 3. CHANGELOG.md 업데이트
새 버전 섹션을 기존 최상단 버전 바로 위에 추가.

### 4. 버전 3곳 동시 업데이트
아래 세 파일의 version을 모두 동일한 새 버전으로 교체:
- `.claude-plugin/marketplace.json` — `metadata.version` + 모든 `plugins[].version`
- `plugins/woojoo-magic/.claude-plugin/plugin.json` — `version`

### 5. description + 숫자 동기화 (필수 검증)
**매 릴리스마다 반드시 아래를 검사하고 불일치 시 수정:**

#### 5-1. 스킬/커맨드/에이전트 수 검증
```bash
# 실제 수 세기
ls plugins/woojoo-magic/commands/ | wc -l        # 커맨드 수
ls plugins/woojoo-magic/skills/ | wc -l           # 스킬 수
ls plugins/woojoo-magic/agents/ | wc -l           # 에이전트 수
```
- `marketplace.json`의 `plugins[].description` 내 숫자와 대조
- `plugin.json`의 `description` 내 숫자와 대조
- `commands/help.md`의 커맨드 테이블 행 수, "Skills (N개)", "Agents (N개)" 대조
- **불일치 시 전부 동일하게 수정**

#### 5-2. description 내용 동기화
- `marketplace.json`의 `plugins[].description`과 `plugin.json`의 `description`이 **동일한 내용**인지 확인
- 신규 기능이 추가됐으면 description에 반영 (예: "smoke test" 추가됐으면 description에 포함)

#### 5-3. help.md 커맨드 테이블 검증
- `commands/` 디렉토리의 실제 파일과 `help.md` 커맨드 테이블이 1:1 매칭인지
- 빠진 커맨드 있으면 추가
- 삭제된 커맨드 있으면 제거

### 6. 커밋
`chore: marketplace.json + CHANGELOG vX.Y.Z 반영` 포맷

### 7. 푸쉬
`git push origin <current-branch>`

### 8. 설치된 클론 동기화
```bash
cd ~/.claude/plugins/marketplaces/wj-tools && git pull origin main
```
소스 repo push만으로는 설치된 플러그인 클론이 자동 갱신되지 않음. **이 단계를 빠뜨리면 Claude Code UI에 옛 버전이 표시됨.**

### 9. 구버전 캐시 정리
```bash
# wj-magic: 새 버전만 남기고 구버전 삭제
_cache_dir="$HOME/.claude/plugins/cache/wj-tools/wj-magic"
_new_ver="<새 버전>"  # Step 2에서 결정한 버전
for _dir in "$_cache_dir"/*/; do
  [ "$(basename "$_dir")" = "$_new_ver" ] && continue
  rm -rf "$_dir"
done

# srt-magic도 동일 처리 (버전 변경 시)
_srt_cache="$HOME/.claude/plugins/cache/wj-tools/srt-magic"
_srt_ver="$(python3 -c "import json; print(json.load(open('.claude-plugin/marketplace.json'))['plugins'][1]['version'])")"
for _dir in "$_srt_cache"/*/; do
  [ "$(basename "$_dir")" = "$_srt_ver" ] && continue
  rm -rf "$_dir"
done
```
플러그인 시스템에 자동 GC가 없어서, 버전업마다 구버전 캐시가 누적됨. **릴리스 시 반드시 실행.**

## 파일 위치

| 파일 | 역할 | 업데이트 항목 |
|------|------|-------------|
| `CHANGELOG.md` | 변경 이력 | 새 버전 섹션 추가 |
| `.claude-plugin/marketplace.json` | 원격 배포용 | `metadata.version`, `plugins[].version`, `plugins[].description` |
| `plugins/woojoo-magic/.claude-plugin/plugin.json` | Claude Code UI용 | `version`, `description` |
| `plugins/woojoo-magic/commands/help.md` | 사용자 가이드 | 커맨드 테이블, Skills 수, Agents 수 |

## CHANGELOG 포맷

```markdown
## X.Y.Z — YYYY-MM-DD

### Fixed / Added / Changed
- **제목**: 설명
```

## 주의사항

- 버전 번호는 반드시 세 자리 (X.Y.Z)
- marketplace.json 내 버전이 2곳 이상이면 전부 동일하게 맞출 것
- **Step 5를 절대 건너뛰지 마라** — description/숫자 불일치가 누적되면 사용자 혼동 유발

---

## ⚡ 즉시 실행

**대기하지 마라. 이 프롬프트를 받는 즉시 아래 순서대로 실행하라:**

1. `git log --oneline` + `git diff --stat` → 변경 내역 수집
2. 시맨틱 버전 결정 → CHANGELOG.md 업데이트
3. 버전 3곳 동시 업데이트 (marketplace.json × 2, plugin.json × 1)
4. **description + 숫자 동기화 검증** (커맨드 수, 스킬 수, 에이전트 수, help.md 테이블)
5. 불일치 있으면 수정
6. 커밋 → 푸쉬 → 클론 동기화 → 구버전 캐시 정리

**Step 4~5를 건너뛰고 커밋하는 것은 릴리스 미완료다.**
