# srt-magic

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)]()
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows%20%7C%20Linux-lightgrey)
![Python](https://img.shields.io/badge/python-3.10+-blue)
![Status](https://img.shields.io/badge/status-1.0.2-green)

> **한국 SRT 매진 좌석 자동 감시·예약 매크로** — Claude Code 플러그인.
> 매진된 좌석을 사람과 비슷한 간격으로 폴링하다가 자리가 나면 즉시 예약하고, macOS·텔레그램으로 알림을 보낸다.

---

## ✨ 주요 기능

- 🚄 **다중 노선 동시 감시** — 왕복 표 한 번에 (`--route` 반복)
- 🔒 **계정 잠김 방지** — 세션 재사용 + 지터 폴링 + 백오프 + 시도 캡 + lockfile (8중 안전 가드)
- 📲 **텔레그램 푸시** — 시작·헬스체크(30분 간격)·예약 성공·종료 알림
- 🛑 **원격 종료 명령** — 휴대폰에서 `/stop`, `/status`, `/help` 전송
- ⚙ **자동 셋업** — 처음 실행 시 venv·의존성 자동 설치 (~30초)
- 🔐 **자격증명 다층화** — 환경변수 > .env > macOS Keychain
- 🚫 **결제 자동화 X** — SRT 정책·계정 보호 (10분 내 사용자 직접 결제)

---

## 📋 사전 요구사항

| 항목 | 요구 |
|---|---|
| OS | macOS / Windows / Linux (플랫폼별 알림 자동 분기) |
| Python | 3.10 이상 (시스템 python3 사용) |
| SRT 회원 | [srail.or.kr](https://etk.srail.kr) 계정 |
| Claude Code | 0.x+ (마켓플레이스 지원 버전) |
| (선택) 텔레그램 | 휴대폰 푸시·원격 종료 받으려면 |

---

## 🚀 설치

### Claude Code 마켓플레이스에서 (권장)

```
/plugin marketplace add woojoo-magic/wj-tools
/plugin install srt-magic@wj-tools
```

### 수동 설치

```bash
# 1) 마켓플레이스 클론
git clone https://github.com/woojoo-magic/wj-tools ~/wj-tools

# 2) Claude Code에 등록
/plugin marketplace add ~/wj-tools
/plugin install srt-magic@wj-tools
```

---

## ⚙ 첫 셋업 (사용자별 1회 — 한 줄로 끝남)

```bash
python3 ~/.claude/plugins/marketplaces/wj-tools/src/srt-magic/skills/srt-macro/scripts/setup.py
```

이 한 줄이 자동 처리:

- ✅ `~/.config/srt-macro/.venv/` 가상환경 생성 (~30초, 1회)
- ✅ `SRTrain` + `python-dotenv` + `requests` 설치
- ✅ SRT ID/비밀번호 **대화형 입력** (비밀번호 화면에 안 보임, 재입력 확인)
- ✅ 텔레그램 봇 토큰 **선택 입력** (없으면 엔터로 스킵)
- ✅ `~/.config/srt-macro/.env` 작성 + chmod 0600
- ✅ 다음 단계 안내

### 대화 흐름 예시

```
🚄  SRT 매크로 자격증명 셋업
============================================================
이 스크립트는 ~/.config/srt-macro/.env 를 만듭니다.
비밀번호는 화면에 표시되지 않으며, chmod 0600(본인만 읽기)로 저장됩니다.

[1/3] SRT 회원 정보
  SRT ID: example@gmail.com
  비밀번호 (입력 안 보임):
  비밀번호 재입력:
  ✓ 일치

[2/3] 텔레그램 봇 토큰 (선택)
  봇 토큰 (입력 안 보임, 엔터로 스킵):
  → 텔레그램 알림 비활성화 (macOS 알림만 작동)

[3/3] .env 파일 작성
  ✓ 저장: /Users/woojoo/.config/srt-macro/.env
  ✓ 권한: -rw------- (본인만 읽기)

✅  셋업 완료!

🚀  매크로 첫 실행 (dry-run으로 검증):
     python3 .../scripts/srt_watcher.py --dep 수서 --arr 부산 ...
```

### 텔레그램 chat_id 자동 등록 (텔레그램 토큰 입력했을 때)

1. 휴대폰에서 만든 봇한테 메시지 1번 보내기 (예: `/start`)
2. 아래 명령 실행 — chat_id 자동 추출 + 테스트 메시지 전송:
   ```bash
   python3 ~/.claude/plugins/marketplaces/wj-tools/src/srt-magic/skills/srt-macro/scripts/setup_telegram.py
   ```

### dry-run 검증

```bash
python3 ~/.claude/plugins/marketplaces/wj-tools/src/srt-magic/skills/srt-macro/scripts/srt_watcher.py \
  --dep 수서 --arr 부산 --date 20260501 \
  --time-from 080000 --dry-run
```

"운행 N대, 가용 좌석 없음" 같은 출력이 나오면 정상.

---

## 🎯 사용

### Claude Code 안에서 (권장)

```
"수서에서 울산 4월 29일 오전 8시 SRT 매진인데 자리 나면 잡아줘"
```

→ `srt-macro` 스킬이 자동 트리거되어 명령을 만들고 실행합니다.

### 직접 백그라운드 실행

**단일 노선:**
```bash
nohup python3 ~/.claude/plugins/marketplaces/wj-tools/src/srt-magic/skills/srt-macro/scripts/srt_watcher.py \
  --dep '수서' --arr '울산(통도사)' --date 20260429 \
  --time-from 080000 --time-to 092000 --seat general \
  > ~/srt-macro.log 2>&1 &
```

**왕복 (가는 표 + 오는 표 동시):**
```bash
nohup python3 ~/.claude/plugins/marketplaces/wj-tools/src/srt-magic/skills/srt-macro/scripts/srt_watcher.py \
  --route '수서:울산(통도사):20260429:080000:092000:general' \
  --route '울산(통도사):수서:20260501:180000:210000:general' \
  > ~/srt-macro.log 2>&1 &
```

외출 시 맥 잠자기 방지 — 명령 앞에 `caffeinate -i` 추가.

### 진행 상황 확인

```bash
tail -f ~/srt-macro.log
```

또는 휴대폰 봇한테 `/status` 메시지.

### 종료

휴대폰 봇한테 `/stop` 메시지 전송 (1~2분 안에 정상 종료).

또는:
```bash
pkill -f srt_watcher.py && rm -f ~/.srt-macro.lock
```

---

## ⚠ 역명 함정

**`"울산"`이 아니라 `"울산(통도사)"`** 입니다. SRTrain은 정확한 33개 역명만 인식합니다:

```
수서, 동탄, 평택지제, 천안아산, 오송, 대전, 김천(구미),
동대구, 서대구, 신경주, 경주, 울산(통도사), 부산,
포항, 밀양, 진영, 창원중앙, 창원, 마산, 진주,
공주, 익산, 정읍, 광주송정, 나주, 목포,
전주, 남원, 곡성, 구례구, 순천, 여천, 여수EXPO
```

자주 틀리는 것:
| ❌ | ✅ |
|---|---|
| 울산 | `울산(통도사)` |
| 구미 | `김천(구미)` |
| 여수 | `여수EXPO` |

---

## 📊 안전 가드 8개

계정 잠김·SRT 봇 감지를 막기 위한 다층 방어:

| # | 가드 | 효과 |
|---|---|---|
| 1 | 세션 재사용 | 시작 시 1회 로그인, 폴링은 search만 |
| 2 | 폴링 간격 지터 | 시간대별 30초~10분 랜덤 |
| 3 | 시도 캡 | 200회 또는 4시간 후 자동 종료 |
| 4 | 로그인 실패 즉시 종료 | 비밀번호 오류 3회 = SRT 계정 잠금 방지 |
| 5 | 에러 백오프 | 2분 → 5분 → 15분 지수 증가 |
| 6 | 단일 인스턴스 | lockfile로 중복 실행 차단 |
| 7 | 예약 후 즉시 종료 | 좌석 잡으면 폴링 중단 (중복 예약 방지) |
| 8 | 결제 자동화 X | SRT 약관 준수, 사용자가 10분 내 직접 결제 |

---

## 📁 파일 구조

```
srt-magic/
├── .claude-plugin/plugin.json
├── skills/srt-macro/
│   ├── SKILL.md            # Claude 트리거·사용법
│   ├── scripts/
│   │   ├── srt_watcher.py  # 메인 매크로
│   │   ├── setup_telegram.py
│   │   └── _bootstrap.py   # venv 자동 셋업
│   └── evals/evals.json    # 트리거 정확도 테스트셋
├── requirements.txt
├── README.md
└── LICENSE

# 사용자별 데이터 (별도 위치)
~/.config/srt-macro/
├── .env                    # 자격증명 (chmod 600)
└── .venv/                  # 자동 생성된 가상환경 (~50MB)

~/srt-macro.log             # 백그라운드 로그
~/.srt-macro.lock           # 단일 인스턴스 lockfile
```

---

## 🔐 보안

- `.env`는 평문이지만 `chmod 600`으로 본인만 읽기
- macOS Keychain은 fallback으로 사용 가능 (`security add-generic-password`)
- 봇 토큰은 채팅창에 직접 입력 금지 — 에디터로 `.env`에 저장
- 로그 파일에는 예약번호가 평문으로 남으므로 사용 후 `rm` 권장

---

## ⚖ 면책 조항

- 이 매크로는 **SRT 약관상 비공식 도구**입니다
- SRT는 자동화 도구를 명시적으로 금지·허용하지 않으나, 비정상 트래픽 감지 시 **계정 정지 가능성**이 있습니다
- 본 도구의 안전 가드(폴링 간격·시도 캡 등)는 위험을 줄이지만 **0%로 만들지는 못합니다**
- **사용으로 인한 계정 정지·법적 책임은 전적으로 사용자에게 있습니다**
- 운영자(woojoo)는 결과에 대해 어떠한 보증·책임도 지지 않습니다 (MIT License 면책)

이 도구를 쓰기 전에 본인의 SRT 회원 약관을 다시 확인하세요.

---

## 🤝 기여

이슈·PR 환영합니다 → https://github.com/woojoo-magic/wj-tools/issues

특히:
- 더 다양한 OS 알림 테스트 (Windows toast, Linux notify-send 실사용 피드백)
- KTX/Korail 지원 (별도 플러그인 권장)
- 더 다양한 알림 채널 (Discord, Slack)

---

## 📜 라이선스

MIT License — [LICENSE](./LICENSE)

Copyright (c) 2026 woojoo
