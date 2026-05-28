const selectedIntensity = "mid";

const commonRoutine = [
  {
    id: "chin-tuck",
    title: "턱 당기기 / 일자목",
    video: "https://www.youtube.com/shorts/pAps-PUqwv0",
    dose: { low: "5초 x 5회", mid: "5초 x 8회", high: "5초 x 10회" },
    checks: [
      "고개를 숙이지 않았다",
      "턱을 뒤로 밀었다",
      "목 앞쪽에 힘을 과하게 주지 않았다",
      "뒤통수가 길어지는 느낌이 있었다",
    ],
  },
  {
    id: "short-foot",
    title: "숏풋 / 발 아치 만들기",
    video: "https://www.youtube.com/watch?v=DoEIW4Y8MEo",
    dose: {
      low: "왼발 10초 x 4회",
      mid: "왼발 10초 x 6회",
      high: "왼발 10초 x 8회",
    },
    note: "오른발은 왼발의 절반 정도만 한다.",
    checks: [
      "발가락을 말아 쥐지 않았다",
      "왼쪽 엄지가 안쪽으로 더 꺾이지 않았다",
      "왼발 아치가 살짝 살아났다",
      "왼쪽 엉덩이가 아주 약하게 켜지는 느낌이 있었다",
    ],
  },
  {
    id: "short-bridge",
    title: "짧은 글루트 브릿지",
    video: "https://www.youtube.com/watch?v=OUgsJ8-Vi0E&t=14s",
    dose: { low: "8회 x 1세트", mid: "8회 x 2세트", high: "10회 x 3세트" },
    checks: [
      "높게 들려고 하지 않았다",
      "허리를 꺾지 않았다",
      "갈비뼈를 살짝 내렸다",
      "엉덩이로 들었다",
      "왼쪽 엉덩이에 느낌이 있었다",
    ],
  },
];

const exercises = {
  run: {
    id: "run",
    title: "러닝",
    dose: { low: "러닝 없음, 걷기 10~15분", mid: "러닝 20~30분", high: "러닝 30~40분" },
    checks: ["뛰는 중 허리 통증 0~2/10", "왼쪽 다리 저림 없음", "러닝 후 허리 뻐근함이 증가하지 않음"],
  },
  calfRaise: {
    id: "calf-raise",
    title: "양발 카프레이즈",
    video: "https://www.youtube.com/shorts/JTzf4IPR7dw",
    dose: { low: "8회 x 2세트", mid: "10회 x 3세트", high: "12~15회 x 3세트" },
    checks: [
      "왼발 엄지 뿌리로 바닥을 밀었다",
      "발목이 바깥으로 도망가지 않았다",
      "허리 힘으로 버티지 않았다",
      "올라갈 때 왼쪽 엉덩이가 10% 정도 켜졌다",
    ],
  },
  hinge: {
    id: "wall-hinge",
    title: "벽 힙힌지",
    video: "https://www.youtube.com/shorts/2AbhlUHCDvM",
    dose: { low: "6회 x 2세트", mid: "8회 x 2세트", high: "10회 x 3세트" },
    checks: ["허리를 숙이지 않았다", "엉덩이를 뒤로 뺐다", "허리 각도는 중립이었다", "왼쪽 햄스트링/엉덩이 뒤쪽이 느껴졌다"],
  },
  walk: {
    id: "walk",
    title: "가볍게 걷기",
    dose: { low: "5~10분", mid: "10~15분", high: "20분" },
    checks: ["왼발 체중을 피하지 않았다", "허리 뻐근함이 증가하지 않았다"],
  },
  clam: {
    id: "clamshell",
    title: "클램셸",
    video: "https://youtu.be/aQVApsdOLSI?t=97",
    dose: { low: "왼쪽 8회 x 2세트", mid: "왼쪽 12회 x 3세트", high: "왼쪽 15회 x 3세트" },
    note: "오른쪽은 왼쪽의 절반 정도만 한다.",
    checks: ["골반이 뒤로 넘어가지 않았다", "무릎을 과하게 열지 않았다", "엉덩이 옆쪽에 느낌이 있었다", "허리나 왼쪽 광배가 긴장하지 않았다"],
  },
  splitStand: {
    id: "split-stand",
    title: "스플릿 스탠스 버티기",
    video: "https://www.youtube.com/shorts/mDP4VbrgYP0",
    dose: { low: "20초 x 2세트", mid: "30초 x 3세트", high: "40초 x 3세트" },
    note: "왼발 앞 / 왼발 뒤 둘 다 한다.",
    checks: ["허리가 꺾이지 않았다", "갈비뼈가 들리지 않았다", "왼발 엄지 뿌리 접지가 유지됐다", "왼쪽 광배가 긴장하지 않았다"],
  },
  stepdown: {
    id: "stepdown",
    title: "스텝다운",
    video: "https://www.youtube.com/watch?v=RgTKgtV1ltk",
    dose: { low: "5회 x 2세트", mid: "6회 x 3세트", high: "8회 x 3세트" },
    note: "처음엔 계단 말고 책 한 권 높이가 더 안전하다.",
    checks: [
      "낮은 높이에서 했다",
      "왼쪽 무릎이 안쪽으로 무너지지 않았다",
      "왼쪽 엉덩이가 옆으로 빠지지 않았다",
      "허리가 꺾이지 않았다",
      "왼발 엄지 접지가 유지됐다",
    ],
  },
  sidePlank: {
    id: "side-plank",
    title: "무릎 대고 사이드 플랭크",
    video: "https://www.youtube.com/shorts/OxUqMcC944g",
    dose: { low: "10초 x 2세트", mid: "15초 x 3세트", high: "20초 x 3세트" },
    checks: ["허리로 버티지 않았다", "옆구리와 엉덩이 옆쪽이 느껴졌다", "왼쪽 광배가 과하게 긴장하지 않았다"],
  },
  deadbug: {
    id: "deadbug",
    title: "데드버그",
    video: "https://www.youtube.com/watch?v=g_BYB0R-4Ws",
    dose: { low: "발만 살짝 들기 5회 x 2세트", mid: "6회 x 3세트", high: "8회 x 3세트" },
    checks: ["허리가 바닥에서 뜨지 않았다", "다리를 멀리 뻗으려고 하지 않았다", "갈비뼈를 내렸다", "복압을 유지했다", "허리 통증이 없었다"],
  },
  standTest: {
    id: "stand-test",
    title: "30초 서기 테스트",
    dose: { low: "30초 x 2회", mid: "30초 x 3회", high: "45초 x 3회" },
    checks: ["갈비뼈가 들리지 않았다", "허리가 꺾이지 않았다", "왼발 체중을 피하지 않았다", "왼쪽 광배가 긴장하지 않았다", "왼발 엄지 뿌리가 바닥에 남아 있었다"],
  },
  singleCalf: {
    id: "single-calf-test",
    title: "벽 짚고 왼쪽 싱글 카프레이즈 테스트",
    video: "https://www.youtube.com/shorts/JTzf4IPR7dw",
    dose: { low: "하지 않음. 양발 카프레이즈만", mid: "왼쪽 5회 x 1~2세트", high: "왼쪽 5회 x 3세트" },
    note: "하나라도 깨지면 바로 중단한다. 이건 운동이라기보다 테스트다.",
    checks: ["허리 통증 없음", "왼쪽 광배 긴장 없음", "왼쪽 엄지 관절 통증 없음", "발목이 바깥으로 도망가지 않음", "왼쪽 엉덩이가 약하게 같이 잡힘"],
  },
  splitSquat: {
    id: "split-squat",
    title: "얕은 스플릿 스쿼트",
    dose: { low: "생략", mid: "6회 x 2세트", high: "8회 x 3세트" },
    note: "참고 검색어: split squat proper form beginner",
    checks: ["깊게 내려가지 않았다", "왼발 엄지 접지가 유지됐다", "무릎이 안쪽으로 무너지지 않았다", "허리가 꺾이지 않았다", "왼쪽 광배가 긴장하지 않았다"],
  },
  weekly: {
    id: "weekly-review",
    title: "주간 기록",
    dose: { low: "체크만", mid: "체크 + 메모", high: "체크 + 다음 주 강도 결정" },
    checks: ["오래 서 있을 때 몇 분부터 허리가 아픈가?", "왼쪽 카프레이즈 때 엉덩이가 잡히는가?", "왼쪽 엄지 쪽 접지가 되는가?", "러닝 다음 날 허리가 괜찮은가?", "왼쪽 광배 쑤심이 줄었는가?", "강아지 자세에서 왼쪽 다리 들 때 통증이 줄었는가?"],
  },
};

exercises.bridgeAgain = { ...commonRoutine[2], id: "bridge-again", title: "짧은 브릿지" };
exercises.chinFinish = { ...commonRoutine[0], id: "chin-finish", title: "턱 당기기 마무리" };
exercises.shortFootExtra = { ...commonRoutine[1], id: "short-foot-extra", title: "숏풋 추가" };

const days = [
  { key: "mon", tab: "월", title: "월요일: 러닝 + 발-종아리 연결", goal: "왼발 엄지 접지와 카프레이즈 패턴 회복", extra: ["run", "calfRaise", "hinge", "walk"] },
  { key: "tue", tab: "화", title: "화요일: 하체 컨트롤 강화", goal: "오래 서 있을 때 무너지는 골반 안정성 강화", extra: ["clam", "hinge", "splitStand", "stepdown", "sidePlank"] },
  { key: "wed", tab: "수", title: "수요일: 러닝 + 코어 안정화", goal: "움직이면서도 허리가 과하게 개입하지 않게 만들기", extra: ["run", "deadbug", "bridgeAgain", "chinFinish"] },
  { key: "thu", tab: "목", title: "목요일: 회복 + 서기 통증 개선", goal: "오래 서 있으면 아픈 패턴 직접 개선", extra: ["splitStand", "calfRaise", "hinge", "standTest"], note: "이 날은 절대 무리하지 않는다. 회복일이지만 중요한 날이다." },
  { key: "fri", tab: "금", title: "금요일: 러닝 + 싱글 카프레이즈 테스트", goal: "왼쪽 카프레이즈 복귀 여부 확인", extra: ["run", "calfRaise", "singleCalf", "hinge"] },
  { key: "sat", tab: "토", title: "토요일: 강화일", goal: "왼쪽 발-둔근-골반 라인에 직접 자극 주기", extra: ["clam", "hinge", "stepdown", "splitSquat", "calfRaise", "sidePlank", "deadbug"], note: "러닝은 하지 않는 쪽을 추천한다." },
  { key: "sun", tab: "일", title: "일요일: 회복 + 점검", goal: "다음 주 강도 조절 결정", extra: ["walk", "shortFootExtra", "bridgeAgain", "standTest", "weekly"] },
];

const quick = ["short-foot", "short-bridge", "wall-hinge", "calf-raise"];
const storagePrefix = "morning-rehab-v1";

let selectedDay = days[(new Date().getDay() + 6) % 7].key;

const el = {
  todayLabel: document.getElementById("today-label"),
  resetDay: document.getElementById("reset-day"),
  weekTabs: document.getElementById("week-tabs"),
  routineList: document.getElementById("routine-list"),
  quickList: document.getElementById("quick-list"),
  weeklyRecord: document.getElementById("weekly-record"),
  videoModal: document.getElementById("video-modal"),
  videoTitle: document.getElementById("video-title"),
  videoFrameWrap: document.getElementById("video-frame-wrap"),
  videoFallback: document.getElementById("video-fallback"),
};

function todayKey() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
}

function storageKey() {
  return `${storagePrefix}:${todayKey()}:${selectedDay}`;
}

function loadDayState() {
  try {
    return JSON.parse(localStorage.getItem(storageKey())) || {};
  } catch {
    return {};
  }
}

function saveDayState(state) {
  localStorage.setItem(storageKey(), JSON.stringify(state));
}

function allExercisesForDay(day) {
  const common = commonRoutine.map((item) => ({ ...item, common: true }));
  const extra = day.extra.map((id) => exercises[id]);
  return [...common, ...extra];
}

function getRoutine() {
  const day = days.find((item) => item.key === selectedDay);
  return allExercisesForDay(day);
}

function renderTabs() {
  el.weekTabs.innerHTML = days
    .map((day) => `<button class="day-tab ${day.key === selectedDay ? "active" : ""}" type="button" data-day="${day.key}">${day.tab}</button>`)
    .join("");
}

function checkKey(exerciseId, index) {
  return `${exerciseId}:check:${index}`;
}

function exerciseKey(exerciseId) {
  return `${exerciseId}:done`;
}

function youtubeEmbedUrl(url) {
  try {
    const parsed = new URL(url);
    let id = "";
    if (parsed.hostname.includes("youtu.be")) {
      id = parsed.pathname.split("/").filter(Boolean)[0] || "";
    } else if (parsed.pathname.includes("/shorts/")) {
      id = parsed.pathname.split("/shorts/")[1]?.split("/")[0] || "";
    } else {
      id = parsed.searchParams.get("v") || "";
    }
    if (!id) return "";
    const start = parsed.searchParams.get("t") || "";
    const seconds = start.endsWith("s") ? start.slice(0, -1) : start;
    const query = new URLSearchParams({ autoplay: "1", rel: "0" });
    if (seconds && Number.isFinite(Number(seconds))) {
      query.set("start", seconds);
    }
    return `https://www.youtube.com/embed/${id}?${query.toString()}`;
  } catch {
    return "";
  }
}

function openVideo(title, url) {
  const embedUrl = youtubeEmbedUrl(url);
  el.videoTitle.textContent = title;
  el.videoFallback.href = url;
  el.videoFrameWrap.innerHTML = embedUrl
    ? `<iframe src="${embedUrl}" title="${title} 참고 영상" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>`
    : `<div class="video-empty">이 영상은 페이지 안에서 바로 열 수 없습니다.</div>`;
  el.videoModal.classList.add("open");
  el.videoModal.setAttribute("aria-hidden", "false");
  document.body.classList.add("modal-open");
}

function closeVideo() {
  el.videoModal.classList.remove("open");
  el.videoModal.setAttribute("aria-hidden", "true");
  el.videoFrameWrap.innerHTML = "";
  document.body.classList.remove("modal-open");
}

function renderRoutine() {
  const day = days.find((item) => item.key === selectedDay);
  const state = loadDayState();
  const routine = getRoutine();

  el.todayLabel.textContent = `${todayKey()} · ${day.tab}요일`;

  el.routineList.innerHTML = routine
    .map((item, index) => {
      const isDone = Boolean(state[exerciseKey(item.id)]);
      const checks = item.checks
        .map((text) => `<li>${text}</li>`)
        .join("");
      const video = item.video ? `<button class="video-link" type="button" data-video-url="${item.video}" data-video-title="${item.title}">영상</button>` : "";
      const note = item.note ? `<p class="note">${item.note}</p>` : "";
      return `
        <article class="exercise-card ${isDone ? "done" : ""}">
          <label class="exercise-main">
            <input class="done-check" type="checkbox" aria-label="${item.title} 완료" data-exercise="${item.id}" ${isDone ? "checked" : ""} />
            <div>
              <p class="exercise-kicker">${String(index + 1).padStart(2, "0")}</p>
              <h3 class="exercise-title">${item.title}</h3>
              <div class="exercise-meta">
                <span class="dose">${item.dose[selectedIntensity]}</span>
                <span class="done-label">${isDone ? "완료" : "대기"}</span>
              </div>
              ${note}
            </div>
          </label>
          <div class="exercise-actions">
            ${video}
            <details class="help-panel">
              <summary>도움말</summary>
              <ul class="help-list">
                ${checks}
              </ul>
            </details>
          </div>
        </article>
      `;
    })
    .join("");
}

function renderQuickList() {
  const byId = [...commonRoutine, ...Object.values(exercises)].reduce((map, item) => {
    map.set(item.id, item);
    return map;
  }, new Map());

  el.quickList.innerHTML = quick
    .map((id, index) => {
      const item = byId.get(id);
      const video = item.video ? `<button class="video-link" type="button" data-video-url="${item.video}" data-video-title="${item.title}">영상</button>` : "";
      return `<div class="quick-item"><strong>${index + 1}</strong><strong>${item.title}</strong>${video}</div>`;
    })
    .join("");
}

function renderWeeklyRecord() {
  const state = loadDayState();
  el.weeklyRecord.innerHTML = exercises.weekly.checks
    .map((text, index) => {
      const key = checkKey("weekly-record", index);
      return `<label class="record-item"><input type="checkbox" data-check="${key}" ${state[key] ? "checked" : ""} /><span>${text}</span></label>`;
    })
    .join("");
}

function render() {
  renderTabs();
  renderRoutine();
  renderQuickList();
  renderWeeklyRecord();
}

el.weekTabs.addEventListener("click", (event) => {
  const button = event.target.closest("[data-day]");
  if (!button) return;
  selectedDay = button.dataset.day;
  render();
  window.scrollTo({ top: 0, behavior: "smooth" });
});

el.routineList.addEventListener("change", (event) => {
  const state = loadDayState();
  const target = event.target;
  if (target.matches("[data-exercise]")) {
    state[exerciseKey(target.dataset.exercise)] = target.checked;
  }
  saveDayState(state);
  renderRoutine();
});

el.routineList.addEventListener("click", (event) => {
  const button = event.target.closest("[data-video-url]");
  if (!button) return;
  openVideo(button.dataset.videoTitle, button.dataset.videoUrl);
});

el.quickList.addEventListener("click", (event) => {
  const button = event.target.closest("[data-video-url]");
  if (!button) return;
  openVideo(button.dataset.videoTitle, button.dataset.videoUrl);
});

el.weeklyRecord.addEventListener("change", (event) => {
  const target = event.target;
  if (!target.matches("[data-check]")) return;
  const state = loadDayState();
  state[target.dataset.check] = target.checked;
  saveDayState(state);
});

el.resetDay.addEventListener("click", () => {
  if (!window.confirm("오늘 선택한 요일의 체크를 모두 지울까요?")) return;
  localStorage.removeItem(storageKey());
  render();
});

el.videoModal.addEventListener("click", (event) => {
  if (event.target.closest("[data-close-video]")) {
    closeVideo();
  }
});

window.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && el.videoModal.classList.contains("open")) {
    closeVideo();
  }
});

render();
