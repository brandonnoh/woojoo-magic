# s9-session-end-hook: SessionEnd hook — 세션 단위 통합

## 배경
Stop hook(s3)은 응답 1개씩 점진 수집. SessionEnd hook은 세션 종료 시 transcript 전체를 다시 훑어 누락분 보완 + 세션 요약 노트 생성.

## 변경 범위
- `src/wj-studybook/hooks/capture-session-end.sh` 신규
- `src/wj-studybook/hooks/hooks.json` 수정 (SessionEnd 등록)
- `tests/wj-studybook/test-capture-session-end.bats`

## SessionEnd hook 입력
```json
{
  "session_id": "...",
  "transcript_path": "...",
  "cwd": "...",
  "end_reason": "logout | clear | resume"
}
```

## 흐름
1. `end_reason == "resume"`이면 즉시 종료 (세션 계속됨)
2. transcript_path JSONL 전체 파싱
3. 모든 assistant text 블록 추출 (`select(.type=="assistant")|.message.content[]|select(.type=="text").text`)
4. filter.sh의 is_educational 통과한 것만 후보
5. 각 후보의 SHA256 hash로 inbox와 중복 검사 (file content hash 비교)
6. 신규 후보만 inbox에 ULID 부여하여 추가
7. 세션 요약 노트 생성: `~/.studybook/inbox/session-<sessionId>.md` (type=session_summary, total_messages, captured_count, end_reason 등)
8. tree.json unsorted_count += 신규 추가 수

## 핵심 함수
- `extract_all_assistant_texts(transcript_path)` — JSONL 파싱
- `is_already_captured(text_hash)` — inbox SHA 인덱스 조회
- `write_session_summary(session_id, stats)` — 요약 노트 작성

## 의존
- s3 (capture-stop과 hash 인덱스 공유)
- s4 (filter)
- s5 (index update)

## 검증
```bash
# 샘플 transcript JSONL 준비 후
bash src/wj-studybook/hooks/capture-session-end.sh < sample-input.json
# session-<id>.md 생성 확인 + 누락 발화 보완 확인 + 중복 0 확인
```
