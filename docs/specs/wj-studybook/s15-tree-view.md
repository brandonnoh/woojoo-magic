# s15-tree-view: /wj:studybook tree — 분류 트리 시각화

## 배경
사용자가 현재 분류 상태를 한눈에 파악.

## 변경 범위
- `commands/studybook.md` (tree 라우팅)
- `lib/tree-view.sh` 신규

## 명령어
```
/wj:studybook tree
/wj:studybook tree --depth 2
/wj:studybook tree --json
```

## 출력 예시
```
📚 woojoo (intermediate, ko)
├── 📁 개발 (47)
│   ├── 📁 프론트엔드 (24)
│   │   ├── react (18)
│   │   └── css (6)
│   └── 📁 백엔드 (23)
│       ├── api-design (10)
│       └── database (13)
├── 📁 디자인 (12)
│   └── ui-패턴 (12)
└── 📁 알고리즘 (8)
    └── 다이나믹-프로그래밍 (8)

미분류 inbox: 5개
마지막 갱신: 2026-04-16 15:01
```

## 핵심 함수
- `tree_render(tree_json, max_depth)` — ASCII 트리 출력
- `tree_render_json(tree_json)` — JSON 그대로 출력 (디버깅)

## 의존
- s5 (tree.json 존재)

## 검증
```bash
# 샘플 tree.json 준비 후
bash src/wj-studybook/lib/tree-view.sh
# ASCII 트리 출력 확인
```
