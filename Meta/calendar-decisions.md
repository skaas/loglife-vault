# Calendar Decisions

이 파일은 `Meta/calendar-candidates.md` 후보에 대한 사람 판단을 기록한다.

## 규칙

- 각 항목은 `## tg:update_id:...` 또는 `## daily:...` 형식 헤더를 쓴다.
- `action`은 `create`, `log`, `hold`, `ignore` 중 하나를 쓴다.
- `date`, `time`, `title`, `comment`는 선택이지만 가능한 한 남긴다.
- 날짜나 시간이 모호한 항목은 먼저 값을 채우고, 확정되면 `action`을 적는다.

## 예시

## tg:update_id:942071267
action: log
date: 2026-04-09
time:
title: 창균님과 약속
comment: 냉삼집

## tg:update_id:942071288
action: create
date: 2026-04-18
time: 12:00
title: 다음주 토요일 아내 생일 점심은 부모님과 저녁은 옥상 파티
comment:

## tg:update_id:942071356
action: 
date: 2026-04-16
time: 14:41
title: 다다음주 재윤님 은석님 술약속
comment:
