#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: scripts/compile-wiki-state.sh [--coverage-file PATH] [--queue-file PATH] [--decisions-file PATH] [--index-file PATH]" >&2
}

repo_root="$(git rev-parse --show-toplevel)"
coverage_file="${repo_root}/Meta/wiki-coverage.md"
queue_file="${repo_root}/Meta/wiki-compile-queue.md"
decisions_file="${repo_root}/Meta/wiki-compile-decisions.md"
index_file="${repo_root}/Wiki/index.md"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --coverage-file)
      [[ $# -ge 2 ]] || {
        usage
        exit 2
      }
      coverage_file="$2"
      shift 2
      ;;
    --queue-file)
      [[ $# -ge 2 ]] || {
        usage
        exit 2
      }
      queue_file="$2"
      shift 2
      ;;
    --decisions-file)
      [[ $# -ge 2 ]] || {
        usage
        exit 2
      }
      decisions_file="$2"
      shift 2
      ;;
    --index-file)
      [[ $# -ge 2 ]] || {
        usage
        exit 2
      }
      index_file="$2"
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

python3 - "$repo_root" "$coverage_file" "$queue_file" "$decisions_file" "$index_file" <<'PY'
from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass, field
from html import unescape
from pathlib import Path
import os
import re
import subprocess
import sys


repo_root = Path(sys.argv[1])
coverage_file = Path(sys.argv[2])
queue_file = Path(sys.argv[3])
decisions_file = Path(sys.argv[4])
index_file = Path(sys.argv[5])

inbox_roots = [repo_root / "Inbox" / "Telegram", repo_root / "Inbox" / "Text"]
daily_root = repo_root / "Daily"
wiki_root = repo_root / "Wiki"

timeline_doc = wiki_root / "Timeline" / "2026.md"
health_doc = wiki_root / "Themes" / "건강.md"
family_doc = wiki_root / "Themes" / "가족-돌봄.md"
work_doc = wiki_root / "Themes" / "일-진로-창업.md"
ideas_root = wiki_root / "Ideas"

ignored_wiki_docs = {wiki_root / "index.md", wiki_root / "README.md"}
generated_sections = ("최근 자동 승격", "수동 승인 반영")


@dataclass
class SourceInfo:
    path: Path
    date: str
    sender: str
    content_type: str
    content: str
    contains_url: bool
    urls: list[str] = field(default_factory=list)
    link_contexts: list["LinkContext"] = field(default_factory=list)
    in_daily: bool = False
    linked_wikis: set[Path] = field(default_factory=set)
    auto_targets: set[Path] = field(default_factory=set)
    idea_targets: set[Path] = field(default_factory=set)
    categories: set[str] = field(default_factory=set)
    queue_status: str | None = None
    queue_reason: str = ""
    terminal: bool = False


@dataclass
class DecisionInfo:
    source: Path
    action: str
    targets: list[Path]
    comment: str


@dataclass
class LinkContext:
    url: str
    title: str
    summary: str
    fetched_via: str


def is_under(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def rel(from_path: Path, to_path: Path) -> str:
    return os.path.relpath(to_path, start=from_path.parent).replace(os.sep, "/")


def md_link(from_path: Path, to_path: Path, label: str | None = None) -> str:
    text = label or to_path.name
    return f"[{text}](<{rel(from_path, to_path)}>)"


def collect_files(root: Path, suffixes: set[str] | None = None) -> list[Path]:
    if not root.exists():
        return []
    files: list[Path] = []
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        if path.name == ".DS_Store":
            continue
        if path.name == "README.md" and is_under(path, repo_root / "Inbox"):
            continue
        if suffixes is not None and path.suffix.lower() not in suffixes:
            continue
        files.append(path)
    return files


def parse_frontmatter(text: str) -> dict[str, str]:
    if not text.startswith("---\n"):
        return {}
    end = text.find("\n---\n", 4)
    if end == -1:
        return {}
    block = text[4:end]
    data: dict[str, str] = {}
    for line in block.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        data[key.strip()] = value.strip().strip('"')
    return data


link_pattern = re.compile(r"\[[^\]]*\]\(<([^>]+)>\)|\[[^\]]*\]\(([^)]+)\)")


def strip_section(text: str, title: str) -> str:
    pattern = re.compile(rf"(?ms)^## {re.escape(title)}\n.*?(?=^## |\Z)")
    return pattern.sub("", text)


def extract_local_links(path: Path, excluded_sections: tuple[str, ...] = ()) -> list[Path]:
    text = path.read_text(encoding="utf-8")
    for title in excluded_sections:
        text = strip_section(text, title)
    results: list[Path] = []
    for match in link_pattern.finditer(text):
        link = match.group(1) or match.group(2)
        if not link:
            continue
        link = link.strip()
        if not link or link.startswith(("http://", "https://", "mailto:")):
            continue
        link = link.split("#", 1)[0].strip()
        if not link:
            continue
        results.append((path.parent / link).resolve(strict=False))
    return results


def read_text_if_possible(path: Path) -> str:
    if path.suffix.lower() not in {".md", ".txt", ".markdown"}:
        return ""
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return ""


def read_raw_content(path: Path) -> str:
    text = read_text_if_possible(path)
    if not text:
        return ""
    match = re.search(r"~~~text\n(.*?)\n~~~", text, flags=re.S)
    return match.group(1).strip() if match else text.strip()


url_pattern = re.compile(r"https?://\S+")


def extract_urls(content: str) -> list[str]:
    urls: list[str] = []
    seen: set[str] = set()
    for raw in url_pattern.findall(content):
        url = raw.rstrip(".,);]>\"'")
        if url and url not in seen:
            urls.append(url)
            seen.add(url)
    return urls


def normalize(value: str) -> str:
    lowered = value.lower().replace("비지니스", "비즈니스")
    return re.sub(r"[^0-9A-Za-z가-힣]+", " ", lowered)


def clean_snippet(content: str) -> str:
    lines: list[str] = []
    for raw in content.splitlines():
        line = raw.strip()
        if not line:
            continue
        if re.match(r"^\d+\.\s", line):
            continue
        if re.match(r"^[-*]\s+\[[ xX]\]", line):
            continue
        lowered = line.lower()
        if lowered in {"caption", "google drive", "google photos"}:
            continue
        if line.startswith("http://") or line.startswith("https://"):
            continue
        line = re.sub(r"https?://\S+", "", line).strip()
        if line:
            lines.append(line)
    if not lines:
        return ""
    joined = " / ".join(lines[:2])
    joined = re.sub(r"\s+", " ", joined).strip()
    if len(joined) > 140:
        joined = joined[:137].rstrip() + "..."
    return joined


def format_inline_snippet(value: str) -> str:
    return value.replace("`", "'")


def is_taskish(content: str) -> bool:
    if re.search(r"(?m)^\d+\.\s", content) and len([line for line in content.splitlines() if line.strip()]) >= 3:
        return True
    if re.search(r"(?m)^[-*]\s+\[[ xX]\]", content):
        return True
    task_terms = (
        "투두",
        "todo",
        "삭제하자",
        "컴파일",
        "정한다",
        "남긴다",
        "다시 적어본다",
        "협업 요청",
    )
    hits = sum(1 for term in task_terms if term in content)
    return hits >= 2


def is_weak_health_log(snippet: str) -> bool:
    normalized = snippet.strip().rstrip(".!").replace(" ", "")
    return normalized in {"기상", "잔다", "이제잔다", "취침"}


def fetch_url_text(url: str, timeout: int = 12) -> str:
    proc = subprocess.run(
        [
            "curl",
            "-LksS",
            "--max-time",
            str(timeout),
            "-A",
            "Mozilla/5.0",
            url,
        ],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        return ""
    return proc.stdout


def parse_html_context(raw: str) -> tuple[str, str]:
    if not raw:
        return "", ""
    title = ""
    description = ""
    for pattern in (
        r'<meta[^>]+property=["\']og:title["\'][^>]+content=["\'](.*?)["\']',
        r'<title[^>]*>(.*?)</title>',
    ):
        match = re.search(pattern, raw, flags=re.I | re.S)
        if match:
            title = re.sub(r"\s+", " ", unescape(match.group(1))).strip()
            break
    for pattern in (
        r'<meta[^>]+property=["\']og:description["\'][^>]+content=["\'](.*?)["\']',
        r'<meta[^>]+name=["\']description["\'][^>]+content=["\'](.*?)["\']',
    ):
        match = re.search(pattern, raw, flags=re.I | re.S)
        if match:
            description = re.sub(r"\s+", " ", unescape(match.group(1))).strip()
            break
    return title, description


def parse_readable_context(raw: str) -> tuple[str, str]:
    if not raw:
        return "", ""

    title = ""
    match = re.search(r"(?m)^Title:\s*(.+)$", raw)
    if match:
        title = match.group(1).strip()

    body = raw.split("Markdown Content:", 1)[1] if "Markdown Content:" in raw else raw
    useful_lines: list[str] = []
    for line in body.splitlines():
        text = re.sub(r"\s+", " ", line).strip()
        if not text:
            continue
        if text.startswith("[!["):
            continue
        if text.startswith("[본문 바로가기]"):
            continue
        if text.startswith("## ["):
            continue
        if text.startswith("* ["):
            continue
        if text.startswith("URL Source:") or text.startswith("Published Time:") or text.startswith("Warning:"):
            continue
        if text in {"--", "Press enter or click to view image in full size", "7 min read", "2 days ago", "**사용자 링크**"}:
            continue
        if re.fullmatch(r"\d+\s+min read", text):
            continue
        useful_lines.append(text)
        if len(useful_lines) >= 2:
            break

    summary = " / ".join(useful_lines)
    summary = re.sub(r"\s+", " ", summary).strip()
    if len(summary) > 220:
        summary = summary[:217].rstrip() + "..."
    return title, summary


def fetch_link_context(url: str) -> LinkContext | None:
    direct_raw = fetch_url_text(url, timeout=10)
    title, summary = parse_html_context(direct_raw)
    blocked_titles = {
        "",
        "Just a moment...",
        "Attention Required! | Cloudflare",
        "장소 - 네이버지도",
    }
    if title not in blocked_titles and (title or summary):
        return LinkContext(url=url, title=title, summary=summary, fetched_via="direct")

    fallback_url = f"https://r.jina.ai/http://{url}"
    readable_raw = fetch_url_text(fallback_url, timeout=20)
    title, summary = parse_readable_context(readable_raw)
    if is_generic_link_title(title):
        summary = ""
    if title or summary:
        return LinkContext(url=url, title=title, summary=summary, fetched_via="r.jina.ai")
    return None


def ensure_link_contexts(info: SourceInfo) -> None:
    if info.link_contexts or not info.urls:
        return
    for url in info.urls[:2]:
        context = fetch_link_context(url)
        if context is not None:
            info.link_contexts.append(context)


def guess_idea_targets(info: SourceInfo) -> set[Path]:
    if not is_under(info.path, repo_root / "Inbox" / "Text"):
        return set()

    blob = normalize(f"{info.path.stem} {info.content}")
    targets: set[Path] = set()

    if "용사였던 기억" in blob or ("용사" in blob and "마왕" in blob and "치매" in blob):
        targets.add(ideas_root / "나는-용사였던-기억을.md")

    if "blood dungeon" in blob or ("던전" in blob and "tv" in blob and "용사" in blob):
        targets.add(ideas_root / "블러드-던전-tv.md")

    if "무한 동물원" in blob or ("동물원" in blob and "동물" in blob and "먹이" in blob):
        targets.add(ideas_root / "무한-동물원.md")

    if "동물 인권" in blob or "침팬지" in blob or "원숭이" in blob:
        targets.add(ideas_root / "동물-인권.md")

    if "영생" in blob and "자유" in blob:
        targets.add(ideas_root / "영생-vs-자유.md")

    return {path for path in targets if path.exists()}


def is_generic_link_title(title: str) -> bool:
    normalized = title.strip().lower()
    return normalized in {
        "",
        "just a moment...",
        "장소 - 네이버지도",
    } or normalized.endswith(" - 네이버지도")


def parse_source(path: Path) -> SourceInfo:
    text = read_text_if_possible(path)
    meta = parse_frontmatter(text)
    content = read_raw_content(path)
    urls = extract_urls(content)
    return SourceInfo(
        path=path,
        date=meta.get("date", ""),
        sender=meta.get("sender", ""),
        content_type=meta.get("content_type", ""),
        content=content,
        contains_url=bool(urls),
        urls=urls,
    )


def ensure_decisions_file(path: Path) -> None:
    if path.exists():
        return
    template = "\n".join(
        [
            "# Wiki Compile Decisions",
            "",
            "이 파일은 `Meta/wiki-compile-queue.md`에서 나온 warning에 대한 사람 판단을 기록한다.",
            "",
            "## 규칙",
            "",
            "- 각 항목은 source 경로를 `## Inbox/...` 형식 헤더로 쓴다.",
            "- `action`은 `promote`, `hold`, `ignore` 중 하나다.",
            "- `target`은 `promote`일 때만 쓰고, 여러 개면 쉼표로 구분한다.",
            "- `comment`는 선택이지만 가능한 한 짧게 남긴다.",
            "- compile은 이 파일을 읽어 `promote`는 `Wiki` 문서의 `수동 승인 반영` 섹션에 반영하고, `hold`와 `ignore`는 queue에서 제외한다.",
            "",
            "## 예시",
            "",
            "- heading: `## Inbox/Telegram/2026-04-14/942071338.md`",
            "- action: `promote`",
            "- target: `Wiki/Self/Tensions.md`",
            "- comment: `후배에게 베푸는 마음과 손해감이 같이 드러나는 긴장으로 본다.`",
            "",
        ]
    )
    path.write_text(template, encoding="utf-8")


def parse_decisions(path: Path) -> tuple[dict[Path, DecisionInfo], list[str]]:
    text = path.read_text(encoding="utf-8")
    decisions: dict[Path, DecisionInfo] = {}
    errors: list[str] = []
    current_title: str | None = None
    current_lines: list[str] = []

    def flush(title: str | None, lines: list[str]) -> None:
        if not title or not title.startswith("Inbox/"):
            return
        source_path = (repo_root / title).resolve(strict=False)
        fields: dict[str, str] = {}
        for raw in lines:
            line = raw.strip()
            if not line or line.startswith("- "):
                continue
            if ":" not in line:
                continue
            key, value = line.split(":", 1)
            fields[key.strip().lower()] = value.strip()

        action = fields.get("action", "").lower()
        target_value = fields.get("target", "")
        comment = fields.get("comment", "")

        if action not in {"promote", "hold", "ignore"}:
            errors.append(f"{title}: action은 promote, hold, ignore 중 하나여야 한다.")
            return

        if source_path not in infos:
            errors.append(f"{title}: source를 찾을 수 없다.")
            return

        targets: list[Path] = []
        if action == "promote":
            if not target_value:
                errors.append(f"{title}: promote에는 target이 필요하다.")
                return
            for raw_target in re.split(r"[;,]", target_value):
                target_text = raw_target.strip()
                if not target_text:
                    continue
                target_path = (repo_root / target_text).resolve(strict=False)
                if not is_under(target_path, wiki_root) or target_path.suffix.lower() != ".md":
                    errors.append(f"{title}: target은 Wiki 아래의 markdown 파일이어야 한다.")
                    continue
                if not target_path.exists():
                    errors.append(f"{title}: target 파일이 존재하지 않는다: {target_text}")
                    continue
                targets.append(target_path)
            if not targets:
                return

        decisions[source_path] = DecisionInfo(
            source=source_path,
            action=action,
            targets=targets,
            comment=comment,
        )

    for line in text.splitlines():
        if line.startswith("## "):
            flush(current_title, current_lines)
            current_title = line[3:].strip()
            current_lines = []
            continue
        if current_title is not None:
            current_lines.append(line)
    flush(current_title, current_lines)
    return decisions, errors


def classify_source(info: SourceInfo) -> None:
    blob = normalize(info.content)
    snippet = clean_snippet(info.content)
    info.idea_targets = guess_idea_targets(info)

    if info.sender == "@setup_check" or "setup check" in blob or "allowlist check" in blob:
        info.terminal = True
        return

    if not snippet:
        info.terminal = True
        return

    if is_taskish(info.content):
        info.terminal = True
        return

    if is_weak_health_log(snippet):
        info.terminal = True
        return

    measure_health = any(term in info.content for term in ("체중", "몸무게"))
    activity_health = any(term in info.content for term in ("조깅", "러닝", "운동"))
    sleep_health = any(
        term in info.content for term in ("잠을 못", "수면", "잠이", "잠 못", "낑낑", "두드러기", "상처", "아프")
    )
    wake_health = "기상" in info.content and bool(re.search(r"\d+\s*시", info.content))
    strong_health = measure_health or activity_health or sleep_health or wake_health

    family_terms = ("민하", "민엽", "아내", "배우자", "부모님", "가족", "할아버지", "제사", "생일", "어머니", "아버지")
    work_terms = ("비즈니스팀", "제페토", "리드", "회사", "영어 회의", "창업", "리더십", "직방", "네이버제트")
    reflection_terms = ("어렵", "아깝", "모르겠다", "생각", "감상", "왜", "어떻게", "원하는가", "무엇을")
    meal_terms = ("점심", "저녁", "돈까스", "햄버거", "에이드", "커피", "우롱", "사내식당", "카페")
    trivial_terms = ("사진 변환 테스트", "구글 포토", "구글 드라이브로 수정", "google photos", "google drive")

    strong_family = any(term in info.content for term in family_terms)
    strong_work = any(term in info.content for term in work_terms)
    strong_reflection = len(snippet) >= 18 and any(term in info.content for term in reflection_terms)
    trivial_meal = any(term in info.content for term in meal_terms) and not (
        strong_health or strong_family or strong_work or strong_reflection or info.contains_url
    )
    trivial_misc = any(term in blob for term in trivial_terms) and not (
        strong_health or strong_family or strong_work or strong_reflection
    )

    if trivial_meal or trivial_misc:
        info.terminal = True
        return

    if strong_health:
        info.categories.add("health")
        info.auto_targets.add(health_doc)

    if strong_family:
        info.categories.add("family")
        info.auto_targets.add(family_doc)

    if strong_work:
        info.categories.add("work")
        info.auto_targets.add(work_doc)

    if strong_reflection:
        info.categories.add("reflection")

    if info.idea_targets:
        info.categories.add("idea")
        info.queue_status = "needs_idea_triage"
        info.queue_reason = "창작/게임/세계관 아이디어라 `Wiki/Ideas` 문서 triage가 필요하다."
        return

    if info.contains_url and not info.auto_targets:
        info.queue_status = "needs_link_summary"
        info.queue_reason = "링크는 있지만 관련 Wiki 요약이 아직 없다."
        return

    if info.categories == {"reflection"}:
        info.queue_status = "needs_self_triage"
        info.queue_reason = "자기이해 성격의 메모지만 자동 대상 문서를 단정하기 어렵다."
        return

    if not info.auto_targets and not info.terminal:
        if is_under(info.path, repo_root / "Inbox" / "Text"):
            info.queue_status = "needs_manual_merge"
            info.queue_reason = "Text source라 기존 Wiki 문서에 수동 merge가 필요하다."
        elif info.in_daily:
            info.queue_status = "needs_triage"
            info.queue_reason = "Daily에는 반영됐지만 승격 대상이 아직 모호하다."
        else:
            info.queue_status = "needs_manual_merge"
            info.queue_reason = "아직 Daily/Wiki 어느 쪽에도 연결되지 않았다."


def replace_section(text: str, title: str, body: str, before_title: str | None = None) -> str:
    pattern = re.compile(rf"(?ms)^## {re.escape(title)}\n.*?(?=^## |\Z)")
    replacement = f"## {title}\n\n{body.strip()}\n" if body.strip() else ""

    if pattern.search(text):
        if replacement:
            text = pattern.sub(replacement + "\n", text, count=1)
        else:
            text = pattern.sub("", text, count=1)
    elif replacement:
        if before_title:
            marker = f"\n## {before_title}\n"
            if marker in text:
                text = text.replace(marker, "\n" + replacement + "\n" + marker, 1)
            else:
                text = text.rstrip() + "\n\n" + replacement + "\n"
        else:
            text = text.rstrip() + "\n\n" + replacement + "\n"

    text = re.sub(r"\n{3,}", "\n\n", text).rstrip() + "\n"
    return text


def write_generated_section(doc_path: Path, title: str, body: str, before_title: str | None = None) -> None:
    text = doc_path.read_text(encoding="utf-8")
    updated = replace_section(text, title, body, before_title=before_title)
    if updated != text:
        doc_path.write_text(updated, encoding="utf-8")


def assign_wiki_links(
    infos: dict[Path, SourceInfo],
    wiki_files: list[Path],
    excluded_sections: tuple[str, ...] = (),
) -> None:
    for info in infos.values():
        info.linked_wikis.clear()
    for wiki in wiki_files:
        if wiki in ignored_wiki_docs:
            continue
        for target in extract_local_links(wiki, excluded_sections=excluded_sections):
            info = infos.get(target)
            if info is not None:
                info.linked_wikis.add(wiki)


def render_timeline_item(info: SourceInfo) -> str:
    labels = []
    if "health" in info.categories:
        labels.append("건강")
    if "family" in info.categories:
        labels.append("가족")
    if "work" in info.categories:
        labels.append("일")
    label = ", ".join(labels) if labels else "기록"
    snippet = format_inline_snippet(clean_snippet(info.content))
    return f"- {label}: `{snippet}`\n  근거: {md_link(timeline_doc, info.path)}"


def render_theme_item(doc_path: Path, info: SourceInfo) -> str:
    snippet = format_inline_snippet(clean_snippet(info.content))
    return f"- `{snippet}`\n  근거: {md_link(doc_path, info.path)}"


def render_recent_section(doc_path: Path, grouped: dict[str, list[SourceInfo]], timeline: bool = False) -> str:
    if not grouped:
        return ""

    intro = (
        "이 구간은 `Inbox/Telegram -> Daily -> Wiki`에서 자동 승격된 최근 항목만 다시 쓴다."
        if timeline
        else "이 구간은 최근 Telegram 기록 중 이 주제에 자동 승격된 항목만 다시 쓴다."
    )

    parts = [intro, ""]
    for date in sorted(grouped.keys(), reverse=True):
        parts.append(f"### {date}")
        parts.append("")
        for info in grouped[date]:
            parts.append(render_timeline_item(info) if timeline else render_theme_item(doc_path, info))
            parts.append("")
    return "\n".join(parts).rstrip()


def has_section(doc_path: Path, title: str) -> bool:
    text = doc_path.read_text(encoding="utf-8")
    pattern = re.compile(rf"(?m)^## {re.escape(title)}\n")
    return bool(pattern.search(text))


def render_manual_item(doc_path: Path, info: SourceInfo, comment: str) -> str:
    snippet = format_inline_snippet(clean_snippet(info.content))
    lines = [f"- `{snippet}`"]
    if comment:
        lines.append(f"  코멘트: {comment}")
    lines.append(f"  근거: {md_link(doc_path, info.path)}")
    return "\n".join(lines)


def render_manual_section(doc_path: Path, grouped: dict[str, list[tuple[SourceInfo, str]]]) -> str:
    if not grouped:
        return ""

    parts = [
        "이 구간은 `Meta/wiki-compile-decisions.md`에서 승인한 항목만 다시 쓴다.",
        "",
    ]
    for date in sorted(grouped.keys(), reverse=True):
        parts.append(f"### {date}")
        parts.append("")
        for info, comment in grouped[date]:
            parts.append(render_manual_item(doc_path, info, comment))
            parts.append("")
    return "\n".join(parts).rstrip()


def suggest_targets(info: SourceInfo) -> list[tuple[str, str]]:
    suggestions: list[tuple[str, str]] = []

    def add(target: str, reason: str) -> None:
        entry = (target, reason)
        if entry not in suggestions:
            suggestions.append(entry)

    blob = normalize(info.content)

    if info.queue_status == "needs_link_summary":
        add("Daily/YYYY/YYYY-MM-DD.md", "링크 메모를 Daily에 짧게 요약하고, 필요하면 관련 Wiki로 연결해야 한다.")
        ensure_link_contexts(info)
        for context in info.link_contexts[:1]:
            if context.title and not is_generic_link_title(context.title):
                add("Wiki/Questions/*.md", f"링크 주제가 `{context.title}`라면 질문/개념 메모로 확장할 수 있다.")

    if "health" in info.categories:
        add("Wiki/Themes/건강.md", "건강/루틴 단서가 보인다.")

    if "family" in info.categories:
        add("Wiki/Themes/가족-돌봄.md", "가족/돌봄 단서가 보인다.")

    if "work" in info.categories:
        add("Wiki/Themes/일-진로-창업.md", "일/진로/창업 축의 단서가 보인다.")

    if "reflection" in info.categories and not info.idea_targets:
        add("Wiki/Self/Tensions.md", "자기 긴장이나 감정 해석 단서가 보인다.")
        add("Wiki/Self/Open Questions.md", "닫히지 않은 질문으로 이어질 수 있다.")

    if info.idea_targets:
        for target in sorted(info.idea_targets):
            add(target.relative_to(repo_root).as_posix(), "창작/게임/세계관 아이디어를 간단한 노드로 누적할 수 있다.")

    if is_under(info.path, repo_root / "Inbox" / "Telegram") and info.in_daily:
        add("Wiki/Timeline/2026.md", "당일 맥락은 우선 연표에 반영할 수 있다.")

    if is_under(info.path, repo_root / "Inbox" / "Text") and not suggestions:
        if any(term in blob for term in ("이력서", "resume", "career", "경력")):
            add("Wiki/Self/Career.md", "이력서/경력 문서 성격이 보인다.")
        elif any(term in blob for term in ("발표", "강연", "slides", "ndc")):
            add("Wiki/Self/Speaking.md", "발표/강연 자료 성격이 보인다.")
        else:
            add("Wiki/index.md", "수동 triage가 필요하다.")

    if not suggestions:
        add("Wiki/index.md", "수동 triage가 필요하다.")

    return suggestions[:3]


source_paths: list[Path] = []
for root in inbox_roots:
    source_paths.extend(collect_files(root))
source_paths = sorted(source_paths)
infos = {path: parse_source(path) for path in source_paths}

ensure_decisions_file(decisions_file)

daily_files = collect_files(daily_root, {".md"})
telegram_by_update_id: dict[str, Path] = {}
for path in source_paths:
    if is_under(path, repo_root / "Inbox" / "Telegram") and path.stem.isdigit():
        telegram_by_update_id[path.stem] = path

for daily in daily_files:
    daily_text = daily.read_text(encoding="utf-8")
    for update_id in re.findall(r"tg:update_id:(\d+)", daily_text):
        source = telegram_by_update_id.get(update_id)
        if source is not None:
            infos[source].in_daily = True
    for target in extract_local_links(daily):
        info = infos.get(target)
        if info is not None:
            info.in_daily = True

wiki_files = collect_files(wiki_root, {".md"})
assign_wiki_links(infos, wiki_files, excluded_sections=generated_sections)

for info in infos.values():
    classify_source(info)


auto_candidates = [
    info
    for info in sorted(infos.values(), key=lambda item: item.path.as_posix())
    if is_under(info.path, repo_root / "Inbox" / "Telegram")
    and info.in_daily
    and not info.linked_wikis
    and info.auto_targets
]

timeline_grouped: dict[str, list[SourceInfo]] = defaultdict(list)
theme_grouped: dict[Path, dict[str, list[SourceInfo]]] = defaultdict(lambda: defaultdict(list))

for info in auto_candidates:
    timeline_grouped[info.date].append(info)
    for target_doc, category in ((health_doc, "health"), (family_doc, "family"), (work_doc, "work")):
        if category in info.categories and target_doc in info.auto_targets:
            theme_grouped[target_doc][info.date].append(info)

write_generated_section(
    timeline_doc,
    "최근 자동 승격",
    render_recent_section(timeline_doc, timeline_grouped, timeline=True),
    before_title="연결",
)

for doc_path in (health_doc, family_doc, work_doc):
    write_generated_section(
        doc_path,
        "최근 자동 승격",
        render_recent_section(doc_path, theme_grouped.get(doc_path, {})),
        before_title="연결",
    )

decisions, decision_errors = parse_decisions(decisions_file)
manual_grouped: dict[Path, dict[str, list[tuple[SourceInfo, str]]]] = defaultdict(lambda: defaultdict(list))
decision_suppressed_paths: set[Path] = set()

for decision in decisions.values():
    if decision.action in {"hold", "ignore"}:
        decision_suppressed_paths.add(decision.source)
        continue
    info = infos[decision.source]
    for target in decision.targets:
        manual_grouped[target][info.date].append((info, decision.comment))

manual_target_docs = {
    doc
    for doc in wiki_files
    if doc not in ignored_wiki_docs and has_section(doc, "수동 승인 반영")
}
manual_target_docs.update(manual_grouped.keys())

for doc_path in sorted(manual_target_docs):
    write_generated_section(
        doc_path,
        "수동 승인 반영",
        render_manual_section(doc_path, manual_grouped.get(doc_path, {})),
        before_title="연결",
    )

# Rebuild mappings after generated Wiki sections are written.
wiki_files = collect_files(wiki_root, {".md"})
assign_wiki_links(infos, wiki_files)

source_to_dailies: dict[Path, set[Path]] = defaultdict(set)
for daily in daily_files:
    daily_text = daily.read_text(encoding="utf-8")
    for update_id in re.findall(r"tg:update_id:(\d+)", daily_text):
        source = telegram_by_update_id.get(update_id)
        if source is not None:
            source_to_dailies[source].add(daily)
    for target in extract_local_links(daily):
        info = infos.get(target)
        if info is not None:
            source_to_dailies[target].add(daily)

source_to_wikis: dict[Path, set[Path]] = defaultdict(set)
wiki_to_sources: dict[Path, set[Path]] = defaultdict(set)
for wiki in wiki_files:
    if wiki in ignored_wiki_docs:
        continue
    for target in extract_local_links(wiki):
        info = infos.get(target)
        if info is not None:
            source_to_wikis[target].add(wiki)
            wiki_to_sources[wiki].add(target)

daily_terminal = [info for info in infos.values() if info.in_daily and not info.linked_wikis and info.terminal]
queue_candidates = [
    info
    for info in infos.values()
    if not info.linked_wikis and info.queue_status and info.path not in decision_suppressed_paths
]
wiki_linked = [info for info in infos.values() if info.linked_wikis]


def root_stats(root: Path) -> tuple[int, int, int]:
    root_infos = [info for info in infos.values() if is_under(info.path, root)]
    daily_count = sum(1 for info in root_infos if info.in_daily)
    wiki_count = sum(1 for info in root_infos if info.linked_wikis)
    return len(root_infos), daily_count, wiki_count


root_lines = []
for root in inbox_roots:
    total, daily_count, wiki_count = root_stats(root)
    root_lines.append(f"- `{root.relative_to(repo_root).as_posix()}`: total {total}, Daily 연결 {daily_count}, Wiki 연결 {wiki_count}")

page_rows = []
for wiki in sorted(wiki_to_sources):
    if wiki.name in {"README.md", "index.md"}:
        continue
    page_rows.append((len(wiki_to_sources[wiki]), wiki))
page_rows.sort(key=lambda item: (-item[0], item[1].as_posix()))

page_lines = []
for count, wiki in page_rows[:20]:
    page_lines.append(f"- {md_link(coverage_file, wiki, wiki.relative_to(repo_root).as_posix())}: source {count}건")
if not page_lines:
    page_lines.append("- 아직 없음")

source_rows = []
for info in infos.values():
    linked_pages = source_to_wikis.get(info.path, set())
    if not linked_pages:
        continue
    source_rows.append((len(linked_pages), info.path))
source_rows.sort(key=lambda item: (-item[0], item[1].as_posix()))

source_lines = []
for count, path in source_rows[:20]:
    targets = ", ".join(md_link(coverage_file, wiki, wiki.relative_to(repo_root).as_posix()) for wiki in sorted(source_to_wikis[path]))
    source_lines.append(f"- {md_link(coverage_file, path, path.relative_to(repo_root).as_posix())}: Wiki {count}곳 -> {targets}")
if not source_lines:
    source_lines.append("- 아직 없음")

coverage_body = "\n".join(
    [
        "# Wiki Coverage",
        "",
        "이 문서는 `Inbox -> Daily -> Wiki` 반영 상태를 요약한다.",
        "",
        "## 요약",
        "",
        f"- Inbox source total: {len(infos)}",
        f"- Daily까지 연결: {sum(1 for info in infos.values() if info.in_daily)}",
        f"- Wiki까지 연결: {len(wiki_linked)}",
        f"- Daily에서 종료된 source: {len(daily_terminal)}",
        f"- 승격/요약 대기 queue: {len(queue_candidates)}",
        f"- 결정 파일로 보류/무시된 source: {len(decision_suppressed_paths)}",
        f"- 아직 raw 상태: {sum(1 for info in infos.values() if not info.in_daily and not info.linked_wikis)}",
        "",
        "## 소스 루트별 상태",
        "",
        *root_lines,
        "",
        "## source를 많이 참조하는 Wiki 페이지",
        "",
        *page_lines,
        "",
        "## 여러 Wiki 페이지에 재사용되는 source",
        "",
        *source_lines,
        "",
    ]
)
coverage_file.write_text(coverage_body.rstrip() + "\n", encoding="utf-8")


def queue_lines(items: list[SourceInfo]) -> list[str]:
    lines: list[str] = []
    for info in items:
        lines.append(f"- {md_link(queue_file, info.path, info.path.relative_to(repo_root).as_posix())}")
        lines.append(f"  상태: {info.queue_status}")
        if source_to_dailies.get(info.path):
            daily_links = ", ".join(md_link(queue_file, daily, daily.name) for daily in sorted(source_to_dailies[info.path]))
            lines.append(f"  Daily 근거: {daily_links}")
        suggestions = suggest_targets(info)
        target_links = ", ".join(
            md_link(queue_file, repo_root / target, target)
            for target, _ in suggestions
            if "*" not in target and target != "Daily/YYYY/YYYY-MM-DD.md"
        )
        virtual_targets = ", ".join(f"`{target}`" for target, _ in suggestions if "*" in target or target == "Daily/YYYY/YYYY-MM-DD.md")
        chunks = [chunk for chunk in (target_links, virtual_targets) if chunk]
        if chunks:
            lines.append(f"  추천 대상: {'; '.join(chunks)}")
        reasons = " / ".join(reason for _, reason in suggestions)
        if info.queue_reason:
            lines.append(f"  이유: {info.queue_reason}")
        if reasons:
            lines.append(f"  참고: {reasons}")
        if info.contains_url:
            ensure_link_contexts(info)
            for context in info.link_contexts[:2]:
                parts = []
                if context.title:
                    parts.append(f"`{context.title}`")
                if context.summary:
                    parts.append(context.summary)
                if parts:
                    lines.append(f"  링크 코멘트 초안: {' / '.join(parts)}")
    if not lines:
        lines.append("- 아직 없음")
    return lines


queue_groups: dict[str, list[SourceInfo]] = defaultdict(list)
for info in sorted(queue_candidates, key=lambda item: item.path.as_posix()):
    queue_groups[info.queue_status or "needs_triage"].append(info)

status_titles = {
    "needs_link_summary": "링크 요약이 필요한 source",
    "needs_idea_triage": "Ideas 문서 triage가 필요한 source",
    "needs_self_triage": "Self 문서 triage가 필요한 source",
    "needs_manual_merge": "기존 Wiki 문서에 수동 merge가 필요한 source",
    "needs_triage": "승격 대상이 아직 모호한 source",
}

queue_parts = [
    "# Wiki Compile Queue",
    "",
    "이 문서는 자동 반영이 끝난 뒤에도 추가 판단이 필요한 source만 남긴다.",
    f"판단 입력 파일: {md_link(queue_file, decisions_file, 'wiki-compile-decisions.md')}",
    "",
    "## 요약",
    "",
    f"- source total: {len(infos)}",
    f"- Daily에서 종료: {len(daily_terminal)}",
    f"- queue total: {len(queue_candidates)}",
    f"- 결정 파일로 보류/무시: {len(decision_suppressed_paths)}",
    f"- 자세한 상태: {md_link(queue_file, coverage_file, 'wiki-coverage.md')}",
    "",
]

if decision_errors:
    queue_parts.extend(
        [
            "## 결정 파일 오류",
            "",
            *[f"- {message}" for message in decision_errors],
            "",
        ]
    )

for status in ("needs_link_summary", "needs_idea_triage", "needs_self_triage", "needs_manual_merge", "needs_triage"):
    queue_parts.extend(
        [
            f"## {status_titles[status]}",
            "",
            *queue_lines(queue_groups.get(status, [])),
            "",
        ]
    )

queue_file.write_text("\n".join(queue_parts).rstrip() + "\n", encoding="utf-8")

preview_items = sorted(queue_candidates, key=lambda info: info.path.stat().st_mtime, reverse=True)[:5]
preview_lines = [
    f"- source total: {len(infos)} / Daily 연결: {sum(1 for info in infos.values() if info.in_daily)} / Wiki 연결: {len(wiki_linked)}",
    f"- Daily에서 종료: {len(daily_terminal)} / queue: {len(queue_candidates)} / 보류·무시: {len(decision_suppressed_paths)}",
    f"- 상태 상세: {md_link(index_file, coverage_file, 'Meta/wiki-coverage.md')}",
    f"- 승격 대기 큐: {md_link(index_file, queue_file, 'Meta/wiki-compile-queue.md')}",
    f"- 결정 파일: {md_link(index_file, decisions_file, 'Meta/wiki-compile-decisions.md')}",
]
if preview_items:
    preview_lines.append("- 최근 queue source:")
    for info in preview_items:
        preview_lines.append(f"  - {md_link(index_file, info.path, info.path.relative_to(repo_root).as_posix())}")

index_text = index_file.read_text(encoding="utf-8")
index_text = replace_section(index_text, "컴파일 상태", "\n".join(preview_lines), before_title="핵심 목차")
index_file.write_text(index_text, encoding="utf-8")
PY
