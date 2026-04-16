# Meta

이 폴더는 이 하네스의 정책과 평가 문서를 둔다.

## 예시

- 설정 점검 기록
- 색인 규칙
- 컴파일 규칙
- 워딩 정규화 사전
- 워딩 충돌 큐
- 자기지식 맵 정의
- 운영 로그
- 폴더 구조 설명

## 역할

- 기록 자체보다, 기록을 어떻게 다룰지에 대한 기준을 보관한다.
- 나중에 자동화 규칙이나 색인 정책을 추가할 때 기준점이 된다.
- 공개 프로필의 톤과 용어를 맞출 때 기준 문서 역할도 한다.
- 사용자가 직접 수정하는 워딩 승인 파일은 `wording-conflicts.md`다.
- 사용자가 직접 수정하는 wiki 승인 파일은 `wiki-compile-decisions.md`다.
- 사용자가 직접 수정하거나 봇 답장으로 갱신하는 calendar 승인 파일은 `calendar-decisions.md`다.
- 열린 review를 한데 모아 보는 generated 파일은 `review.md`다.
- 수동 post-compile TODO 알림 스크립트도 이 운영 규칙을 따른다.
- compile 이후 후속 동작 정의는 `post-compile.md`에 둔다.
- compile 기본 진입점은 `../scripts/compile.sh`이며, 기본적으로 최신 원격 변경을 먼저 pull 하고 Wiki 상태/큐, TODO/Today, 알림, 캘린더 후보, review 큐까지 같이 처리한다.
- 이 폴더는 정책, 경고, 충돌, 승인 절차 같은 평가 레이어를 담당한다.
