# Loglife Vault

이 저장소의 목표는 삶의 기록을 단순히 보관하는 것이 아니라, 원본 기록을 시간이 지나도 남는 자기지식과 공개 가능한 프로필로 컴파일하는 것이다.

- `Inbox`에는 원본을 남긴다.
- `Daily`에는 날짜 맥락을 정리한다.
- `Wiki`에는 반복되는 자기지식을 축적한다.
- `Wiki`에는 최근 진단, 해야 할 일, 개념 정리 같은 해석 결과도 함께 축적한다.
- `Wiki`에는 오늘 하나만 잡는 포커스도 별도 문서로 남긴다.
- `site`에는 외부 공개 가능한 결과물만 다시 컴파일한다.
- `Meta`에는 이 과정을 안정적으로 유지하기 위한 규칙을 둔다.

## 핵심 목표

- 원본 기록을 잃지 않고 남긴다.
- 반복되는 생각, 성향, 관계, 경력, 질문을 `Wiki`로 축적한다.
- 최근 변화, 문제 후보, 다음 행동도 컴파일 결과로 남긴다.
- 내부 지식과 공개용 자기소개를 분리한다.
- 표현 충돌, 파일명 규칙, 근거 링크 같은 품질을 관리한다.
- 시간이 갈수록 `내가 어떤 사람인지` 더 선명하게 만든다.

## 비목표

- 모든 기록을 다 예쁘게 정리하는 것
- 모든 해석을 사실처럼 확정하는 것
- `Wiki` 전체를 그대로 공개하는 것

## 기본 원칙

- 원본 입력은 `Inbox/Telegram`과 `Inbox/Text`에 그대로 쌓는다.
- 사진 공유 링크와 웹 링크는 별도 채널로 나누지 않고, 입력 텍스트 안의 링크로 함께 다룬다.
- 하루 단위 맥락은 `Daily`에서 정리한다.
- 사람, 사건, 주제, 질문 같은 연결 가능한 지식은 `Wiki`에 누적한다.
- 공개 가능한 자기소개와 포트폴리오 성격의 결과물은 `site`에 별도로 만든다.
- 운영 규칙과 점검 메모는 `Meta`에 둔다.

## 기록 흐름

1. 텔레그램이나 텍스트 입력으로 생각, 메모, 사진 링크, 웹 링크를 남긴다.
2. 원본은 입력 채널에 따라 `Inbox/Telegram` 또는 `Inbox/Text`에 저장된다.
3. 텍스트에 링크가 있으면 링크 내용을 확인하고 핵심을 짧게 요약한다.
4. 하루 단위 요약과 맥락은 `Daily`에 반영한다.
5. 실행할 일은 `TODO:`, `[ ]`, `[]`, `- [ ]` 같은 표식으로 적는다.
6. 완료한 일은 `DONE:`, `[x]`, `- [x]` 같은 표식으로 적는다.
7. 컴파일할 때는 `Wiki/Self/Today.md`에 오늘 한 가지 TODO 또는 짧은 글쓰기 프롬프트 1개를 만들고, `Wiki/Self/TODO.md`에는 `오늘 글쓰기 주제`를 같이 갱신한다.
8. 반복되는 인물, 사건, 주제, 질문은 `Wiki` 문서로 승격한다.
9. 필요하면 최근 진단, 다음 행동, 개념 정리와 추가 질문도 `Wiki`에 함께 남긴다.
10. 공개해도 되는 자기소개 정보만 골라 `site/index.html` 같은 공개용 산출물로 다시 컴파일한다.

## TODO 표식 규칙

- `Inbox/Text`와 `Inbox/Telegram`에 `TODO:`가 있으면 실행 후보로 본다.
- `Inbox/Text`와 `Inbox/Telegram`에 `[ ]`, `[]`, `- [ ]`가 있으면 실행 후보로 본다.
- `Inbox/Text`와 `Inbox/Telegram`에 `DONE:`가 있으면 완료 신호로 본다.
- `Inbox/Text`와 `Inbox/Telegram`에 `[x]`, `- [x]`가 있으면 완료 신호로 본다.
- 같은 일을 완료한 경우 [TODO.md](<Wiki/Self/TODO.md>)의 `현재 할 일`에서 내리고 `최근 완료`로 옮긴다.
- 원문이 특정 TODO들을 가리키며 `투두에서 삭제하자`처럼 명시 삭제를 지시하면 해당 항목은 `현재 할 일`에서만 제거한다.
- 완료 메모가 있으면 가능한 한 같이 남긴다.

## 링크 처리 원칙

- 링크가 포함된 기록은 원문 링크를 보존한다.
- 링크 요약은 원본을 대체하지 않고, 원본 이해를 돕는 보조 메모로 남긴다.
- 요약에는 가능한 한 링크의 주제, 핵심 주장, 기록과의 관련성을 짧게 적는다.

## Vault 링크 규칙

- Vault 안의 문서끼리 연결할 때는 macOS 절대경로 같은 OS 경로를 쓰지 않는다.
- 내부 링크는 항상 Vault 상대경로로 쓴다.
- 공백이나 특수 문자가 있는 경로는 `[label](<relative/path>)` 형식을 쓴다.
- 외부 웹 링크만 `https://...` 절대 URL을 유지한다.
- 이 규칙을 지키면 Obsidian에서 바로 열리고, Mac과 Windows 사이에서도 링크 형식이 깨지지 않는다.

## Post-Compile

- compile 기본 진입점은 `scripts/compile.sh`다.
- 이 스크립트는 현재 `scripts/compile-today-focus.sh`를 호출해 `Wiki/Self/Today.md`와 `Wiki/Self/TODO.md`의 `오늘 글쓰기 주제`를 함께 갱신한다.
- compile 이후 기본 후속 동작은 [Meta/post-compile.md](<Meta/post-compile.md>)를 따른다.
- `scripts/post-compile.sh`는 아래를 한 번에 처리한다.
  compile 실행, TODO 텔레그램 전송, 캘린더 후보 리포트 생성
- TODO 전송에는 `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`가 필요하다.
- 로컬에서는 [`.env.local`](</Users/user/Documents/loglife/loglife-vault/.env.local>) 파일에 넣는 방식을 기본으로 쓴다.
- 예시는 [`.env.example`](</Users/user/Documents/loglife/loglife-vault/.env.example>) 에 있다.
- 캘린더 후보는 `Meta/calendar-candidates.md`에 쓰고, 날짜/시간이 모호하면 사용자에게 질문한다.

```bash
scripts/compile.sh
scripts/post-compile.sh --dry-run
scripts/post-compile.sh
```

## Windows 호환 규칙

- 파일명과 폴더명에는 Windows 금지 문자 `<>:"/\\|?*`를 쓰지 않는다.
- 파일명 끝의 공백과 점도 금지한다.
- 커밋 전에는 `scripts/check-windows-paths.sh --staged`로 검사한다.
- 이 저장소는 `.githooks/pre-commit`에서 같은 검사를 자동으로 실행하도록 맞춘다.

## 공개 프로필 원칙

- `Wiki`는 내부 지식 베이스이고, 그대로 공개하지 않는다.
- 공개 페이지는 `site/index.html`처럼 별도 산출물로 만든다.
- 공개 페이지에는 경력, 강연, 선택된 프로젝트, 작업 방식처럼 외부에 보여도 되는 내용만 넣는다.
- 가족, 건강, 미완성 질문, 내적 충돌, 원본 `Inbox` 텍스트는 공개 산출물에서 제외한다.
- 공개 페이지 문장은 `Meta/wording-map.yaml`의 정규 표현을 우선 사용한다.
- 같은 의미를 다른 말로 썼는데 승인된 기준이 없으면 `Meta/wording-conflicts.md`에 컴파일 충돌로 남긴다.
