# Wording Conflicts

이 문서는 컴파일 중 발견된 `단어의 충돌`을 모으는 동시에, 사용자가 직접
승인 결정을 적는 입력 파일이다.

여기서 충돌은 git 충돌처럼 빌드를 멈추는 에러가 아니라, `같은 의미인데 표현이
다르기 때문에 정규 표현 선택이 필요한 상태`를 뜻한다.

## 목적

- 컴파일할 때마다 공개 프로필과 위키 문장의 톤을 맞춘다.
- 같은 의미를 매번 다른 말로 쓰는 문제를 `open conflict`로 관리한다.
- 원본 문서를 덮어쓰지 않고, 컴파일 산출물에서만 표현을 정리한다.

## 사용 방법

1. 각 conflict 아래의 `yaml` 블록에서 `selected`를 고른다.
2. 선택을 끝냈으면 `status`를 `approved`로 바꾼다.
3. 비슷해 보여도 실제로는 합치지 않으려면 `status`를 `keep_distinct`로 바꾼다.
4. 컴파일러는 이 파일을 읽고 `targets`에 적힌 파일만 다시 컴파일한다.

## 상태 값

- `open`
  아직 선택하지 않은 상태
- `approved`
  `selected` 문장으로 통일하는 상태
- `keep_distinct`
  비슷하지만 합치지 않고 구분해서 유지하는 상태

## 컴파일 규칙

1. 새 문장을 만들기 전에 `Meta/wording-map.yaml`의 승인된 정규 표현을 먼저 본다.
2. 승인된 정규 표현이 있으면 자동으로 그 문장을 쓴다.
3. 승인된 정규 표현이 없는데 뜻이 같은 다른 표현들이 보이면 `wording conflict`를 연다.
4. 충돌이 열려 있어도 컴파일은 계속한다.
5. 다만 이 경우 컴파일 상태는 `warning`으로 본다.
6. 사용자가 `selected`와 `status`를 수정하면, 이후 컴파일부터 그 결정이 반영된다.

## Conflict Entries

### wording_conflict_001

```yaml
concept_id: public_role
label: 대표 직함
status: approved
policy: unify
selected: 데이터 분석과 사용자 행동 로그를 바탕으로 서비스 구조를 설계하는 Product 기획자
recommended: 데이터 분석과 사용자 행동 로그를 바탕으로 서비스 구조를 설계하는 Product 기획자
variants:
  - Product 기획자
  - Product Owner
  - Product Manager
  - World Service Product Manager
targets:
  - site/index.html
  - Wiki/Self/Career.md
```

질문:
공개 프로필의 대표 직함을 `Product 기획자` 중심으로 고정할까, 아니면 문맥에 따라
`Product Owner`와 `Product Manager`를 계속 병기할까?

### wording_conflict_002

```yaml
concept_id: log_driven_method
label: 핵심 강점 설명
status: approved
policy: unify
selected: 사용자 행동 로그를 바탕으로 서비스 구조와 운영 기준을 설계한다
recommended: 사용자 행동 로그를 바탕으로 서비스 구조와 운영 기준을 설계한다
variants:
  - 로그 설계
  - 행동 데이터 분석
  - 데이터 기반 기획
  - 로그 기반 기획
targets:
  - site/index.html
  - Wiki/Self/Career.md
  - Wiki/Self/Speaking.md
```

질문:
로그와 데이터 관련 강점을 앞으로 이 한 문장으로 묶을까, 아니면 `로그 설계`와
`데이터 분석`을 계속 분리해서 보여줄까?

### wording_conflict_003

```yaml
concept_id: domain_span
label: 경력 범위 소개
status: approved
policy: unify
selected: 게임, 부동산, 공간 기획
recommended: 게임, 부동산, 소셜 월드 플랫폼
variants:
  - 게임·플랫폼·부동산 서비스
  - 게임, 부동산, 소셜 월드 플랫폼
  - 게임에서 플랫폼까지
targets:
  - site/index.html
  - Wiki/Self/Career.md
```

질문:
대외 소개에서는 이 세 범위를 명시하는 문장을 기본으로 쓸까, 아니면
`게임과 플랫폼`처럼 더 짧게 줄일까?

## 메모

- 이 문서는 `질문 리스트`가 아니라 `컴파일 충돌 큐`다.
- 충돌이 열린 동안에도 컴파일은 진행한다.
- 다만 승인된 정규 표현이 생기기 전까지는 `warning 있는 컴파일`로 본다.
- 사용자가 실제로 수정하는 파일도 바로 이 문서다.
