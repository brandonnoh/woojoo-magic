---
name: release
description: 플러그인 버전업 + 마켓플레이스 배포. 트리거 - 배포, 릴리스, release, 버전업, 버전 올려, 마켓 배포, marketplace deploy, bump version, publish. CHANGELOG.md + marketplace.json 버전 업데이트 + 커밋 + 푸쉬 + 로컬 설치본 갱신(claude plugin update) + 5지점 교차 검증까지 한번에 처리.
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
아래 파일의 version을 모두 동일한 새 버전으로 교체:
- `.claude-plugin/marketplace.json` — `metadata.version` + 해당 `plugins[].version`
- `src/wj-magic/.claude-plugin/plugin.json` — `version`
  (srt-magic 릴리스라면 `src/srt-magic/.claude-plugin/plugin.json`)

수정 후 반드시 JSON 유효성을 확인한다 — 깨진 매니페스트를 배포하면
모든 새 세션에서 플러그인이 로드되지 않는다.

```bash
python3 -c "import json;[json.load(open(p)) for p in ['.claude-plugin/marketplace.json','src/wj-magic/.claude-plugin/plugin.json']];print('JSON OK')"
claude plugin validate src/wj-magic
```

### 5. description + 숫자 동기화 (필수 검증)
**매 릴리스마다 반드시 아래를 검사하고 불일치 시 수정:**

#### 5-1. 스킬/커맨드/에이전트 수 검증
```bash
# 실제 수 세기
ls src/wj-magic/commands/ | wc -l          # 커맨드 수
ls src/wj-magic/skills/ | wc -l            # 스킬 수
ls src/wj-magic/agents/*.md | wc -l        # 에이전트 수
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
아래 "푸시 인증" 절의 gh HTTPS 자격증명 방식을 쓴다 (평범한 `git push`는 막힌다).

### 8. 로컬 설치본 갱신 (공식 CLI)

push만으로는 이 컴퓨터에 **설치된** 플러그인이 갱신되지 않는다. 마켓 클론을
당긴 뒤 플러그인을 실제로 재설치해야 다음 세션이 새 버전을 쓴다.

```bash
claude plugin marketplace update wj-tools      # GitHub → 마켓 클론 갱신
claude plugin update wj-magic@wj-tools         # 설치본 재설치
# srt-magic 버전이 바뀐 릴리스라면:
claude plugin update srt-magic@wj-tools
```

> `git pull`로 마켓 클론만 당기는 것으로는 부족하다. 그건 마켓 메타데이터만
> 바꿀 뿐, `installed_plugins.json`이 가리키는 설치 경로는 옛 버전에 그대로
> 머문다. 반드시 `claude plugin update`까지 실행할 것.

### 9. 검증 (5지점 교차 확인)

아래 다섯 곳이 **전부 같은 버전·같은 커밋**이어야 릴리스 완료다.

```bash
gh api repos/brandonnoh/woojoo-magic/commits/main --jq '.sha[0:7]'   # ① 원격 HEAD
git log --oneline -1                                                 # ② 로컬 repo
git -C ~/.claude/plugins/marketplaces/wj-tools log --oneline -1      # ③ 마켓 클론
claude plugin list | grep -A2 wj-magic                               # ④ 설치본 버전
python3 -c "import json;d=json.load(open('$HOME/.claude/plugins/installed_plugins.json'));\
e=d['plugins']['wj-magic@wj-tools'][0];import os;\
print(e['version'], e['gitCommitSha'][:7], os.path.isdir(e['installPath']))"  # ⑤ 설치 경로 실재
```

신규 스킬을 추가한 릴리스라면 설치본에 자산이 실제로 들어갔는지도 확인한다:

```bash
ls ~/.claude/plugins/cache/wj-tools/wj-magic/<새 버전>/skills/
```

### 10. 구버전 캐시 정리 (⚠️ Step 8·9 성공 이후에만)

```bash
# 반드시 installed_plugins.json이 가리키는 "현재 설치 버전"만 보존한다.
# 새 버전을 임의로 지정하지 마라 — update가 실패했는데 구버전을 지우면
# installPath가 사라져 플러그인이 통째로 깨진다.
_keep="$(python3 -c "import json;print(json.load(open('$HOME/.claude/plugins/installed_plugins.json'))['plugins']['wj-magic@wj-tools'][0]['version'])")"
_cache_dir="$HOME/.claude/plugins/cache/wj-tools/wj-magic"
for _dir in "$_cache_dir"/*/; do
  [ "$(basename "$_dir")" = "$_keep" ] && continue
  rm -rf "$_dir"
done
```

플러그인 시스템에 자동 GC가 없어 버전업마다 구버전 캐시가 누적된다.
다만 **정리는 선택 사항이고, 갱신 검증이 우선**이다. Step 9가 통과하지
못했으면 이 단계를 절대 실행하지 마라.

> ⚠️ **지금 돌고 있는 세션이 쓰는 버전은 지우지 마라.** 세션은 시작 시점의
> 캐시 디렉터리(`CLAUDE_PLUGIN_ROOT`)를 계속 참조한다. 릴리스 직전에 켠
> 세션은 **구버전** 캐시에서 훅·스킬을 읽고 있으므로, 그 디렉터리를 지우면
> 진행 중인 세션의 훅이 통째로 깨진다.
>
> 안전한 순서: 모든 세션을 재시작해 새 버전으로 올라간 **다음** 릴리스에서
> 정리하거나, 세션을 다 닫은 상태에서 정리한다. 캐시 몇십 MB보다
> 돌고 있는 작업이 비싸다.

### 11. 사용자에게 재시작 안내 (필수)

`claude plugin update`는 `Restart to apply changes.`를 출력한다. 실제로:

| 대상 | 적용 |
|------|------|
| 이미 돌고 있는 세션 (이 세션 포함) | ❌ 옛 버전 유지 — 세션 시작 시점에 로드되기 때문 |
| 지금 이후 새로 시작하는 세션 | ✅ 새 버전 자동 적용 |

**"배포 끝났으니 바로 쓸 수 있다"고 말하지 마라.** 돌던 세션은 재시작이
필요하다는 점을 반드시 함께 알린다.

## 파일 위치

| 파일 | 역할 | 업데이트 항목 |
|------|------|-------------|
| `CHANGELOG.md` | 변경 이력 | 새 버전 섹션 추가 |
| `.claude-plugin/marketplace.json` | 원격 배포용 | `metadata.version`, `plugins[].version`, `plugins[].description` |
| `src/wj-magic/.claude-plugin/plugin.json` | Claude Code UI용 | `version`, `description`, `keywords` |
| `src/wj-magic/commands/help.md` | 사용자 가이드 | 커맨드/스킬 테이블, 에이전트 수 |
| `src/wj-magic/references/INDEX.md` | 레퍼런스 라우터 | 신규 레퍼런스 등록 |
| `CLAUDE.md` | 저장소 안내 | 구조 섹션의 스킬·에이전트 수 |

## 설치 상태 파일 (수동 편집 금지)

| 파일 | 역할 |
|------|------|
| `~/.claude/plugins/known_marketplaces.json` | 마켓 소스(`brandonnoh/woojoo-magic`)·클론 경로 |
| `~/.claude/plugins/marketplaces/wj-tools/` | 마켓 git 클론 |
| `~/.claude/plugins/installed_plugins.json` | 설치 버전·커밋 SHA·installPath |
| `~/.claude/plugins/cache/wj-tools/<plugin>/<version>/` | 실제 로드되는 플러그인 본체 |

이 파일들은 `claude plugin` CLI가 관리한다. 직접 고치면 설치 상태가 깨진다.

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
- **push = 배포 아님.** `claude plugin update`까지 해야 이 컴퓨터에 반영된다
- **update = 즉시 적용 아님.** 돌던 세션은 재시작해야 한다
- 캐시 정리는 갱신 검증 **이후**에만. 검증 실패 상태에서 지우면 플러그인이 깨진다

## 푸시 인증

SSH 키가 다른 계정이라 `git push`가 막힌다. gh HTTPS 자격증명을 쓴다:

```bash
GH_TOKEN="$(gh auth token)" git -c credential.helper='!f(){ echo username=x-access-token; echo password=$GH_TOKEN; };f' push origin main
```

---

## ⚡ 즉시 실행

**대기하지 마라. 이 프롬프트를 받는 즉시 아래 순서대로 실행하라:**

1. `git log --oneline` + `git diff --stat` → 변경 내역 수집
2. 시맨틱 버전 결정 → CHANGELOG.md 업데이트
3. 버전 동시 업데이트 (marketplace.json × 2, plugin.json × 1) → JSON 유효성 + `claude plugin validate`
4. **description + 숫자 동기화 검증** (커맨드 수, 스킬 수, 에이전트 수, help.md 테이블)
5. 불일치 있으면 수정 → 테스트 (`bats tests/skills/ tests/hooks/ tests/lib/ tests/commands/`)
6. 커밋 → 푸쉬
7. **`claude plugin marketplace update wj-tools` → `claude plugin update wj-magic@wj-tools`**
8. **5지점 교차 검증** (원격 HEAD / 로컬 repo / 마켓 클론 / 설치본 버전 / installPath 실재)
9. 검증 통과 시에만 구버전 캐시 정리
10. 사용자에게 **재시작 필요**를 명시해 보고

**Step 4~5를 건너뛰고 커밋하는 것은 릴리스 미완료다.**
**Step 7~8을 건너뛰면 "배포했다"고 말할 수 없다 — 로컬은 여전히 옛 버전이다.**
