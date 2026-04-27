---
name: srt-macro
description: 매진된 SRT 좌석을 안전한 폴링 간격으로 감시하다가 자리가 나면 자동 예약하는 스킬. 계정 잠김 방지 다층 안전 가드(세션 재사용·지터·백오프·시도 캡·lockfile) + 다중 노선(왕복) 동시 감시 + 텔레그램 푸시·헬스체크·원격 종료 명령 내장. "SRT 매진 잡아줘", "SRT 자리 나면 예약해줘", "SRT 매크로 돌려줘", "SRT 빈자리 감시", "SRT 왕복 매크로" 요청에 트리거. SRT 좌석 예매·매진 감시·취소표 잡기 관련 모든 요청에 반드시 이 스킬을 사용하라.
license: MIT
metadata:
  category: travel
  locale: ko-KR
  os: macOS
---

# SRT 매크로

## What this skill does

매진된 SRT 좌석을 사람과 비슷한 간격으로 폴링하다가 자리가 나면 즉시 1좌석을 예약하고 macOS 알림 + 텔레그램 푸시를 보낸다. 결제는 자동화하지 않는다 (계정 안전 + SRT 정책).

## When to use

- "수서→부산 4/30 18시 SRT 매진인데 자리 나면 잡아줘"
- "SRT 빈자리 감시해줘"
- "왕복 표 둘 다 매진인데 둘 다 잡아줘"
- "SRT 매크로 돌려줘"

## When NOT to use

- 결제까지 자동화 (의도적으로 미지원)
- KTX/Korail (SRT 전용)
- 비밀번호를 채팅창에 받아오기
- 윈도우/리눅스 환경 (현재 macOS 전용 — Keychain·osascript·afplay·SIGALRM 의존)

## 계정 잠김 방지 안전 가드

| 레이어 | 정책 |
|---|---|
| 세션 재사용 | 시작 시 1회 로그인, 폴링은 `search_train`만 반복 |
| 폴링 간격 지터 | 골든타임(7-10/18-21시) 30~60초, 평시 60~120초, 야간(0-6시) 5~10분 |
| 시도 캡 | 200회 또는 4시간 (둘 중 빠른 것) → 자동 종료 |
| 로그인 실패 처리 | 즉시 종료. 재시도 절대 안 함 (3회면 SRT 계정 잠김) |
| 에러 백오프 | 2분 → 5분 → 15분 지수 증가, 3회 연속 실패 시 종료 |
| 단일 인스턴스 | `~/.srt-macro.lock`으로 중복 실행 차단 |
| 예약 후 즉시 종료 | 1좌석 잡히면 폴링 중단 |
| 결제 자동화 | 안 함 — 10분 내 사용자가 SRT 앱에서 직접 |

## 처음 사용 시 (사용자별 1회 셋업)

**한 줄로 끝나는 대화형 셋업 스크립트**가 있다. 처음 사용자에게는 반드시 이걸 안내하라:

```bash
python3 ~/.claude/plugins/marketplaces/wj-tools/src/srt-magic/skills/srt-macro/scripts/setup.py
```

이 스크립트가 자동으로 처리하는 것:

1. **venv 자동 생성** (`~/.config/srt-macro/.venv/`, ~30초 1회)
2. **SRT ID/비밀번호** 대화형 입력 (비밀번호 화면에 안 보임, 재입력 확인)
3. **텔레그램 봇 토큰** 입력 (선택, 빈 엔터로 스킵)
4. **`.env` 파일 작성** (`~/.config/srt-macro/.env`, chmod 0600 자동)
5. **다음 단계 안내** (텔레그램 chat_id 등록 + 첫 dry-run 명령)

기존 `.env`가 있으면 덮어쓰기 전 확인하고 `.env.backup`으로 자동 백업한다.

### 자격증명을 직접 편집하고 싶으면

`.env` 파일을 에디터로 열어서 수정:
```bash
nano ~/.config/srt-macro/.env
chmod 600 ~/.config/srt-macro/.env  # 권한 재확인
```

## 설정 파일 (.env)

`~/.config/srt-macro/.env` (chmod 0600).

자격증명 로드 우선순위:
1. **환경변수** (`KSKILL_SRT_ID`, `KSKILL_SRT_PASSWORD`) — CI/일회성 override
2. **`.env` 파일** — 평상시 사용
3. **macOS Keychain** — fallback (백업)

`.env` 항목:
```ini
KSKILL_SRT_ID=...
KSKILL_SRT_PASSWORD=...
SRT_MACRO_MAX_ATTEMPTS=200
SRT_MACRO_MAX_DURATION_SEC=14400
SRT_MACRO_SEARCH_TIMEOUT_SEC=30
SRT_MACRO_HEALTHCHECK_MIN=30
SRT_MACRO_NOTIFY_SOUND=Glass
SRT_MACRO_TELEGRAM_TOKEN=
SRT_MACRO_TELEGRAM_CHAT_ID=
```

### 텔레그램 알림 설정 (선택)

휴대폰 푸시·원격 종료를 받고 싶으면:

1. 텔레그램에서 `@BotFather`로 봇 생성 → 토큰 받기
2. `.env`의 `SRT_MACRO_TELEGRAM_TOKEN`에 붙여넣기
3. 봇과 대화 시작 (`/start`)
4. 헬퍼 실행 → chat_id 자동 추출 + 테스트 메시지:
   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/skills/srt-macro/scripts/setup_telegram.py"
   ```

## ⚠ 역명 함정 — 반드시 정확한 이름 사용

`"울산"`, `"수원"` 같이 흔히 부르는 이름은 **SRTrain에서 ValueError**가 발생한다 (즉시 종료). 정확한 33개 역명만 허용:

```
수서, 동탄, 평택지제, 천안아산, 오송, 대전, 김천(구미),
동대구, 서대구, 신경주, 경주, 울산(통도사), 부산,
포항, 밀양, 진영, 창원중앙, 창원, 마산, 진주,
공주, 익산, 정읍, 광주송정, 나주, 목포,
전주, 남원, 곡성, 구례구, 순천, 여천, 여수EXPO
```

전체 역명 조회 한 줄 (venv 자동 셋업 후):
```bash
~/.config/srt-macro/.venv/bin/python -c \
  "from SRT.constants import STATION_CODE; print(list(STATION_CODE.keys()))"
```

자주 틀리는 것:
| ❌ 잘못 | ✅ 정확 |
|---|---|
| 울산 | `울산(통도사)` |
| 구미 | `김천(구미)` |
| 여수 | `여수EXPO` |

## Inputs

### 단일 노선 모드

| 인자 | 설명 | 예시 |
|---|---|---|
| `--dep` | 출발역 | `수서`, `동탄`, `평택지제` |
| `--arr` | 도착역 | `부산`, `동대구`, `광주송정` |
| `--date` | YYYYMMDD | `20260430` |
| `--time-from` | HHMMSS (희망 출발) | `180000` |
| `--time-to` | HHMMSS 상한 (선택) | `220000` |
| `--seat` | 좌석 선호 | `general`(기본) / `special` / `both` |
| `--dry-run` | 1 사이클 후 종료, 예약 X | (옵션) |

### 다중 노선 모드 (왕복·여러 시간대 동시 감시)

`--route 'dep:arr:date:time_from[:time_to[:seat]]'` 인자를 반복해서 지정. 한 프로세스 / 1회 로그인으로 여러 노선을 번갈아 폴링하므로 **계정 안전**.

| 인자 | 설명 | 형식 |
|---|---|---|
| `--route` | 노선 한 개 (반복 가능) | `dep:arr:date:time_from[:time_to[:seat]]` |

콜론 구분, time_to·seat은 생략 가능. 노선당 좌석 잡히면 그 노선만 종료, 다른 노선은 계속 폴링. 모든 노선 잡히면 매크로 자동 종료.

## 텔레그램 알림 종류 + 원격 명령

`.env`에 텔레그램 토큰·chat_id 설정 시 다음 5가지 알림이 자동 발송됩니다:

| 알림 | 시점 | 내용 |
|---|---|---|
| 🚀 시작 | 매크로 실행 시 | 노선 목록 + 헬스체크 간격 + 원격 명령 안내 |
| 🟢 alive | `SRT_MACRO_HEALTHCHECK_MIN`마다 | 경과 시간, 사이클, 대기 노선 |
| 🚄 예약 성공 | 좌석 잡힐 때마다 | 노선 + "10분 내 결제!" |
| 🛑 종료 | 원격 `/stop` 수신 시 | "원격 명령으로 정상 종료" |
| ❌ 종료 | 연속 실패로 안전 종료 시 | 사유 |

휴대폰에서 봇한테 보낼 수 있는 명령 (본인 chat_id에서만 인식):

| 명령 | 동작 |
|---|---|
| `/stop` (또는 `/kill`, `/abort`, `/exit`, `/quit`) | 매크로 즉시 종료 (최대 사이클 1개 대기 후 반응) |
| `/status` | 즉시 헬스체크 (다음 예약 시간 안 기다리고 현재 상태 받기) |
| `/help` | 명령 목록 |

헬스체크 메시지 예시:
```
🟢 SRT 매크로 alive
경과 1h 23m | 사이클 47/200 | 대기 2개
수서→울산(통도사) 04/29 08:00~09:20
울산(통도사)→수서 04/30 18:00~21:00
```

## Workflow

### 1. 항상 dry-run으로 먼저 검증

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/srt-macro/scripts/srt_watcher.py" \
  --dep 수서 --arr 부산 --date 20260430 \
  --time-from 180000 --time-to 220000 --dry-run
```

자리가 있으면 `--dry-run`은 발견 즉시 종료(예약 X). 매진이면 1 사이클 후 종료. 첫 실행이면 venv가 자동 셋업되어 ~30초 추가 소요.

### 2. 실 매크로 백그라운드 실행 (권장)

**단일 노선:**
```bash
nohup python3 "${CLAUDE_PLUGIN_ROOT}/skills/srt-macro/scripts/srt_watcher.py" \
  --dep '수서' --arr '울산(통도사)' --date 20260429 \
  --time-from 080000 --time-to 092000 --seat general \
  > ~/srt-macro.log 2>&1 &

echo "PID: $!"
```

**왕복 (가는 표 + 오는 표 동시 감시):**
```bash
nohup python3 "${CLAUDE_PLUGIN_ROOT}/skills/srt-macro/scripts/srt_watcher.py" \
  --route '수서:울산(통도사):20260429:080000:092000:general' \
  --route '울산(통도사):수서:20260501:180000:210000:general' \
  > ~/srt-macro.log 2>&1 &

echo "PID: $!"
```

터미널 닫혀도 계속 돕니다 (`nohup`). 노선 추가는 `--route`를 더 붙이면 됩니다 (3개·4개 가능). 외출 시 맥 잠자기 방지: 명령 앞에 `caffeinate -i` 추가.

### 3. 진행 상황 보기

```bash
tail -f ~/srt-macro.log
```

다른 창에서 실행. `Ctrl+C`로 tail만 빠져나옴 (매크로는 계속 돔). 또는 휴대폰에서 봇한테 `/status` 전송.

### 4. 중단

**텔레그램으로 (권장):** 휴대폰에서 봇한테 `/stop` 전송. 1~2분 안에 정상 종료.

**터미널로:**
```bash
pkill -f srt_watcher.py && rm -f ~/.srt-macro.lock
```

### 5. 좌석 잡히면

- macOS notification + 시스템 사운드
- 텔레그램 푸시 (`.env`에 토큰 있으면)
- 터미널·로그에 예약번호·구입기한 출력
- **SRT 앱/사이트에서 10분 내 결제** (필수, 자동화 X)
- 매크로는 자동 종료 (예약 후 폴링 안 함)

## Failure modes

- **로그인 실패** → 비밀번호 오류 가능성. `.env` 또는 Keychain 재등록. 절대 재시도 안 함.
- **연속 3회 API 에러** → SRT 점검 또는 차단 가능성. 자동 종료. 30분 이상 쉬고 재시도.
- **lockfile 존재** → 이미 실행 중이거나 비정상 종료. `cat ~/.srt-macro.lock`으로 PID 확인 후 죽었으면 `rm ~/.srt-macro.lock`.
- **첫 실행 시 venv 셋업 실패** → 시스템 python에 venv 모듈 없음. `python3 -m venv --help` 로 확인.

## Done when

- 좌석 잡힘 → 예약번호 + 구입기한 알림
- 시간/시도 만료 → "좌석 못 잡음" 메시지
- 에러 종료 → 명확한 사유 메시지

## 헬퍼 스크립트

| 파일 | 용도 | 실행 시점 |
|---|---|---|
| `scripts/srt_watcher.py` | 메인 매크로 (감시·예약) | 평소 사용 |
| `scripts/setup_telegram.py` | 텔레그램 chat_id 자동 추출 + .env 업데이트 + 테스트 메시지 발송 | 봇 토큰 처음 등록 시 1회 |
| `scripts/_bootstrap.py` | venv 자동 생성·재실행 (직접 호출 X) | (자동) |

## 사용자 데이터 완전 제거

플러그인 자체는 마켓플레이스에서 제거하면 됩니다 (`/plugin remove srt-magic`). 사용자가 만든 데이터는 별도로 지워야 합니다:

```bash
# 자격증명·설정·venv (~50MB)
rm -rf ~/.config/srt-macro

# Keychain fallback (있으면)
security delete-generic-password -a "$USER" -s KSKILL_SRT_ID 2>/dev/null
security delete-generic-password -a "$USER" -s KSKILL_SRT_PASSWORD 2>/dev/null

# 로그·lockfile
rm -f ~/srt-macro.log ~/.srt-macro.lock
```

## Notes

- SRT 정책상 매크로는 비공식 — 계정 보호 위해 보수적 간격 유지
- `~/srt-macro.log`에는 평문 로그가 남음 (예약번호 포함). 민감하면 끝나고 `rm` 권장
- venv는 `~/.config/srt-macro/.venv/`에 생성됨 (~50MB). 처음 한 번만 ~30초 셋업
