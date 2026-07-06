# Findings & Decisions

## Requirements
- 全面接手 Pic2WebP 项目
- 修复评审发现的所有问题
- 补充工程规范 (gitignore, 测试等)
- 实现真正的 HEIC 解码支持
- 为后续博客推广做好准备
- 过程中尽量多问用户，不要自己猜

## Research Findings

### 项目现状
- **技术栈**: Tauri v2 + Rust 后端 + 原生 HTML/CSS/JS 前端 + Vite 构建
- **版本**: package.json=1.1.2, tauri.conf.json=1.1.2, Cargo.toml=1.0.0 → 已统一为 1.1.2
- **Git**: 已初始化，已 force push 覆盖远程，远程仓库 old-Dang/pic2webp
- **CI**: 已添加 GitHub Actions (build.yml)，但首次构建失败

### 已完成
1. ✅ Git 初始化 + .gitignore + force push
2. ✅ 版本号统一 (Cargo.toml 1.0.0 → 1.1.2)
3. ✅ 移除 Google Fonts CDN，使用系统字体栈
4. ✅ 删除死代码 style.css，修复 SVG 拼接 bug 和 app.js 残留
5. ✅ 添加 GitHub Actions CI 工作流

### 当前阻断问题

#### 问题 A: CI 构建失败 (build-and-sign.sh)
- **现象**: macOS 构建成功生成了 `Pic2WebP_1.1.2_aarch64.dmg`，但 build-and-sign.sh 脚本找不到它
- **根因**: 脚本中 SCRIPT_DIR 路径计算有问题，`-f` 检查对 aarch64 DMG 返回 false，fall through 到 arm64 fallback 也找不到
- **影响**: CI 无法完成，无法自动生成 release
- **修复方案**: 重写 DMG 查找逻辑，使用 find 命令直接搜索

#### 问题 B: Windows MSI 重装报错 1909
- **现象**: Windows 上已存在旧版本时，重新安装提示警告 1909
- **根因**: Error 1909 = "Could not create Shortcut"（无法创建快捷方式），MSI 在覆盖安装时无法正确处理旧快捷方式
- **影响**: Windows 用户升级时遇到警告
- **修复方案**: 
  - 方案1: 在 tauri.conf.json 的 windows 配置中加 `allowDowngrades: true`
  - 方案2: 从 MSI 切换到 NSIS 安装包（NSIS 的升级处理更好）
  - 需要和用户确认

#### 问题 C: Windows 上 cwebp 缺失
- **现象**: Windows 安装后打开应用，提示 cwebp 缺失
- **根因**: 外部 cwebp.exe 在 Windows MSI 安装后未被正确找到（资源打包/路径解析问题）
- **影响**: Windows 上核心功能完全不可用
- **修复方案**:
  - 方案A: 修复资源打包和路径解析逻辑（保留外部 cwebp）
  - 方案B: 用 Rust 原生 WebP 编码替代外部 cwebp（image crate 已有 webp feature）
  - 方案B 优势: 彻底消除外部依赖，不再需要打包 cwebp.exe，真正跨平台
  - 方案B 劣势: 可能丢失 cwebp 的一些高级选项（如 -sharp_yuv），改动较大
  - 需要和用户确认

### HEIC 解码调研
- `image` crate 0.25 不原生支持 HEIC 解码（需要 libheif C 库后端）
- `libheif-rs` 是 libheif 的 Rust 封装，但需要系统安装 libheif-dev
- 纯 Rust 的 HEIC 解码方案目前不成熟
- 需要和用户确认方案

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| 工作流程: 直接在 main 分支改 | 用户选择 A，改好由用户 review |
| HEIC: 引入 libheif 真正实现 | 用户选择 A，功能完整优先 |
| 字体: 系统字体栈 | 用户确认方案1，真正离线 |
| CI: push main 测试 + tag 发 release | 用户选择 1-C |
| 平台: macOS aarch64 + Windows x64 | 用户选择 2-A |
| macOS: ad-hoc 签名 | 用户选择 3-A |
| Release: tag 名即版本号 | 用户选择 4-C |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| Git 仓库未初始化 | 已初始化 + force push |
| CI build-and-sign.sh 找不到 DMG | 待修复 |
| Windows MSI 重装报错 1909 | 待确认方案 |
| Windows cwebp 缺失 | 待确认方案 |

## Resources
- 项目路径: /Users/danglei/Documents/vibe coding/pic2webp
- 用户博客: https://www.91hym.cn/
- GitHub 仓库: https://github.com/old-Dang/pic2webp
- Tauri v2 文档: https://v2.tauri.app/
- Windows Installer Error 1909: 快捷方式创建失败，常见于覆盖安装
- image crate v0.25 WebP: 已有 webp feature，支持编解码

---
*Update this file after every 2 view/browser/search operations*
