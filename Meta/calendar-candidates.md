# Calendar Candidates

이 문서는 post-compile 이후 캘린더로 검토할 약속 후보를 모은다.
현재 shell compile은 실제 Google Calendar 추가를 자동으로 실행하지 않고, 후보/질문 필요/지난 일정 로그 상태만 정리한다.

## 기준

- source daily: Daily 전체 (10 files)
- ready:
  날짜와 시간이 함께 잡혀 있고 현재 시각 기준 아직 지나지 않아 캘린더 추가를 바로 검토할 수 있는 항목
- past:
  날짜가 추정되고 현재 시각 기준 이미 지난 일정이라 자동 추가는 하지 않지만 캘린더 로그 후보로 남기는 항목
- needs_question:
  날짜나 시간이 부족해 사용자 확인이 더 필요한 항목

## 바로 캘린더에 넣을 후보

- 다음주 토요일 아내 생일 점심은 부모님과 저녁은 옥상 파티 <!-- tg:update_id:942071288 -->
  상태: 일정 날짜 추정: 2026-04-18 (relative weekday: 다음주 토요일); 일정 시간 추정: 12:00 (time word: 점심); 현재 시각 기준 아직 지나지 않음
  근거: [2026-04-09.md](<../Daily/2026/2026-04-09.md>):62
  원문:
~~~text
다음주 토요일 아내 생일 점심은 부모님과 저녁은 옥상 파티 <!-- tg:update_id:942071288 -->
~~~
- [] 질문: 플레이스 꾸미기나 검색어 올리기를 해본 사람을 찾아보자. 주아아빠? 금요일날 약속이 있으니 그때 물어보자. <!-- tg:update_id:942071321 -->
  상태: 일정 날짜 추정: 2026-04-17 (weekday hint: 금요일); 일정 시간 추정: 15:12 (message timestamp: daily log prefix); 현재 시각 기준 아직 지나지 않음
  근거: [2026-04-13.md](<../Daily/2026/2026-04-13.md>):37
  원문:
~~~text
[] 질문: 플레이스 꾸미기나 검색어 올리기를 해본 사람을 찾아보자. 주아아빠? 금요일날 약속이 있으니 그때 물어보자. <!-- tg:update_id:942071321 -->
~~~

## 이미 지난 일정 로그 후보

- 재윤님은 청담에 오피스텔이있다. 재윤님과 5월에 옥상 파티를 하기로했다 <!-- tg:update_id:942071255 -->
  상태: 일정 날짜 추정: 2026-04-07 (daily date anchor); 일정 시간 추정: 14:35 (message timestamp: daily log prefix); 현재 시각 기준 이미 지난 일정
  근거: [2026-04-07.md](<../Daily/2026/2026-04-07.md>):38
  원문:
~~~text
재윤님은 청담에 오피스텔이있다. 재윤님과 5월에 옥상 파티를 하기로했다 <!-- tg:update_id:942071255 -->
~~~
- 내일 창균님과 약속. 냉삼집(https://naver.me/FY3ycBnN) <!-- tg:update_id:942071267 -->
  상태: 일정 날짜 추정: 2026-04-09 (relative date: 내일); 일정 시간 추정: 10:41 (message timestamp: daily log prefix); 현재 시각 기준 이미 지난 일정
  근거: [2026-04-08.md](<../Daily/2026/2026-04-08.md>):16
  원문:
~~~text
내일 창균님과 약속. 냉삼집(https://naver.me/FY3ycBnN) <!-- tg:update_id:942071267 -->
~~~
- 저스트 댄스 관련 회의를 영어로 함. With  max 두 번째. 힘들다.... <!-- tg:update_id:942071284 -->
  상태: 일정 날짜 추정: 2026-04-09 (daily date anchor); 일정 시간 추정: 16:57 (message timestamp: daily log prefix); 현재 시각 기준 이미 지난 일정
  근거: [2026-04-09.md](<../Daily/2026/2026-04-09.md>):54
  원문:
~~~text
저스트 댄스 관련 회의를 영어로 함. With  max 두 번째. 힘들다.... <!-- tg:update_id:942071284 -->
~~~
- 이제 속초로 출발 <!-- tg:update_id:942071294 -->
  상태: 일정 날짜 추정: 2026-04-10 (daily date anchor); 일정 시간 추정: 19:31 (message timestamp: daily log prefix); 현재 시각 기준 이미 지난 일정
  근거: [2026-04-10.md](<../Daily/2026/2026-04-10.md>):20
  원문:
~~~text
이제 속초로 출발 <!-- tg:update_id:942071294 -->
~~~
- 이제 서울로 출발 <!-- tg:update_id:942071311 -->
  상태: 일정 날짜 추정: 2026-04-12 (daily date anchor); 일정 시간 추정: 18:24 (message timestamp: daily log prefix); 현재 시각 기준 이미 지난 일정
  근거: [2026-04-12.md](<../Daily/2026/2026-04-12.md>):22
  원문:
~~~text
이제 서울로 출발 <!-- tg:update_id:942071311 -->
~~~
- 저녁 양꼬치. 월드팀 쫑파티. 2차 <!-- tg:update_id:942071324 -->
  상태: 일정 날짜 추정: 2026-04-14 (daily date anchor); 일정 시간 추정: 19:00 (time word: 저녁); 현재 시각 기준 이미 지난 일정
  근거: [2026-04-14.md](<../Daily/2026/2026-04-14.md>):10
  원문:
~~~text
저녁 양꼬치. 월드팀 쫑파티. 2차 <!-- tg:update_id:942071324 -->
노래방
~~~
- 사진: 오늘은 할아버지 제사. 민하민엽이 전 부치는 중. 아내가 연락이 늦었다고 어머니께 한소리를 들었다. 내가 중간에서 잘 못한거 같다. 소통이 잘 되게 조금 더 신경 써보자. <!-- tg:update_id:942071333 -->
  상태: 일정 날짜 추정: 2026-04-14 (relative date: 오늘); 일정 시간 추정: 15:54 (message timestamp: daily log prefix); 현재 시각 기준 이미 지난 일정
  근거: [2026-04-14.md](<../Daily/2026/2026-04-14.md>):31
  원문:
~~~text
사진: 오늘은 할아버지 제사. 민하민엽이 전 부치는 중. 아내가 연락이 늦었다고 어머니께 한소리를 들었다. 내가 중간에서 잘 못한거 같다. 소통이 잘 되게 조금 더 신경 써보자. <!-- tg:update_id:942071333 -->
[Google Photos에서 보기](https://photos.google.com/lr/album/AA6PbcN09NONgMIDt6eW0E1POTLnUM7xREEQBdXfDwLReSyV_pAIzYLI2M752I72PEzduWU6ISGa/photo/AA6PbcNbpdoJvPIA5wWN_90TIbQTpPcMPSQG7duczVGeKD4cl5NJED0G2PQTeC3Vd9QV3Wam8P1N1glcQKJYcavKjbs4SJkEyA)
~~~
- 사진: 할아버지 제사. 발렌타인21 모임주 <!-- tg:update_id:942071339 -->
  상태: 일정 날짜 추정: 2026-04-14 (daily date anchor); 일정 시간 추정: 21:15 (message timestamp: daily log prefix); 현재 시각 기준 이미 지난 일정
  근거: [2026-04-14.md](<../Daily/2026/2026-04-14.md>):43
  원문:
~~~text
사진: 할아버지 제사. 발렌타인21 모임주 <!-- tg:update_id:942071339 -->
[Google Drive에서 보기](https://drive.google.com/file/d/1qrsLJFQLneZqqJ6u8p60QZecVXH8Pk4V/view?usp=drivesdk)
~~~
- 제사끝 집으로 주차딱지 끊음 <!-- tg:update_id:942071340 -->
  상태: 일정 날짜 추정: 2026-04-14 (daily date anchor); 일정 시간 추정: 22:04 (message timestamp: daily log prefix); 현재 시각 기준 이미 지난 일정
  근거: [2026-04-14.md](<../Daily/2026/2026-04-14.md>):46
  원문:
~~~text
제사끝 집으로 주차딱지 끊음 <!-- tg:update_id:942071340 -->
~~~

## 질문이 필요한 후보

- 아직 없음

