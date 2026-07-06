import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { open } from "@tauri-apps/plugin-dialog";

// ─── State ──────────────────────────────────────────────────────────

let files = [];
let selectedDir = null;
let isConverting = false;
let stats = null;

// ─── DOM refs ───────────────────────────────────────────────────────

const $ = (s) => document.querySelector(s);

const dropzone = $("#dropzone");
const fileList = $("#file-list");
const fileCountText = $("#file-count-text");
const clearBtn = $("#clear-btn");
const qualitySlider = $("#quality-slider");
const qualityVal = $("#quality-val");
const qualityFill = $("#quality-fill");
const preset70 = $("#preset-70");
const preset80 = $("#preset-80");
const preset95 = $("#preset-95");
const chkRecursive = $("#chk-recursive");
const chkDelete = $("#chk-delete");
const outputDir = $("#output-dir");
const dirBtn = $("#dir-btn");
const dirClear = $("#dir-clear");
const namingMode = $("#naming-mode");
const convertBtn = $("#convert-btn");
const btnText = $("#btn-text");
const btnSpinner = $("#btn-spinner");
const statsPanel = $("#stats-panel");
const statSuccess = $("#stat-success");
const statSkip = $("#stat-skip");
const statFail = $("#stat-fail");
const statSaved = $("#stat-saved");
const toolStatus = $("#tool-status");
const donateBtn = $("#donate-btn");
const donateModal = $("#donate-modal");
const modalClose = $("#modal-close");

// ─── Format helpers ─────────────────────────────────────────────────

function formatBytes(bytes, decimals = 1) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(decimals)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(decimals)} MB`;
}

// ─── Tool check ─────────────────────────────────────────────────────

async function checkTools() {
  try {
    const tools = await invoke("check_tools");
    let html = "";
    html += tools.cwebp
      ? '<span style="color:#10b981">✓</span> cwebp'
      : '<span style="color:#ef4444">✗</span> cwebp (必需)';
    html += tools.jpegoptim
      ? ' · <span style="color:#10b981">✓</span> jpegoptim'
      : ' · <span style="color:#999">—</span> jpegoptim';
    html += tools.pngquant
      ? ' · <span style="color:#10b981">✓</span> pngquant'
      : ' · <span style="color:#999">—</span> pngquant';
    html += tools.oxipng
      ? ' · <span style="color:#10b981">✓</span> oxipng'
      : ' · <span style="color:#999">—</span> oxipng';
    toolStatus.innerHTML = html;
    updateConvertBtn();
  } catch (e) {
    toolStatus.textContent = "工具检查失败: " + e;
  }
}

// ─── Add files ───────────────────────────────────────────────────────

function addFiles(paths) {
  for (const p of paths) {
    // Skip invalid paths
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
        <p>为什么要用 WebP？</p>
        <ul>
          <li>Google 开发的现代图片格式</li>
          <li>同等质量下比 JPEG 小 25-35%</li>
          <li>支持透明通道（替代 PNG）</li>
          <li>Chrome / Edge / Firefox / Safari 全支持</li>
        </ul>
      </div>`;
    fileCountText.textContent = `已选择 ${files.length} 个文件`;
    clearBtn.hidden = true;
    return;
  }

  fileCountText.textContent = `已选择 ${files.length} 个文件`;
  clearBtn.hidden = false;

  for (const f of files) {
    // Skip malformed entries
    if (!f.path || typeof f.path !== "string") continue;

    const item = document.createElement("div");
    item.className = "file-item";
    item.dataset.path = f.path;

    const name = f.path.split(/[/\\]/).pop();
    const ext = name.split('.').pop().toLowerCase().replace(/[^a-z0-9]/g, '');
    const thumbColors = { jpg: '#f59e0b', jpeg: '#f59e0b', png: '#3b82f6', webp: '#10b981' };
    const thumbColor = thumbColors[ext] || '#999';
    const thumbSrc = `data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 32 32%22><rect width=%2232%22 height=%2232%22 rx=%224%22 fill=%22${thumbColor}%22/><text x=%2216%22 y=%2222%22 text-anchor=%22middle%22 fill=%22white%22 font-size=%2211%22 font-weight=%22600%22>${ext.toUpperCase()}</text></svg>`;

    item.innerHTML = `
      <img class="file-thumb" src="${thumbSrc}" alt="" />
      <div class="file-info">
        <div class="file-name" title="${name}">${name}</div>
        <div class="file-size">${f.savedBytes > 0 ? `节省 ${formatBytes(f.savedBytes)}` : f.message || ""}</div>
      </div>
      <span class="file-status status-${f.status}">${statusLabel(f.status)}</span>
    `;

    fileList.appendChild(item);
  }
}

function statusLabel(s) {
  const m = { pending: "等待中", compressing: "压缩中", converting: "转换中", done: "完成", skipped: "跳过", failed: "失败" };
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

  const item = fileList.querySelector(`[data-path="${CSS.escape(filePath)}"]`);
  if (item) {
    const badge = item.querySelector(".file-status");
    badge.className = `file-status status-${status}`;
    badge.textContent = statusLabel(status);
    const size = item.querySelector(".file-size");
    size.textContent = savedBytes > 0 ? `节省 ${formatBytes(savedBytes)}` : message || "";
  }
}

// ─── Update stats ───────────────────────────────────────────────────

function updateStats(s) {
  stats = s;
  statsPanel.hidden = false;
  statSuccess.textContent = s.success_count;
  statSkip.textContent = s.skip_count;
  statFail.textContent = s.fail_count;
  // saved=0 is valid (quality=100 or all failed), always show it
  statSaved.textContent = formatBytes(s.saved);
}

// ─── Convert button state ───────────────────────────────────────────

function updateConvertBtn() {
  if (isConverting) {
    convertBtn.disabled = true;
    btnText.textContent = "转换中...";
    btnSpinner.hidden = false;
    return;
  }
  btnSpinner.hidden = true;

  if (files.length === 0) {
    convertBtn.disabled = true;
    btnText.textContent = "开始转换";
    return;
  }

  // Check if any files are still being processed
  const allDone = files.every((f) => f.status === "done" || f.status === "skipped" || f.status === "failed");
  if (allDone && files.length > 0) {
    btnText.textContent = "重新转换";
  } else {
    btnText.textContent = "开始转换";
  }

  convertBtn.disabled = false;
}

// ─── Start conversion ───────────────────────────────────────────────

async function startConvert() {
  if (isConverting) return;

  isConverting = true;
  updateConvertBtn();

  // Reset all file statuses
  for (const f of files) {
    f.status = "pending";
    f.message = "";
    f.savedBytes = 0;
    f.savedPct = 0;
  }
  renderFiles();

  // Reset stats
  stats = null;
  statsPanel.hidden = true;

  try {
    await invoke("start_convert", {
      request: {
        files: files.map((f) => f.path),
        quality: Math.max(10, Math.min(100, parseInt(qualitySlider.value) || 80)),
        recursive: chkRecursive.checked,
        delete_source: chkDelete.checked,
        naming_mode: namingMode.value,
        output_dir: selectedDir || null,
      },
    });
  } catch (e) {
    // M6: restore file statuses since conversion never actually started
    for (const f of files) {
      f.status = "pending";
      f.message = "";
      f.savedBytes = 0;
      f.savedPct = 0;
    }
    renderFiles();
    isConverting = false;
    updateConvertBtn();
    alert("启动转换失败: " + e);
  }
}

// ─── Event listeners ────────────────────────────────────────────────

// Drag & drop — read files from the DOM event directly
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
  // Extract file paths from DataTransfer (works in Tauri WebView on all platforms)
  if (e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files.length > 0) {
    const paths = Array.from(e.dataTransfer.files)
      .map((f) => f.path)
      .filter(Boolean); // drop undefined/null paths
    if (paths.length > 0) addFiles(paths);
  }
});

// File picker — use Tauri native dialog
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

// Clear
clearBtn.addEventListener("click", () => {
  files = [];
  stats = null;
  statsPanel.hidden = true;
  renderFiles();
  updateConvertBtn();
});

// Quality slider
function setQuality(v) {
  const val = Math.max(10, Math.min(100, parseInt(v) || 80));
  qualitySlider.value = val;
  qualityVal.textContent = val;
  qualityFill.style.width = `${(val - 10) * 100 / 90}%`;
  // Update preset button highlight
  preset70.classList.remove("primary");
  preset80.classList.remove("primary");
  preset95.classList.remove("primary");
  if (val <= 72) preset70.classList.add("primary");
  else if (val <= 87) preset80.classList.add("primary");
  else preset95.classList.add("primary");
}

qualitySlider.addEventListener("input", () => setQuality(qualitySlider.value));

preset70.addEventListener("click", () => setQuality(70));
preset80.addEventListener("click", () => setQuality(80));
preset95.addEventListener("click", () => setQuality(95));

// Output dir
dirBtn.addEventListener("click", async () => {
  try {
    const dir = await open({ directory: true, title: "选择输出目录" });
    if (dir) {
      selectedDir = dir;
      outputDir.value = dir;
      dirClear.hidden = false;
    }
  } catch (e) {
    // Tauri dialog may not be available in dev mode
    console.log("Dialog not available:", e);
  }
});

dirClear.addEventListener("click", () => {
  selectedDir = null;
  outputDir.value = "";
  dirClear.hidden = true;
});

// Convert
convertBtn.addEventListener("click", startConvert);

// Donate modal
donateBtn.addEventListener("click", () => { donateModal.classList.add("visible"); });
modalClose.addEventListener("click", () => { donateModal.classList.remove("visible"); });
donateModal.addEventListener("click", (e) => { if (e.target === donateModal) donateModal.classList.remove("visible"); });

// Keyboard shortcut: Enter to start (M3: skip when typing in input fields)
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

// ─── Init ────────────────────────────────────────────────────────────

async function init() {
  await checkTools();
  await setupListeners();

  // Handle files dropped from OS (passed via Tauri's drag-drop event)
  await listen("tauri://drag-drop", (event) => {
    const raw = event.payload.paths || [];
    // Normalize: Tauri v2 might return string[] or [{path: string}, ...]
    const paths = raw.map((p) => (typeof p === "string" ? p : p && p.path)).filter(Boolean);
    if (paths.length > 0) addFiles(paths);
  });
}

init();
