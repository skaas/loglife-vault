#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: scripts/compile-todo-state.sh [--todo-file PATH] [--telegram-root PATH] [--text-root PATH]" >&2
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck disable=SC1091
source "${repo_root}/scripts/script-lib.sh"
todo_file="${repo_root}/Wiki/Self/TODO.md"
telegram_root="${repo_root}/Inbox/Telegram"
text_root="${repo_root}/Inbox/Text"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --todo-file)
      [[ $# -ge 2 ]] || {
        usage
        exit 2
      }
      todo_file="$2"
      shift 2
      ;;
    --telegram-root)
      [[ $# -ge 2 ]] || {
        usage
        exit 2
      }
      telegram_root="$2"
      shift 2
      ;;
    --text-root)
      [[ $# -ge 2 ]] || {
        usage
        exit 2
      }
      text_root="$2"
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

run_python - "$todo_file" "$telegram_root" "$text_root" <<'PY'
from __future__ import annotations

from dataclasses import dataclass, field
from difflib import SequenceMatcher
import os
from pathlib import Path
import re
import sys


todo_file = Path(sys.argv[1])
telegram_root = Path(sys.argv[2])
text_root = Path(sys.argv[3])


def parse_sections(text: str) -> tuple[list[str], dict[str, str]]:
    headers = list(re.finditer(r"^##\s+(.+)$", text, flags=re.M))
    intro = text[: headers[0].start()].rstrip() if headers else text.rstrip()
    order = []
    sections: dict[str, str] = {}
    for idx, match in enumerate(headers):
        name = match.group(1).strip()
        start = match.end()
        end = headers[idx + 1].start() if idx + 1 < len(headers) else len(text)
        order.append(name)
        sections[name] = text[start:end].strip("\n")
    return [intro] + order, sections


@dataclass
class Item:
    text: str
    details: list[str] = field(default_factory=list)

    def ensure_detail(self, detail: str) -> None:
        if detail not in self.details:
            self.details.append(detail)


def parse_bullet_items(section_text: str) -> list[Item]:
    if not section_text.strip():
        return []
    lines = section_text.splitlines()
    items: list[Item] = []
    current: Item | None = None
    for line in lines:
        if line.startswith("- "):
            if current is not None:
                items.append(current)
            current = Item(text=line[2:].strip(), details=[])
            continue
        if current is not None:
            detail = line.rstrip()
            if detail:
                current.details.append(detail)
    if current is not None:
        items.append(current)
    return items


def render_items(items: list[Item]) -> str:
    if not items:
        return "- 아직 없음"
    blocks: list[str] = []
    for item in items:
        lines = [f"- {item.text}"]
        lines.extend(item.details)
        blocks.append("\n".join(lines))
    return "\n\n".join(blocks)


def replace_section(text: str, title: str, body: str) -> str:
    section = f"## {title}\n\n{body.strip()}\n"
    pattern = re.compile(rf"(?ms)^## {re.escape(title)}\n.*?(?=^## |\Z)")
    if pattern.search(text):
        return pattern.sub(section + "\n", text, count=1).rstrip() + "\n"

    marker = "\n## 최근 완료\n"
    if marker in text:
        return text.replace(marker, "\n" + section + "\n## 최근 완료\n", 1).rstrip() + "\n"

    return text.rstrip() + "\n\n" + section + "\n"


def source_detail(path: Path) -> str:
    rel = Path(os.path.relpath(path, start=todo_file.parent))
    return f"  근거: [{path.name}](<{rel.as_posix()}>)"


def note_detail(note: str) -> str:
    compact = re.sub(r"\s+", " ", note).strip()
    return f"  메모: {compact}"


def read_raw_content(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    match = re.search(r"~~~text\n(.*?)\n~~~", text, flags=re.S)
    return match.group(1).strip() if match else text.strip()


def normalize_text(text: str) -> str:
    value = text
    value = re.sub(r"https?://\S+", " ", value)
    value = re.sub(r'"[^"]+\.(?:md|markdown|txt)"', " ", value)
    value = value.replace("`", " ")
    value = re.sub(r"글쓰기\s*완료.*$", " ", value)
    value = re.sub(r"\b완료\b", " ", value)
    replacements = {
        "옥산": "옥상",
        "듁후감": "독후감",
        "크롤러": "크롤",
        "크롤링": "크롤",
        "셋팅": "세팅",
        "비지니스": "비즈니스",
    }
    for src, dst in replacements.items():
        value = value.replace(src, dst)
    value = re.sub(r"[^0-9A-Za-z가-힣]+", "", value.lower())
    return value


def texts_match(left: str, right: str) -> bool:
    a = normalize_text(left)
    b = normalize_text(right)
    if not a or not b:
        return False
    if a in b or b in a:
        return True
    return SequenceMatcher(None, a, b).ratio() >= 0.55


def clean_task_text(text: str) -> str:
    value = text.strip()
    value = re.sub(r"https?://\S+", " ", value)
    value = re.sub(r"\s+", " ", value)
    value = value.strip(" .")
    return value


def extract_marker_task(line: str, done: bool) -> str:
    stripped = line.strip()
    for prefix in ("- [ ]", "[ ]", "[]", "TODO:"):
        if not done and stripped.startswith(prefix):
            return clean_task_text(stripped[len(prefix) :])
    for prefix in ("- [x]", "[x]", "DONE:"):
        if done and stripped.startswith(prefix):
            value = stripped[len(prefix) :]
            value = re.sub(r"글쓰기\s*완료.*$", "", value).strip()
            return clean_task_text(value)
    return ""


def extract_open_tasks(content: str) -> list[str]:
    results = []
    for line in content.splitlines():
        task = extract_marker_task(line, done=False)
        if task:
            results.append(task)
    return results


def extract_done_tasks(content: str) -> list[tuple[str, str]]:
    lines = content.splitlines()
    results = []
    for idx, line in enumerate(lines):
        task = extract_marker_task(line, done=True)
        if not task:
            continue
        trailing = [part.strip() for part in lines[idx + 1 :] if part.strip()]
        note = " ".join(trailing)
        results.append((task, note))
    return results


def extract_deleted_tasks(content: str) -> list[str]:
    if "투두에서 삭제하자" not in content:
        return []
    results = []
    for line in content.splitlines():
        match = re.match(r"^\s*\d+\.\s*(.+)$", line)
        if match:
            results.append(clean_task_text(match.group(1)))
    return results


def extract_corrections(content: str) -> list[tuple[str, str]]:
    results = []
    for source, target in re.findall(r"오타\s*([^-\s]+)\s*->\s*([^\s]+)", content):
        results.append((source.strip(), target.strip()))
    return results


def apply_corrections(items: list[Item], corrections: list[tuple[str, str]]) -> None:
    for source, target in corrections:
        for item in items:
            item.text = item.text.replace(source, target)
            item.details = [detail.replace(source, target) for detail in item.details]


def find_item(items: list[Item], task_text: str) -> Item | None:
    for item in items:
        if texts_match(item.text, task_text):
            return item
    return None


raw_todo = todo_file.read_text(encoding="utf-8")
layout, sections = parse_sections(raw_todo)

current_items = parse_bullet_items(sections.get("현재 할 일", ""))
completed_items = parse_bullet_items(sections.get("최근 완료", ""))
completion_rules = sections.get("완료 처리 규칙", "").strip()

source_files: list[Path] = []
if telegram_root.exists():
    source_files.extend(sorted(telegram_root.rglob("*.md")))
if text_root.exists():
    source_files.extend(sorted(path for path in text_root.rglob("*") if path.is_file() and path.suffix.lower() in {".md", ".txt", ".markdown"}))

for path in source_files:
    content = read_raw_content(path)
    if not content:
        continue

    corrections = extract_corrections(content)
    if corrections:
        apply_corrections(current_items, corrections)
        apply_corrections(completed_items, corrections)

    for deleted in extract_deleted_tasks(content):
        current_items = [item for item in current_items if not texts_match(item.text, deleted)]

    for task in extract_open_tasks(content):
        existing_current = find_item(current_items, task)
        if existing_current is not None:
            existing_current.ensure_detail(source_detail(path))
            continue

        existing_completed = find_item(completed_items, task)
        if existing_completed is not None:
            completed_items.remove(existing_completed)
            existing_completed.ensure_detail(source_detail(path))
            current_items.append(existing_completed)
            continue

        current_items.append(Item(text=task, details=[source_detail(path)]))

    for task, note in extract_done_tasks(content):
        matched_current = find_item(current_items, task)
        if matched_current is not None:
            current_items.remove(matched_current)
            matched_current.ensure_detail(source_detail(path))
            if note:
                matched_current.ensure_detail(note_detail(note))
            existing_completed = find_item(completed_items, matched_current.text)
            if existing_completed is not None:
                for detail in matched_current.details:
                    existing_completed.ensure_detail(detail)
            else:
                completed_items.append(matched_current)
            continue

        existing_completed = find_item(completed_items, task)
        if existing_completed is not None:
            existing_completed.ensure_detail(source_detail(path))
            if note:
                existing_completed.ensure_detail(note_detail(note))
            continue

        completed_text = task
        if "글쓰기" in content and "완료" in content:
            completed_text = f"{task} 글쓰기 초안을 저장했다."
        completed_item = Item(text=completed_text, details=[source_detail(path)])
        if note:
            completed_item.ensure_detail(note_detail(note))
        completed_items.append(completed_item)

updated = raw_todo
updated = replace_section(updated, "현재 할 일", render_items(current_items))
updated = replace_section(updated, "최근 완료", render_items(completed_items))
if completion_rules:
    updated = replace_section(updated, "완료 처리 규칙", completion_rules)

todo_file.write_text(updated, encoding="utf-8")
PY
