---
description: wj-studybook 커맨드 안내 — 처음 시작하는 분도 OK
---

아래 가이드를 **그대로 전부 출력**하세요. 요약하거나 생략하지 마세요.

# 📚 wj-studybook 사용 가이드

> **이 플러그인이 뭔가요?**
> Claude와 평소처럼 대화만 하면, 배운 내용이 자동으로 저장됩니다.
> 세션이 끝나면 백그라운드에서 **토픽별 쪽 페이지**로 자동 편집·발간됩니다.
> 필요 시 `/wj-studybook:digest` 로 즉시 실행할 수도 있어요.

---

## 🚀 처음 시작하는 2단계

```
1단계 — 내 정보 입력 (최초 1회)
  /wj-studybook:init          ← 단축키
  (또는 /wj-studybook:config init)

2단계 — 대화만 하세요
  세션이 끝나면 쌓인 inbox 노트가
  토픽별 쪽 페이지로 자동 발간됩니다.
  (필요하면 /wj-studybook:digest 로 즉시 실행)
```

> 나머지는 자동입니다. Claude가 답변할 때마다 몰래 inbox에 저장해두고,
> 세션 종료 시점에 백그라운드에서 분류·편집·발간까지 처리해요.

---

## ⚙️ 설정 — `/wj-studybook:config`

내 학습자 프로필(나이, 수준, 관심사 등)을 관리합니다.

| 커맨드 | 하는 일 |
|--------|--------|
| `/wj-studybook:config init` | **처음 설정 마법사** — 이름·나이·수준·언어 입력 |
| `/wj-studybook:config` | 현재 설정 내용 확인 |
| `/wj-studybook:config profile list` | 저장된 프로필 목록 보기 |
| `/wj-studybook:config profile use <이름>` | 다른 프로필로 전환 |
| `/wj-studybook:config profile new` | 새 프로필 추가 (가족 구성원 등) |
| `/wj-studybook:config profile delete <이름>` | 프로필 삭제 |
| `/wj-studybook:config profile delete <이름> --purge` | 프로필 + 책 폴더까지 전부 삭제 |
| `/wj-studybook:config set <항목> <값>` | 설정 값 하나만 바꾸기 (예: `learner.level advanced`) |
| `/wj-studybook:config edit` | 에디터로 직접 편집 |

---

## 📥 과거 대화 불러오기 — `/wj-studybook:backfill`

플러그인 설치 전에 했던 Claude 대화도 소급해서 가져올 수 있어요.

| 커맨드 | 하는 일 |
|--------|--------|
| `/wj-studybook:backfill --since 2026-01-01` | 해당 날짜 이후 세션 전부 가져오기 |
| `/wj-studybook:backfill --since 2026-01-01 --project <폴더명>` | 특정 프로젝트 세션만 |
| `/wj-studybook:backfill --all` | 모든 과거 세션 전부 가져오기 |

---

## 🗂️ 노트 분류 — `/wj-studybook:digest`

inbox에 쌓인 노트를 Claude가 주제별 폴더로 자동 분류해줍니다.

| 커맨드 | 하는 일 |
|--------|--------|
| `/wj-studybook:digest` | **자동 파이프라인** — 라우팅 → 토픽별 병렬 편집 → 쪽 페이지 발간 |
| `/wj-studybook:digest auto` | 위와 동일 (명시적) |
| `/wj-studybook:digest prepare` | 분류할 노트 목록만 미리 보기 (디버깅) |
| `/wj-studybook:digest apply <파일>` | 직접 만든 분류 JSON 적용 (고급) |
| `/wj-studybook:digest bucket <cat>/<sub>/<topic>` | 특정 토픽 버킷만 prepare (고급) |

> 세션이 끝날 때 백그라운드에서 자동 실행됩니다. 수동 실행은 즉시 처리가 필요할 때만.

---

## 🔍 유사 노트 찾기 — `/wj-studybook:similar`

"이거 전에 배운 것 같은데?" 싶을 때 사용하세요.

| 커맨드 | 하는 일 |
|--------|--------|
| `/wj-studybook:similar <검색어>` | **그냥 이것만** — 의미적으로 비슷한 노트 Top 5 |
| `/wj-studybook:similar keyword <검색어>` | 키워드 일치 노트만 빠르게 검색 |
| `/wj-studybook:similar prepare <검색어>` | Claude 분석용 컨텍스트 출력 (고급) |
| `/wj-studybook:similar format <파일>` | 분석 결과 JSON을 보기 좋게 출력 (고급) |

---

## 🔀 중복 폴더 정리 — `/wj-studybook:merge`

"react"와 "리액트" 같은 중복 폴더를 합쳐줍니다.

| 커맨드 | 하는 일 |
|--------|--------|
| `/wj-studybook:merge` | **그냥 이것만** — 중복 의심 폴더 Claude가 자동 탐지 후 제안 |
| `/wj-studybook:merge --auto-detect` | 위와 동일 |
| `/wj-studybook:merge <from폴더> <to폴더>` | 직접 지정해서 병합 (확인 후 실행) |
| `/wj-studybook:merge <from폴더> <to폴더> --yes` | 확인 없이 바로 병합 |

---

## 🌳 분류 트리 보기 — `/wj-studybook:tree`

지금까지 쌓인 노트가 어떤 주제로 분류됐는지 한눈에 볼 수 있어요.

| 커맨드 | 하는 일 |
|--------|--------|
| `/wj-studybook:tree` | 기본 트리 보기 (깊이 3단계) |
| `/wj-studybook:tree --depth 2` | 더 넓게 보기 (2단계까지만) |
| `/wj-studybook:tree --depth 5` | 더 깊게 보기 |
| `/wj-studybook:tree --json` | JSON 형태로 출력 (고급) |

---

## ☁️ 동기화 — `/wj-studybook:sync`

책 파일을 iCloud나 Obsidian에서도 볼 수 있게 연결해줍니다.
(파일을 외부 서버로 보내는 게 아니라, 내 기기 안에서 폴더를 연결하는 것입니다.)

| 커맨드 | 하는 일 |
|--------|--------|
| `/wj-studybook:sync status` | 현재 연결 상태 확인 |
| `/wj-studybook:sync --target icloud` | iCloud Drive에 연결 (iPhone에서 읽기 가능) |
| `/wj-studybook:sync --target obsidian --vault <경로>` | Obsidian vault에 연결 |
| `/wj-studybook:sync --target git` | git 저장소로 관리 |
| `/wj-studybook:sync --target none` | 연결 해제, 로컬 경로만 출력 |
| `/wj-studybook:sync` | 프로필에 설정된 방식으로 실행 |

---

## ⏸ 일시정지 / 재개

자동 수집을 잠깐 끄고 싶을 때 사용하세요.

| 커맨드 | 하는 일 |
|--------|--------|
| `/wj-studybook:pause` | 자동 수집 일시정지 (Stop/SessionEnd hook 비활성화) |
| `/wj-studybook:resume` | 자동 수집 재개 |

> 일시정지 중에는 세션 시작 시 `⏸ 일시정지 중` 알림이 뜹니다.

---

## 🔁 전체 흐름도

```
Claude 답변
  │
  ▼
[0차] 슬래시 커맨드? ──YES──▶ 버림 (플러그인 실행 응답)
  │ NO
  ▼
[1차] 휴리스틱 필터
  ├─ 200자 미만?          ──▶ 버림
  ├─ 액션 발화?           ──▶ 버림 ("파일을 읽겠습니다" 등)
  ├─ 테이블 덤프?         ──▶ 버림 (50%+ 라인이 | 포함)
  └─ 학습 키워드 2개 미만 AND 코드 페어 없음? ──▶ 버림
  │ 통과
  ▼
inbox 저장 (~/.studybook/inbox/)
  │
  ▼ (세션 종료 시 SessionEnd hook이 자동 트리거 — 백그라운드)
/wj-studybook:digest auto
  │
  ├─ 1단계: 토픽 라우팅 (경량)
  ├─ 2단계: 토픽별 버킷팅
  ├─ 3단계: 버킷마다 서브에이전트 병렬 투입 (max 4)
  │         - 대화 기록 → 지식 교훈 쪽 페이지로 재작성
  └─ 4단계: apply — topics/<cat>/<sub>/<topic>/*.md 저장
  │
  ▼
토픽 폴더 = 쪽 페이지 발간물
_index.md = 토픽 목차 (자동 갱신)
```

---

## 🧮 휴리스틱 필터 기준

| 조건 | 기준 | 이유 |
|------|------|------|
| 최소 길이 | 200자 이상 | 짧은 확인/동의 응답 제거 |
| 슬래시 커맨드 | user가 `/`로 시작 → 버림 | 플러그인 커맨드 실행 결과 |
| 액션 발화 | "파일을 읽겠습니다" 등 → 버림 | 도구 호출 중계 응답 |
| 테이블 덤프 | 전체 라인의 50%+ 가 `\|` 포함 → 버림 | help 가이드·커맨드 레퍼런스 |
| 학습 키워드 | 2개 이상 OR 코드+설명 페어 | 우연 매칭 방지 |

학습 키워드 예시: `패턴`, `구조`, `원리`, `왜`, `설계`, `버그`, `해결`, `because`, `pattern`, `trade-off` 등

> 필터를 통과한 것만 inbox에 저장되고, 이후 `/wj-studybook:digest`에서 Claude가 재분류합니다.

---

## 🤖 자동으로 실행되는 것들

따로 실행하지 않아도 백그라운드에서 알아서 동작합니다.

| 언제 | 무슨 일이 |
|------|---------|
| Claude가 답변할 때마다 | 학습 내용을 inbox에 몰래 저장 |
| 대화 세션이 끝날 때 | 빠진 내용 보완 + **백그라운드 자동 digest 실행** (inbox → 토픽 쪽 페이지) |
| **처음 설치 후 세션 시작** | 프로필 없으면 설정 안내 자동 출력 |
