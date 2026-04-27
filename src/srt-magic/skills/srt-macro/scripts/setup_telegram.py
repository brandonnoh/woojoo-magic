#!/usr/bin/env python3
"""텔레그램 chat_id 자동 추출 + .env 업데이트 + 테스트 메시지 발송."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from _bootstrap import ensure_venv  # noqa: E402
ensure_venv()

import os  # noqa: E402
import re  # noqa: E402

ENV_PATH = Path.home() / ".config" / "srt-macro" / ".env"


def load_env() -> dict[str, str]:
    if not ENV_PATH.exists():
        sys.exit(f"❌ {ENV_PATH} 없음. .env 먼저 생성.")
    env = {}
    for line in ENV_PATH.read_text().splitlines():
        if line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        env[k.strip()] = v.strip()
    return env


def update_env_value(key: str, value: str) -> None:
    text = ENV_PATH.read_text()
    pattern = rf"^{re.escape(key)}=.*$"
    if re.search(pattern, text, flags=re.MULTILINE):
        new = re.sub(pattern, f"{key}={value}", text, flags=re.MULTILINE)
    else:
        new = text.rstrip() + f"\n{key}={value}\n"
    ENV_PATH.write_text(new)


def main() -> None:
    import requests
    env = load_env()
    token = env.get("SRT_MACRO_TELEGRAM_TOKEN", "")
    if not token:
        sys.exit("❌ .env에 SRT_MACRO_TELEGRAM_TOKEN 비어있음.")

    print(f"[1/3] getUpdates 호출 중...")
    r = requests.get(f"https://api.telegram.org/bot{token}/getUpdates", timeout=10)
    data = r.json()
    if not data.get("ok"):
        sys.exit(f"❌ API 오류: {data}")

    updates = data.get("result", [])
    if not updates:
        sys.exit(
            "❌ 받은 메시지 없음.\n"
            "👉 휴대폰에서 봇과 대화 시작 후 다시 실행:\n"
            f"   1) t.me/<your_bot> 열기\n"
            f"   2) /start 또는 아무 메시지 전송\n"
            f"   3) 이 스크립트 재실행"
        )

    chat_ids = list({u["message"]["chat"]["id"] for u in updates if "message" in u})
    if len(chat_ids) > 1:
        print(f"⚠ 여러 chat 발견: {chat_ids}")
        print(f"   첫 번째 사용: {chat_ids[0]}")
    chat_id = str(chat_ids[0])
    print(f"[2/3] chat_id 발견: {chat_id}")

    update_env_value("SRT_MACRO_TELEGRAM_CHAT_ID", chat_id)
    print(f"   .env 업데이트 완료")

    print(f"[3/3] 테스트 메시지 발송...")
    test = requests.post(
        f"https://api.telegram.org/bot{token}/sendMessage",
        json={"chat_id": chat_id, "text": "🚄 *SRT 매크로 알림 테스트*\n설정 완료! 좌석 잡히면 여기로 알려드립니다.", "parse_mode": "Markdown"},
        timeout=10,
    )
    if test.json().get("ok"):
        print("✅ 텔레그램 알림 설정 완료. 휴대폰 확인!")
    else:
        sys.exit(f"❌ 메시지 발송 실패: {test.json()}")


if __name__ == "__main__":
    main()
