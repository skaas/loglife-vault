#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: scripts/compile-today-focus.sh [--stdout] [--today-file PATH] [--todo-file PATH] [--skip-todo-writing-topic]" >&2
}

repo_root="$(git rev-parse --show-toplevel)"
today_file="${repo_root}/Wiki/Self/Today.md"
todo_file="${repo_root}/Wiki/Self/TODO.md"
questions_file="${repo_root}/Wiki/Self/Open Questions.md"
diagnosis_file="${repo_root}/Wiki/Self/Current Diagnosis.md"
stdout_mode=0
sync_todo_writing_topic=1
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
    --todo-file)
      [[ $# -ge 2 ]] || {
        usage
        exit 2
      }
      todo_file="$2"
      shift 2
      ;;
    --skip-todo-writing-topic)
      sync_todo_writing_topic=0
      shift
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

extract_first_open_question_block() {
  local questions_file="$1"
  local todo_file="$2"

  python3 - "$questions_file" "$todo_file" <<'PY'
import pathlib
import re
import sys
from difflib import SequenceMatcher

questions_file = pathlib.Path(sys.argv[1])
todo_file = pathlib.Path(sys.argv[2])


def normalize(text: str) -> str:
    value = text
    value = re.sub(r"https?://\S+", " ", value)
    value = value.replace("`", " ")
    value = re.sub(r"글쓰기\s*초안을\s*저장했다\.?", " ", value)
    value = re.sub(r"\b완료\b", " ", value)
    value = re.sub(r"[^0-9A-Za-z가-힣]+", "", value.lower())
    return value


def matches(left: str, right: str) -> bool:
    a = normalize(left)
    b = normalize(right)
    if not a or not b:
        return False
    if a in b or b in a:
        return True
    return SequenceMatcher(None, a, b).ratio() >= 0.55


todo_text = todo_file.read_text(encoding="utf-8") if todo_file.exists() else ""
completed = []
in_completed = False
for line in todo_text.splitlines():
    if line.startswith("## "):
        in_completed = line.strip() == "## 최근 완료"
        continue
    if in_completed and line.startswith("- "):
        completed.append(line[2:].strip())

question_text = questions_file.read_text(encoding="utf-8")
lines = question_text.splitlines()
in_section = False
current = []

def emit(block):
    print("\n".join(block))

for line in lines:
    if line.startswith("## "):
        if in_section and current:
            title = current[0][2:].strip()
            if not any(matches(title, item) for item in completed):
                emit(current)
                sys.exit(0)
            current = []
        in_section = line.strip() == "## 현재 열린 질문"
        continue

    if not in_section:
        continue

    if line.startswith("- "):
        if current:
            title = current[0][2:].strip()
            if not any(matches(title, item) for item in completed):
                emit(current)
                sys.exit(0)
        current = [line]
        continue

    if current and line.startswith("  "):
        current.append(line)

if in_section and current:
    title = current[0][2:].strip()
    if not any(matches(title, item) for item in completed):
        emit(current)
PY
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

replace_or_insert_section() {
  local file="$1"
  local section_title="$2"
  local new_section="$3"

  python3 - "$file" "$section_title" "$new_section" <<'PY'
import pathlib
import re
import sys

file_path = pathlib.Path(sys.argv[1])
section_title = sys.argv[2]
new_section = sys.argv[3].rstrip("\n")

text = file_path.read_text(encoding="utf-8")
pattern = re.compile(rf"(?ms)^## {re.escape(section_title)}\n.*?(?=^## |\Z)")

if pattern.search(text):
    updated = pattern.sub(new_section + "\n\n", text, count=1)
else:
    marker = "\n## 최근 완료\n"
    if marker in text:
        updated = text.replace(marker, "\n" + new_section + "\n\n## 최근 완료\n", 1)
    else:
        updated = text.rstrip() + "\n\n" + new_section + "\n"

file_path.write_text(updated, encoding="utf-8")
PY
}

today_mode=""
today_source_label=""
today_source_link=""
today_reason=""
today_prompts=""
focus_block=""
writing_source_label=""
writing_source_link=""
writing_reason=""
writing_block=""

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
  focus_block="$(extract_first_open_question_block "$questions_file" "$todo_file")"
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

if [[ -f "$questions_file" ]]; then
  writing_block="$(extract_first_open_question_block "$questions_file" "$todo_file")"
fi

if [[ -n "$writing_block" ]]; then
  writing_source_label="Open Questions.md"
  writing_source_link="Open Questions.md"
  writing_reason='현재 `TODO`와 별개로, 짧게라도 생각을 쌓을 글쓰기 주제는 열린 질문에서 먼저 고른다.'
elif [[ -f "$diagnosis_file" ]]; then
  writing_block="$(extract_first_diagnosis_block "$diagnosis_file")"
  if [[ -n "$writing_block" ]]; then
    writing_source_label="Current Diagnosis.md"
    writing_source_link="Current Diagnosis.md"
    writing_reason='열린 질문이 비어 있으면 최근 진단의 첫 문제 후보를 글쓰기 주제로 사용한다.'
  fi
fi

if [[ -z "$writing_block" ]]; then
  writing_source_label="Map.md"
  writing_source_link="Map.md"
  writing_reason="열린 질문과 진단이 비어 있으면, 오늘 가장 오래 붙잡고 있던 생각을 새 글쓰기 근거로 만든다."
  writing_block="- 오늘 가장 오래 붙잡고 있던 생각 하나를 5줄 안에 적는다."
fi

focus_text="$(extract_text_line "$focus_block")"
evidence_lines="$(extract_evidence_lines "$focus_block")"
writing_text="$(extract_text_line "$writing_block")"
writing_evidence_lines="$(extract_evidence_lines "$writing_block")"

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

if [[ "$sync_todo_writing_topic" -eq 1 && -f "$todo_file" ]]; then
  todo_writing_section="$(
    cat <<EOF
## 오늘 글쓰기 주제

- ${writing_text}
  source: [${writing_source_label}](<${writing_source_link}>)
EOF
  )"

  if [[ -n "$writing_evidence_lines" ]]; then
    todo_writing_section="${todo_writing_section}"$'\n'"${writing_evidence_lines}"
  fi

  todo_writing_section="${todo_writing_section}"$'\n'"  메모: ${writing_reason}"
  replace_or_insert_section "$todo_file" "오늘 글쓰기 주제" "$todo_writing_section"
fi
