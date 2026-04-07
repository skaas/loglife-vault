# Inbox To Wiki Compiler

이 문서는 `Inbox`에서 `Wiki`로 지식이 이동하는 규칙을 설명한다.

## 목적

- 원본 기록을 잃지 않으면서 자기 이해가 쌓이게 한다.
- 매일의 메모를 장기적인 자기지식으로 바꾼다.
- 같은 생각이 여러 번 나타날 때 하나의 노드로 합친다.

## 컴파일 모델

`Inbox`는 소스 코드다.  
`Daily`는 빌드 중간 산출물이다.  
`Wiki`는 누적되는 지식 베이스다.

즉, 모든 기록을 그대로 위키에 옮기는 게 아니라 아래를 골라낸다.

- 반복되는 자기서술
- 중요한 욕구와 가치
- 행동 패턴과 사고 패턴
- 반복되는 충돌과 한계
- 계속 남는 질문
- 사람, 사건, 프로젝트로 이어지는 단서

## 기본 출력 경로

- 자기서술:
  `Wiki/Self/Profile.md`
- 자기 안의 충돌:
  `Wiki/Self/Tensions.md`
- 아직 답을 못 낸 질문:
  `Wiki/Self/Open Questions.md`
- 주제별 반복 패턴:
  `Wiki/Themes/*.md`

## 컴파일 예시

### 1. 욕구와 방향

원본:
[나는 무엇일까?.txt](/Users/user/Documents/loglife/loglife-vault/Inbox/Text/나는%20무엇일까?.txt)

추출:

- 성공, 자유, 인정 욕구가 함께 등장한다.
- 창업 욕망이 자기 방향과 연결된다.
- 리더십은 성격 문제라고 스스로 해석한다.

출력:

- `Wiki/Self/Profile.md`
- `Wiki/Self/Tensions.md`
- `Wiki/Self/Open Questions.md`

### 2. 성격과 대인관계

원본:
[나의 성격.txt](/Users/user/Documents/loglife/loglife-vault/Inbox/Text/나의%20성격.txt)

추출:

- 무뚝뚝함, 감정 거리두기, 침묵 내성
- 멘탈 강함으로 이어지는 장점
- 공감 부족과 사람을 다루는 어려움

출력:

- `Wiki/Self/Profile.md`
- 필요 시 `Wiki/Themes/관계.md`

### 3. 건강과 행동 변화

원본:
[건강.txt](/Users/user/Documents/loglife/loglife-vault/Inbox/Text/건강.txt)

추출:

- 건강을 위해 담배를 끊은 행동
- 체중 증가라는 부작용
- 건강 판단 기준에 대한 혼란

출력:

- `Wiki/Themes/건강.md`
- 필요 시 `Wiki/Self/Tensions.md`

### 4. 생각의 전환

원본:
[생각의 변화.txt](/Users/user/Documents/loglife/loglife-vault/Inbox/Text/생각의%20변화.txt)

추출:

- 제도 해석이 소비 태도를 바꿨다.
- 생각 변화가 편견을 만든다는 자각이 있다.
- 자기 사고가 어떻게 틀어질 수 있는지 메타 인식이 있다.

출력:

- `Wiki/Themes/생각의-변화.md`
- `Wiki/Self/Profile.md`

## 링크가 있는 텍스트 처리

텍스트에 링크가 있으면 아래 순서로 다룬다.

1. 원문 링크를 보존한다.
2. 링크 내용을 확인한다.
3. 무엇에 대한 링크인지 한 줄로 요약한다.
4. 핵심 포인트를 2~4줄로 적는다.
5. 왜 내 기록과 연결되는지 한 줄 남긴다.
6. 관련 `Daily` 또는 `Wiki` 문서에 연결한다.

## 좋은 컴파일의 기준

- 한 번의 기록이 아니라, 시간이 쌓일수록 더 선명해져야 한다.
- 새 문서를 계속 늘리기보다 기존 노드를 업데이트해야 한다.
- 원본을 읽지 않아도 맥락이 보이되, 원본으로 역추적 가능해야 한다.

