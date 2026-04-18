---
description: 처음 설정 마법사 — /wj-studybook:config init 단축키
---

처음 사용자를 위한 설정 마법사를 시작합니다.

```bash
set -euo pipefail
# shellcheck source=/dev/null
. "${CLAUDE_PLUGIN_ROOT}/lib/config-wizard.sh"
wizard_main
```
