#!/usr/bin/env python3
"""SRT 매크로 자격증명 대화형 셋업.

처음 사용자가 한 번만 실행하면 ~/.config/srt-macro/.env 를 만들어준다.
비밀번호는 화면에 보이지 않게 입력받고, chmod 600 자동 적용.
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from _bootstrap import ensure_venv  # noqa: E402
ensure_venv()

import getpass  # noqa: E402

ENV_DIR = Path.home() / ".config" / "srt-macro"
ENV_PATH = ENV_DIR / ".env"
SCRIPTS_DIR = Path(__file__).resolve().parent

TEMPLATE = """\
# ============================================
# SRT 매크로 설정 파일
# 위치: ~/.config/srt-macro/.env
# 권한: 0600 (본인만 읽기·쓰기)
# 보안: 평문 저장이므로 절대 git에 커밋 금지
# ============================================

# === SRT 자격증명 ===
KSKILL_SRT_ID={srt_id}
KSKILL_SRT_PASSWORD={srt_pw}

# === 폴링 안전 파라미터 ===
SRT_MACRO_MAX_ATTEMPTS=200
SRT_MACRO_MAX_DURATION_SEC=14400
SRT_MACRO_SEARCH_TIMEOUT_SEC=30
SRT_MACRO_HEALTHCHECK_MIN=30

# === 알림 채널 ===
SRT_MACRO_NOTIFY_SOUND=Glass
SRT_MACRO_TELEGRAM_TOKEN={tg_token}
SRT_MACRO_TELEGRAM_CHAT_ID=
"""


def banner() -> None:
    print()
    print("🚄  SRT 매크로 자격증명 셋업")
    print("=" * 60)
    print(f"이 스크립트는 {ENV_PATH} 를 만듭니다.")
    print("비밀번호는 화면에 표시되지 않으며, chmod 0600(본인만 읽기)로 저장됩니다.")
    print("중간에 빠져나가려면 Ctrl+C 누르세요.")
    print()


def check_existing() -> bool:
    if not ENV_PATH.exists():
        return True
    print(f"⚠  이미 .env 파일이 있습니다: {ENV_PATH}")
    ans = input("덮어쓸까요? 기존 파일은 .env.backup 으로 백업됩니다. [y/N]: ").strip().lower()
    if ans != "y":
        print("✗ 셋업 취소. 기존 파일 유지.")
        return False
    backup = ENV_PATH.with_name(".env.backup")
    ENV_PATH.rename(backup)
    print(f"✓ 기존 파일을 {backup} 로 백업.\n")
    return True


def ask_credentials() -> tuple[str, str]:
    print("[1/3] SRT 회원 정보")
    print("  · SRT 홈페이지(etk.srail.kr) 회원가입 시 사용한 ID/이메일/휴대폰번호")
    print("  · 예: example@gmail.com, 01012345678, 1234567890")
    print()
    while True:
        srt_id = input("  SRT ID: ").strip()
        if srt_id:
            break
        print("  ✗ 빈 값 입력 불가.")
    while True:
        pw1 = getpass.getpass("  비밀번호 (입력 안 보임): ")
        pw2 = getpass.getpass("  비밀번호 재입력: ")
        if not pw1:
            print("  ✗ 빈 값 입력 불가.")
            continue
        if pw1 != pw2:
            print("  ✗ 일치하지 않습니다. 다시 입력하세요.")
            continue
        print("  ✓ 일치")
        break
    print()
    return srt_id, pw1


def ask_telegram() -> str:
    print("[2/3] 텔레그램 봇 토큰 (선택)")
    print("  · 휴대폰 푸시 알림 + 원격 종료(/stop) 받으려면 봇 토큰 입력")
    print("  · 텔레그램에서 @BotFather → /newbot 으로 만들고 받은 토큰")
    print("  · 예: 1234567890:AAFoBTndBBkdcTNHW4rsoGvjSqatVqRmx2Y")
    print("  · 없으면 엔터만 누르세요 (나중에 .env 직접 수정해서 추가 가능)")
    print()
    token = getpass.getpass("  봇 토큰 (입력 안 보임, 엔터로 스킵): ").strip()
    if not token:
        print("  → 텔레그램 알림 비활성화 (macOS 알림만 작동).")
    else:
        print("  ✓ 토큰 저장됨")
    print()
    return token


def write_env(srt_id: str, srt_pw: str, tg_token: str) -> None:
    print("[3/3] .env 파일 작성")
    ENV_DIR.mkdir(parents=True, exist_ok=True)
    ENV_DIR.chmod(0o700)
    ENV_PATH.write_text(TEMPLATE.format(srt_id=srt_id, srt_pw=srt_pw, tg_token=tg_token))
    ENV_PATH.chmod(0o600)
    print(f"  ✓ 저장: {ENV_PATH}")
    print(f"  ✓ 권한: -rw------- (본인만 읽기)")
    print()


def show_next_steps(tg_token: str) -> None:
    print("=" * 60)
    print("✅  셋업 완료!")
    print()
    if tg_token:
        print("📲  텔레그램 chat_id 등록 (다음 단계):")
        print("  1. 휴대폰에서 만든 봇한테 메시지 1번 보내기 (예: /start)")
        print("  2. 아래 명령 실행:")
        print(f"     python3 {SCRIPTS_DIR / 'setup_telegram.py'}")
        print()
    print("🚀  매크로 첫 실행 (dry-run으로 검증):")
    print(f"     python3 {SCRIPTS_DIR / 'srt_watcher.py'} \\")
    print("       --dep 수서 --arr 부산 --date 20260503 \\")
    print("       --time-from 180000 --dry-run")
    print()
    print("또는 Claude Code 안에서:")
    print('     "수서→부산 5/3 18시 SRT 매진 잡아줘"')
    print()


def main() -> None:
    banner()
    if not check_existing():
        sys.exit(0)
    try:
        srt_id, srt_pw = ask_credentials()
        tg_token = ask_telegram()
    except (KeyboardInterrupt, EOFError):
        print("\n\n✗ 셋업 취소 (사용자 중단).")
        sys.exit(1)
    write_env(srt_id, srt_pw, tg_token)
    show_next_steps(tg_token)


if __name__ == "__main__":
    main()
