---
description: 학습 노트 자동 수집 재개
argument-hint: ""
---

아래 스크립트를 실행하고 **출력 결과를 그대로 사용자에게 보여주세요.**

```bash
set -euo pipefail

source "${CLAUDE_PLUGIN_ROOT}/lib/config-helpers.sh"

_pause_file="$(get_studybook_dir)/.paused"

if [ ! -f "$_pause_file" ]; then
  echo "현재 일시정지 상태가 아닙니다"
  exit 0
fi

rm "$_pause_file"

echo "자동 수집이 재개되었습니다."
```
