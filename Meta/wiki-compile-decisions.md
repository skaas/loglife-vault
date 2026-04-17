# Wiki Compile Decisions

이 파일은 `Meta/wiki-compile-queue.md`에서 나온 warning에 대한 사람 판단을 기록한다.

## 규칙

- 각 항목은 source 경로를 `## Inbox/...` 형식 헤더로 쓴다.
- `action`은 `promote`, `hold`, `ignore` 중 하나다.
- `target`은 `promote`일 때만 쓰고, 여러 개면 쉼표로 구분한다.
- `comment`는 선택이지만 가능한 한 짧게 남긴다.
- compile은 이 파일을 읽어 `promote`는 `Wiki` 문서의 `수동 승인 반영` 섹션에 반영하고, `hold`와 `ignore`는 queue에서 제외한다.

## 예시

- heading: `## Inbox/Telegram/2026-04-14/942071338.md`
- action: `promote`
- target: `Wiki/Self/Tensions.md`
- comment: `후배에게 베푸는 마음과 손해감이 혼란스러워. 나도 많이 받으며 자랐는데, 쏘는게 어렵네. 라는 내면의 고민?`

## Draft Review Note

아래는 자동 초안이다. 그대로 확정하지 말고 `action`, `target`, `comment`를 검토한 뒤 compile하는 전제를 둔다.

## Inbox/Telegram/2026-04-08/942071267.md
action: ignore
comment: Wiki 승격 대신 캘린더 로그 후보로 다룬다.

## Inbox/Telegram/2026-04-14/942071330.md
action: promote
target: Wiki/Self/Open Questions.md
comment: 로컬 모델과 무제한 토큰보다 실제 코딩 품질이 중요한지로 이어지는 열린 질문이다.

## Inbox/Telegram/2026-04-14/942071338.md
action: promote
target: Wiki/Self/Tensions.md
comment: 후배에게 베푸는 마음과 손해감이 혼란스러워. 나도 많이 받으며 자랐는데, 쏘는게 어렵네. 라는 내면의 고민?

## Inbox/Text/[시놉시스]나는 용사였던 기억을.txt
action: ignore
comment: 같은 아이디어의 시놉시스 초안 중복본으로 본다.

## Inbox/Text/나는 용사였던 기억을.txt
action: promote
target: Wiki/Ideas/나는-용사였던-기억을.md
comment: 노년의 용사, 치매, 기록, 죽이지 않는 마왕이라는 반전이 함께 있는 판타지 아이디어다.

## Inbox/Text/돈이되는것.markdown
action: promote
target: Wiki/Self/Tensions.md, Wiki/Themes/일-진로-창업.md
comment: 좋아하는 것과 돈이 되는 것의 충돌이 선명한 경력/정체성 메모다.

## Inbox/Text/스마트 드롭 시스템.txt
action: promote
target: Wiki/Projects/스테이지-난이도-마법사.md
comment: 유저 행동과 보상 조정을 연결하는 설계 자산으로 본다.

## Inbox/Text/Likeme.txt
action: promote
target: Wiki/Themes/가족-돌봄.md
comment: 아이들이 다래끼가 자주 나는 상황에서 쓴 돌봄과 미안함의 기록이다.

## Inbox/Text/게임 시놉.txt
action: promote
target: Wiki/Ideas/블러드-던전-tv.md
comment: 던전 생존 예능과 로그라이트 반복 구조가 결합된 게임 아이디어다.

## Inbox/Text/게임아이디어-무한 동물원.txt
action: ignore
comment: 무한 동물원 메모의 중복 초안으로 본다.

## Inbox/Text/동물 인권.txt
action: promote
target: Wiki/Ideas/동물-인권.md
comment: 언어를 가진 동물과 권리 문제를 중심 갈등으로 두는 세계관 메모다.

## Inbox/Text/무한 동물원.txt
action: promote
target: Wiki/Ideas/무한-동물원.md
comment: 동물 생존과 흥행이 맞물리는 운영 게임 아이디어다.

## Inbox/Text/여름.txt
action: hold
comment: 내 마음을 적은 짧은 메모지만 현재는 안정적인 자기서술로 올리기엔 애매하다.

## Inbox/Text/영생 vs 자유.txt
action: promote
target: Wiki/Ideas/영생-vs-자유.md
comment: 영생과 자유를 서로 다른 인간 집단의 조건으로 대립시키는 세계관 메모다.

## Inbox/Telegram/2026-04-08/942071265.md
action: ignore
comment: 당일 출근 형태를 적은 운영 로그로 종료한다.

## Inbox/Telegram/2026-04-08/942071266.md
action: promote
target: Wiki/Timeline/2026.md
comment: 전배 또는 이동 맥락에서 외부 응원을 받은 장면으로 본다.

## Inbox/Telegram/2026-04-08/942071269.md
action: ignore
comment: 일회성 소비 또는 미용 로그로 종료한다.

## Inbox/Telegram/2026-04-08/942071270.md
action: ignore
comment: 현재 위키 축에서는 관계 기록으로 승격할 근거가 약하다.

## Inbox/Telegram/2026-04-09/942071286.md
action: ignore
comment: 독서 시작 로그는 독후감이나 별도 생각 메모가 있을 때만 승격한다.

## Inbox/Telegram/2026-04-10/942071290.md
action: ignore
comment: 일회성 구매 로그로 종료한다.

## Inbox/Telegram/2026-04-11/942071296.md
action: ignore
comment: 식사 로그로 종료한다.

## Inbox/Telegram/2026-04-11/942071298.md
action: ignore
comment: 장소 체험 로그로 종료한다.

## Inbox/Telegram/2026-04-11/942071304.md
action: ignore
comment: 단순 시청 로그로 종료한다.

## Inbox/Telegram/2026-04-12/942071307.md
action: ignore
comment: 식사 로그로 종료한다.

## Inbox/Telegram/2026-04-12/942071310.md
action: ignore
comment: 식사 로그로 종료한다.

## Inbox/Telegram/2026-04-13/942071314.md
action: promote
target: Wiki/Self/Open Questions.md, Wiki/Timeline/2026.md
comment: 소설을 장면화하며 읽는 습관을 만들겠다는 자기 관찰로 본다.

## Inbox/Text/돈이되는것.markdown
action: promote
target: Wiki/Self/Tensions.md
