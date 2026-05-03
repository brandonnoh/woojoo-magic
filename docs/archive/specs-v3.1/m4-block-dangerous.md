# m4-block-dangerous: block-dangerous.sh 정규식 우회 방지 강화

> 우선순위: MEDIUM  
> 예상 작업량: ~30줄 추가/수정  
> 의존성: 없음 (독립 작업)

## 1. 현황 분석

`hooks/block-dangerous.sh`는 위험한 Bash 명령을 차단하는 PreToolUse 훅이다.
현재 정규식이 일부 우회 패턴을 놓치고 있다.

## 2. rm -rf 우회 가능 패턴

### 2.1 현재 패턴 (27줄)

```bash
if [[ "${CMD}" =~ rm[[:space:]]+-rf?[[:space:]]+/ ]] || [[ "${CMD}" =~ rm[[:space:]]+-rf?[[:space:]]+~/?([[:space:]]|$) ]]; then
```

이 정규식은 `rm -rf /` 또는 `rm -r /`만 잡는다.

### 2.2 우회 가능한 변형들

| 변형 | 차단 여부 | 이유 |
|------|-----------|------|
| `rm -rf /` | O | `-rf` 패턴 매칭 |
| `rm -r /` | O | `-rf?` 에서 `f`가 optional |
| `rm -r -f /` | **X** | `-rf?` 는 `-r -f`를 못 잡음 |
| `rm -f -r /` | **X** | `-rf?`는 `-f -r` 순서를 못 잡음 |
| `rm --recursive --force /` | **X** | 긴 옵션 미지원 |
| `rm --recursive /` | **X** | `--recursive`만으로도 디렉토리 삭제 가능 |
| `rm -fr /` | **X** | `-fr`은 `-rf`와 다른 순서 |
| `rm -rfi /` | **X** | `-rfi`는 `-rf`의 superset |
| `rm -Rf /` | **X** | `-R`은 `-r`과 동의어 (대문자) |
| `rm -Rf ~/` | **X** | 위와 동일, 홈 경로 |
| `rm    -rf   /` | **X** | 다중 공백 (현재 `+` 사용해서 O 일 수 있으나 경계 조건) |

### 2.3 수정된 rm 패턴

**Before (27줄):**
```bash
if [[ "${CMD}" =~ rm[[:space:]]+-rf?[[:space:]]+/ ]] || [[ "${CMD}" =~ rm[[:space:]]+-rf?[[:space:]]+~/?([[:space:]]|$) ]]; then
  deny "rm -rf 루트/홈 경로 금지"
fi
```

**After:**
```bash
# rm 재귀 삭제 — 루트/홈 경로 대상
# 커버 범위: rm -rf, rm -r -f, rm -fr, rm -Rf, rm --recursive, rm --force --recursive 등
if echo "${CMD}" | grep -qE 'rm\s+(-[a-zA-Z]*[rR][a-zA-Z]*\s+|--recursive\s+).*(\s|^)\/' ||
   echo "${CMD}" | grep -qE 'rm\s+(-[a-zA-Z]*[rR][a-zA-Z]*\s+|--recursive\s+).*(\s|^)~\/' ||
   echo "${CMD}" | grep -qE 'rm\s+(-[a-zA-Z]*\s+)*-[a-zA-Z]*[rR][a-zA-Z]*\s+(\s|^)\/' ||
   echo "${CMD}" | grep -qE 'rm\s+(-[a-zA-Z]*\s+)*-[a-zA-Z]*[rR][a-zA-Z]*\s+(\s|^)~/'; then
  deny "rm 재귀 삭제 — 루트/홈 경로 금지"
fi
```

위 방식은 너무 복잡하므로, **단순화된 2단계 검사**를 권장한다:

**권장 구현:**
```bash
# rm 재귀 삭제 — 루트/홈 경로 대상
# Step 1: rm 명령이 재귀 옵션을 포함하는지 확인
_rm_recursive=false
if [[ "${CMD}" =~ rm[[:space:]] ]]; then
  # -r, -R, --recursive (단독 또는 결합 플래그 -rf, -fr, -Rf, -rfi 등)
  if [[ "${CMD}" =~ rm[[:space:]]+(-[a-zA-Z]*[rR]|--recursive) ]]; then
    _rm_recursive=true
  elif [[ "${CMD}" =~ rm[[:space:]]+[^|;]*(-[a-zA-Z]*[rR]|--recursive) ]]; then
    _rm_recursive=true
  fi
fi

# Step 2: 재귀 rm이 루트(/) 또는 홈(~/) 경로를 대상으로 하는지 확인
if [[ "$_rm_recursive" == "true" ]]; then
  if [[ "${CMD}" =~ [[:space:]]/([[:space:]]|$) ]] || [[ "${CMD}" =~ [[:space:]]~/?([[:space:]]|$) ]]; then
    deny "rm 재귀 삭제 — 루트/홈 경로 금지"
  fi
fi
```

### 2.4 새 패턴 검증 매트릭스

| 명령 | `_rm_recursive` | 경로 매칭 | 결과 |
|------|-----------------|-----------|------|
| `rm -rf /` | true (`-rf` 에 `r`) | `/` 매칭 | **차단** |
| `rm -r -f /` | true (`-r` 에 `r`) | `/` 매칭 | **차단** |
| `rm -f -r /` | true (`-r` 에 `r`) | `/` 매칭 | **차단** |
| `rm --recursive --force /` | true (`--recursive`) | `/` 매칭 | **차단** |
| `rm --recursive /` | true (`--recursive`) | `/` 매칭 | **차단** |
| `rm -fr /` | true (`-fr` 에 `r`) | `/` 매칭 | **차단** |
| `rm -Rf /` | true (`-Rf` 에 `R`) | `/` 매칭 | **차단** |
| `rm -rfi /` | true (`-rfi` 에 `r`) | `/` 매칭 | **차단** |
| `rm -rf ~/` | true | `~/` 매칭 | **차단** |
| `rm -rf /tmp/build` | true | `/tmp/build`은 `/`+공백 아님 | **허용** (정상) |
| `rm file.txt` | false | - | **허용** (정상) |
| `rm -f file.txt` | false (`-f`에 `r`/`R` 없음) | - | **허용** (정상) |

## 3. git push --force 우회 가능 패턴

### 3.1 현재 패턴 (42-46줄)

```bash
if [[ "${CMD}" =~ git[[:space:]]+push.*(--force|[[:space:]]-f[[:space:]]) ]]; then
  if [[ "${CMD}" =~ (main|master) ]]; then
    deny "main/master 강제 푸시 금지"
  fi
fi
```

### 3.2 우회 가능한 변형들

| 변형 | 차단 여부 | 이유 |
|------|-----------|------|
| `git push --force origin main` | O | `--force` + `main` 매칭 |
| `git push -f origin main` | O | `-f` + `main` 매칭 |
| `git push --force-with-lease origin main` | **X** | `--force-with-lease`는 `--force`에 매칭되지만 의도적 허용일 수 있음 |
| `git push origin main -f` | **X** | `-f`가 뒤에 오면 `[[:space:]]-f[[:space:]]`가 매칭 안 됨 (`-f` 뒤에 공백 없이 줄 끝) |
| `git push origin main --force` | O | `--force` 매칭 |
| `git push -f origin main` (줄 끝) | **X** | `-f[[:space:]]` 패턴은 `-f` 뒤에 공백 필요 |

### 3.3 수정

**Before (42-46줄):**
```bash
if [[ "${CMD}" =~ git[[:space:]]+push.*(--force|[[:space:]]-f[[:space:]]) ]]; then
  if [[ "${CMD}" =~ (main|master) ]]; then
    deny "main/master 강제 푸시 금지"
  fi
fi
```

**After:**
```bash
# git push --force / -f (--force-with-lease는 안전하므로 허용)
if [[ "${CMD}" =~ git[[:space:]]+push ]]; then
  _is_force=false
  if [[ "${CMD}" =~ --force($|[[:space:]]) ]] && [[ ! "${CMD}" =~ --force-with-lease ]]; then
    _is_force=true
  elif [[ "${CMD}" =~ [[:space:]]-f($|[[:space:]]) ]] || [[ "${CMD}" =~ [[:space:]]-[a-zA-Z]*f ]]; then
    _is_force=true
  fi
  if [[ "$_is_force" == "true" ]] && [[ "${CMD}" =~ (main|master) ]]; then
    deny "main/master 강제 푸시 금지"
  fi
fi
```

### 3.4 검증 매트릭스

| 명령 | `_is_force` | `main/master` | 결과 |
|------|-------------|---------------|------|
| `git push --force origin main` | true | main | **차단** |
| `git push -f origin main` | true | main | **차단** |
| `git push origin main -f` | true (`-f$` 매칭) | main | **차단** |
| `git push origin main --force` | true | main | **차단** |
| `git push --force-with-lease origin main` | false (제외) | - | **허용** (안전) |
| `git push origin feature/test --force` | true | feature (no) | **허용** (정상) |
| `git push origin main` | false | - | **허용** (정상) |

## 4. 추가 강화: dd 명령 차단

`dd`는 디스크를 직접 덮어쓸 수 있는 위험 명령이다. 현재 차단되지 않음.

**추가 위치: 50줄 (chmod 777 체크) 뒤**

```bash
# dd if=/dev/* of=/dev/* (디스크 직접 쓰기)
if [[ "${CMD}" =~ (^|[[:space:]])dd[[:space:]] ]] && [[ "${CMD}" =~ of=/dev/ ]]; then
  deny "dd 디바이스 직접 쓰기 금지"
fi
```

## 5. 추가 강화: mkfs 명령 차단

```bash
# mkfs (파일시스템 포맷)
if [[ "${CMD}" =~ (^|[[:space:]])mkfs ]]; then
  deny "mkfs (파일시스템 포맷) 금지"
fi
```

## 6. 추가 강화: :(){ :|:& };: (fork bomb) 차단

```bash
# fork bomb 패턴
if [[ "${CMD}" =~ :\(\)\{.*\|.*\& ]]; then
  deny "fork bomb 금지"
fi
```

## 7. 최종 block-dangerous.sh 변경 요약

**수정할 줄:**
- 27-29줄: rm 패턴 전면 교체 (단순 1줄 → 2단계 검사 ~12줄)
- 42-46줄: git push 패턴 교체 (~5줄 → ~9줄)

**추가할 블록 (50줄 뒤):**
- dd 차단 (~3줄)
- mkfs 차단 (~3줄)
- fork bomb 차단 (~3줄)

## 8. 테스트 계획

각 우회 패턴을 직접 테스트하는 bats 파일 작성:

```bash
# tests/block-dangerous.bats (신규)
@test "rm -r -f / 차단" {
  echo '{"tool_input":{"command":"rm -r -f /"}}' | bash "$HOOK" 2>/dev/null
  [ "$?" -eq 2 ]
}

@test "rm --recursive --force / 차단" {
  echo '{"tool_input":{"command":"rm --recursive --force /"}}' | bash "$HOOK" 2>/dev/null
  [ "$?" -eq 2 ]
}

@test "rm -fr / 차단" {
  echo '{"tool_input":{"command":"rm -fr /"}}' | bash "$HOOK" 2>/dev/null
  [ "$?" -eq 2 ]
}

@test "rm -Rf / 차단" {
  echo '{"tool_input":{"command":"rm -Rf /"}}' | bash "$HOOK" 2>/dev/null
  [ "$?" -eq 2 ]
}

@test "rm -rf /tmp/build 허용" {
  echo '{"tool_input":{"command":"rm -rf /tmp/build"}}' | bash "$HOOK" 2>/dev/null
  [ "$?" -eq 0 ]
}

@test "git push origin main -f 차단" {
  echo '{"tool_input":{"command":"git push origin main -f"}}' | bash "$HOOK" 2>/dev/null
  [ "$?" -eq 2 ]
}

@test "git push --force-with-lease origin main 허용" {
  echo '{"tool_input":{"command":"git push --force-with-lease origin main"}}' | bash "$HOOK" 2>/dev/null
  [ "$?" -eq 0 ]
}
```

## 9. 파일 변경 요약

| 파일 | 동작 |
|------|------|
| `src/wj-magic/hooks/block-dangerous.sh` | rm 패턴 교체 (27-29줄) + git push 패턴 교체 (42-46줄) + dd/mkfs/forkbomb 추가 |
| `tests/block-dangerous.bats` | **신규 생성** — 우회 패턴 테스트 |
