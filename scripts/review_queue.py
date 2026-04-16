#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
META_ROOT = REPO_ROOT / "Meta"
WIKI_ROOT = REPO_ROOT / "Wiki"

DEFAULT_QUEUE_FILE = META_ROOT / "wiki-compile-queue.md"
DEFAULT_WIKI_DECISIONS_FILE = META_ROOT / "wiki-compile-decisions.md"
DEFAULT_CALENDAR_FILE = META_ROOT / "calendar-candidates.md"
DEFAULT_CALENDAR_DECISIONS_FILE = META_ROOT / "calendar-decisions.md"
DEFAULT_WORDING_FILE = META_ROOT / "wording-conflicts.md"
DEFAULT_REVIEW_FILE = META_ROOT / "review.md"
DEFAULT_STATE_FILE = META_ROOT / "review-state.json"
DEFAULT_DISPATCH_FILE = META_ROOT / "review-dispatch.json"

QUEUE_PRIORITIES = {
    "needs_link_summary": 35,
    "needs_self_triage": 40,
    "needs_idea_triage": 45,
    "needs_manual_merge": 50,
    "needs_triage": 55,
}

CALENDAR_PRIORITIES = {
    "ready": 10,
    "needs_question": 20,
    "past": 60,
}


@dataclass
class ReviewItem:
    id: str
    kind: str
    key: str
    title: str
    summary: str
    source_path: str | None
    priority: int
    sort_key: str
    reason: str = ""
    suggested_command: str = ""
    suggested_effect: str = ""
    commands: list[str] | None = None
    data: dict | None = None

    def to_json(self) -> dict:
        return {
            "id": self.id,
            "kind": self.kind,
            "key": self.key,
            "title": self.title,
            "summary": self.summary,
            "source_path": self.source_path,
            "priority": self.priority,
            "sort_key": self.sort_key,
            "reason": self.reason,
            "suggested_command": self.suggested_command,
            "suggested_effect": self.suggested_effect,
            "commands": self.commands or [],
            "data": self.data or {},
        }


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def stable_review_id(kind: str, key: str) -> str:
    digest = hashlib.sha1(f"{kind}|{key}".encode("utf-8")).hexdigest()[:10]
    return f"rvw_{digest}"


def repo_rel(path: Path) -> str:
    return path.relative_to(REPO_ROOT).as_posix()


def rel(from_path: Path, to_path: Path) -> str:
    return os.path.relpath(to_path, start=from_path.parent).replace(os.sep, "/")


def md_link(from_path: Path, to_path: Path, label: str | None = None) -> str:
    text = label or to_path.name
    return f"[{text}](<{rel(from_path, to_path)}>)"


def load_json(path: Path, default):
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return default


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def item_field(item, name: str) -> str:
    if isinstance(item, dict):
        value = item.get(name, "")
    else:
        value = getattr(item, name, "")
    return str(value or "").strip()


def dispatch_entries_from_payload(payload: dict) -> list[dict[str, str]]:
    entries: list[dict[str, str]] = []
    seen_ids: set[str] = set()

    raw_entries = payload.get("dispatched_reviews", [])
    if isinstance(raw_entries, list):
        for raw in raw_entries:
            if not isinstance(raw, dict):
                continue
            review_id = str(raw.get("id", "")).strip()
            if not review_id or review_id in seen_ids:
                continue
            entry = {"id": review_id}
            for field in ("sent_at", "kind", "key"):
                value = str(raw.get(field, "")).strip()
                if value:
                    entry[field] = value
            entries.append(entry)
            seen_ids.add(review_id)

    active_id = str(payload.get("active_review_id", "")).strip()
    if active_id and active_id not in seen_ids:
        entry = {"id": active_id}
        for field in ("sent_at", "kind", "key"):
            value = str(payload.get(field, "")).strip()
            if value:
                entry[field] = value
        entries.append(entry)

    return entries


def normalize_dispatch_entries(entries: list[dict[str, str]], pending_items: list | None = None) -> list[dict[str, str]]:
    pending_lookup: dict[str, object] | None = None
    if pending_items is not None:
        pending_lookup = {item_field(item, "id"): item for item in pending_items if item_field(item, "id")}

    normalized: list[dict[str, str]] = []
    seen_ids: set[str] = set()
    for raw in entries:
        review_id = str(raw.get("id", "")).strip()
        if not review_id or review_id in seen_ids:
            continue
        item = pending_lookup.get(review_id) if pending_lookup is not None else None
        if pending_lookup is not None and item is None:
            continue
        entry = {"id": review_id}
        kind = str(raw.get("kind", "")).strip() or (item_field(item, "kind") if item is not None else "")
        key = str(raw.get("key", "")).strip() or (item_field(item, "key") if item is not None else "")
        sent_at = str(raw.get("sent_at", "")).strip()
        if sent_at:
            entry["sent_at"] = sent_at
        if kind:
            entry["kind"] = kind
        if key:
            entry["key"] = key
        normalized.append(entry)
        seen_ids.add(review_id)
    return normalized


def write_dispatch(path: Path, entries: list[dict[str, str]]) -> None:
    if not entries:
        path.write_text("{}\n", encoding="utf-8")
        return
    write_json(path, {"dispatched_reviews": entries})


def read_text_if_possible(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return ""
    except UnicodeDecodeError:
        return ""


def read_source_content(path: Path) -> str:
    text = read_text_if_possible(path)
    if not text:
        return ""
    match = re.search(r"~~~text\n(.*?)\n~~~", text, flags=re.S)
    if match:
        return match.group(1).strip()
    return text.strip()


def clean_snippet(content: str) -> str:
    lines: list[str] = []
    for raw in content.splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("http://") or line.startswith("https://"):
            continue
        line = re.sub(r"https?://\S+", "", line).strip()
        line = re.sub(r"<!--.*?-->", "", line).strip()
        if not line:
            continue
        lines.append(line)
    if not lines:
        return ""
    joined = " / ".join(lines[:2])
    joined = re.sub(r"\s+", " ", joined).strip()
    if len(joined) > 160:
        joined = joined[:157].rstrip() + "..."
    return joined


def ensure_calendar_decisions_file(path: Path) -> None:
    if path.exists():
        return
    template = "\n".join(
        [
            "# Calendar Decisions",
            "",
            "이 파일은 `Meta/calendar-candidates.md` 후보에 대한 사람 판단을 기록한다.",
            "",
            "## 규칙",
            "",
            "- 각 항목은 `## tg:update_id:...` 또는 `## daily:...` 형식 헤더를 쓴다.",
            "- `action`은 `create`, `log`, `hold`, `ignore` 중 하나를 쓴다.",
            "- `date`, `time`, `title`, `comment`는 선택이지만 가능한 한 남긴다.",
            "- 날짜나 시간이 모호한 항목은 먼저 값을 채우고, 확정되면 `action`을 적는다.",
            "",
            "## 예시",
            "",
            "## tg:update_id:942071267",
            "action: log",
            "date: 2026-04-09",
            "time:",
            "title: 창균님과 약속",
            "comment: 냉삼집",
            "",
        ]
    )
    path.write_text(template, encoding="utf-8")


def parse_heading_blocks(path: Path, required_prefix: str | None = None) -> dict[str, dict[str, str]]:
    text = read_text_if_possible(path)
    blocks: dict[str, dict[str, str]] = {}
    current_title: str | None = None
    current_lines: list[str] = []

    def flush() -> None:
        nonlocal current_title, current_lines
        if not current_title:
            return
        if required_prefix and not current_title.startswith(required_prefix):
            return
        fields: dict[str, str] = {}
        for raw in current_lines:
            line = raw.strip()
            if not line or line.startswith("- ") or ":" not in line:
                continue
            key, value = line.split(":", 1)
            fields[key.strip().lower()] = value.strip()
        blocks[current_title] = fields

    for line in text.splitlines():
        if line.startswith("## "):
            flush()
            current_title = line[3:].strip()
            current_lines = []
            continue
        if current_title is not None:
            current_lines.append(line)
    flush()
    return blocks


def extract_wiki_targets(field_value: str, base_file: Path) -> list[str]:
    targets: list[str] = []
    for label, link in re.findall(r"\[([^\]]+)\]\(<([^>]+)>\)", field_value):
        target_path = (base_file.parent / link).resolve(strict=False)
        if target_path.suffix.lower() != ".md":
            continue
        try:
            target_rel = repo_rel(target_path)
        except ValueError:
            continue
        if target_rel.startswith("Wiki/"):
            targets.append(target_rel)
    return targets


def normalize_comment(value: str) -> str:
    value = re.sub(r"\s+", " ", value).strip()
    if len(value) > 220:
        value = value[:217].rstrip() + "..."
    return value


def parse_wiki_queue(queue_file: Path, decisions_file: Path) -> list[ReviewItem]:
    queue_text = read_text_if_possible(queue_file)
    decision_blocks = parse_heading_blocks(decisions_file, required_prefix="Inbox/")
    items: list[ReviewItem] = []
    section = ""
    current: dict | None = None

    def flush() -> None:
        nonlocal current
        if not current:
            return
        source_rel = current["source_rel"]
        source_abs = REPO_ROOT / source_rel
        existing = decision_blocks.get(source_rel, {})
        existing_action = existing.get("action", "").lower()
        existing_targets = [part.strip() for part in re.split(r"[;,]", existing.get("target", "")) if part.strip()]
        existing_comment = normalize_comment(existing.get("comment", ""))
        queue_targets = current["targets"]

        if existing_action == "promote" and existing_targets:
            suggested_action = "promote"
            suggested_targets = existing_targets
            suggested_comment = existing_comment or current["note"] or current["reason"]
        elif existing_action in {"hold", "ignore"}:
            suggested_action = existing_action
            suggested_targets = []
            suggested_comment = existing_comment or current["reason"]
        elif queue_targets:
            suggested_action = "promote"
            suggested_targets = queue_targets[:1]
            suggested_comment = current["note"] or current["reason"]
        else:
            suggested_action = "hold"
            suggested_targets = []
            suggested_comment = current["reason"]

        if suggested_action == "promote":
            suggested_command = "accept"
            effect = "promote -> " + ", ".join(suggested_targets)
            commands = ["accept(승인)", "hold(보류)", "ignore(무시)", "retarget: Wiki/...", "comment: ..."]
        else:
            suggested_command = suggested_action
            effect = suggested_action
            commands = ["accept(승인)", "hold(보류)", "ignore(무시)", "promote: Wiki/...", "comment: ..."]

        snippet = clean_snippet(read_source_content(source_abs))
        summary = snippet or current["reason"] or source_rel
        queue_status = current["queue_status"]
        priority = QUEUE_PRIORITIES.get(queue_status, 90)
        items.append(
            ReviewItem(
                id=stable_review_id("wiki", source_rel),
                kind="wiki",
                key=source_rel,
                title=source_rel,
                summary=summary,
                source_path=source_rel,
                priority=priority,
                sort_key=f"{priority:02d}:{source_rel}",
                reason=current["reason"],
                suggested_command=suggested_command,
                suggested_effect=effect,
                commands=commands,
                data={
                    "source_rel": source_rel,
                    "queue_section": section,
                    "queue_status": queue_status,
                    "daily_ref": current["daily_ref"],
                    "targets": queue_targets,
                    "note": current["note"],
                    "suggested_action": suggested_action,
                    "suggested_targets": suggested_targets,
                    "suggested_comment": normalize_comment(suggested_comment),
                },
            )
        )
        current = None

    for raw in queue_text.splitlines():
        line = raw.rstrip()
        if line.startswith("## "):
            flush()
            section = line[3:].strip()
            continue
        match = re.match(r"^- \[([^\]]+)\]\(<([^>]+)>\)", line)
        if match:
            flush()
            source_rel = match.group(1)
            current = {
                "source_rel": source_rel,
                "queue_status": "",
                "daily_ref": "",
                "targets": [],
                "reason": "",
                "note": "",
            }
            continue
        if not current:
            continue
        stripped = line.strip()
        if stripped.startswith("상태:"):
            current["queue_status"] = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("Daily 근거:"):
            current["daily_ref"] = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("추천 대상:"):
            current["targets"] = extract_wiki_targets(stripped.split(":", 1)[1].strip(), queue_file)
        elif stripped.startswith("이유:"):
            current["reason"] = normalize_comment(stripped.split(":", 1)[1].strip())
        elif stripped.startswith("참고:"):
            current["note"] = normalize_comment(stripped.split(":", 1)[1].strip())
    flush()
    return items


def parse_calendar_decisions(path: Path) -> dict[str, dict[str, str]]:
    ensure_calendar_decisions_file(path)
    return parse_heading_blocks(path)


def calendar_key(title: str, daily_ref: str, text: str) -> str:
    match = re.search(r"tg:update_id:(\d+)", title)
    if not match:
        match = re.search(r"tg:update_id:(\d+)", text)
    if match:
        return f"tg:update_id:{match.group(1)}"
    digest = hashlib.sha1(f"{daily_ref}|{title}|{text}".encode("utf-8")).hexdigest()[:12]
    return f"daily:{digest}"


def strip_html_comment(text: str) -> str:
    cleaned = re.sub(r"\s*<!--.*?-->\s*", "", text).strip()
    return re.sub(r"\s+", " ", cleaned).strip()


def parse_calendar_candidates(report_file: Path, decisions_file: Path) -> list[ReviewItem]:
    decision_blocks = parse_calendar_decisions(decisions_file)
    report_text = read_text_if_possible(report_file)
    items: list[ReviewItem] = []
    section = ""
    current: dict | None = None
    in_text_block = False
    text_lines: list[str] = []

    relevant_sections = {
        "바로 캘린더에 넣을 후보": "ready",
        "이미 지난 일정 로그 후보": "past",
        "질문이 필요한 후보": "needs_question",
    }

    def flush() -> None:
        nonlocal current, text_lines, in_text_block
        if not current:
            return
        source_key = calendar_key(current["raw_title"], current["daily_ref"], current["raw_text"])
        decision = decision_blocks.get(source_key, {})
        action = decision.get("action", "").lower()
        if action in {"create", "log", "hold", "ignore"}:
            current = None
            text_lines = []
            in_text_block = False
            return

        known_date_match = re.search(r"일정 날짜 추정: (\d{4}-\d{2}-\d{2})", current["status_line"])
        known_time_match = re.search(r"일정 시간 추정: (\d{2}:\d{2})", current["status_line"])
        known_date = decision.get("date", "") or (known_date_match.group(1) if known_date_match else "")
        known_time = decision.get("time", "") or (known_time_match.group(1) if known_time_match else "")
        known_title = decision.get("title", "") or current["title"]
        comment = normalize_comment(decision.get("comment", ""))

        bucket = relevant_sections.get(section, "")
        if not bucket:
            current = None
            text_lines = []
            in_text_block = False
            return

        if bucket == "ready":
            suggested_command = "create"
            suggested_effect = "create calendar event"
        elif bucket == "past":
            suggested_command = "log"
            suggested_effect = "save as calendar log"
        elif known_date and known_time:
            suggested_command = "create"
            suggested_effect = f"create calendar event at {known_date} {known_time}"
        else:
            suggested_command = "answer"
            missing = []
            if not known_date:
                missing.append("date")
            if not known_time:
                missing.append("time")
            suggested_effect = "need " + ", ".join(missing)

        commands = []
        if bucket == "past":
            commands.append("log(기록)")
        else:
            commands.append("create(생성)")
        commands.extend(["hold(보류)", "ignore(무시)", "date: YYYY-MM-DD", "time: HH:MM", "title: ...", "comment: ..."])

        priority = CALENDAR_PRIORITIES[bucket]
        summary = strip_html_comment(current["title"])
        if comment:
            summary = f"{summary} / {comment}"
        item = ReviewItem(
            id=stable_review_id("calendar", source_key),
            kind="calendar",
            key=source_key,
            title=summary,
            summary=summary,
            source_path=current["source_path"],
            priority=priority,
            sort_key=f"{priority:02d}:{current['source_path']}:{current['line']}",
            reason=current["status_line"],
            suggested_command=suggested_command,
            suggested_effect=suggested_effect,
            commands=commands,
            data={
                "calendar_bucket": bucket,
                "source_key": source_key,
                "daily_ref": current["daily_ref"],
                "source_path": current["source_path"],
                "line": current["line"],
                "raw_text": current["raw_text"],
                "known_date": known_date,
                "known_time": known_time,
                "known_title": known_title,
                "comment": comment,
                "question": current["question"],
            },
        )
        items.append(item)
        current = None
        text_lines = []
        in_text_block = False

    for raw in report_text.splitlines():
        line = raw.rstrip("\n")
        if line.startswith("## "):
            flush()
            section = line[3:].strip()
            continue
        if section not in relevant_sections:
            continue
        if in_text_block:
            if line.strip() == "~~~":
                in_text_block = False
                if current is not None:
                    current["raw_text"] = "\n".join(text_lines).strip()
                continue
            text_lines.append(line)
            continue
        if line.startswith("- "):
            flush()
            raw_title = line[2:].strip()
            if raw_title == "아직 없음":
                current = None
                continue
            current = {
                "raw_title": raw_title,
                "title": strip_html_comment(raw_title),
                "status_line": "",
                "daily_ref": "",
                "source_path": "",
                "line": "",
                "question": "",
                "raw_text": "",
            }
            continue
        if not current:
            continue
        stripped = line.strip()
        if stripped.startswith("상태:"):
            current["status_line"] = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("근거:"):
            current["daily_ref"] = stripped.split(":", 1)[1].strip()
            match = re.search(r"\]\(<\.\./([^>]+)\>\):(\d+)", stripped)
            if match:
                current["source_path"] = match.group(1)
                current["line"] = match.group(2)
        elif stripped.startswith("확인 질문:"):
            current["question"] = normalize_comment(stripped.split(":", 1)[1].strip())
        elif stripped == "원문:":
            text_lines = []
        elif stripped == "~~~text":
            in_text_block = True
            text_lines = []
    flush()
    return items


def parse_yaml_block(block: str) -> dict[str, object]:
    data: dict[str, object] = {}
    current_list_key: str | None = None
    for raw in block.splitlines():
        if raw.startswith("  - ") and current_list_key:
            data.setdefault(current_list_key, [])
            cast = data[current_list_key]
            assert isinstance(cast, list)
            cast.append(raw[4:].strip())
            continue
        current_list_key = None
        if ":" not in raw:
            continue
        key, value = raw.split(":", 1)
        key = key.strip()
        value = value.strip()
        if value:
            data[key] = value
        else:
            data[key] = []
            current_list_key = key
    return data


def parse_wording_conflicts(wording_file: Path) -> list[ReviewItem]:
    text = read_text_if_possible(wording_file)
    pattern = re.compile(r"(?ms)^### (wording_conflict_[^\n]+)\n\n```yaml\n(.*?)\n```\n")
    items: list[ReviewItem] = []
    for match in pattern.finditer(text):
        conflict_id = match.group(1).strip()
        block = match.group(2)
        data = parse_yaml_block(block)
        status = str(data.get("status", "")).strip().lower()
        if status != "open":
            continue
        selected = str(data.get("selected", "")).strip()
        recommended = str(data.get("recommended", "")).strip()
        label = str(data.get("label", "")).strip() or conflict_id
        variants = data.get("variants", [])
        targets = data.get("targets", [])
        if not isinstance(variants, list):
            variants = []
        if not isinstance(targets, list):
            targets = []
        summary = f"{label}: " + ", ".join(variants[:3])
        choice = recommended or selected
        items.append(
            ReviewItem(
                id=stable_review_id("wording", conflict_id),
                kind="wording",
                key=conflict_id,
                title=label,
                summary=summary,
                source_path="Meta/wording-conflicts.md",
                priority=70,
                sort_key=f"70:{conflict_id}",
                reason="같은 의미의 표현 충돌이 아직 열려 있다.",
                suggested_command="accept",
                suggested_effect=f"approve -> {choice}" if choice else "approve wording",
                commands=["accept(승인)", "keep_distinct(구분)", "select: ..."],
                data={
                    "conflict_id": conflict_id,
                    "selected": selected,
                    "recommended": recommended,
                    "variants": variants,
                    "targets": targets,
                },
            )
        )
    return items


def build_items(
    queue_file: Path = DEFAULT_QUEUE_FILE,
    wiki_decisions_file: Path = DEFAULT_WIKI_DECISIONS_FILE,
    calendar_file: Path = DEFAULT_CALENDAR_FILE,
    calendar_decisions_file: Path = DEFAULT_CALENDAR_DECISIONS_FILE,
    wording_file: Path = DEFAULT_WORDING_FILE,
) -> list[ReviewItem]:
    items = []
    items.extend(parse_calendar_candidates(calendar_file, calendar_decisions_file))
    items.extend(parse_wiki_queue(queue_file, wiki_decisions_file))
    items.extend(parse_wording_conflicts(wording_file))
    items.sort(key=lambda item: (item.priority, item.sort_key, item.id))
    return items


def build_review_markdown(items: list[ReviewItem], review_file: Path, dispatch_file: Path) -> str:
    dispatch = load_json(dispatch_file, {})
    dispatch_entries = normalize_dispatch_entries(dispatch_entries_from_payload(dispatch), items)
    dispatched_by_id = {entry["id"]: entry for entry in dispatch_entries}
    dispatched_items = [item for item in items if item.id in dispatched_by_id]
    lines = [
        "# Review Queue",
        "",
        "이 문서는 텔레그램 답장 기반 검토를 위해 열린 review 항목을 하나로 모은 generated queue다.",
        "",
        "## 입력 파일",
        "",
        f"- wiki 승인: {md_link(review_file, DEFAULT_WIKI_DECISIONS_FILE, 'wiki-compile-decisions.md')}",
        f"- calendar 승인: {md_link(review_file, DEFAULT_CALENDAR_DECISIONS_FILE, 'calendar-decisions.md')}",
        f"- wording 승인: {md_link(review_file, DEFAULT_WORDING_FILE, 'wording-conflicts.md')}",
        "",
        "## 요약",
        "",
        f"- pending total: {len(items)}",
        f"- calendar: {sum(1 for item in items if item.kind == 'calendar')}",
        f"- wiki: {sum(1 for item in items if item.kind == 'wiki')}",
        f"- wording: {sum(1 for item in items if item.kind == 'wording')}",
    ]
    if dispatched_items:
        preview_items = ", ".join(f"{item.id} ({item.kind})" for item in dispatched_items[:3])
        remaining = len(dispatched_items) - min(len(dispatched_items), 3)
        lines.append(f"- active dispatch: {len(dispatched_items)}건")
        if remaining > 0:
            lines.append(f"- dispatch preview: {preview_items}, +{remaining} more")
        else:
            lines.append(f"- dispatch preview: {preview_items}")
    else:
        lines.append("- active dispatch: 없음")
    if not items:
        lines.extend(["", "## Pending Items", "", "- 현재 열린 review가 없다."])
        return "\n".join(lines).rstrip() + "\n"

    lines.extend(["", "## Pending Items", ""])
    for item in items:
        lines.append(f"### {item.id} [{item.kind}]")
        if item.source_path:
            target = REPO_ROOT / item.source_path
            if target.exists():
                lines.append(f"- source: {md_link(review_file, target, item.source_path)}")
            else:
                lines.append(f"- source: {item.source_path}")
        lines.append(f"- summary: {item.summary}")
        if item.reason:
            lines.append(f"- reason: {item.reason}")
        if item.suggested_command:
            lines.append(f"- suggested: `{item.suggested_command}` -> {item.suggested_effect}")
        if item.commands:
            lines.append("- reply:")
            for command in item.commands:
                lines.append(f"  - `{command}`")
        data = item.data or {}
        if item.kind == "wiki":
            targets = data.get("targets", [])
            if targets:
                target_links = ", ".join(md_link(review_file, REPO_ROOT / target, target) for target in targets)
                lines.append(f"- queue targets: {target_links}")
        elif item.kind == "calendar":
            if data.get("known_date") or data.get("known_time"):
                lines.append(f"- known: date={data.get('known_date') or '?'} time={data.get('known_time') or '?'}")
            if data.get("question"):
                lines.append(f"- question: {data.get('question')}")
        elif item.kind == "wording":
            variants = data.get("variants", [])
            if variants:
                lines.append("- variants: " + ", ".join(variants[:4]))
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def build_state(args: argparse.Namespace) -> int:
    items = build_items(
        queue_file=Path(args.queue_file),
        wiki_decisions_file=Path(args.wiki_decisions_file),
        calendar_file=Path(args.calendar_file),
        calendar_decisions_file=Path(args.calendar_decisions_file),
        wording_file=Path(args.wording_file),
    )
    review_file = Path(args.review_file)
    state_file = Path(args.state_file)
    dispatch_file = Path(args.dispatch_file)
    review_text = build_review_markdown(items, review_file, dispatch_file)
    review_file.write_text(review_text, encoding="utf-8")
    state_payload = {
        "generated_at": now_iso(),
        "items": [item.to_json() for item in items],
    }
    write_json(state_file, state_payload)
    if args.stdout:
        sys.stdout.write(review_text)
    return 0


def load_state_or_build(args: argparse.Namespace) -> dict:
    build_args = argparse.Namespace(
        queue_file=args.queue_file,
        wiki_decisions_file=args.wiki_decisions_file,
        calendar_file=args.calendar_file,
        calendar_decisions_file=args.calendar_decisions_file,
        wording_file=args.wording_file,
        review_file=args.review_file,
        state_file=args.state_file,
        dispatch_file=args.dispatch_file,
        stdout=False,
    )
    build_state(build_args)
    return load_json(Path(args.state_file), {"items": []})


def format_message(item: dict) -> str:
    lines = [
        f"[{item['id']}] {item['kind']}",
        f"summary: {item['summary']}",
    ]
    if item.get("source_path"):
        lines.append(f"source: {item['source_path']}")
    if item.get("reason"):
        lines.append(f"reason: {item['reason']}")
    if item.get("suggested_command"):
        lines.append(f"suggested: {item['suggested_command']} -> {item.get('suggested_effect', '')}")
    data = item.get("data", {})
    if item["kind"] == "calendar":
        known_date = data.get("known_date") or "?"
        known_time = data.get("known_time") or "?"
        lines.append(f"known: date={known_date} time={known_time}")
        if data.get("question"):
            lines.append(f"question: {data['question']}")
    lines.extend(["", "reply"])
    for command in item.get("commands", []):
        lines.append(command)
    lines.extend(
        [
            "",
            "meta",
            "review_meta_version: 1",
            f"review_id: {item['id']}",
            f"review_kind: {item['kind']}",
            f"review_key: {item['key']}",
        ]
    )
    if item.get("source_path"):
        lines.append(f"review_source: {item['source_path']}")
    if item.get("suggested_command"):
        lines.append(f"suggested_command: {item['suggested_command']}")
    data = item.get("data", {})
    if item["kind"] == "wiki":
        if data.get("suggested_action"):
            lines.append(f"suggested_action: {data['suggested_action']}")
        targets = data.get("suggested_targets", [])
        if targets:
            lines.append(f"suggested_targets: {', '.join(targets)}")
    elif item["kind"] == "calendar":
        if data.get("known_date"):
            lines.append(f"known_date: {data['known_date']}")
        if data.get("known_time"):
            lines.append(f"known_time: {data['known_time']}")
        if data.get("known_title"):
            lines.append(f"known_title: {data['known_title']}")
    elif item["kind"] == "wording":
        if data.get("selected"):
            lines.append(f"selected: {data['selected']}")
        if data.get("recommended"):
            lines.append(f"recommended: {data['recommended']}")
    return "\n".join(lines).rstrip()


def send_next(args: argparse.Namespace) -> int:
    state = load_state_or_build(args)
    items = state.get("items", [])
    dispatch_file = Path(args.dispatch_file)
    dispatch = load_json(dispatch_file, {})
    dispatch_entries = normalize_dispatch_entries(dispatch_entries_from_payload(dispatch), items)
    dispatched_ids = {entry["id"] for entry in dispatch_entries}

    if not items:
        if args.stdout:
            sys.stdout.write("review: pending 없음\n")
        else:
            print("review send: pending 없음", file=sys.stderr)
            write_dispatch(dispatch_file, [])
        return 0

    items_to_send = items if args.force else [item for item in items if item["id"] not in dispatched_ids]
    if not items_to_send:
        message = f"review: pending {len(items)}건은 이미 개별 발송됨"
        if args.stdout:
            sys.stdout.write(message + "\n")
        else:
            print(message, file=sys.stderr)
        return 0

    rendered_messages = [format_message(item) for item in items_to_send]
    if args.stdout:
        sys.stdout.write(("\n\n---\n\n").join(rendered_messages) + "\n")
        return 0

    send_script = REPO_ROOT / "scripts" / "send-telegram-message.sh"
    items_to_send_ids = {item["id"] for item in items_to_send}
    updated_entries = [entry for entry in dispatch_entries if entry["id"] not in items_to_send_ids]
    sent_at = now_iso()
    for item, message in zip(items_to_send, rendered_messages):
        subprocess.run([str(send_script)], input=message.encode("utf-8"), check=True)
        updated_entries.append(
            {
                "id": item["id"],
                "sent_at": sent_at,
                "kind": item["kind"],
                "key": item["key"],
            }
        )
    write_dispatch(dispatch_file, updated_entries)
    print(f"review send: delivered {len(items_to_send)} item(s)", file=sys.stderr)
    return 0


def parse_reply_lines(text: str) -> dict:
    result = {
        "verbs": [],
        "comment": "",
        "target": "",
        "selected": "",
        "date": "",
        "time": "",
        "title": "",
    }
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        lowered = line.lower()
        compact = re.sub(r"\s+", "", lowered)
        compact = re.sub(r"[.!?~]+$", "", compact)
        if lowered in {"accept", "승인", "승인해줘", "승인해주세요"} or compact in {"accept", "승인", "승인해줘", "승인해주세요"}:
            result["verbs"].append("accept")
            continue
        if lowered in {"hold", "보류", "보류해줘", "보류해주세요"} or compact in {"hold", "보류", "보류해줘", "보류해주세요"}:
            result["verbs"].append("hold")
            continue
        if lowered in {"ignore", "무시", "무시해줘", "무시해주세요"} or compact in {"ignore", "무시", "무시해줘", "무시해주세요"}:
            result["verbs"].append("ignore")
            continue
        if lowered in {"create", "생성", "생성해줘", "생성해주세요", "만들어줘", "만들어주세요", "추가해줘", "추가해주세요"} or compact in {"create", "생성", "생성해줘", "생성해주세요", "만들어줘", "만들어주세요", "추가해줘", "추가해주세요", "캘린더에추가해줘", "캘린더에넣어줘"}:
            result["verbs"].append("create")
            continue
        if lowered in {"log", "기록", "기록해줘", "기록해주세요"} or compact in {"log", "기록", "기록해줘", "기록해주세요", "로그로남겨줘", "로그로기록해줘"}:
            result["verbs"].append("log")
            continue
        if lowered in {"keep_distinct", "구분", "구분해줘", "구분해주세요"} or compact in {"keep_distinct", "구분", "구분해줘", "구분해주세요"}:
            result["verbs"].append("keep_distinct")
            continue
        if ":" in line:
            key, value = line.split(":", 1)
            key = key.strip().lower()
            value = value.strip()
            if key in {"comment", "메모"}:
                result["comment"] = value
            elif key in {"retarget", "promote"}:
                result["target"] = value
            elif key in {"select", "선택"}:
                result["selected"] = value
            elif key in {"date", "날짜"}:
                result["date"] = value
            elif key in {"time", "시간"}:
                result["time"] = value
            elif key in {"title", "제목"}:
                result["title"] = value
    return result


def upsert_heading_block(path: Path, heading: str, body_lines: list[str], dry_run: bool = False) -> str:
    text = read_text_if_possible(path)
    block = "\n".join([f"## {heading}", *body_lines]).rstrip() + "\n"
    pattern = re.compile(rf"(?ms)^## {re.escape(heading)}\n.*?(?=^## |\Z)")
    if pattern.search(text):
        updated = pattern.sub(block, text).rstrip() + "\n"
    else:
        spacer = "" if not text.rstrip() else "\n\n"
        updated = text.rstrip() + spacer + block
        updated = updated.rstrip() + "\n"
    if not dry_run:
        path.write_text(updated, encoding="utf-8")
    return block


def apply_wiki_reply(item: dict, parsed: dict, decisions_file: Path, dry_run: bool) -> tuple[bool, bool, str]:
    data = item.get("data", {})
    action = ""
    targets: list[str] = []
    comment = normalize_comment(parsed.get("comment", "") or data.get("suggested_comment", ""))

    verbs = parsed["verbs"]
    if "ignore" in verbs:
        action = "ignore"
    elif "hold" in verbs:
        action = "hold"
    elif parsed.get("target"):
        action = "promote"
        targets = [part.strip() for part in re.split(r"[;,]", parsed["target"]) if part.strip()]
    elif "accept" in verbs:
        action = data.get("suggested_action", "")
        targets = list(data.get("suggested_targets", []))
    elif "create" in verbs or "log" in verbs or "keep_distinct" in verbs:
        return False, False, "wiki review에는 accept/hold/ignore/retarget를 써야 한다."

    if action == "promote" and not targets:
        targets = list(data.get("suggested_targets", []))
    if action not in {"promote", "hold", "ignore"}:
        return False, False, "wiki reply를 해석하지 못했다."
    if action == "promote" and not targets:
        return False, False, "promote에는 target이 필요하다."

    body = [f"action: {action}"]
    if action == "promote":
        body.append(f"target: {', '.join(targets)}")
    if comment:
        body.append(f"comment: {comment}")
    block = upsert_heading_block(decisions_file, data["source_rel"], body, dry_run=dry_run)
    return True, True, block


def validate_date(value: str) -> bool:
    return bool(re.fullmatch(r"\d{4}-\d{2}-\d{2}", value))


def validate_time(value: str) -> bool:
    return bool(re.fullmatch(r"\d{2}:\d{2}", value))


def apply_calendar_reply(item: dict, parsed: dict, decisions_file: Path, dry_run: bool) -> tuple[bool, bool, str]:
    data = item.get("data", {})
    current = parse_calendar_decisions(decisions_file).get(item["key"], {})
    action = current.get("action", "").lower()
    date_value = parsed.get("date") or current.get("date", "") or data.get("known_date", "")
    time_value = parsed.get("time") or current.get("time", "") or data.get("known_time", "")
    title_value = parsed.get("title") or current.get("title", "") or data.get("known_title", "") or item["title"]
    comment_value = normalize_comment(parsed.get("comment") or current.get("comment", "") or data.get("comment", ""))

    if parsed.get("date") and not validate_date(parsed["date"]):
        return False, False, "date 형식은 YYYY-MM-DD 여야 한다."
    if parsed.get("time") and not validate_time(parsed["time"]):
        return False, False, "time 형식은 HH:MM 여야 한다."

    verbs = parsed["verbs"]
    if "ignore" in verbs:
        action = "ignore"
    elif "hold" in verbs:
        action = "hold"
    elif "create" in verbs:
        action = "create"
    elif "log" in verbs:
        action = "log"
    elif "accept" in verbs:
        suggested = item.get("suggested_command", "")
        if suggested in {"create", "log"}:
            action = suggested
        elif date_value and time_value:
            action = "create"
        else:
            return False, False, "이 calendar review는 날짜/시간 답이 더 필요하다."

    if action == "create":
        if not date_value or not time_value:
            return False, False, "create에는 date와 time이 모두 필요하다."

    body = [f"action: {action}"] if action else ["action:"]
    body.append(f"date: {date_value}")
    body.append(f"time: {time_value}")
    body.append(f"title: {title_value}")
    body.append(f"comment: {comment_value}")
    block = upsert_heading_block(decisions_file, item["key"], body, dry_run=dry_run)
    resolved = action in {"create", "log", "hold", "ignore"}
    return True, resolved, block


def apply_wording_reply(item: dict, parsed: dict, wording_file: Path, dry_run: bool) -> tuple[bool, bool, str]:
    data = item.get("data", {})
    conflict_id = data["conflict_id"]
    text = read_text_if_possible(wording_file)
    pattern = re.compile(rf"(?ms)(^### {re.escape(conflict_id)}\n\n```yaml\n)(.*?)(\n```)")
    match = pattern.search(text)
    if not match:
        return False, False, "wording conflict를 찾지 못했다."

    block = match.group(2)
    lines = block.splitlines()
    fields = parse_yaml_block(block)
    selected = parsed.get("selected") or str(fields.get("selected", "")).strip() or str(data.get("recommended", "")).strip()
    status = str(fields.get("status", "")).strip()
    verbs = parsed["verbs"]
    if "keep_distinct" in verbs:
        status = "keep_distinct"
    elif "accept" in verbs or parsed.get("selected"):
        status = "approved"
    else:
        return False, False, "wording review에는 accept/keep_distinct/select를 써야 한다."

    updated_lines: list[str] = []
    for raw in lines:
        if raw.startswith("status:"):
            updated_lines.append(f"status: {status}")
        elif raw.startswith("selected:"):
            updated_lines.append(f"selected: {selected}")
        else:
            updated_lines.append(raw)
    updated_block = "\n".join(updated_lines)
    updated_text = text[: match.start(2)] + updated_block + text[match.end(2) :]
    if not dry_run:
        wording_file.write_text(updated_text, encoding="utf-8")
    return True, True, updated_block


def apply_reply(args: argparse.Namespace) -> int:
    state = load_state_or_build(args)
    items = {item["id"]: item for item in state.get("items", [])}
    item = items.get(args.review_id)
    if item is None:
        print(f"review apply: id를 찾지 못했다: {args.review_id}", file=sys.stderr)
        return 1

    parsed = parse_reply_lines(args.reply)
    dispatch_file = Path(args.dispatch_file)
    dry_run = args.dry_run

    if item["kind"] == "wiki":
        ok, resolved, preview = apply_wiki_reply(item, parsed, Path(args.wiki_decisions_file), dry_run)
    elif item["kind"] == "calendar":
        ok, resolved, preview = apply_calendar_reply(item, parsed, Path(args.calendar_decisions_file), dry_run)
    elif item["kind"] == "wording":
        ok, resolved, preview = apply_wording_reply(item, parsed, Path(args.wording_file), dry_run)
    else:
        print(f"review apply: unsupported kind {item['kind']}", file=sys.stderr)
        return 1

    if not ok:
        print(preview, file=sys.stderr)
        return 1

    if dry_run:
        sys.stdout.write(preview if preview.endswith("\n") else preview + "\n")
        return 0

    build_state(
        argparse.Namespace(
            queue_file=args.queue_file,
            wiki_decisions_file=args.wiki_decisions_file,
            calendar_file=args.calendar_file,
            calendar_decisions_file=args.calendar_decisions_file,
            wording_file=args.wording_file,
            review_file=args.review_file,
            state_file=args.state_file,
            dispatch_file=args.dispatch_file,
            stdout=False,
        )
    )

    updated_state = load_json(Path(args.state_file), {"items": []})
    pending_items = updated_state.get("items", [])
    dispatch_entries = normalize_dispatch_entries(
        dispatch_entries_from_payload(load_json(dispatch_file, {})),
        pending_items,
    )
    if resolved and args.review_id not in {item["id"] for item in pending_items}:
        dispatch_entries = [entry for entry in dispatch_entries if entry["id"] != args.review_id]
    write_dispatch(dispatch_file, dispatch_entries)
    print(f"review apply: updated {args.review_id}", file=sys.stderr)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Loglife review queue helper")
    subparsers = parser.add_subparsers(dest="command", required=True)

    def add_common_flags(subparser: argparse.ArgumentParser) -> None:
        subparser.add_argument("--queue-file", default=str(DEFAULT_QUEUE_FILE))
        subparser.add_argument("--wiki-decisions-file", default=str(DEFAULT_WIKI_DECISIONS_FILE))
        subparser.add_argument("--calendar-file", default=str(DEFAULT_CALENDAR_FILE))
        subparser.add_argument("--calendar-decisions-file", default=str(DEFAULT_CALENDAR_DECISIONS_FILE))
        subparser.add_argument("--wording-file", default=str(DEFAULT_WORDING_FILE))
        subparser.add_argument("--review-file", default=str(DEFAULT_REVIEW_FILE))
        subparser.add_argument("--state-file", default=str(DEFAULT_STATE_FILE))
        subparser.add_argument("--dispatch-file", default=str(DEFAULT_DISPATCH_FILE))

    build_cmd = subparsers.add_parser("build")
    add_common_flags(build_cmd)
    build_cmd.add_argument("--stdout", action="store_true")
    build_cmd.set_defaults(func=build_state)

    send_cmd = subparsers.add_parser("send")
    add_common_flags(send_cmd)
    send_cmd.add_argument("--stdout", action="store_true")
    send_cmd.add_argument("--force", action="store_true")
    send_cmd.set_defaults(func=send_next)

    apply_cmd = subparsers.add_parser("apply")
    add_common_flags(apply_cmd)
    apply_cmd.add_argument("--review-id", required=True)
    apply_cmd.add_argument("--reply", required=True)
    apply_cmd.add_argument("--dry-run", action="store_true")
    apply_cmd.set_defaults(func=apply_reply)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
