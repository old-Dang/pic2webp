use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc;
use std::sync::{Arc, Mutex};
use std::time::Duration;
use image::ImageReader;
use tauri::{AppHandle, Emitter, Manager, State};

// ─── Data types ─────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConvertRequest {
    pub files: Vec<String>,
    pub quality: i32,
    pub recursive: bool,
    pub delete_source: bool,
    pub output_dir: Option<String>,
    pub naming_mode: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileProgress {
    pub file: String,
    pub status: String,
    pub message: String,
    pub saved_bytes: i64,
    pub saved_pct: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConvertResult {
    pub success_count: u32,
    pub skip_count: u32,
    pub fail_count: u32,
    pub total_original: i64,
    pub total_converted: i64,
    pub saved: i64,
    pub saved_pct: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolCheck {
    pub jpegoptim: bool,
    pub pngquant: bool,
    pub oxipng: bool,
}

// ─── App state ──────────────────────────────────────────────────────

pub struct AppState {
    pub is_converting: Mutex<bool>,
    pub tool_paths: HashMap<String, Option<String>>,
}

// ─── Tool resolution ────────────────────────────────────────────────

fn tool_exe_name(name: &str) -> String {
    if cfg!(target_os = "windows") {
        format!("{}.exe", name)
    } else {
        name.to_string()
    }
}

fn resolve_tools(app: &AppHandle) -> HashMap<String, Option<String>> {
    let tool_names = ["jpegoptim", "pngquant", "oxipng"];
    let mut map = HashMap::new();
    let mut search_dirs: Vec<PathBuf> = Vec::new();

    if let Ok(res_dir) = app.path().resource_dir() {
        search_dirs.push(res_dir.clone());
        // CR1: also search resource_dir/tools/ (Windows bundle places tools here)
        search_dirs.push(res_dir.join("tools"));
    }
    if let Ok(exe) = std::env::current_exe() {
        if let Some(parent) = exe.parent() {
            search_dirs.push(parent.join("tools"));
        }
    }

    let homebrew_paths = if cfg!(target_os = "macos") {
        vec![
            PathBuf::from("/opt/homebrew/bin"),
            PathBuf::from("/usr/local/bin"),
        ]
    } else {
        vec![]
    };

    for name in &tool_names {
        let exe_name = tool_exe_name(name);
        let mut found: Option<String> = None;

        for dir in &search_dirs {
            let candidate = dir.join(&exe_name);
            if candidate.exists() {
                found = Some(candidate.to_string_lossy().to_string());
                break;
            }
        }
        if found.is_none() {
            for dir in &homebrew_paths {
                let candidate = dir.join(&exe_name);
                if candidate.exists() {
                    found = Some(candidate.to_string_lossy().to_string());
                    break;
                }
            }
        }
        if found.is_none() {
            // S2: which auto-searches PATHEXT on Windows, so pass bare name
            found = which::which(name)
                .ok()
                .map(|p| p.to_string_lossy().to_string());
        }
        map.insert(name.to_string(), found);
    }
    map
}

// ─── Commands ───────────────────────────────────────────────────────

#[tauri::command]
fn check_tools(state: State<AppState>) -> ToolCheck {
    ToolCheck {
        jpegoptim: state.tool_paths.get("jpegoptim").and_then(|o| o.as_ref()).is_some(),
        pngquant: state.tool_paths.get("pngquant").and_then(|o| o.as_ref()).is_some(),
        oxipng: state.tool_paths.get("oxipng").and_then(|o| o.as_ref()).is_some(),
    }
}

/// Helper: unlock is_converting and return an Err with the given message.
macro_rules! bail_and_unlock {
    ($guard:expr, $msg:expr) => {{
        *$guard = false;
        drop($guard);
        return Err(($msg).into());
    }};
}

#[tauri::command]
fn start_convert(app: AppHandle, state: State<AppState>, request: ConvertRequest) -> Result<(), String> {
    let mut converting = state.is_converting.lock().map_err(|e| e.to_string())?;
    if *converting {
        return Err("已经在转换中".into());
    }
    *converting = true;

    // Read tool paths (clone before dropping the lock)
    let jpegoptim = state.tool_paths.get("jpegoptim").and_then(|o| o.clone());
    let pngquant = state.tool_paths.get("pngquant").and_then(|o| o.clone());
    let oxipng = state.tool_paths.get("oxipng").and_then(|o| o.clone());

    let quality = request.quality.clamp(10, 100);

    // ── Collect files ──
    let mut all_files: Vec<String> = Vec::new();
    let supported = ["jpg", "jpeg", "png", "webp", "heic", "heif", "avif"];

    for file in &request.files {
        let path = Path::new(file);
        if !path.exists() {
            continue;
        }
        if path.is_dir() && request.recursive {
            for entry in walkdir::WalkDir::new(path)
                .follow_links(false)
                .into_iter()
                .filter_map(|e| e.ok())
                .filter(|e| e.file_type().is_file())
            {
                let ext = entry.path().extension().and_then(|e| e.to_str()).unwrap_or("").to_lowercase();
                if supported.contains(&ext.as_str()) {
                    all_files.push(entry.path().to_string_lossy().to_string());
                }
            }
        } else if path.is_file() {
            let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("").to_lowercase();
            if supported.contains(&ext.as_str()) {
                all_files.push(file.clone());
            }
        }
    }

    // Deduplicate
    let mut seen = std::collections::HashSet::new();
    all_files.retain(|f| seen.insert(f.clone()));

    if all_files.is_empty() {
        bail_and_unlock!(converting, "没有找到支持的图片文件");
    }

    let mut stats = ConvertResult {
        success_count: 0,
        skip_count: 0,
        fail_count: 0,
        total_original: 0,
        total_converted: 0,
        saved: 0,
        saved_pct: 0,
    };

    let app_handle = app.clone();

    // Release the converting lock right before spawning the background thread
    drop(converting);

    std::thread::spawn(move || {
        for src_path in &all_files {
            let path = Path::new(src_path);
            let original_size = std::fs::metadata(src_path).map(|m| m.len() as i64).unwrap_or(0);
            stats.total_original += original_size;

            let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("").to_lowercase();
            let parent = path.parent().unwrap_or(Path::new(""));
            let stem = path.file_stem().and_then(|s| s.to_str()).unwrap_or("output");
            // N1: build filename based on naming mode
            let filename = match request.naming_mode.as_str() {
                "overwrite" => format!("{}.webp", stem),
                "webp-suffix" => format!("{}-webp.webp", stem),
                "q-suffix" => format!("{}-q{}.webp", stem, quality),
                "ts-suffix" => {
                    use std::time::{SystemTime, UNIX_EPOCH};
                    let ts = SystemTime::now()
                        .duration_since(UNIX_EPOCH).unwrap_or_default()
                        .as_secs();
                    format!("{}-{}.webp", stem, ts)
                }
                _ => format!("{}.webp", stem),
            };

            // S1: use set_extension instead of format! to avoid panic on {} in filename
            let output_path = match &request.output_dir {
                Some(dir) => {
                    let dir_path = Path::new(dir);
                    std::fs::create_dir_all(dir_path).ok();
                    Path::new(dir).join(&filename)
                }
                None => {
                    parent.join(&filename)
                }
            };
            let output_str = output_path.to_string_lossy().to_string();

            // ── Step 1: pre-compress JPEG ──
            if (ext == "jpg" || ext == "jpeg") && jpegoptim.is_some() {
                emit_progress(&app_handle, src_path, "compressing", "JPEG 预压缩...", 0, 0);
                let mut cmd = Command::new(jpegoptim.as_ref().unwrap());
                cmd.arg("--strip-all").arg("--all-normal").arg(src_path);
                run_cmd_timeout(&mut cmd, 60); // CR11: 60s for jpegoptim
            }

            // ── Step 2: pre-compress PNG ──
            if ext == "png" {
                emit_progress(&app_handle, src_path, "compressing", "PNG 预压缩...", 0, 0);

                // P1: use system temp dir, no path traversal
                // S1: use set_extension to avoid format! panic on {}
                // CR6: stem is a format arg (not template), so {test} filenames are safe
                // CR9: Windows MAX_PATH: temp_dir ~40 chars + prefix ~20 + stem + .pngquant.png
                //      may exceed 260 on extreme filenames (>180 chars), but rare
                let pngquant_output = if let (Some(tool), Some(oxi)) = (&pngquant, &oxipng) {
                    let temp_dir = std::env::temp_dir();
                    let stem = Path::new(src_path).file_stem().and_then(|s| s.to_str()).unwrap_or("temp");
                    debug_assert!(!stem.contains('/') && !stem.contains('\\'), "stem contains path separator");
                    let mut tmp_path = temp_dir.join(format!("pic2webp-{}", stem));
                    tmp_path.set_extension("pngquant.png");
                    let tmp_str = tmp_path.to_string_lossy().to_string();

                    let mut png_cmd = Command::new(tool);
                    // M7: cap at 85 — pngquant compression above 85 is negligible,
                    // WebP encoder re-encodes anyway. The min bound follows user quality slider.
                    png_cmd.arg("--quality")
                        .arg(format!("{}-100", quality.min(85)))
                        .arg("--force")
                        .arg("--output")
                        .arg(&tmp_str)
                        .arg(src_path);
                    let (code, _) = run_cmd_timeout(&mut png_cmd, 90);

                    if code == 0 && tmp_path.exists() {
                        let mut oxi_cmd = Command::new(oxi);
                        oxi_cmd.arg("--strip").arg("safe")
                            .arg("--opt").arg("3")
                            .arg("--out").arg(src_path)
                            .arg(&tmp_str);
                        run_cmd_timeout(&mut oxi_cmd, 120);
                        let _ = std::fs::remove_file(&tmp_str);
                        true
                    } else {
                        let _ = std::fs::remove_file(&tmp_str);
                        false
                    }
                } else {
                    false
                };

                if !pngquant_output {
                    // pngquant unavailable or failed — try oxipng directly on original
                    if let Some(ref oxi) = oxipng {
                        let mut oxi_cmd = Command::new(oxi);
                        oxi_cmd.arg("--strip").arg("safe")
                            .arg("--opt").arg("1")
                            .arg(src_path);
                        run_cmd_timeout(&mut oxi_cmd, 120);
                    }
                }
            }   // ← CR2: if-ext-png closes here

            // ── Step 3: decode image & encode to WebP (native, no external cwebp) ──
            emit_progress(&app_handle, src_path, "converting", "转换为 WebP...", 0, 0);

            let img = match ImageReader::open(src_path)
                .map_err(|e| format!("无法打开图片: {}", e))
                .and_then(|r| r.decode().map_err(|e| format!("解码失败: {}", e)))
            {
                Ok(img) => img,
                Err(e) => {
                    stats.fail_count += 1;
                    emit_progress(&app_handle, src_path, "failed", &e, 0, 0);
                    let _ = app_handle.emit("convert-stats", &stats);
                    continue;
                }
            };

            let (w, h) = (img.width(), img.height());
            let encode_result = if img.color().has_alpha() {
                let rgba = img.to_rgba8();
                webp::Encoder::from_rgba(rgba.as_raw(), w, h)
                    .encode_simple(false, quality as f32)
            } else {
                let rgb = img.to_rgb8();
                webp::Encoder::from_rgb(rgb.as_raw(), w, h)
                    .encode_simple(false, quality as f32)
            };

            match encode_result {
                Ok(webp_mem) => {
                    if let Err(e) = std::fs::write(&output_str, &*webp_mem) {
                        stats.fail_count += 1;
                        emit_progress(&app_handle, src_path, "failed", &format!("写入失败: {}", e), 0, 0);
                    } else {
                        let new_size = webp_mem.len() as i64;
                        stats.total_converted += new_size;

                        let saved_bytes = original_size - new_size;
                        let saved_pct = if original_size > 0 {
                            (saved_bytes * 100 / original_size) as i32
                        } else {
                            0
                        };
                        stats.success_count += 1;

                        emit_progress(&app_handle, src_path, "done", &format!("已保存 {} KB", new_size / 1024), saved_bytes, saved_pct);

                        if request.delete_source {
                            if let Err(e) = std::fs::remove_file(src_path) {
                                emit_progress(&app_handle, src_path, "done",
                                    &format!("已转换，但删除源文件失败: {}", e), saved_bytes, saved_pct);
                            }
                        }
                    }
                }
                Err(e) => {
                    stats.fail_count += 1;
                    emit_progress(&app_handle, src_path, "failed", &format!("WebP 编码失败: {:?}", e), 0, 0);
                }
            }

            let _ = app_handle.emit("convert-stats", &stats);
        }

        stats.saved = stats.total_original - stats.total_converted;
        stats.saved_pct = if stats.total_original > 0 {
            (stats.saved * 100 / stats.total_original) as i32
        } else {
            0
        };

        let _ = app_handle.emit("convert-done", &stats);

        if let Some(state) = app_handle.try_state::<AppState>() {
            if let Ok(mut converting) = state.is_converting.lock() {
                *converting = false;
            }
        }
    });

    Ok(())
}

// ─── Command timeout helper (H2) ──────────────────────────────────

/// Kill a process by PID (cross-platform)
#[cfg(unix)]
fn kill_process(pid: u32) {
    let _ = std::process::Command::new("kill")
        .arg("-9")
        .arg(pid.to_string())
        .status();
}
#[cfg(windows)]
fn kill_process(pid: u32) {
    let _ = std::process::Command::new("taskkill")
        .arg("/PID").arg(pid.to_string())
        .arg("/F").arg("/T")
        .status();
}

/// Run a command with a timeout. Returns (exit_code, combined stdout+stderr).
/// Kills the process if it exceeds the timeout.
fn run_cmd_timeout(cmd: &mut Command, secs: u64) -> (i32, String) {
    let mut child = match cmd
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
    {
        Ok(c) => c,
        Err(e) => return (-1, format!("启动失败: {}", e)),
    };

    let pid = child.id();
    let (exit_tx, exit_rx) = mpsc::channel();
    let (out_tx, out_rx) = mpsc::channel();
    let (err_tx, err_rx) = mpsc::channel();
    let cancelled = Arc::new(AtomicBool::new(false));

    if let Some(stdout) = child.stdout.take() {
        let cancelled_r = cancelled.clone();
        std::thread::spawn(move || {
            let mut buf = String::new();
            let _ = std::io::BufReader::new(stdout).read_to_string(&mut buf);
            if !cancelled_r.load(Ordering::Relaxed) {
                let _ = out_tx.send(buf);
            }
        });
    }
    if let Some(stderr) = child.stderr.take() {
        let cancelled_r = cancelled.clone();
        std::thread::spawn(move || {
            let mut buf = String::new();
            let _ = std::io::BufReader::new(stderr).read_to_string(&mut buf);
            if !cancelled_r.load(Ordering::Relaxed) {
                let _ = err_tx.send(buf);
            }
        });
    }

    let exit_tx2 = exit_tx.clone();
    std::thread::spawn(move || {
        let status = child.wait();
        let _ = exit_tx2.send(status);
    });

    match exit_rx.recv_timeout(Duration::from_secs(secs)) {
        Ok(Ok(s)) => {
            let code = s.code().unwrap_or(-1);
            let out = out_rx.recv_timeout(Duration::from_secs(3)).unwrap_or_default();
            let err = err_rx.recv_timeout(Duration::from_secs(3)).unwrap_or_default();
            (code, format!("{}{}", out, err))
        }
        Ok(Err(_)) => (-1, "进程监控错误".into()),
        Err(mpsc::RecvTimeoutError::Timeout) => {
            // CR3: cross-platform kill (kill -9 on Unix, taskkill on Windows)
            // CR4: signal reader threads to drop their output
            cancelled.store(true, Ordering::Relaxed);
            kill_process(pid);
            std::thread::sleep(Duration::from_millis(200));
            (-1, format!("超时 (>{}s)", secs))
        }
        Err(_) => (-1, "通道错误".into()),
    }
}

fn emit_progress(app: &AppHandle, file: &str, status: &str, message: &str, saved_bytes: i64, saved_pct: i32) {
    let progress = FileProgress {
        file: file.to_string(),
        status: status.to_string(),
        message: message.to_string(),
        saved_bytes,
        saved_pct,
    };
    let _ = app.emit("convert-progress", &progress);
}

// ─── App builder ────────────────────────────────────────────────────

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .setup(|app| {
            let tool_paths = resolve_tools(app.handle());
            app.manage(AppState {
                is_converting: Mutex::new(false),
                tool_paths,
            });
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![check_tools, start_convert])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
