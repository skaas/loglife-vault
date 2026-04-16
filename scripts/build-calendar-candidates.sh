#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: scripts/build-calendar-candidates.sh [--daily-file PATH] [--report-file PATH] [--stdout]" >&2
}

repo_root="$(git rev-parse --show-toplevel)"
timezone="${LOGLIFE_NOTIFY_TZ:-Asia/Seoul}"
daily_file=""
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

daily_files=()
source_label=""

if [[ -n "$daily_file" ]]; then
  if [[ -f "$daily_file" ]]; then
    daily_files=("$daily_file")
    source_label="[${daily_file##*/}](<../${daily_file#${repo_root}/}>)"
  else
    source_label="${daily_file} (파일 없음)"
  fi
else
  while IFS= read -r path; do
    daily_files+=("$path")
  done < <(find "${repo_root}/Daily" -type f -name '*.md' | LC_ALL=C sort)
  source_label="Daily 전체 (${#daily_files[@]} files)"
fi

if [[ "${#daily_files[@]}" -eq 0 ]]; then
  output="# Calendar Candidates

이 문서는 post-compile 이후 캘린더로 검토할 약속 후보를 모은다.

## 기준

- source daily: ${source_label}
- 상태: daily 파일 없음

## 바로 캘린더에 넣을 후보

- 아직 없음

## 이미 지난 일정 로그 후보

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
  python3 - "$timezone" "$repo_root" "${daily_files[@]}" <<'PY'
import pathlib
import re
import sys
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

timezone = ZoneInfo(sys.argv[1])
repo_root = pathlib.Path(sys.argv[2])
daily_files = [pathlib.Path(arg) for arg in sys.argv[3:]]
now = datetime.now(timezone)

keyword_re = re.compile(r"(약속|미팅|회의|파티|만나|방문|병원|생일|출발|예약|제사)")
iso_date_re = re.compile(r"(\d{4}-\d{2}-\d{2})")
month_day_re = re.compile(r"\b(\d{1,2})/(\d{1,2})\b")
weekday_re = re.compile(r"(월요일|화요일|수요일|목요일|금요일|토요일|일요일)")
clock_time_re = re.compile(r"\b(\d{1,2}):(\d{2})\b")
korean_time_re = re.compile(r"\b(\d{1,2})시(?:\s*(\d{1,2})분)?\b")
log_prefix_re = re.compile(r"^-\s+\d{1,2}:\d{2}\s+\[@[^\]]+\]\s*")
log_prefix_time_re = re.compile(r"^-\s+(\d{1,2}):(\d{2})\s+\[@[^\]]+\]\s*")
update_id_re = re.compile(r"tg:update_id:(\d+)")
weekday_map = {
    "월요일": 0,
    "화요일": 1,
    "수요일": 2,
    "목요일": 3,
    "금요일": 4,
    "토요일": 5,
    "일요일": 6,
}
time_word_map = {
    "아침": time(9, 0),
    "점심": time(12, 0),
    "저녁": time(19, 0),
}
telegram_root = repo_root / "Inbox" / "Telegram"
telegram_by_update_id: dict[str, pathlib.Path] = {}

if telegram_root.exists():
    for telegram_file in telegram_root.rglob("*.md"):
        telegram_by_update_id[telegram_file.stem] = telegram_file


def parse_daily_date(text: str, fallback: pathlib.Path) -> date | None:
    for line in text.splitlines():
        if line.startswith("# "):
            try:
                return date.fromisoformat(line[2:].strip())
            except ValueError:
                break
    try:
        return date.fromisoformat(fallback.stem)
    except ValueError:
        return None


def strip_log_prefix(line: str) -> str:
    line = log_prefix_re.sub("", line.strip())
    if line.startswith("- "):
        line = line[2:].strip()
    return line


def parse_frontmatter(text: str) -> dict[str, str]:
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}

    fields: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        fields[key.strip()] = value.strip().strip('"')
    return fields


def parse_iso_datetime(value: str) -> datetime | None:
    cleaned = value.strip().strip('"')
    if not cleaned:
        return None
    if cleaned.endswith("Z"):
        cleaned = cleaned[:-1] + "+00:00"
    try:
        return datetime.fromisoformat(cleaned)
    except ValueError:
        return None


def extract_update_id(text: str) -> str:
    match = update_id_re.search(text)
    return match.group(1) if match else ""


def resolve_default_time(block_first_line: str, update_id: str) -> tuple[time | None, str]:
    match = log_prefix_time_re.search(block_first_line)
    if match:
        hour = int(match.group(1))
        minute = int(match.group(2))
        if 0 <= hour <= 23 and 0 <= minute <= 59:
            return time(hour, minute), "message timestamp: daily log prefix"

    raw_note = telegram_by_update_id.get(update_id)
    if raw_note is None:
        return None, ""

    raw_text = raw_note.read_text(encoding="utf-8")
    received_at = parse_frontmatter(raw_text).get("received_at", "")
    received_at_dt = parse_iso_datetime(received_at)
    if received_at_dt is not None:
        localized = received_at_dt.astimezone(timezone)
        return time(localized.hour, localized.minute), "message timestamp: telegram received_at"

    modified_at = datetime.fromtimestamp(raw_note.stat().st_mtime, tz=timezone)
    return time(modified_at.hour, modified_at.minute), "message timestamp: raw note modified_at"


def split_blocks(lines: list[str]) -> list[tuple[int, list[str]]]:
    blocks: list[tuple[int, list[str]]] = []
    current: list[str] = []
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
    return blocks


def resolve_date_hint(text: str, base_date: date | None) -> tuple[date | None, str]:
    if base_date is None:
        return None, ""

    match = iso_date_re.search(text)
    if match:
        try:
            return date.fromisoformat(match.group(1)), "explicit date"
        except ValueError:
            pass

    match = month_day_re.search(text)
    if match:
        month = int(match.group(1))
        day = int(match.group(2))
        try:
            return date(base_date.year, month, day), "month/day hint"
        except ValueError:
            pass

    if "모레" in text:
        return base_date + timedelta(days=2), "relative date: 모레"
    if "내일" in text:
        return base_date + timedelta(days=1), "relative date: 내일"
    if "오늘" in text:
        return base_date, "relative date: 오늘"

    match = weekday_re.search(text)
    if match:
        target = weekday_map[match.group(1)]
        current_monday = base_date - timedelta(days=base_date.weekday())
        if "다음주" in text:
            return current_monday + timedelta(weeks=1, days=target), f"relative weekday: 다음주 {match.group(1)}"
        if "이번주" in text:
            return current_monday + timedelta(days=target), f"relative weekday: 이번주 {match.group(1)}"
        delta = (target - base_date.weekday()) % 7
        return base_date + timedelta(days=delta), f"weekday hint: {match.group(1)}"

    return base_date, "daily date anchor"


def resolve_time_hint(text: str, default_time: time | None = None, default_reason: str = "") -> tuple[time | None, str]:
    match = clock_time_re.search(text)
    if match:
        hour = int(match.group(1))
        minute = int(match.group(2))
        if 0 <= hour <= 23 and 0 <= minute <= 59:
            return time(hour, minute), "explicit hh:mm"

    match = korean_time_re.search(text)
    if match:
        hour = int(match.group(1))
        minute = int(match.group(2) or "0")
        if 0 <= hour <= 23 and 0 <= minute <= 59:
            return time(hour, minute), "explicit 시/분"

    for keyword, mapped in time_word_map.items():
        if keyword in text:
            return mapped, f"time word: {keyword}"

    if default_time is not None:
        return default_time, default_reason

    return None, ""


results: list[dict[str, str]] = []

for daily_file in daily_files:
    text = daily_file.read_text(encoding="utf-8")
    lines = text.splitlines()
    base_date = parse_daily_date(text, daily_file)

    for start_line, block in split_blocks(lines):
        joined = "\n".join(block).strip()
        if "<!-- tg:update_id:" not in joined:
            continue

        title = strip_log_prefix(block[0])
        detection_lines = [title]
        detection_lines.extend(line.strip() for line in block[1:] if line.strip())
        detection_text = "\n".join(detection_lines)
        if not keyword_re.search(detection_text):
            continue

        update_id = extract_update_id(joined)
        event_date, date_reason = resolve_date_hint(detection_text, base_date)
        default_time, default_time_reason = resolve_default_time(block[0], update_id)
        event_time, time_reason = resolve_time_hint(detection_text, default_time, default_time_reason)

        reasons: list[str] = []
        questions: list[str] = []

        if event_date is not None:
            reasons.append(f"일정 날짜 추정: {event_date.isoformat()} ({date_reason})")
        else:
            reasons.append("일정 날짜 추정 실패")
            questions.append("어느 날짜로 넣을지 확인 필요")

        if event_time is not None:
            reasons.append(f"일정 시간 추정: {event_time.strftime('%H:%M')} ({time_reason})")
        else:
            reasons.append("일정 시간 미상")
            questions.append("몇 시에 시작하는지 확인 필요")

        status = "needs_question"
        if event_date is not None and event_time is not None:
            candidate_at = datetime.combine(event_date, event_time, tzinfo=timezone)
            if candidate_at <= now:
                status = "past"
                reasons.append("현재 시각 기준 이미 지난 일정")
            else:
                status = "ready"
                reasons.append("현재 시각 기준 아직 지나지 않음")
        elif event_date is not None and event_date < now.date():
            status = "past"
            reasons.append("현재 날짜 기준 이미 지난 일정")

        results.append(
            {
                "status": status,
                "file": daily_file.as_posix(),
                "line": str(start_line),
                "title": title,
                "reasons": "; ".join(reasons),
                "questions": " / ".join(questions),
                "text": detection_text,
            }
        )

results.sort(key=lambda item: (item["file"], int(item["line"])))

for item in results:
    print(f"STATUS\t{item['status']}")
    print(f"FILE\t{item['file']}")
    print(f"LINE\t{item['line']}")
    print(f"TITLE\t{item['title']}")
    print(f"REASONS\t{item['reasons']}")
    print(f"QUESTIONS\t{item['questions']}")
    print("TEXT")
    print(item["text"])
    print("END")
PY
)"

ready_items=""
past_items=""
question_items=""

if [[ -n "$candidates" ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    [[ "$line" == STATUS$'\t'* ]] || continue
    status="${line#STATUS	}"

    IFS= read -r line
    source_file="${line#FILE	}"
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
  근거: [$(basename "$source_file")](<../${source_file#${repo_root}/}>):${start_line}
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
    elif [[ "$status" == "past" ]]; then
      if [[ -n "$past_items" ]]; then
        past_items="${past_items}"$'\n'"${item}"
      else
        past_items="${item}"
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
[[ -n "$past_items" ]] || past_items="- 아직 없음"
[[ -n "$question_items" ]] || question_items="- 아직 없음"

output="# Calendar Candidates

이 문서는 post-compile 이후 캘린더로 검토할 약속 후보를 모은다.
현재 shell compile은 실제 Google Calendar 추가를 자동으로 실행하지 않고, 후보/질문 필요/지난 일정 로그 상태만 정리한다.

## 기준

- source daily: ${source_label}
- ready:
  날짜와 시간이 함께 잡혀 있고 현재 시각 기준 아직 지나지 않아 캘린더 추가를 바로 검토할 수 있는 항목
- past:
  날짜가 추정되고 현재 시각 기준 이미 지난 일정이라 자동 추가는 하지 않지만 캘린더 로그 후보로 남기는 항목
- needs_question:
  날짜나 시간이 부족해 사용자 확인이 더 필요한 항목

## 바로 캘린더에 넣을 후보

${ready_items}

## 이미 지난 일정 로그 후보

${past_items}

## 질문이 필요한 후보

${question_items}
"

if [[ "$stdout_mode" -eq 1 ]]; then
  printf '%s\n' "$output"
else
  printf '%s\n' "$output" >"$report_file"
fi
