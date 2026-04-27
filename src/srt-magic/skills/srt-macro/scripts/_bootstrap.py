"""venv 자동 셋업 + 자기 재실행 부트스트랩.

처음 호출 시 ~/.config/srt-macro/.venv 를 만들고 의존성 설치 후
같은 스크립트를 venv 인터프리터로 재실행한다. 이미 venv 안이면 무동작.
"""
import os
import subprocess
import sys
from pathlib import Path

ENV_DIR = Path.home() / ".config" / "srt-macro"
VENV = ENV_DIR / ".venv"
PY = VENV / "bin" / "python"
PLUGIN_ROOT = Path(__file__).resolve().parents[3]
REQUIREMENTS = PLUGIN_ROOT / "requirements.txt"


def _create_venv() -> None:
    print(f"⚙ 초기 셋업: {VENV} 생성 중 (~30초)", flush=True)
    ENV_DIR.mkdir(parents=True, exist_ok=True)
    subprocess.run([sys.executable, "-m", "venv", str(VENV)], check=True)
    pip = VENV / "bin" / "pip"
    subprocess.run([str(pip), "install", "--upgrade", "pip", "--quiet"], check=False)
    if REQUIREMENTS.exists():
        subprocess.run([str(pip), "install", "-r", str(REQUIREMENTS), "--quiet"], check=True)
    else:
        subprocess.run([str(pip), "install", "SRTrain", "python-dotenv", "requests", "--quiet"], check=True)
    print("✓ 셋업 완료, 매크로 재실행", flush=True)


def ensure_venv() -> None:
    if not VENV.exists():
        _create_venv()
    # sys.prefix는 venv 안에서는 venv 경로, 밖에서는 원본 python prefix.
    # sys.executable.resolve()를 쓰면 venv python이 base python으로 풀려서 오판하므로 사용 금지.
    if str(Path(sys.prefix)) != str(VENV):
        os.execv(str(PY), [str(PY), *sys.argv])
