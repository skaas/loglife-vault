#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: scripts/build-calendar-candidates.sh [--daily-file PATH] [--report-file PATH] [--stdout]" >&2
}

repo_root="$(git rev-parse --show-toplevel)"
timezone="${LOGLIFE_NOTIFY_TZ:-Asia/Seoul}"
today="$(TZ="$timezone" date +%F)"
year="$(TZ="$timezone" date +%Y)"
daily_file="${repo_root}/Daily/${year}/${today}.md"
report_file="${repo_root}/Meta/calendar-candidates.md"
stdout_mode=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --daily-file)
      [[ $# -ge 2 ]] || {
        usage
        exit 2
      }
      daily_file="$2"
      shift 2
      ;;
    --report-file)
      [[ $# -ge 2 ]] || {
        usage
        exit 2
      }
      report_file="$2"
      shift 2
      ;;
    --stdout)
      stdout_mode=1
      shift
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [[ ! -f "$daily_file" ]]; then
  output="# Calendar Candidates

이 문서는 post-compile 이후 캘린더로 검토할 약속 후보를 모은다.

## 기준

- source daily: ${daily_file}
- 상태: daily 파일 없음

## 바로 캘린더에 넣을 후보

- 아직 없음

## 질문이 필요한 후보

- 아직 없음
"

  if [[ "$stdout_mode" -eq 1 ]]; then
    printf '%s\n' "$output"
  else
    printf '%s\n' "$output" >"$report_file"
  fi
  exit 0
fi

candidates="$(
  python3 - "$daily_file" <<'PY'
import pathlib
import re
import sys

daily_file = pathlib.Path(sys.argv[1])
text = daily_file.read_text(encoding="utf-8")
lines = text.splitlines()

date_key = ""
for line in lines:
    if line.startswith("# "):
        date_key = line[2:].strip()
        break

keyword_re = re.compile(r"(약속|미팅|회의|점심|저녁|파티|만나|방문|병원|생일|출발|예약)")
date_re = re.compile(r"(\d{4}-\d{2}-\d{2}|\d{1,2}/\d{1,2}|오늘|내일|모레|다음주|이번주|월요일|화요일|수요일|목요일|금요일|토요일|일요일)")
time_re = re.compile(r"(\b\d{1,2}:\d{2}\b|\b\d{1,2}시(?:\s*\d{1,2}분)?\b|아침|점심|저녁)")

blocks = []
current = []
start_line = 0

for idx, line in enumerate(lines, start=1):
    if line.startswith("- "):
      if current:
        blocks.append((start_line, current))
      current = [line]
      start_line = idx
      continue
    if current and (line.startswith("  ") or line.strip() == ""):
      current.append(line)
      continue
    if current:
      blocks.append((start_line, current))
      current = []

if current:
    blocks.append((start_line, current))

for start_line, block in blocks:
    joined = "\n".join(block).strip()
    if "<!-- tg:update_id:" not in joined:
        continue
    if not keyword_re.search(joined):
        continue

    title = block[0].strip()[2:].strip()
    has_date = bool(date_re.search(joined)) or bool(date_key)
    has_time = bool(time_re.search(joined))
    status = "ready" if has_date and has_time else "needs_question"
    reasons = []
    questions = []
    if has_date:
        reasons.append("date hint 있음")
    else:
        reasons.append("date hint 없음")
        questions.append("어느 날짜로 넣을지 확인 필요")
    if has_time:
        reasons.append("time hint 있음")
    else:
        reasons.append("time hint 없음")
        questions.append("몇 시에 시작하는지 확인 필요")

    print(f"STATUS\t{status}")
    print(f"LINE\t{start_line}")
    print(f"TITLE\t{title}")
    print(f"REASONS\t{'; '.join(reasons)}")
    print(f"QUESTIONS\t{' / '.join(questions)}")
    print("TEXT")
    print(joined)
    print("END")
PY
)"

ready_items=""
question_items=""

if [[ -n "$candidates" ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    [[ "$line" == STATUS$'\t'* ]] || continue
    status="${line#STATUS	}"

    IFS= read -r line
    start_line="${line#LINE	}"
    IFS= read -r line
    title="${line#TITLE	}"
    IFS= read -r line
    reasons="${line#REASONS	}"
    IFS= read -r line
    questions="${line#QUESTIONS	}"
    IFS= read -r line
    text=""
    while IFS= read -r line; do
      [[ "$line" == END ]] && break
      if [[ -n "$text" ]]; then
        text="${text}"$'\n'"${line}"
      else
        text="${line}"
      fi
    done

    item="- ${title}
  상태: ${reasons}
  근거: [$(basename "$daily_file")](<../${daily_file#${repo_root}/}>):${start_line}
"

    if [[ -n "$questions" ]]; then
      item="${item}  확인 질문: ${questions}
"
    fi

    item="${item}  원문:
~~~text
${text}
~~~"

    if [[ "$status" == "ready" ]]; then
      if [[ -n "$ready_items" ]]; then
        ready_items="${ready_items}"$'\n'"${item}"
      else
        ready_items="${item}"
      fi
    else
      if [[ -n "$question_items" ]]; then
        question_items="${question_items}"$'\n'"${item}"
      else
        question_items="${item}"
      fi
    fi
  done <<<"$candidates"
fi

[[ -n "$ready_items" ]] || ready_items="- 아직 없음"
[[ -n "$question_items" ]] || question_items="- 아직 없음"

output="# Calendar Candidates

이 문서는 post-compile 이후 캘린더로 검토할 약속 후보를 모은다.

## 기준

- source daily: [$(basename "$daily_file")](<../${daily_file#${repo_root}/}>)
- ready:
  날짜 힌트와 시간 힌트가 함께 있어 캘린더 추가를 바로 검토할 수 있는 항목
- needs_question:
  날짜나 시간이 빠져 있어 사용자 확인 질문이 필요한 항목

## 바로 캘린더에 넣을 후보

${ready_items}

## 질문이 필요한 후보

${question_items}
"

if [[ "$stdout_mode" -eq 1 ]]; then
  printf '%s\n' "$output"
else
  printf '%s\n' "$output" >"$report_file"
fi
