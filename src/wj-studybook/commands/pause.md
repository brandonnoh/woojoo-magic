---
description: 학습 노트 자동 수집 일시정지
argument-hint: ""
---

아래 스크립트를 실행하고 **출력 결과를 그대로 사용자에게 보여주세요.**

```bash
set -euo pipefail

source "${CLAUDE_PLUGIN_ROOT}/lib/config-helpers.sh"

_pause_file="$(get_studybook_dir)/.paused"

if [ -f "$_pause_file" ]; then
  echo "이미 일시정지 중입니다"
  exit 0
fi

mkdir -p "$(get_studybook_dir)"
touch "$_pause_file"

echo "자동 수집이 일시정지되었습니다. 재개하려면: /wj-studybook:resume"
```
