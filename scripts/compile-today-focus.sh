#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: scripts/compile-today-focus.sh [--stdout] [--today-file PATH]" >&2
}

repo_root="$(git rev-parse --show-toplevel)"
today_file="${repo_root}/Wiki/Self/Today.md"
todo_file="${repo_root}/Wiki/Self/TODO.md"
questions_file="${repo_root}/Wiki/Self/Open Questions.md"
diagnosis_file="${repo_root}/Wiki/Self/Current Diagnosis.md"
stdout_mode=0
today_date="$(TZ="${LOGLIFE_NOTIFY_TZ:-Asia/Seoul}" date +%F)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stdout)
      stdout_mode=1
      shift
      ;;
    --today-file)
      [[ $# -ge 2 ]] || {
        usage
        exit 2
      }
      today_file="$2"
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

extract_first_block() {
  local file="$1"
  local section="$2"

  awk -v section="$section" '
    $0 == "## " section { in_section = 1; next }
    /^## / && in_section { exit }
    in_section {
      if (!capturing && /^- /) {
        capturing = 1
        print
        next
      }

      if (capturing) {
        if (/^  /) {
          print
          next
        }

        exit
      }
    }
  ' "$file"
}

extract_first_diagnosis_block() {
  local file="$1"

  awk '
    /^### 현재 문제 후보/ { in_problem = 1; next }
    /^### / && in_problem { exit }
    in_problem {
      if (!capturing && /^- /) {
        capturing = 1
        print
        next
      }

      if (capturing) {
        if (/^  /) {
          print
          next
        }

        exit
      }
    }
  ' "$file"
}

extract_text_line() {
  printf '%s\n' "$1" | sed -n '1s/^- //p'
}

extract_evidence_lines() {
  printf '%s\n' "$1" | sed -n '2,$p'
}

today_mode=""
today_source_label=""
today_source_link=""
today_reason=""
today_prompts=""
focus_block=""

if [[ -f "$todo_file" ]]; then
  focus_block="$(extract_first_block "$todo_file" "현재 할 일")"
fi

if [[ -n "$focus_block" ]]; then
  today_mode="todo"
  today_source_label="TODO.md"
  today_source_link="TODO.md"
  today_reason='현재 `TODO` 목록의 첫 항목이다. 지금 구조에서는 목록의 앞쪽을 오늘 가장 먼저 밀어야 할 항목으로 본다.'
  today_prompts=$'- 오늘 이걸 10~20분 안에 어디까지 밀 수 있는가.\n- 막히는 지점이 있다면 정확히 무엇이 막히는가.\n- 다음 컴파일에 남길 사실 1개는 무엇인가.'
elif [[ -f "$questions_file" ]]; then
  focus_block="$(extract_first_block "$questions_file" "현재 열린 질문")"
  if [[ -n "$focus_block" ]]; then
    today_mode="writing_prompt"
    today_source_label="Open Questions.md"
    today_source_link="Open Questions.md"
    today_reason='현재 `TODO`가 비었거나 오늘 바로 움직이기 어려울 때는, 위키에 쌓일 만한 열린 질문 하나를 짧게라도 써보는 편이 낫다.'
    today_prompts=$'- 5줄 이내로 지금 시점의 답을 적는다.\n- 사실 1개와 해석 1개를 구분해서 적는다.\n- 답이 닫히지 않으면 다음 질문 1개를 남긴다.'
  fi
fi

if [[ -z "$focus_block" && -f "$diagnosis_file" ]]; then
  focus_block="$(extract_first_diagnosis_block "$diagnosis_file")"
  if [[ -n "$focus_block" ]]; then
    today_mode="writing_prompt"
    today_source_label="Current Diagnosis.md"
    today_source_link="Current Diagnosis.md"
    today_reason='명시적인 `TODO`나 열린 질문이 없으면, 최근 진단에서 가장 먼저 잡힌 패턴을 관찰 메모로 남기는 것이 다음 컴파일의 질을 올린다.'
    today_prompts=$'- 오늘 확인할 관찰 사실 1개를 적는다.\n- 해석보다 관찰을 먼저 적는다.\n- 다음에 더 확인할 조건 1개를 남긴다.'
  fi
fi

if [[ -z "$focus_block" ]]; then
  today_mode="writing_prompt"
  today_source_label="Self Map"
  today_source_link="Map.md"
  today_reason="아직 당겨 쓸 `TODO`, 열린 질문, 최근 진단이 부족하면 가장 자주 붙잡히는 생각 하나를 짧게 남겨 새 근거를 만드는 쪽이 낫다."
  focus_block="- 오늘 가장 오래 붙잡고 있던 생각 하나를 5줄 안에 적는다."
  today_prompts=$'- 사실 1개를 먼저 적는다.\n- 왜 기억에 남는지 해석 1개를 적는다.\n- 이어서 보고 싶은 질문 1개를 남긴다.'
fi

focus_text="$(extract_text_line "$focus_block")"
evidence_lines="$(extract_evidence_lines "$focus_block")"

output="$(
  cat <<EOF
# Today

이 문서는 오늘 하나만 잡을 포커스를 정리한다.

## ${today_date}

### 상태

- mode: ${today_mode}
- source: [${today_source_label}](<${today_source_link}>)

### 오늘의 한 가지

- ${focus_text}
EOF
)"

if [[ -n "$evidence_lines" ]]; then
  output="${output}"$'\n'"${evidence_lines}"
fi

output="${output}"$'\n\n'"### 왜 이것인가"$'\n\n'"- ${today_reason}"$'\n\n'"### 짧게 남길 것"$'\n\n'

while IFS= read -r prompt_line; do
  [[ -n "$prompt_line" ]] || continue
  output="${output}- ${prompt_line#- }"$'\n'
done <<<"$today_prompts"

output="${output}"$'\n'

if [[ "$stdout_mode" -eq 1 ]]; then
  printf '%s' "$output"
  exit 0
fi

printf '%s' "$output" >"$today_file"
