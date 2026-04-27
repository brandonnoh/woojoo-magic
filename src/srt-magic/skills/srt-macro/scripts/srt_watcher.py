#!/usr/bin/env python3
"""SRT 매진 감시 매크로 - 계정 잠김 방지 다층 안전 가드 + 다중 노선 동시 감시."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from _bootstrap import ensure_venv  # noqa: E402
ensure_venv()  # venv 밖에서 호출되면 venv 만들고 자기 재실행

import argparse  # noqa: E402
import os  # noqa: E402
import random  # noqa: E402
import socket  # noqa: E402
import subprocess  # noqa: E402
import time  # noqa: E402
from dataclasses import dataclass  # noqa: E402

ENV_PATH = Path.home() / ".config" / "srt-macro" / ".env"
if ENV_PATH.exists():
    try:
        from dotenv import load_dotenv
        load_dotenv(ENV_PATH, override=False)
    except ImportError:
        pass

socket.setdefaulttimeout(30)
SEARCH_TIMEOUT_SEC = int(os.environ.get("SRT_MACRO_SEARCH_TIMEOUT_SEC", 30))
TELEGRAM_TOKEN = os.environ.get("SRT_MACRO_TELEGRAM_TOKEN", "").strip()
TELEGRAM_CHAT_ID = os.environ.get("SRT_MACRO_TELEGRAM_CHAT_ID", "").strip()
NOTIFY_SOUND = os.environ.get("SRT_MACRO_NOTIFY_SOUND", "Glass")

LOCKFILE = Path.home() / ".srt-macro.lock"
MAX_ATTEMPTS = int(os.environ.get("SRT_MACRO_MAX_ATTEMPTS", 200))
MAX_DURATION_SEC = int(os.environ.get("SRT_MACRO_MAX_DURATION_SEC", 14400))
HEALTHCHECK_MIN = int(os.environ.get("SRT_MACRO_HEALTHCHECK_MIN", 30))
GOLDEN_HOURS = set(range(7, 11)) | set(range(18, 22))


@dataclass
class Route:
    dep: str
    arr: str
    date: str
    time_from: str
    time_to: str | None = None
    seat: str = "general"
    reserved: bool = False

    @property
    def label(self) -> str:
        def fmt_time(t: str) -> str:
            return f"{t[:2]}:{t[2:4]}"
        date_pretty = f"{self.date[4:6]}/{self.date[6:8]}"
        time_range = (
            f"{fmt_time(self.time_from)}~{fmt_time(self.time_to)}"
            if self.time_to
            else f"{fmt_time(self.time_from)}~"
        )
        return f"{self.dep}→{self.arr} {date_pretty} {time_range}"

    @classmethod
    def parse(cls, spec: str) -> "Route":
        parts = spec.split(":")
        if len(parts) < 4:
            raise ValueError(
                f"--route 형식 오류: {spec!r}\n"
                f"  형식: 'dep:arr:date:time_from[:time_to[:seat]]'\n"
                f"  예시: '수서:부산:20260501:080000:120000:general'"
            )
        kwargs = {"dep": parts[0], "arr": parts[1], "date": parts[2], "time_from": parts[3]}
        if len(parts) >= 5 and parts[4]:
            kwargs["time_to"] = parts[4]
        if len(parts) >= 6 and parts[5]:
            if parts[5] not in ("general", "special", "both"):
                raise ValueError(f"--route seat 오류: {parts[5]!r}, 허용: general/special/both")
            kwargs["seat"] = parts[5]
        return cls(**kwargs)


def load_credentials() -> tuple[str, str]:
    user_id = os.environ.get("KSKILL_SRT_ID")
    pw = os.environ.get("KSKILL_SRT_PASSWORD")
    if user_id and pw:
        return user_id, pw
    # macOS Keychain fallback (다른 OS는 .env 전용)
    if sys.platform == "darwin":
        user = os.environ.get("USER", "")
        try:
            if not user_id:
                user_id = subprocess.check_output(
                    ["security", "find-generic-password", "-a", user, "-s", "KSKILL_SRT_ID", "-w"],
                    text=True, stderr=subprocess.DEVNULL,
                ).strip()
            if not pw:
                pw = subprocess.check_output(
                    ["security", "find-generic-password", "-a", user, "-s", "KSKILL_SRT_PASSWORD", "-w"],
                    text=True, stderr=subprocess.DEVNULL,
                ).strip()
        except subprocess.CalledProcessError:
            pass
    if not user_id or not pw:
        setup_path = Path(__file__).resolve().parent / "setup.py"
        sys.exit(
            "❌ SRT 자격증명을 찾을 수 없음.\n\n"
            "👉 처음 사용이라면 셋업 스크립트를 먼저 실행하세요:\n"
            f"   python3 {setup_path}\n"
        )
    return user_id, pw


class _StopRequested(Exception):
    """텔레그램 /stop 수신 시 sleep 즉시 탈출용."""


def _calc_jitter() -> tuple[float, str]:
    """시간대별 폴링 간격 계산. (초, 존이름) 반환."""
    hour = time.localtime().tm_hour
    if hour in GOLDEN_HOURS:
        return random.uniform(30, 60), "골든타임"
    if 0 <= hour < 6:
        return random.uniform(300, 600), "야간"
    return random.uniform(60, 120), "일반"


# ── interruptible sleep: 5초 tick마다 텔레그램 명령·헬스체크 수행 ──

_SLEEP_CTX: dict = {}  # main()에서 start_time, attempt, pending, last_hc 주입


def _interruptible_sleep(total: float, label: str) -> None:
    """total초 동안 5초 tick으로 쪼개 sleep. 매 tick마다 텔레그램·헬스체크 체크.
    /stop 수신 시 _StopRequested를 raise하여 즉시 탈출."""
    print(f"  → {label} 대기 {total:.0f}초", flush=True)
    elapsed = 0.0
    tick = 5.0
    while elapsed < total:
        chunk = min(tick, total - elapsed)
        time.sleep(chunk)
        elapsed += chunk

        ctx = _SLEEP_CTX
        if not ctx:
            continue

        # 텔레그램 명령 체크
        pending = [r for r in ctx["active"] if not r.reserved]
        cmd = check_telegram_commands(ctx["start"], ctx["attempt"], pending)
        if cmd == "stop":
            raise _StopRequested()

        # 헬스체크
        if HEALTHCHECK_MIN > 0 and time.time() - ctx["last_hc"] >= HEALTHCHECK_MIN * 60:
            send_healthcheck(ctx["start"], ctx["attempt"], pending)
            ctx["last_hc"] = time.time()


def notify_desktop(title: str, message: str, sound: str) -> None:
    plat = sys.platform
    try:
        if plat == "darwin":
            safe_msg = message.replace('"', '\\"')
            safe_title = title.replace('"', '\\"')
            subprocess.run(
                ["osascript", "-e",
                 f'display notification "{safe_msg}" with title "{safe_title}" sound name "{sound}"'],
                check=False, timeout=5,
            )
            subprocess.run(["afplay", f"/System/Library/Sounds/{sound}.aiff"], check=False, timeout=5)
        elif plat == "win32":
            # PowerShell toast + 시스템 비프
            ps_script = (
                f"[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null; "
                f"$n = New-Object System.Windows.Forms.NotifyIcon; "
                f"$n.Icon = [System.Drawing.SystemIcons]::Information; "
                f"$n.Visible = $true; "
                f'$n.ShowBalloonTip(5000, "{title}", "{message}", "Info"); '
                f"[Console]::Beep(800, 300)"
            )
            subprocess.run(["powershell", "-Command", ps_script], check=False, timeout=10)
        else:
            # Linux: notify-send
            subprocess.run(["notify-send", title, message], check=False, timeout=5)
    except Exception:
        pass


def notify_telegram(title: str, message: str) -> None:
    if not (TELEGRAM_TOKEN and TELEGRAM_CHAT_ID):
        return
    try:
        import requests
        requests.post(
            f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage",
            json={"chat_id": TELEGRAM_CHAT_ID, "text": f"*{title}*\n{message}", "parse_mode": "Markdown"},
            timeout=10,
        )
    except Exception as e:
        print(f"  ⚠ 텔레그램 푸시 실패: {e}")


def notify(title: str, message: str, sound: str = NOTIFY_SOUND) -> None:
    notify_desktop(title, message, sound)
    notify_telegram(title, message)


def send_healthcheck(start_time: float, attempt: int, pending: list["Route"]) -> None:
    """텔레그램으로만 발송 (macOS 알림 X). 매크로 살아있음 신호."""
    if not (TELEGRAM_TOKEN and TELEGRAM_CHAT_ID):
        return
    elapsed = int(time.time() - start_time)
    h, m = elapsed // 3600, (elapsed % 3600) // 60
    elapsed_str = f"{h}h {m}m" if h else f"{m}m"
    labels = [r.label for r in pending[:3]]
    if len(pending) > 3:
        labels.append(f"외 {len(pending)-3}개")
    msg = f"경과 {elapsed_str} | 사이클 {attempt}/{MAX_ATTEMPTS} | 대기 {len(pending)}개\n" + "\n".join(labels)
    notify_telegram("🟢 SRT 매크로 alive", msg)


_LAST_UPDATE_ID = 0


def init_telegram_offset() -> None:
    """매크로 시작 시점의 update_id를 baseline으로 잡아 이전 메시지 무시."""
    global _LAST_UPDATE_ID
    if not (TELEGRAM_TOKEN and TELEGRAM_CHAT_ID):
        return
    try:
        import requests
        r = requests.get(f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/getUpdates",
                         params={"timeout": 0}, timeout=5)
        updates = r.json().get("result", [])
        if updates:
            _LAST_UPDATE_ID = max(u["update_id"] for u in updates)
    except Exception:
        pass


def check_telegram_commands(start_time: float, attempt: int, pending: list["Route"]) -> str | None:
    """본인 chat_id에서 온 명령만 처리. returns: 'stop' | None."""
    global _LAST_UPDATE_ID
    if not (TELEGRAM_TOKEN and TELEGRAM_CHAT_ID):
        return None
    try:
        import requests
        r = requests.get(f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/getUpdates",
                         params={"offset": _LAST_UPDATE_ID + 1, "timeout": 0}, timeout=5)
        updates = r.json().get("result", [])
    except Exception:
        return None
    for u in updates:
        _LAST_UPDATE_ID = max(_LAST_UPDATE_ID, u["update_id"])
        msg = u.get("message", {})
        if str(msg.get("chat", {}).get("id", "")) != TELEGRAM_CHAT_ID:
            continue
        text = msg.get("text", "").strip().lower().lstrip("/")
        if text in ("stop", "kill", "abort", "exit", "quit"):
            notify_telegram("🛑 SRT 매크로 종료", "원격 명령으로 정상 종료.")
            return "stop"
        if text == "status":
            send_healthcheck(start_time, attempt, pending)
        elif text == "help":
            notify_telegram(
                "🆘 사용 가능한 명령",
                "/stop · 매크로 종료\n/status · 즉시 상태 조회\n/help · 이 도움말",
            )
    return None


def search_with_timeout(srt, route: Route):
    import threading
    result_box: list = []
    error_box: list = []

    def _search():
        try:
            kwargs = {"time_limit": route.time_to} if route.time_to else {}
            result_box.append(
                srt.search_train(route.dep, route.arr, route.date, route.time_from,
                                 available_only=False, **kwargs))
        except Exception as e:
            error_box.append(e)

    t = threading.Thread(target=_search, daemon=True)
    t.start()
    t.join(timeout=SEARCH_TIMEOUT_SEC)
    if t.is_alive():
        raise TimeoutError(f"search_train > {SEARCH_TIMEOUT_SEC}s")
    if error_box:
        raise error_box[0]
    return result_box[0]


def find_available(trains, seat_pref: str):
    from SRT import SeatType
    for t in trains:
        if seat_pref in ("general", "both") and t.general_seat_available():
            return t, SeatType.GENERAL_FIRST
        if seat_pref in ("special", "both") and t.special_seat_available():
            return t, SeatType.SPECIAL_FIRST
    return None, None


def poll_route(srt, route: Route, dry_run: bool) -> str:
    """단일 노선 1회 폴링.

    returns: 'reserved' | 'sold-out' | 'invalid'
           | 'congested' (NetFunnel 일시 혼잡)
           | 'relogin'   (세션 만료)
           | 'error'     (기타)
    """
    from SRT import Adult
    from SRT.errors import SRTNetFunnelError, SRTNotLoggedInError, SRTResponseError
    try:
        trains = search_with_timeout(srt, route)
        target, seat_type = find_available(trains, route.seat)
        if target:
            print(f"  🎯 [{route.label}] 좌석 발견: {target}")
            if dry_run:
                print(f"     (--dry-run: 예약 생략)")
                route.reserved = True
                return "reserved"
            res = srt.reserve(target, passengers=[Adult(1)], special_seat=seat_type)
            print(f"  ✅ [{route.label}] 예약 성공!\n{res}")
            notify("🚄 SRT 예약 성공!", f"{route.label} | 10분 내 결제!")
            route.reserved = True
            return "reserved"
        print(f"  [{route.label}] 운행 {len(trains)}대, 가용 좌석 없음")
        return "sold-out"
    except ValueError as e:
        print(f"  ❌ [{route.label}] 입력 오류 (영구 제외): {e}")
        return "invalid"
    except SRTNetFunnelError as e:
        print(f"  ⏳ [{route.label}] NetFunnel 혼잡 (일시적): {e}")
        return "congested"
    except SRTNotLoggedInError as e:
        print(f"  🔄 [{route.label}] 세션 만료: {e}")
        return "relogin"
    except SRTResponseError as e:
        print(f"  ⚠ [{route.label}] API 에러: {e}")
        return "error"
    except Exception as e:
        print(f"  ⚠ [{route.label}] 예외 {type(e).__name__}: {e}")
        return "error"


def parse_routes(args) -> list[Route]:
    routes: list[Route] = []
    if args.dep:
        if not (args.arr and args.date and args.time_from):
            sys.exit("❌ --dep 사용 시 --arr/--date/--time-from 필수")
        routes.append(Route(dep=args.dep, arr=args.arr, date=args.date,
                            time_from=args.time_from, time_to=args.time_to, seat=args.seat))
    for spec in args.route:
        try:
            routes.append(Route.parse(spec))
        except ValueError as e:
            sys.exit(f"❌ {e}")
    if not routes:
        sys.exit("❌ --dep+--arr+--date+--time-from 또는 --route 중 최소 1개 필요")
    return routes


def main() -> None:
    p = argparse.ArgumentParser(
        description="SRT 매진 감시 매크로 (다중 노선 지원)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="예시:\n"
               "  단일 노선:\n"
               "    --dep 수서 --arr '울산(통도사)' --date 20260429 --time-from 080000\n"
               "  왕복 (다중 노선):\n"
               "    --route '수서:울산(통도사):20260429:080000:092000:general' \\\n"
               "    --route '울산(통도사):수서:20260501:180000:210000:general'",
    )
    p.add_argument("--dep", help="출발역 (단일 노선)")
    p.add_argument("--arr", help="도착역 (단일 노선)")
    p.add_argument("--date", help="YYYYMMDD (단일 노선)")
    p.add_argument("--time-from", dest="time_from", help="HHMMSS (단일 노선)")
    p.add_argument("--time-to", default=None, dest="time_to", help="HHMMSS 상한 (선택)")
    p.add_argument("--seat", default="general", choices=["general", "special", "both"])
    p.add_argument("--route", action="append", default=[],
                   help="다중 노선: 'dep:arr:date:time_from[:time_to[:seat]]' (반복 가능)")
    p.add_argument("--dry-run", action="store_true", help="검색만, 예약 안 함")
    args = p.parse_args()

    routes = parse_routes(args)

    if LOCKFILE.exists():
        sys.exit(f"❌ 이미 실행 중. PID 확인 후 {LOCKFILE} 삭제.")
    LOCKFILE.write_text(str(os.getpid()))

    try:
        from SRT import SRT
        from SRT.errors import SRTLoginError

        user_id, pw = load_credentials()
        print(f"[로그인] {user_id[:3]}***")
        try:
            srt = SRT(user_id, pw)
        except SRTLoginError as e:
            sys.exit(f"❌ 로그인 실패. 비밀번호 확인 후 재등록. 재시도 안 함: {e}")
        print(f"✓ 로그인 성공. {len(routes)}개 노선 감시 시작:")
        for r in routes:
            print(f"  - {r.label} ({r.seat})")
        print()

        if not args.dry_run:
            init_telegram_offset()
            start_msg = f"{len(routes)}개 노선 감시 시작\n" + "\n".join(f"- {r.label}" for r in routes)
            if HEALTHCHECK_MIN > 0:
                start_msg += f"\n\n헬스체크: {HEALTHCHECK_MIN}분 간격"
            start_msg += "\n원격 명령: /stop · /status · /help"
            notify_telegram("🚀 SRT 매크로 시작", start_msg)

        active = list(routes)
        start = time.time()
        last_hc = time.time()
        fails = 0

        # interruptible sleep 컨텍스트 공유
        _SLEEP_CTX.update({"start": start, "active": active, "attempt": 0, "last_hc": last_hc})

        for attempt in range(1, MAX_ATTEMPTS + 1):
            _SLEEP_CTX["attempt"] = attempt

            if time.time() - start > MAX_DURATION_SEC:
                print(f"⏱ 최대 시간({MAX_DURATION_SEC}s) 도달. 종료.")
                return

            pending = [r for r in active if not r.reserved]
            if not pending:
                print(f"\n🎉 모든 노선 예약 완료!")
                notify("🚄 SRT 모든 노선 완료!",
                       f"{len(routes)}개 전부 예약. 10분 내 결제!")
                return

            now = time.strftime("%H:%M:%S")
            print(f"[{now}] 사이클 {attempt}/{MAX_ATTEMPTS} (대기 중 {len(pending)}개)")

            cycle_error = False
            cycle_congested = False
            need_relogin = False
            for i, route in enumerate(pending):
                result = poll_route(srt, route, args.dry_run)
                if result == "invalid":
                    active.remove(route)
                elif result == "congested":
                    cycle_congested = True
                elif result == "relogin":
                    need_relogin = True
                elif result == "error":
                    cycle_error = True
                if i < len(pending) - 1:
                    time.sleep(random.uniform(3, 7))

            if args.dry_run:
                print(f"\n(--dry-run: 1 사이클 완료, 종료)")
                return

            if not [r for r in active if not r.reserved]:
                print(f"\n🎉 모든 노선 예약 완료!")
                notify("🚄 SRT 모든 노선 완료!", f"{len(routes)}개 전부 예약. 10분 내 결제!")
                return

            # 세션 만료 → 재로그인 1회 시도 (실패 시 종료)
            if need_relogin:
                print("  🔄 세션 만료 — 재로그인 시도")
                try:
                    srt = SRT(user_id, pw)
                    print("  ✓ 재로그인 성공")
                    _interruptible_sleep(random.uniform(10, 20), "재로그인 후 안정화")
                    continue
                except SRTLoginError as e:
                    notify_telegram("❌ SRT 매크로 종료", f"재로그인 실패: {e}")
                    sys.exit(f"❌ 재로그인 실패. 비밀번호 확인: {e}")

            # NetFunnel 혼잡 — fails 카운터 안 올림, 짧은 대기 후 재시도
            if cycle_congested and not cycle_error:
                congestion_wait = random.uniform(30, 60)
                print(f"  ⏳ NetFunnel 혼잡 — {congestion_wait:.0f}초 후 재시도")
                _interruptible_sleep(congestion_wait, "NetFunnel 대기")
                continue

            if cycle_error:
                fails += 1
                if fails >= 5:
                    notify_telegram("❌ SRT 매크로 종료", f"연속 사이클 실패 {fails}회. 안전 종료.")
                    sys.exit(f"❌ 연속 사이클 실패 {fails}회. 안전 종료.")
                backoff = min(120 * 2 ** fails, 900)
                _interruptible_sleep(backoff, f"에러 백오프")
                continue
            fails = 0

            # 사이클 종료 직후 즉시 1회 체크 (sleep 진입 전)
            pending_now = [r for r in active if not r.reserved]
            if check_telegram_commands(start, attempt, pending_now) == "stop":
                return

            if HEALTHCHECK_MIN > 0 and time.time() - _SLEEP_CTX["last_hc"] >= HEALTHCHECK_MIN * 60:
                send_healthcheck(start, attempt, pending_now)
                _SLEEP_CTX["last_hc"] = time.time()

            delay, zone = _calc_jitter()
            _interruptible_sleep(delay, zone)

        print("종료: 시도 횟수 소진. 일부 좌석 못 잡음.")
    except _StopRequested:
        print("🛑 텔레그램 /stop 명령 수신. 정상 종료.")
    finally:
        LOCKFILE.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
