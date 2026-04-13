const state = {
  rootHandle: null,
  tasks: [],
  completedKeys: new Set(),
  activeTaskIndex: -1,
  todayFocus: null,
};

const el = {
  connectBtn: document.getElementById("connect-btn"),
  reloadBtn: document.getElementById("reload-btn"),
  statusText: document.getElementById("status-text"),
  openCount: document.getElementById("open-count"),
  doneCount: document.getElementById("done-count"),
  todayFocusCard: document.getElementById("today-focus-card"),
  taskList: document.getElementById("task-list"),
  dialog: document.getElementById("complete-dialog"),
  completeForm: document.getElementById("complete-form"),
  dialogTaskText: document.getElementById("dialog-task-text"),
  cancelComplete: document.getElementById("cancel-complete"),
  doneNote: document.getElementById("done-note"),
  doneLinks: document.getElementById("done-links"),
  doneFiles: document.getElementById("done-files"),
  todayDialog: document.getElementById("today-note-dialog"),
  todayNoteForm: document.getElementById("today-note-form"),
  todayDialogFocusText: document.getElementById("today-dialog-focus-text"),
  cancelTodayNote: document.getElementById("cancel-today-note"),
  todayNote: document.getElementById("today-note"),
  todayLinks: document.getElementById("today-links"),
  todayFiles: document.getElementById("today-files"),
};

function setStatus(text) {
  el.statusText.textContent = text;
}

function fnv1a(input) {
  let hash = 0x811c9dc5;
  for (let i = 0; i < input.length; i += 1) {
    hash ^= input.charCodeAt(i);
    hash = (hash + ((hash << 1) + (hash << 4) + (hash << 7) + (hash << 8) + (hash << 24))) >>> 0;
  }
  return hash.toString(16).padStart(8, "0");
}

function taskKeyFromText(text) {
  return `task-${fnv1a(text.trim().toLowerCase())}`;
}

function sanitizeName(name) {
  const replaced = name.replace(/[<>:"/\\|?*\u0000-\u001F]/g, "_");
  const trimmed = replaced.replace(/[.\s]+$/g, "");
  return trimmed || "attachment";
}

function timestampCompact(date = new Date()) {
  const y = date.getFullYear();
  const mo = `${date.getMonth() + 1}`.padStart(2, "0");
  const d = `${date.getDate()}`.padStart(2, "0");
  const h = `${date.getHours()}`.padStart(2, "0");
  const mi = `${date.getMinutes()}`.padStart(2, "0");
  const s = `${date.getSeconds()}`.padStart(2, "0");
  return `${y}${mo}${d}-${h}${mi}${s}`;
}

function cleanTaskText(line) {
  let text = line.trim().replace(/^- /, "").trim();
  text = text.replace(/^`(.+)`\.?$/, "$1");
  return text;
}

function escapeHtml(input) {
  return String(input)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function quoteYamlString(input) {
  return `"${String(input).replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
}

function splitPath(path) {
  return String(path)
    .split("/")
    .map((segment) => segment.trim())
    .filter(Boolean);
}

function resolveVaultPath(basePath, targetPath) {
  const clean = String(targetPath).trim().replace(/^<|>$/g, "");
  if (!clean) {
    return "";
  }

  if (/^[a-z]+:\/\//i.test(clean)) {
    return clean;
  }

  const baseSegments = splitPath(basePath).slice(0, -1);
  const resolved = [...baseSegments];

  for (const segment of clean.split("/")) {
    if (!segment || segment === ".") {
      continue;
    }
    if (segment === "..") {
      if (resolved.length > 0) {
        resolved.pop();
      }
      continue;
    }
    resolved.push(segment);
  }

  return resolved.join("/");
}

function toSiteHref(vaultPath) {
  if (!vaultPath) {
    return "";
  }
  if (/^[a-z]+:\/\//i.test(vaultPath)) {
    return vaultPath;
  }
  return `../${vaultPath}`;
}

function relativePath(fromFilePath, toPath) {
  if (/^[a-z]+:\/\//i.test(toPath)) {
    return toPath;
  }

  const fromSegments = splitPath(fromFilePath).slice(0, -1);
  const toSegments = splitPath(toPath);

  let shared = 0;
  while (
    shared < fromSegments.length &&
    shared < toSegments.length &&
    fromSegments[shared] === toSegments[shared]
  ) {
    shared += 1;
  }

  const up = new Array(fromSegments.length - shared).fill("..");
  const down = toSegments.slice(shared);
  return [...up, ...down].join("/") || ".";
}

function markdownLinkForVaultPath(label, vaultPath, destinationPath) {
  const safeLabel = String(label).replace(/]/g, "\\]");
  if (/^[a-z]+:\/\//i.test(vaultPath)) {
    return `[${safeLabel}](${vaultPath})`;
  }
  return `[${safeLabel}](<${relativePath(destinationPath, vaultPath)}>)`;
}

function parseMarkdownLink(text) {
  const match = text.match(/\[(.+?)\]\(<(.+?)>\)/) || text.match(/\[(.+?)\]\((.+?)\)/);
  if (!match) {
    return null;
  }
  return {
    label: match[1].trim(),
    href: match[2].trim(),
  };
}

function parseBulletedSection(markdown, sectionName, sourcePath) {
  const lines = markdown.split(/\r?\n/);
  const items = [];
  let section = "";

  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    const header = line.match(/^##\s+(.+)$/);
    if (header) {
      section = header[1].trim();
      continue;
    }

    if (section !== sectionName || !line.trim().startsWith("- ")) {
      continue;
    }

    const text = cleanTaskText(line);
    const evidence = [];

    let j = i + 1;
    while (j < lines.length && lines[j].startsWith("  ")) {
      const ev = lines[j].match(/^\s*근거:\s*\[(.+?)\]\((.+?)\)\s*$/);
      if (ev) {
        const vaultPath = resolveVaultPath(sourcePath, ev[2]);
        evidence.push({
          label: ev[1],
          vaultPath,
          href: toSiteHref(vaultPath),
        });
      }
      j += 1;
    }

    items.push({ text, evidence });
    i = j - 1;
  }

  return items;
}

function parseTodoMarkdown(markdown) {
  return parseBulletedSection(markdown, "현재 할 일", "Wiki/Self/TODO.md").map((task) => ({
    ...task,
    key: taskKeyFromText(task.text),
  }));
}

function parseOpenQuestionMarkdown(markdown) {
  return parseBulletedSection(markdown, "현재 열린 질문", "Wiki/Self/Open Questions.md");
}

function collectThirdLevelSections(lines) {
  const sections = new Map();
  let currentSection = null;

  for (const line of lines) {
    const thirdLevel = line.match(/^###\s+(.+)$/);
    if (thirdLevel) {
      currentSection = thirdLevel[1].trim();
      sections.set(currentSection, []);
      continue;
    }

    if (/^##\s+/.test(line)) {
      currentSection = null;
      continue;
    }

    if (currentSection) {
      sections.get(currentSection).push(line);
    }
  }

  return sections;
}

function parseTodayMarkdown(markdown) {
  const sections = collectThirdLevelSections(markdown.split(/\r?\n/));
  const focus = {
    mode: "writing_prompt",
    text: "",
    evidence: [],
    prompts: [],
    reason: "",
    sourceLabel: "",
    sourcePath: "",
    sourceHref: "",
  };

  const statusLines = sections.get("상태") ?? [];
  for (const line of statusLines) {
    if (!line.trim().startsWith("- ")) {
      continue;
    }

    const item = line.trim().replace(/^- /, "").trim();
    if (item.startsWith("mode:")) {
      focus.mode = item.slice(5).trim() || "writing_prompt";
      continue;
    }

    if (item.startsWith("source:")) {
      const link = parseMarkdownLink(item.slice(7).trim());
      if (!link) {
        continue;
      }

      const sourcePath = resolveVaultPath("Wiki/Self/Today.md", link.href);
      focus.sourceLabel = link.label;
      focus.sourcePath = sourcePath;
      focus.sourceHref = toSiteHref(sourcePath);
    }
  }

  const focusLines = sections.get("오늘의 한 가지") ?? [];
  for (const line of focusLines) {
    if (!focus.text && line.trim().startsWith("- ")) {
      focus.text = cleanTaskText(line);
      continue;
    }

    const ev = line.match(/^\s*근거:\s*\[(.+?)\]\((.+?)\)\s*$/);
    if (!ev) {
      continue;
    }

    const vaultPath = resolveVaultPath("Wiki/Self/Today.md", ev[2]);
    focus.evidence.push({
      label: ev[1],
      vaultPath,
      href: toSiteHref(vaultPath),
    });
  }

  const reasonLines = sections.get("왜 이것인가") ?? [];
  for (const line of reasonLines) {
    if (line.trim().startsWith("- ")) {
      focus.reason = cleanTaskText(line);
      break;
    }
  }

  const promptLines = sections.get("짧게 남길 것") ?? [];
  focus.prompts = promptLines
    .filter((line) => line.trim().startsWith("- "))
    .map((line) => cleanTaskText(line));

  return focus.text ? focus : null;
}

function deriveTodayFocus(tasks, questions) {
  if (tasks.length > 0) {
    return {
      mode: "todo",
      text: tasks[0].text,
      evidence: tasks[0].evidence,
      prompts: [
        "오늘 이걸 10~20분 안에 어디까지 밀 수 있는가.",
        "막히는 지점이 있다면 정확히 무엇이 막히는가.",
        "다음 컴파일에 남길 사실 1개는 무엇인가.",
      ],
      reason: "현재 `TODO` 목록의 첫 항목을 오늘의 실행 포커스로 본다.",
      sourceLabel: "TODO.md",
      sourcePath: "Wiki/Self/TODO.md",
      sourceHref: "../Wiki/Self/TODO.md",
    };
  }

  if (questions.length > 0) {
    return {
      mode: "writing_prompt",
      text: questions[0].text,
      evidence: questions[0].evidence,
      prompts: [
        "5줄 이내로 지금 시점의 답을 적는다.",
        "사실 1개와 해석 1개를 구분해서 적는다.",
        "답이 닫히지 않으면 다음 질문 1개를 남긴다.",
      ],
      reason: "실행할 TODO가 없을 때는 위키에 도움이 되는 열린 질문 하나를 짧게 적는 편이 낫다.",
      sourceLabel: "Open Questions.md",
      sourcePath: "Wiki/Self/Open Questions.md",
      sourceHref: "../Wiki/Self/Open Questions.md",
    };
  }

  return {
    mode: "writing_prompt",
    text: "오늘 가장 오래 붙잡고 있던 생각 하나를 5줄 안에 적는다.",
    evidence: [],
    prompts: [
      "사실 1개를 먼저 적는다.",
      "왜 기억에 남는지 해석 1개를 적는다.",
      "이어서 보고 싶은 질문 1개를 남긴다.",
    ],
    reason: "아직 명시된 TODO나 열린 질문이 부족하면 새 근거를 하나 만드는 것이 다음 컴파일에 가장 도움이 된다.",
    sourceLabel: "Self Map",
    sourcePath: "Wiki/Self/Map.md",
    sourceHref: "../Wiki/Self/Map.md",
  };
}

async function getDirHandle(root, segments, create = false) {
  let handle = root;
  for (const segment of segments) {
    handle = await handle.getDirectoryHandle(segment, { create });
  }
  return handle;
}

async function readTextFile(root, pathSegments) {
  const dir = await getDirHandle(root, pathSegments.slice(0, -1), false);
  const fileHandle = await dir.getFileHandle(pathSegments[pathSegments.length - 1], {
    create: false,
  });
  const file = await fileHandle.getFile();
  return file.text();
}

async function writeTextFile(root, pathSegments, content) {
  const dir = await getDirHandle(root, pathSegments.slice(0, -1), true);
  const fileHandle = await dir.getFileHandle(pathSegments[pathSegments.length - 1], {
    create: true,
  });
  const writable = await fileHandle.createWritable();
  await writable.write(content);
  await writable.close();
}

async function copyAttachmentsToInbox(root, files, stamp) {
  if (!files || files.length === 0) {
    return [];
  }

  const attachmentDir = await getDirHandle(root, ["Inbox", "Text", "attachments"], true);
  const saved = [];

  for (let i = 0; i < files.length; i += 1) {
    const file = files[i];
    const safeName = sanitizeName(file.name);
    const filename = `${stamp}-${String(i + 1).padStart(2, "0")}-${safeName}`;
    const target = await attachmentDir.getFileHandle(filename, { create: true });
    const writable = await target.createWritable();
    await writable.write(await file.arrayBuffer());
    await writable.close();
    saved.push(`Inbox/Text/attachments/${filename}`);
  }

  return saved;
}

async function loadCompletions(root) {
  const inboxTextDir = await getDirHandle(root, ["Inbox", "Text"], false);
  const completedKeys = new Set();

  for await (const entry of inboxTextDir.values()) {
    if (entry.kind !== "file") {
      continue;
    }
    if (!entry.name.startsWith("web-todo-complete-") || !entry.name.endsWith(".md")) {
      continue;
    }
    const file = await entry.getFile();
    const text = await file.text();
    const match = text.match(/^task_key:\s*(.+)$/m);
    if (match && match[1]) {
      completedKeys.add(match[1].trim());
    }
  }

  return completedKeys;
}

function renderEvidenceList(items) {
  if (!items.length) {
    return `<p class="empty">근거 링크 없음</p>`;
  }

  const rows = items
    .map(
      (item) =>
        `<li><a href="${escapeHtml(item.href)}" target="_blank" rel="noopener noreferrer">${escapeHtml(item.label)}</a></li>`,
    )
    .join("");

  return `<ul class="evidence">${rows}</ul>`;
}

function renderTodayFocus() {
  const focus = state.todayFocus;
  if (!focus) {
    el.todayFocusCard.innerHTML = `<p class="empty">오늘의 포커스를 계산하지 못했습니다.</p>`;
    return;
  }

  const modeClass = focus.mode === "todo" ? "todo" : "writing";
  const modeLabel = focus.mode === "todo" ? "today todo" : "writing prompt";
  const sourceHtml = focus.sourceHref
    ? `<a href="${escapeHtml(focus.sourceHref)}" target="_blank" rel="noopener noreferrer">${escapeHtml(focus.sourceLabel || focus.sourcePath)}</a>`
    : `<span>${escapeHtml(focus.sourceLabel || "source 없음")}</span>`;
  const promptsHtml = focus.prompts.length
    ? `<ul class="prompt-list">${focus.prompts.map((prompt) => `<li>${escapeHtml(prompt)}</li>`).join("")}</ul>`
    : `<p class="empty">짧게 남길 가이드 없음</p>`;

  el.todayFocusCard.innerHTML = `
    <article class="focus-card ${modeClass}">
      <div class="focus-meta">
        <div>
          <p class="eyebrow">Daily Focus</p>
          <span class="focus-mode">${escapeHtml(modeLabel)}</span>
        </div>
        <button class="btn primary" data-open-today-note>짧은 생각 저장</button>
      </div>
      <h3 class="focus-title">${escapeHtml(focus.text)}</h3>
      <p class="focus-reason">${escapeHtml(focus.reason)}</p>
      <p class="subtitle">source: ${sourceHtml}</p>
      <div>
        <p class="label">짧게 남길 것</p>
        ${promptsHtml}
      </div>
      <div>
        <p class="label">근거</p>
        ${renderEvidenceList(focus.evidence)}
      </div>
    </article>
  `;
}

function renderTasks() {
  const openTasks = state.tasks.filter((task) => !state.completedKeys.has(task.key));
  const doneTasks = state.tasks.filter((task) => state.completedKeys.has(task.key));

  el.openCount.textContent = String(openTasks.length);
  el.doneCount.textContent = String(doneTasks.length);

  if (state.tasks.length === 0) {
    el.taskList.innerHTML = `<p class="empty">TODO.md에서 할 일을 찾지 못했습니다.</p>`;
    return;
  }

  const rows = state.tasks
    .map((task, index) => {
      const done = state.completedKeys.has(task.key);
      return `
        <article class="task-item ${done ? "done" : ""}">
          <div class="task-top">
            <p class="task-text">${escapeHtml(task.text)}</p>
            <div class="task-actions">
              <span class="status-chip ${done ? "done" : "open"}">${done ? "done" : "open"}</span>
              <button class="btn ${done ? "ghost" : "primary"}" data-complete-index="${index}" ${
                done ? "disabled" : ""
              }>
                완료 처리
              </button>
            </div>
          </div>
          ${renderEvidenceList(task.evidence)}
        </article>
      `;
    })
    .join("");

  el.taskList.innerHTML = rows;
}

async function loadBoard() {
  if (!state.rootHandle) {
    return;
  }

  setStatus("TODO 로드 중...");

  const todoMarkdown = await readTextFile(state.rootHandle, ["Wiki", "Self", "TODO.md"]);
  state.tasks = parseTodoMarkdown(todoMarkdown);

  let todayFocus = null;
  try {
    const todayMarkdown = await readTextFile(state.rootHandle, ["Wiki", "Self", "Today.md"]);
    todayFocus = parseTodayMarkdown(todayMarkdown);
  } catch (error) {
    console.warn("Today.md를 읽지 못해 즉석 계산으로 대체합니다.", error);
  }

  if (!todayFocus) {
    let questions = [];
    try {
      const questionsMarkdown = await readTextFile(state.rootHandle, ["Wiki", "Self", "Open Questions.md"]);
      questions = parseOpenQuestionMarkdown(questionsMarkdown);
    } catch (error) {
      console.warn("Open Questions.md를 읽지 못했습니다.", error);
    }
    todayFocus = deriveTodayFocus(state.tasks, questions);
  }

  state.todayFocus = todayFocus;
  state.completedKeys = await loadCompletions(state.rootHandle);
  renderTodayFocus();
  renderTasks();
  setStatus("연결됨");
}

function openCompleteDialog(taskIndex) {
  state.activeTaskIndex = taskIndex;
  const task = state.tasks[taskIndex];
  el.dialogTaskText.textContent = task?.text || "";
  el.doneNote.value = "";
  el.doneLinks.value = "";
  el.doneFiles.value = "";
  el.dialog.showModal();
}

function openTodayNoteDialog() {
  if (!state.todayFocus) {
    return;
  }

  el.todayDialogFocusText.textContent = state.todayFocus.text;
  el.todayNote.value = "";
  el.todayLinks.value = "";
  el.todayFiles.value = "";
  el.todayDialog.showModal();
}

function parseLinkLines(text) {
  return text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
}

async function writeCompletionToInbox(task, note, links, files) {
  const now = new Date();
  const stamp = timestampCompact(now);
  const iso = now.toISOString();
  const savedFiles = await copyAttachmentsToInbox(state.rootHandle, files, stamp);
  const filename = `web-todo-complete-${stamp}-${task.key}.md`;
  const destinationPath = `Inbox/Text/${filename}`;

  const parts = [
    "---",
    "source: web_todo_board",
    "document_type: task_completion",
    `captured_at: ${iso}`,
    `task_key: ${task.key}`,
    `task_text: ${quoteYamlString(task.text)}`,
    "---",
    "",
    "# Web TODO Completion",
    "",
    `DONE: ${task.text}`,
    "",
  ];

  if (note) {
    parts.push("## Completion Note", "", note, "");
  }

  if (links.length > 0) {
    parts.push("## Attached Links", "");
    links.forEach((link) => {
      parts.push(`- ${link}`);
    });
    parts.push("");
  }

  if (savedFiles.length > 0) {
    parts.push("## Attached Files", "");
    savedFiles.forEach((path) => {
      const label = path.split("/").pop() || path;
      parts.push(`- ${markdownLinkForVaultPath(label, path, destinationPath)}`);
    });
    parts.push("");
  }

  if (task.evidence.length > 0) {
    parts.push("## Evidence", "");
    task.evidence.forEach((item) => {
      parts.push(`- ${markdownLinkForVaultPath(item.label, item.vaultPath, destinationPath)}`);
    });
    parts.push("");
  }

  await writeTextFile(state.rootHandle, ["Inbox", "Text", filename], `${parts.join("\n").trim()}\n`);
}

async function writeTodayNoteToInbox(focus, note, links, files) {
  const now = new Date();
  const stamp = timestampCompact(now);
  const iso = now.toISOString();
  const savedFiles = await copyAttachmentsToInbox(state.rootHandle, files, stamp);
  const filename = `web-today-note-${stamp}.md`;
  const destinationPath = `Inbox/Text/${filename}`;

  if (!note && links.length === 0 && savedFiles.length === 0) {
    throw new Error("생각, 링크, 파일 중 하나는 필요합니다.");
  }

  const parts = [
    "---",
    "source: web_today_focus",
    "document_type: today_focus_note",
    `captured_at: ${iso}`,
    `today_mode: ${focus.mode}`,
    `today_focus: ${quoteYamlString(focus.text)}`,
    `today_source_path: ${quoteYamlString(focus.sourcePath || "")}`,
    "---",
    "",
    "# Today Focus Note",
    "",
    "## Focus",
    "",
    `- ${focus.text}`,
    "",
  ];

  if (focus.sourcePath) {
    parts.push("## Source", "");
    parts.push(`- ${markdownLinkForVaultPath(focus.sourceLabel || focus.sourcePath, focus.sourcePath, destinationPath)}`);
    parts.push("");
  }

  if (focus.reason) {
    parts.push("## Why Today", "", `- ${focus.reason}`, "");
  }

  if (note) {
    parts.push("## Short Thought", "", note, "");
  }

  if (links.length > 0) {
    parts.push("## Attached Links", "");
    links.forEach((link) => {
      parts.push(`- ${link}`);
    });
    parts.push("");
  }

  if (savedFiles.length > 0) {
    parts.push("## Attached Files", "");
    savedFiles.forEach((path) => {
      const label = path.split("/").pop() || path;
      parts.push(`- ${markdownLinkForVaultPath(label, path, destinationPath)}`);
    });
    parts.push("");
  }

  if (focus.evidence.length > 0) {
    parts.push("## Evidence", "");
    focus.evidence.forEach((item) => {
      parts.push(`- ${markdownLinkForVaultPath(item.label, item.vaultPath, destinationPath)}`);
    });
    parts.push("");
  }

  if (focus.prompts.length > 0) {
    parts.push("## Prompts", "");
    focus.prompts.forEach((prompt) => {
      parts.push(`- ${prompt}`);
    });
    parts.push("");
  }

  await writeTextFile(state.rootHandle, ["Inbox", "Text", filename], `${parts.join("\n").trim()}\n`);
}

async function submitCompletion(event) {
  event.preventDefault();
  const task = state.tasks[state.activeTaskIndex];
  if (!task || !state.rootHandle) {
    return;
  }

  const note = el.doneNote.value.trim();
  const links = parseLinkLines(el.doneLinks.value);
  const files = Array.from(el.doneFiles.files || []);

  try {
    setStatus("완료 기록 저장 중...");
    await writeCompletionToInbox(task, note, links, files);
    state.completedKeys.add(task.key);
    renderTasks();
    setStatus("완료 기록 저장됨 (Inbox/Text)");
    el.dialog.close();
  } catch (error) {
    console.error(error);
    setStatus(`저장 실패: ${error.message || "알 수 없는 오류"}`);
  }
}

async function submitTodayNote(event) {
  event.preventDefault();
  if (!state.todayFocus || !state.rootHandle) {
    return;
  }

  const note = el.todayNote.value.trim();
  const links = parseLinkLines(el.todayLinks.value);
  const files = Array.from(el.todayFiles.files || []);

  try {
    setStatus("오늘 생각 기록 저장 중...");
    await writeTodayNoteToInbox(state.todayFocus, note, links, files);
    setStatus("오늘 생각 기록 저장됨 (Inbox/Text)");
    el.todayDialog.close();
  } catch (error) {
    console.error(error);
    setStatus(`저장 실패: ${error.message || "알 수 없는 오류"}`);
  }
}

async function connectVault() {
  if (!window.showDirectoryPicker) {
    setStatus("이 브라우저는 Vault 연결 기능을 지원하지 않습니다.");
    return;
  }

  try {
    state.rootHandle = await window.showDirectoryPicker({ mode: "readwrite" });
    el.reloadBtn.disabled = false;
    await loadBoard();
  } catch (error) {
    if (error.name === "AbortError") {
      return;
    }
    console.error(error);
    setStatus(`연결 실패: ${error.message || "알 수 없는 오류"}`);
  }
}

el.connectBtn.addEventListener("click", connectVault);
el.reloadBtn.addEventListener("click", loadBoard);

el.todayFocusCard.addEventListener("click", (event) => {
  const button = event.target.closest("[data-open-today-note]");
  if (!button) {
    return;
  }
  openTodayNoteDialog();
});

el.taskList.addEventListener("click", (event) => {
  const button = event.target.closest("[data-complete-index]");
  if (!button) {
    return;
  }
  const index = Number(button.dataset.completeIndex);
  if (!Number.isInteger(index)) {
    return;
  }
  openCompleteDialog(index);
});

el.cancelComplete.addEventListener("click", () => el.dialog.close());
el.completeForm.addEventListener("submit", submitCompletion);
el.cancelTodayNote.addEventListener("click", () => el.todayDialog.close());
el.todayNoteForm.addEventListener("submit", submitTodayNote);
