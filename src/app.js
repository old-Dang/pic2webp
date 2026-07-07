import { invoke, isTauri } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { open } from "@tauri-apps/plugin-dialog";
import { openUrl } from "@tauri-apps/plugin-opener";
import { initLang, getLang, toggleLang, t, translateBackendMessage } from "./i18n.js";

// ─── State ──────────────────────────────────────────────────────────

let files = [];
let selectedDir = null;
let isConverting = false;
let stats = null;
let namingMode = "webp-suffix";

// ─── DOM refs ───────────────────────────────────────────────────────

const $ = (s) => document.querySelector(s);

const dropzone = $("#dropzone");
const fileList = $("#file-list");
const fileCountText = $("#file-count-text");
const clearBtn = $("#clear-btn");
const qualitySlider = $("#quality-slider");
const qualityVal = $("#quality-val");
const chkRecursive = $("#chk-recursive");
const chkDelete = $("#chk-delete");
const outputDir = $("#output-dir");
const dirBtn = $("#dir-btn");
const dirClear = $("#dir-clear");
const namingPills = $("#naming-pills");
const convertBtn = $("#convert-btn");
const btnText = $("#btn-text");
const btnSpinner = $("#btn-spinner");
const statsPanel = $("#stats-panel");
const statSuccess = $("#stat-success");
const statSkip = $("#stat-skip");
const statFail = $("#stat-fail");
const statSaved = $("#stat-saved");
const donateBtn = $("#donate-btn");
const donateModal = $("#donate-modal");
const modalClose = $("#modal-close");
const langToggle = $("#lang-toggle");
const langZh = $("#lang-zh");
const langEn = $("#lang-en");

// ─── Format helpers ─────────────────────────────────────────────────

function formatBytes(bytes, decimals = 1) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(decimals)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(decimals)} MB`;
}

// ─── Tool check ─────────────────────────────────────────────────────

async function checkTools() {
  if (!isTauri()) {
    updateConvertBtn();
    return;
  }
  try {
    await invoke("check_tools");
    updateConvertBtn();
  } catch (e) {
    console.warn("Tool check failed:", e);
    updateConvertBtn();
  }
}

// ─── Add files ───────────────────────────────────────────────────────

function addFiles(paths) {
  for (const p of paths) {
    if (!p || typeof p !== "string") continue;
    if (!files.some((f) => f.path === p)) {
      files.push({ path: p, status: "pending", message: "", savedBytes: 0, savedPct: 0 });
    }
  }
  renderFiles();
  updateConvertBtn();
}

// ─── Render file list ───────────────────────────────────────────────

function renderFiles() {
  fileList.innerHTML = "";

  if (files.length === 0) {
    fileList.innerHTML = `
      <div class="empty-state">
        <div class="info-section">
          <p data-i18n="why-webp">${t("why-webp")}</p>
          <ul>
            <li data-i18n="why-1">${t("why-1")}</li>
            <li data-i18n="why-2">${t("why-2")}</li>
            <li data-i18n="why-3">${t("why-3")}</li>
            <li data-i18n="why-4">${t("why-4")}</li>
          </ul>
        </div>
        <div class="info-section">
          <p data-i18n="how-title">${t("how-title")}</p>
          <ul>
            <li data-i18n="how-1">${t("how-1")}</li>
            <li data-i18n="how-2">${t("how-2")}</li>
            <li data-i18n="how-3">${t("how-3")}</li>
            <li data-i18n="how-4">${t("how-4")}</li>
          </ul>
        </div>
      </div>`;
    fileCountText.textContent = t("file-count", { n: files.length });
    clearBtn.hidden = true;
    return;
  }

  fileCountText.textContent = t("file-count", { n: files.length });
  clearBtn.hidden = false;

  for (const f of files) {
    if (!f.path || typeof f.path !== "string") continue;

    const item = document.createElement("div");
    item.className = "file-item";
    item.dataset.path = f.path;

    const name = f.path.split(/[/\\]/).pop();
    const ext = name.split('.').pop().toLowerCase().replace(/[^a-z0-9]/g, '');
    const thumbColors = { jpg: '#f59e0b', jpeg: '#f59e0b', png: '#3b82f6', webp: '#10b981' };
    const thumbColor = thumbColors[ext] || '#999';
    const thumbSrc = `data:image/svg+xml,${encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect width="32" height="32" rx="4" fill="' + thumbColor + '"/><text x="16" y="22" text-anchor="middle" fill="white" font-size="11" font-weight="600">' + ext.toUpperCase() + '</text></svg>')}`;

    item.innerHTML = `
      <img class="file-thumb" src="${thumbSrc}" alt="" />
      <div class="file-info">
        <div class="file-name" title="${name}">${name}</div>
        <div class="file-size">${f.savedBytes > 0 ? t("saved-bytes", { size: formatBytes(f.savedBytes) }) : translateBackendMessage(f.message) || ""}</div>
      </div>
      <span class="file-status status-${f.status}">${statusLabel(f.status)}</span>
    `;

    fileList.appendChild(item);
  }
}

function statusLabel(s) {
  const m = {
    pending: t("status-pending"),
    compressing: t("status-compressing"),
    converting: t("status-converting"),
    done: t("status-done"),
    skipped: t("status-skipped"),
    failed: t("status-failed"),
  };
  return m[s] || s;
}

// ─── Update UI for file progress ────────────────────────────────────

function updateFileProgress(filePath, status, message, savedBytes, savedPct) {
  const f = files.find((x) => x.path === filePath);
  if (!f) return;
  f.status = status;
  f.message = message;
  f.savedBytes = savedBytes;
  f.savedPct = savedPct;

  // 不用 CSS.escape（它用于 CSS 标识符，不适合属性值），
  // 改为遍历查找，兼容 Windows 路径中的反斜杠
  const items = fileList.querySelectorAll(".file-item");
  let item = null;
  for (const el of items) {
    if (el.dataset.path === filePath) { item = el; break; }
  }
  if (item) {
    const badge = item.querySelector(".file-status");
    badge.className = `file-status status-${status}`;
    badge.textContent = statusLabel(status);
    const size = item.querySelector(".file-size");
    size.textContent = savedBytes > 0 ? t("saved-bytes", { size: formatBytes(savedBytes) }) : translateBackendMessage(message) || "";
  }
}

// ─── Update stats ───────────────────────────────────────────────────

function updateStats(s) {
  stats = s;
  statsPanel.hidden = false;
  statSuccess.textContent = s.success_count;
  statSkip.textContent = s.skip_count;
  statFail.textContent = s.fail_count;
  statSaved.textContent = formatBytes(s.saved);
}

// ─── Convert button state ───────────────────────────────────────────

function updateConvertBtn() {
  if (isConverting) {
    convertBtn.disabled = true;
    btnText.textContent = t("converting");
    btnSpinner.hidden = false;
    return;
  }
  btnSpinner.hidden = true;

  if (files.length === 0) {
    convertBtn.disabled = true;
    btnText.textContent = t("start-convert");
    return;
  }

  const allDone = files.every((f) => f.status === "done" || f.status === "skipped" || f.status === "failed");
  if (allDone && files.length > 0) {
    btnText.textContent = t("re-convert");
  } else {
    btnText.textContent = t("start-convert");
  }

  convertBtn.disabled = false;
}

// ─── Start conversion ───────────────────────────────────────────────

async function startConvert() {
  if (isConverting) return;

  isConverting = true;
  updateConvertBtn();

  for (const f of files) {
    f.status = "pending";
    f.message = "";
    f.savedBytes = 0;
    f.savedPct = 0;
  }
  renderFiles();

  stats = null;
  statsPanel.hidden = true;

  try {
    await invoke("start_convert", {
      request: {
        files: files.map((f) => f.path),
        quality: Math.max(10, Math.min(100, parseInt(qualitySlider.value) || 80)),
        recursive: chkRecursive.checked,
        delete_source: chkDelete.checked,
        naming_mode: namingMode,
        output_dir: selectedDir || null,
      },
    });
  } catch (e) {
    for (const f of files) {
      f.status = "pending";
      f.message = "";
      f.savedBytes = 0;
      f.savedPct = 0;
    }
    renderFiles();
    isConverting = false;
    updateConvertBtn();
    alert(t("convert-failed") + ": " + e);
  }
}

// ─── Event listeners ────────────────────────────────────────────────

dropzone.addEventListener("dragover", (e) => {
  e.preventDefault();
  dropzone.classList.add("dragover");
});

dropzone.addEventListener("dragleave", () => {
  dropzone.classList.remove("dragover");
});

dropzone.addEventListener("drop", (e) => {
  e.preventDefault();
  dropzone.classList.remove("dragover");
  if (e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files.length > 0) {
    const paths = Array.from(e.dataTransfer.files)
      .map((f) => f.path)
      .filter(Boolean);
    if (paths.length > 0) addFiles(paths);
  }
});

dropzone.addEventListener("click", async () => {
  try {
    const result = await open({
      multiple: true,
      filters: [
        { name: "Images", extensions: ["jpg", "jpeg", "png", "webp", "heic", "avif"] }
      ]
    });
    if (result && Array.isArray(result)) {
      addFiles(result);
    } else if (typeof result === "string") {
      addFiles([result]);
    }
  } catch (e) {
    console.warn("Dialog not available:", e);
  }
});

clearBtn.addEventListener("click", () => {
  files = [];
  stats = null;
  statsPanel.hidden = true;
  renderFiles();
  updateConvertBtn();
});

// Quality slider — update value + q-suffix pill label
function setQuality(v) {
  const val = Math.max(10, Math.min(100, parseInt(v) || 80));
  qualitySlider.value = val;
  qualityVal.textContent = val;
  const qPill = namingPills.querySelector('[data-value="q-suffix"]');
  if (qPill) qPill.textContent = `-q${val}`;
}

qualitySlider.addEventListener("input", () => setQuality(qualitySlider.value));

// Naming mode — pill buttons
namingPills.querySelectorAll(".pill-btn").forEach((btn) => {
  btn.addEventListener("click", () => {
    namingPills.querySelectorAll(".pill-btn").forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
    namingMode = btn.dataset.value;
  });
});

// Output dir
dirBtn.addEventListener("click", async () => {
  try {
    const dir = await open({ directory: true, title: t("select-output-dir") });
    if (dir) {
      selectedDir = dir;
      outputDir.value = dir;
      dirClear.hidden = false;
    }
  } catch (e) {
    console.log("Dialog not available:", e);
  }
});

dirClear.addEventListener("click", () => {
  selectedDir = null;
  outputDir.value = "";
  dirClear.hidden = true;
});

convertBtn.addEventListener("click", startConvert);

donateBtn.addEventListener("click", () => { donateModal.classList.add("visible"); });
modalClose.addEventListener("click", () => { donateModal.classList.remove("visible"); });
donateModal.addEventListener("click", (e) => { if (e.target === donateModal) donateModal.classList.remove("visible"); });

document.addEventListener("keydown", (e) => {
  if (e.key === "Enter" && e.target.tagName !== "INPUT" && !convertBtn.disabled) startConvert();
});

// ─── Tauri event listeners ──────────────────────────────────────────

async function setupListeners() {
  await listen("convert-progress", (event) => {
    const p = event.payload;
    updateFileProgress(p.file, p.status, p.message, p.saved_bytes, p.saved_pct);
  });

  await listen("convert-stats", (event) => {
    updateStats(event.payload);
  });

  await listen("convert-done", (event) => {
    isConverting = false;
    updateStats(event.payload);
    updateConvertBtn();
  });
}

// ─── Blog link — use opener plugin to open external URL ─────────────

const blogLink = $("#blog-link");
if (blogLink) {
  blogLink.addEventListener("click", async (e) => {
    e.preventDefault();
    const url = blogLink.getAttribute("href");
    if (isTauri()) {
      try {
        await openUrl(url);
      } catch (err) {
        console.warn("Failed to open URL:", err);
      }
    } else {
      window.open(url, "_blank");
    }
  });
}

// ─── Language toggle ─────────────────────────────────────────────────

function updateLangToggle() {
  const lang = getLang();
  langZh.classList.toggle("active", lang === "zh");
  langEn.classList.toggle("active", lang === "en");
}

if (langToggle) {
  langToggle.addEventListener("click", () => {
    toggleLang();
    updateLangToggle();
    // Re-render file list to update dynamic text
    renderFiles();
    updateConvertBtn();
  });
}

// ─── Init ────────────────────────────────────────────────────────────

async function init() {
  initLang();
  updateLangToggle();

  // Re-render on language change (for dynamic content not covered by applyLang)
  window.addEventListener("lang-changed", () => {
    renderFiles();
    updateConvertBtn();
  });

  await checkTools();

  if (!isTauri()) return;

  await setupListeners();

  await listen("tauri://drag-drop", (event) => {
    const raw = event.payload.paths || [];
    const paths = raw.map((p) => (typeof p === "string" ? p : p && p.path)).filter(Boolean);
    if (paths.length > 0) addFiles(paths);
  });
}

init();
