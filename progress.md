# Pic2WebP 工作日志

## 2026-07-06（周一）

### 今日概览
从零接手 Pic2WebP 项目，完成 Tauri 重构、CI/CD 搭建、多处 bug 修复，最终发布 v1.2.0 版本。
共 7 次提交，5 次 Action 构建（3 失败 → 2 成功），发布 1 个 Release。

---

### 提交记录（按时间顺序）

| # | Commit | 内容 |
|---|--------|------|
| 1 | `67045d2` | 初始化项目，Tauri 重构版作为新起点 |
| 2 | `364dfae` | 统一版本号为 1.1.2（Cargo.toml 从 1.0.0 修正） |
| 3 | `b56f6dc` | 移除 Google Fonts CDN，使用系统字体栈实现真正离线 |
| 4 | `d97e947` | 添加 GitHub Actions 自动构建和发布工作流 |
| 5 | `37aeba6` | 删除死代码 style.css，修复缩略图 SVG 拼接 bug 和 app.js 残留 |
| 6 | `f3b4738` | v1.2.0: 原生 WebP 编码 + NSIS 安装器 + CI 修复 |
| 7 | `1ddb782` | fix: 修复 transformCallback 运行时错误 + 左下角添加博客链接 |

---

### 详细工作内容

#### 1. 项目初始化与工程规范
- Tauri 重构版作为新起点，初始化项目结构
- 统一版本号：Cargo.toml（1.0.0 → 1.1.2 → 1.2.0）
- 创建 `task_plan.md`、`findings.md`、`progress.md` 规划文件

#### 2. 移除 Google Fonts，实现真正离线
- 移除 `index.html` 中的 Google Fonts CDN 链接
- 使用系统字体栈替代：`-apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif`
- 确保 CSP 策略一致性，100% 本地运行无网络请求

#### 3. 搭建 GitHub Actions CI/CD
- 创建 `.github/workflows/build.yml`
- 触发条件：push 到 main（构建+artifact） / push `v*` tag（构建+Release）
- macOS + Windows 双平台并行构建
- macOS: 构建 + ad-hoc 签名 → DMG
- Windows: 构建 → NSIS 安装器

#### 4. 清理死代码
- 删除未引用的 `style.css`
- 修复缩略图 SVG 拼接 bug
- 清理 `app.js` 中的残留代码

#### 5. v1.2.0 核心升级
- **原生 WebP 编码**：用 `webp` crate（libwebp Rust 绑定）替换外部 `cwebp` 命令行工具，静态链接，零外部依赖
- **Windows NSIS 安装器**：从 MSI 切换到 NSIS，解决重装报错 1909，添加 `allowDowngrades: true`
- **CI 修复**：`build-and-sign.sh` 改用 `find` 动态查找 DMG 文件名，修复硬编码问题
- 版本号升级 1.1.2 → 1.2.0

#### 6. 修复 transformCallback 运行时错误
- **问题**：`TypeError: Cannot read properties of undefined (reading 'transformCallback')`
- **根因**：Tauri v2 环境检测使用了错误的 `window.__TAURI__`，实际应使用官方 `isTauri()` 函数（检查 `window.isTauri`）
- **修复**：从 `@tauri-apps/api/core` 导入官方 `isTauri()`，在 `init()` 和 `checkTools()` 中正确判断环境
- **附带修复**：`build-and-sign.sh` 从 DMG 提取 .app 再签名（Tauri v2 构建 DMG 后会清理 .app）

#### 7. 左下角添加博客链接
- 在左侧面板底部添加低调的 `91hym.cn` 链接
- 9px 字号 + 50% 透明度，几乎与背景融为一体
- 悬停时恢复完全不透明并变橙色

---

### GitHub Actions 构建记录

| # | 触发 | 分支/Tag | 结果 | 说明 |
|---|------|---------|------|------|
| 1 | push | main | ❌ cancelled | CI 工作流被新推送取消 |
| 2 | push | main | ❌ failure | 死代码清理提交，构建失败 |
| 3 | push | main | ❌ failure | v1.2.0 提交，构建失败 |
| 4 | push | main | ✅ success | transformCallback 修复，构建成功（仅 artifact） |
| 5 | push | v1.2.0 tag | ✅ success | Release 构建，成功发布 v1.2.0 |

### Release 发布

- **v1.2.0**（Latest）— 包含 macOS DMG + Windows NSIS 安装包
  - macOS: `Pic2WebP_1.2.0_aarch64.dmg`（ad-hoc 签名）
  - Windows: NSIS `.exe` 安装器
  - 下载页: https://github.com/old-Dang/pic2webp/releases/tag/v1.2.0

---

### 遇到的问题与解决

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| `transformCallback` undefined 错误 | 环境检测用错变量名（`__TAURI__` vs `isTauri`） | 使用官方 `isTauri()` 函数 |
| 点击图片提示"仅在Tauri可用" | 同上，误判为非 Tauri 环境 | 同上 |
| CI 构建失败 | `build-and-sign.sh` 硬编码 DMG 文件名 | 改用 `find` 动态查找 |
| CI 构建失败 | Tauri v2 构建 DMG 后清理 .app，找不到 .app 签名 | 从 DMG 提取 .app 再签名 |
| Action 成功但无 Release | push main 只上传 artifact，不发 Release | 需 push `v*` tag 才触发 Release |
| Windows 重装报错 1909 | MSI 安装器问题 | 切换到 NSIS + `allowDowngrades: true` |
| Windows 缺少 cwebp.exe | 依赖外部命令行工具 | 用 `webp` crate 原生编码，静态链接 |

---

### 待办（未完成）

- [ ] HEIC 真正解码支持（需引入 libheif）
- [ ] Rust 代码重构（拆分 `start_convert` 超长函数）
- [ ] 补充单元测试和集成测试
- [ ] README 修正（开发指南路径、"已配国内源"声明）
