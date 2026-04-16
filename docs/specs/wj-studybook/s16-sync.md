# s16-sync: /wj:studybook sync — 동기화 경로 안내 (icloud/obsidian/git)

## 배경
모바일에서 책처럼 읽으려면 books/ 디렉토리가 동기화되는 위치에 있어야 함. 이 task는 **실제 외부 전송은 하지 않고**, symlink 또는 경로 안내만 제공 (P4: Local-first 원칙 준수).

## 변경 범위
- `commands/studybook.md` (sync 라우팅)
- `lib/sync.sh` 신규

## 명령어
```
/wj:studybook sync           # 활성 프로필의 sync_to 설정대로 실행
/wj:studybook sync --target icloud
/wj:studybook sync --target obsidian --vault ~/Documents/MyVault
/wj:studybook sync --target git
/wj:studybook sync status    # 현재 sync 상태 표시
```

## 분기별 동작

### icloud
```
~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Studybook/ 자동 감지
→ 없으면 ~/Library/Mobile Documents/com~apple~CloudDocs/Studybook/
→ books/<profile>/ → 위 경로에 symlink 생성 (또는 cp -R 옵션)
```

### obsidian
```
사용자가 vault 경로 입력
→ <vault>/Studybook/ 에 symlink
→ Obsidian이 즉시 인식 (frontmatter, wikilinks 호환)
```

### git
```
~/.studybook/books/<profile>/ 에 git init (없으면)
→ 안내: "git remote add origin <url> 후 git push로 백업하세요"
→ 자동 push X (사용자 명시)
```

### none
```
현재 books/ 위치 안내만 출력
```

## 핵심 함수
- `sync_detect_icloud_path()` — Mac iCloud 경로 자동 감지
- `sync_create_symlink(src, dst)` — symlink + 충돌 검사
- `sync_status()` — 현재 어디로 sync 되어있나 표시

## 의존
- s13 (books 존재 전제)

## 검증
```bash
# 각 sync_to 값별 명령 실행 → 적절한 메시지/symlink 검증
# 외부 전송 0 확인 (네트워크 호출 grep)
```
