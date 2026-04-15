# Post-Compile Actions

이 문서는 compile 이후 바로 이어지는 후속 동작을 정의한다.

## 목표

- 현재 `TODO`를 텔레그램으로 바로 전달한다.
- 약속성 로그를 놓치지 않고 캘린더 처리 후보로 모은다.
- 날짜나 시간이 불명확하면 질문이 필요한 후보로 남기고, 충분히 명확하면 캘린더 추가 검토 대상으로 남긴다.

## 기본 흐름

1. `scripts/compile.sh`가 저장소를 먼저 pull 받은 뒤 compile 가능한 산출물을 갱신한다.
2. 이 실행 안에서 `scripts/compile-todo-state.sh`가 `TODO` 상태와 최근 완료를 raw 로그 기준으로 갱신한다.
3. 이어서 `scripts/compile-today-focus.sh`가 `Wiki/Self/Today.md`와 `Wiki/Self/TODO.md`의 `오늘 글쓰기 주제`를 갱신한다.
4. `scripts/send-post-compile-todo.sh`로 `Wiki/Self/TODO.md`의 `현재 할 일`과 `오늘 글쓰기 주제`를 텔레그램 봇으로 보낸다.
5. `scripts/build-calendar-candidates.sh`로 당일 `Daily/YYYY/YYYY-MM-DD.md`에서 약속 후보를 추린다.
6. 결과는 `Meta/calendar-candidates.md`에 `추가 가능`, `이미 지난 일정`, `질문 필요` 상태로 쓴다.
7. 현재 shell compile은 실제 Google Calendar 이벤트 생성까지 자동으로 실행하지 않는다.
8. 날짜나 시간이 부족하면 그 항목만 사용자에게 질문한다.

## 캘린더 후보 규칙

- 키워드 예시:
  `약속`, `미팅`, `회의`, `파티`, `만나`, `방문`, `병원`, `생일`, `출발`, `예약`, `제사`
- `ready`:
  날짜 힌트와 시간 힌트가 같이 있는 항목
- `needs_question`:
  날짜 또는 시간 힌트가 빠진 항목

## 질문 규칙

- 날짜가 없으면:
  어느 날짜로 넣을지 물어본다.
- 시간이 없으면:
  시작 시각을 물어본다.
- 제목이 모호하면:
  캘린더 제목을 어떻게 적을지 물어본다.
- 장소가 있으면:
  설명이나 위치에 함께 넣는다.

## 캘린더 추가 원칙

- 명확한 항목만 캘린더에 넣는다.
- 추가가 끝나면 생성된 이벤트 정보나 공유 링크를 사용자에게 다시 보낸다.
- 추정만으로 임의 시간을 넣지 않는다.

## 실행 예시

```bash
scripts/compile.sh
scripts/compile.sh --dry-run
scripts/compile.sh --skip-pull
scripts/post-compile.sh --dry-run
```
