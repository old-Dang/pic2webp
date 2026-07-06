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
- **版本**: package.json=1.1.2, tauri.conf.json=1.1.2, Cargo.toml=1.0.0 (不一致!)
- **Git**: 项目未初始化 Git 仓库，无 .git 目录
- **构建产物**: dist/ 和 src-tauri/target/ 都在工作区中，未被 ignore

### 评审发现的问题清单

#### 严重
1. Google Fonts CDN 与"完全离线"声明矛盾 (index.html L7-9)
2. HEIC 解码无法工作 — image crate 未开启 HEIC feature
3. 缺少 .gitignore — 构建产物可能入库

#### 中等
4. 版本号不一致 — Cargo.toml 落后 (1.0.0 vs 1.1.2)
5. style.css 是死代码 — 未被引用，与内联样式冲突
6. 缩略图 SVG 拼接 bug — app.js L129 thumbColor 后多了 "22"
7. 非递归模式传入目录被静默忽略
8. start_convert 函数过长 (~250行)

#### 轻微
9. README 开发指南有误 (cd tauri → 应为项目根目录)
10. README 声称"已配国内源"但项目中无配置
11. app.js 有死代码 (fileCount = null)
12. 缺少测试
13. ad-hoc 签名脚本仅处理 aarch64

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
|          |           |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| Git 仓库未初始化 | 待用户确认 |

## Resources
- 项目路径: /Users/danglei/Documents/vibe coding/pic2webp
- 用户博客: https://www.91hym.cn/
- GitHub 仓库: https://github.com/old-Dang/pic2webp (从 README 获知)
- Tauri v2 文档: https://v2.tauri.app/

---
*Update this file after every 2 view/browser/search operations*
