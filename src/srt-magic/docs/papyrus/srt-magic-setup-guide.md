---
title: "srt-magic 설치 가이드"
authors: "노우주"
date: "2026-04-27"
classification: "외부용"
template_id: "custom"
color_primary: "#4A0E8F"
color_primary_hover: "#6B2FB0"
---

## 개요

srt-magic은 매진된 SRT 좌석을 자동 감시하다가 빈자리가 나면 즉시 예약하는 Claude Code 플러그인입니다.

- 다중 노선(왕복) 동시 감시: 한 프로세스, 1회 로그인으로 여러 노선 동시 추적
- 텔레그램 푸시 알림: 예약 성공, 헬스체크, 원격 종료 명령 지원
- 8중 안전 가드: 세션 재사용, 지터 폴링, 시도 캡, 에러 백오프 등 계정 잠김 방지
- 크로스플랫폼: macOS / Windows / Linux

> srt-magic은 결제를 자동화하지 않습니다. 좌석을 잡으면 10분 내 사용자가 직접 결제해야 합니다.

### 사전 요구사항

| 항목 | 요구 |
|------|------|
| OS | macOS / Windows / Linux |
| Python | 3.10 이상 |
| SRT 계정 | etk.srail.or.kr 회원가입 필수 |
| Claude Code | 마켓플레이스 지원 버전 |
| 텔레그램 | (선택) 푸시 알림 + 원격 종료 |

## 설치 및 셋업

### 플러그인 설치

Claude Code에서 마켓플레이스를 등록하고 플러그인을 설치합니다.

Step 1: 마켓플레이스 등록 (최초 1회)

```
/plugin marketplace add brandonnoh/woojoo-magic
```

Step 2: 플러그인 설치

```
/plugin install wj-magic@woojoo-magic
/plugin install srt-magic@woojoo-magic
```

또는 대화형으로: `/plugin` → Discover 탭 → 플러그인 선택 → Install

Step 3: 활성화 확인

```
/reload-plugins
/plugin          → Installed 탭에서 확인
```

### SRT 자격증명 등록

Claude Code에서 자연어로 요청하면 대화를 통해 자격증명을 등록할 수 있습니다.

```
SRT 셋업해줘
```

Claude가 대화로 안내하는 것:

- SRT 회원번호(ID) 입력
- 비밀번호 입력
- 텔레그램 봇 토큰 입력 (선택)
- ~/.config/srt-macro/.env 파일 자동 생성 (chmod 0600)

Claude Code 밖에서 터미널로 직접 설정하고 싶으면:

```
! python3 <플러그인경로>/scripts/setup.py
```

> [!warning] 기존 .env가 있으면 덮어쓰기 전 확인 후 .env.backup으로 자동 백업됩니다.

### 자격증명 우선순위

| 우선순위 | 소스 | 용도 |
|---------|------|------|
| 1 | 환경변수 (KSKILL_SRT_ID / KSKILL_SRT_PASSWORD) | CI/일회성 override |
| 2 | .env 파일 | 평상시 사용 |
| 3 | macOS Keychain | fallback (macOS만) |

### .env 파일 항목

```
KSKILL_SRT_ID=회원번호
KSKILL_SRT_PASSWORD=비밀번호
SRT_MACRO_MAX_ATTEMPTS=200
SRT_MACRO_MAX_DURATION_SEC=14400
SRT_MACRO_SEARCH_TIMEOUT_SEC=30
SRT_MACRO_HEALTHCHECK_MIN=30
SRT_MACRO_NOTIFY_SOUND=Glass
SRT_MACRO_TELEGRAM_TOKEN=
SRT_MACRO_TELEGRAM_CHAT_ID=
```

## 텔레그램 알림 설정

외출 중에도 휴대폰으로 예약 성공 알림을 받고, `/stop`으로 원격 종료할 수 있습니다.

### 봇 생성 및 연결

- Step 1: 텔레그램에서 @BotFather 검색 → `/newbot` → 봇 이름 지정 → 토큰 복사
- Step 2: `.env`의 `SRT_MACRO_TELEGRAM_TOKEN`에 토큰 붙여넣기
- Step 3: 생성한 봇과 대화 시작 (`/start` 전송)
- Step 4: Claude Code에서 `텔레그램 chat_id 등록해줘` 또는 터미널에서 헬퍼 실행

테스트 메시지가 텔레그램으로 도착하면 설정 완료입니다.

### 텔레그램 원격 명령

| 명령 | 동작 |
|------|------|
| /stop (또는 /kill, /abort, /exit, /quit) | 매크로 종료 |
| /status | 즉시 상태 조회 |
| /help | 명령 목록 |

> 본인 chat_id에서 보낸 메시지만 인식합니다. 다른 사람이 명령을 보내도 무시됩니다.

## 텔레그램 알림 케이스

텔레그램 토큰과 chat_id가 설정되어 있으면 아래 6가지 알림이 자동 발송됩니다.

### 매크로 시작

매크로 실행 시 감시 노선 목록, 헬스체크 간격, 원격 명령 안내를 전송합니다.

![매크로 시작 알림](./images/telegram-01-start.png)

### 헬스체크 및 /status 응답

30분마다 자동 헬스체크를 전송합니다. `/status` 명령으로 즉시 상태를 조회할 수도 있습니다.

![헬스체크 및 status 응답](./images/telegram-02-alive.png)

### 예약 성공

좌석을 잡으면 즉시 알림이 옵니다. **10분 내 SRT 앱에서 결제**해야 합니다.

![예약 성공 알림](./images/telegram-03-success.png)

> [!warning] 예약 후 10분 내 결제하지 않으면 자동 취소됩니다. 결제는 자동화하지 않습니다.

### 원격 종료 (/stop)

외출 중 매크로를 멈추고 싶으면 봇에게 `/stop`을 전송합니다. 1~2분 안에 정상 종료됩니다.

![원격 종료](./images/telegram-04-stop.png)

### 에러 종료

연속 5회 API 에러 발생 시 계정 보호를 위해 자동 종료됩니다.

![에러 종료](./images/telegram-05-error.png)

### /help 명령

사용 가능한 텔레그램 명령 목록을 확인합니다.

![help 명령](./images/telegram-06-help.png)

## 사용법

### dry-run 검증 (첫 실행 권장)

실제 예약 없이 검색만 테스트합니다. 첫 실행이면 venv가 자동 셋업됩니다 (~30초).

Claude Code에서:

```
SRT 수서→부산 5/1 08시 dry-run 해줘
```

### Claude Code에서 실행 (권장)

자연어로 요청하면 자동으로 매크로를 실행합니다.

```
SRT 수서→울산(통도사) 4/29 08시~09시20분 매진 잡아줘
```

### 왕복 (다중 노선 동시 감시)

```
SRT 왕복 잡아줘
수서→울산(통도사) 4/29 08시~09시20분
울산(통도사)→수서 4/29 18시~20시
```

### 인자 설명

| 인자 | 설명 | 예시 |
|------|------|------|
| 출발역 | 정확한 SRT 역명 | 수서 |
| 도착역 | 정확한 SRT 역명 | 울산(통도사) |
| 날짜 | 날짜 | 4/29, 20260429 |
| 출발 시각 | 희망 출발 시각 | 08시, 080000 |
| 시간 상한 | (선택) 시간 상한 | ~09시20분 |
| 좌석 | (선택) 좌석 선호 | 일반석 / 특실 |

### 진행 상황 확인

```
tail -f ~/srt-macro.log
```

`Ctrl+C`로 tail만 빠져나옵니다 (매크로는 계속 실행).

또는 텔레그램에서 `/status` 전송.

### 매크로 중단

텔레그램: 봇에게 `/stop` 전송 (권장)

터미널:
```
pkill -f srt_watcher.py && rm -f ~/.srt-macro.lock
```

## 안전 가드 및 주의사항

### 8중 안전 가드

SRT 계정 잠김을 방지하기 위해 다층 안전 장치가 내장되어 있습니다.

| 레이어 | 정책 |
|--------|------|
| 세션 재사용 | 시작 시 1회 로그인, 이후 search_train만 반복 |
| 폴링 간격 지터 | 골든타임(7~10/18~21시) 30~60초, 평시 60~120초, 야간(0~6시) 5~10분 |
| 시도 캡 | 200회 또는 4시간 (먼저 도달하는 것) → 자동 종료 |
| 로그인 실패 | 즉시 종료, 재시도 절대 안 함 (3회면 SRT 계정 잠김) |
| NetFunnel 혼잡 | 서버 대기열 혼잡은 일시적 에러로 분류, 30~60초 후 재시도 |
| 에러 백오프 | 2분 → 5분 → 15분 지수 증가, 5회 연속 실패 시 종료 |
| 세션 만료 | 자동 재로그인 1회 시도 |
| 단일 인스턴스 | ~/.srt-macro.lock으로 중복 실행 차단 |

> [!danger] SRT 정책상 매크로는 비공식입니다. 보수적 간격을 유지하여 계정을 보호합니다.

### 역명 함정 주의

SRT 역명은 정확히 입력해야 합니다. 흔히 부르는 이름과 실제 이름이 다릅니다.

| 잘못된 입력 | 올바른 입력 |
|------------|-----------|
| 울산 | 울산(통도사) |
| 구미 | 김천(구미) |
| 여수 | 여수EXPO |

전체 허용 역명 (33개): 수서, 동탄, 평택지제, 천안아산, 오송, 대전, 김천(구미), 동대구, 서대구, 신경주, 경주, 울산(통도사), 부산, 포항, 밀양, 진영, 창원중앙, 창원, 마산, 진주, 공주, 익산, 정읍, 광주송정, 나주, 목포, 전주, 남원, 곡성, 구례구, 순천, 여천, 여수EXPO

### 환경변수 조정

| 변수 | 기본값 | 설명 |
|------|--------|------|
| SRT_MACRO_MAX_ATTEMPTS | 200 | 최대 폴링 사이클 수 |
| SRT_MACRO_MAX_DURATION_SEC | 14400 (4시간) | 최대 실행 시간 |
| SRT_MACRO_SEARCH_TIMEOUT_SEC | 30 | 검색 API 타임아웃 |
| SRT_MACRO_HEALTHCHECK_MIN | 30 | 헬스체크 간격 (0이면 비활성) |

## 트러블슈팅 및 제거

### 로그인 실패

`.env`의 ID/비밀번호 확인. SRT 사이트에서 직접 로그인 테스트.

### lockfile 존재

이미 실행 중이거나 비정상 종료된 경우:

```
cat ~/.srt-macro.lock
ps -p $(cat ~/.srt-macro.lock)
rm -f ~/.srt-macro.lock
```

### 연속 사이클 실패

SRT 서버 점검이거나 일시적 장애. 30분 이상 대기 후 재시도.

### 완전 제거

```
# 플러그인 제거
/plugin uninstall srt-magic@woojoo-magic

# 설정·자격증명·venv
rm -rf ~/.config/srt-macro

# macOS Keychain fallback
security delete-generic-password -a "$USER" -s KSKILL_SRT_ID 2>/dev/null
security delete-generic-password -a "$USER" -s KSKILL_SRT_PASSWORD 2>/dev/null

# 로그·lockfile
rm -f ~/srt-macro.log ~/.srt-macro.lock
```
