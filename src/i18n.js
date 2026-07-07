// ─── i18n: 中英文国际化模块 ─────────────────────────────────────────

const dict = {
  zh: {
    // Header
    "subtitle": "图片转 WebP · 免费 · 本地处理",

    // Dropzone
    "dropzone-text": "拖拽图片到此处",
    "dropzone-hint": "或点击选择文件 · 支持 JPG / PNG / WebP / HEIC / AVIF",

    // File list
    "file-count": "已选择 {n} 个文件",
    "clear": "清空",

    // Empty state
    "why-webp": "为什么要用 WebP？",
    "why-1": "Google 开发的现代图片格式",
    "why-2": "同等画质体积减少 25-50%",
    "why-3": "支持透明通道，替代 PNG",
    "why-4": "Chrome / Edge / Firefox / Safari 全兼容",
    "how-title": "如何实现？",
    "how-1": "内置 WebP 编码引擎，无需安装任何工具",
    "how-2": "可选 jpegoptim / pngquant 预压缩，进一步减小体积",
    "how-3": "所有处理本地完成，不上传任何文件",
    "how-4": "转换后自动统计节省空间",

    // Blog
    "blog": "博客",

    // Quality
    "output-quality": "输出质量",
    "quality": "质量",
    "small-file": "小文件",
    "high-quality": "高质量",

    // Options
    "convert-options": "转换选项",
    "recursive": "递归子目录",
    "delete-source": "转换后删除源文件",

    // Output dir
    "output-dir": "输出目录",
    "same-dir": "与源文件同目录",
    "select": "选择",

    // Naming
    "naming-rule": "命名规则",
    "overwrite": "覆盖",
    "timestamp": "时间戳",

    // Stats
    "success": "成功",
    "skip": "跳过",
    "fail": "失败",
    "saved": "节省",

    // Convert button
    "start-convert": "开始转换",
    "converting": "转换中...",
    "re-convert": "重新转换",

    // Status labels
    "status-pending": "等待中",
    "status-compressing": "压缩中",
    "status-converting": "转换中",
    "status-done": "完成",
    "status-skipped": "跳过",
    "status-failed": "失败",

    // File size messages
    "saved-bytes": "节省 {size}",
    "convert-failed": "启动转换失败",

    // Dialog
    "select-output-dir": "选择输出目录",

    // Donate
    "donate-btn": "请作者喝杯奶茶 ☕",
    "donate-title": "请作者喝杯奶茶 🧋",
    "donate-hint": "如果 Pic2WebP 帮到了你，欢迎随意打赏",
    "alipay": "支付宝",
    "wechat-pay": "微信支付",

    // Backend message overrides (maps Rust message to localized)
    "msg-jpeg-precompress": "JPEG 预压缩...",
    "msg-png-precompress": "PNG 预压缩...",
    "msg-converting": "转换为 WebP...",
    "msg-saved": "已保存 {n} KB",
    "msg-write-fail": "写入失败: {e}",
    "msg-delete-fail": "已转换，但删除源文件失败: {e}",
    "msg-encode-fail": "WebP 编码失败: {e}",
  },

  en: {
    // Header
    "subtitle": "JPG to WebP · Free · Local",

    // Dropzone
    "dropzone-text": "Drop images here",
    "dropzone-hint": "or click to select · JPG / PNG / WebP / HEIC / AVIF",

    // File list
    "file-count": "{n} file(s) selected",
    "clear": "Clear",

    // Empty state
    "why-webp": "Why WebP?",
    "why-1": "Modern image format by Google",
    "why-2": "25-50% smaller at same quality",
    "why-3": "Supports transparency, replaces PNG",
    "why-4": "Chrome / Edge / Firefox / Safari compatible",
    "how-title": "How it works",
    "how-1": "Built-in WebP encoder, no extra tools needed",
    "how-2": "Optional jpegoptim / pngquant pre-compression",
    "how-3": "All processing is local, no uploads",
    "how-4": "Auto-calculates space savings",

    // Blog
    "blog": "Blog",

    // Quality
    "output-quality": "Output Quality",
    "quality": "Quality",
    "small-file": "Smaller",
    "high-quality": "Better",

    // Options
    "convert-options": "Options",
    "recursive": "Include subdirectories",
    "delete-source": "Delete source after conversion",

    // Output dir
    "output-dir": "Output Directory",
    "same-dir": "Same as source",
    "select": "Browse",

    // Naming
    "naming-rule": "Naming",
    "overwrite": "Overwrite",
    "timestamp": "Timestamp",

    // Stats
    "success": "Done",
    "skip": "Skip",
    "fail": "Fail",
    "saved": "Saved",

    // Convert button
    "start-convert": "Convert",
    "converting": "Converting...",
    "re-convert": "Convert Again",

    // Status labels
    "status-pending": "Pending",
    "status-compressing": "Compressing",
    "status-converting": "Converting",
    "status-done": "Done",
    "status-skipped": "Skipped",
    "status-failed": "Failed",

    // File size messages
    "saved-bytes": "Saved {size}",
    "convert-failed": "Failed to start conversion",

    // Dialog
    "select-output-dir": "Select output directory",

    // Donate
    "donate-btn": "Buy me a coffee ☕",
    "donate-title": "Buy me a coffee 🧋",
    "donate-hint": "If Pic2WebP helped you, feel free to support",
    "alipay": "Alipay",
    "wechat-pay": "WeChat Pay",

    // Backend message overrides
    "msg-jpeg-precompress": "Pre-compressing JPEG...",
    "msg-png-precompress": "Pre-compressing PNG...",
    "msg-converting": "Converting to WebP...",
    "msg-saved": "Saved {n} KB",
    "msg-write-fail": "Write failed: {e}",
    "msg-delete-fail": "Converted, but failed to delete source: {e}",
    "msg-encode-fail": "WebP encoding failed: {e}",
  },
};

// ─── State ──────────────────────────────────────────────────────────

let currentLang = "zh";

// ─── Public API ─────────────────────────────────────────────────────

/**
 * Initialize language from localStorage or system locale
 */
export function initLang() {
  const saved = localStorage.getItem("pic2webp-lang");
  if (saved === "zh" || saved === "en") {
    currentLang = saved;
  } else {
    // Detect system language
    const sysLang = navigator.language || navigator.userLanguage || "zh";
    currentLang = sysLang.startsWith("zh") ? "zh" : "en";
  }
  applyLang();
}

/**
 * Get current language
 */
export function getLang() {
  return currentLang;
}

/**
 * Toggle between zh and en
 */
export function toggleLang() {
  currentLang = currentLang === "zh" ? "en" : "zh";
  localStorage.setItem("pic2webp-lang", currentLang);
  applyLang();
  return currentLang;
}

/**
 * Translate a key with optional template params
 * @param {string} key - dictionary key
 * @param {object} params - { n: 5, size: "12 KB" } etc.
 * @returns {string}
 */
export function t(key, params = {}) {
  const langDict = dict[currentLang] || dict.zh;
  let str = langDict[key] || dict.zh[key] || key;
  for (const [k, v] of Object.entries(params)) {
    str = str.replace(`{${k}}`, v);
  }
  return str;
}

/**
 * Apply translations to all [data-i18n] elements in the DOM
 * Called on init and on language toggle
 */
export function applyLang() {
  document.documentElement.lang = currentLang === "zh" ? "zh-CN" : "en";

  document.querySelectorAll("[data-i18n]").forEach((el) => {
    const key = el.getAttribute("data-i18n");
    const paramsAttr = el.getAttribute("data-i18n-params");
    let params = {};
    if (paramsAttr) {
      try { params = JSON.parse(paramsAttr); } catch (_) {}
    }
    el.textContent = t(key, params);
  });

  // Update placeholders
  document.querySelectorAll("[data-i18n-placeholder]").forEach((el) => {
    const key = el.getAttribute("data-i18n-placeholder");
    el.placeholder = t(key);
  });

  // Notify other modules that language changed
  window.dispatchEvent(new CustomEvent("lang-changed", { detail: currentLang }));
}

/**
 * Translate a backend message string
 * Tries to match known patterns, falls back to original
 */
export function translateBackendMessage(message) {
  if (!message) return "";

  // Try to match known patterns
  const patterns = [
    { regex: /^JPEG 预压缩\.\.\.$/, key: "msg-jpeg-precompress" },
    { regex: /^PNG 预压缩\.\.\.$/, key: "msg-png-precompress" },
    { regex: /^转换为 WebP\.\.\.$/, key: "msg-converting" },
    { regex: /^已保存 (\d+) KB$/, key: "msg-saved", extract: (m) => ({ n: m[1] }) },
    { regex: /^写入失败: (.+)$/, key: "msg-write-fail", extract: (m) => ({ e: m[1] }) },
    { regex: /^已转换，但删除源文件失败: (.+)$/, key: "msg-delete-fail", extract: (m) => ({ e: m[1] }) },
    { regex: /^WebP 编码失败: (.+)$/, key: "msg-encode-fail", extract: (m) => ({ e: m[1] }) },
  ];

  for (const p of patterns) {
    const m = message.match(p.regex);
    if (m) {
      return t(p.key, p.extract ? p.extract(m) : {});
    }
  }

  return message;
}
