# Task Plan: Pic2WebP 项目接手与改进

## Goal
全面接手 Pic2WebP 项目，修复评审发现的问题，补充工程规范，实现真正的 HEIC 支持，为后续博客推广做好准备。

## Current Phase
Phase 1

## Phases

### Phase 1: 项目初始化与工程规范
- [ ] 确认 Git 仓库状态，初始化或关联远程仓库
- [ ] 创建 .gitignore
- [ ] 统一版本号 (package.json / Cargo.toml / tauri.conf.json → 1.1.2)
- [ ] 创建计划文件 (task_plan.md, findings.md, progress.md)
- **Status:** in_progress

### Phase 2: 移除 Google Fonts，修复离线声明
- [ ] 移除 index.html 中的 Google Fonts CDN 链接
- [ ] 使用系统字体栈替代
- [ ] 验证 CSP 策略一致性
- **Status:** pending

### Phase 3: 清理死代码
- [ ] 删除未引用的 style.css
- [ ] 清理 app.js 中的死代码 (fileCount = null 等)
- [ ] 修复缩略图 SVG 拼接 bug (thumbColor 多余的 "22")
- **Status:** pending

### Phase 4: HEIC 真正解码支持
- [ ] 调研 Rust 生态中 HEIC 解码方案 (libheif-rs / image crate HEIC feature)
- [ ] 确定方案并实现
- [ ] 测试 HEIC → WebP 转换
- **Status:** pending

### Phase 5: Rust 代码重构
- [ ] 拆分 start_convert 超长函数
- [ ] 改进 kill_process 实现 (用 child.kill() 替代外部命令)
- [ ] 非递归模式传入目录时给用户提示
- **Status:** pending

### Phase 6: 补充测试
- [ ] 为核心纯函数添加单元测试
- [ ] 添加集成测试
- **Status:** pending

### Phase 7: README 修正
- [ ] 修复开发指南 (cd tauri → 项目根目录)
- [ ] 修正"已配国内源"声明
- [ ] 更新功能描述 (确保与实际一致)
- **Status:** pending

### Phase 8: 构建验证
- [ ] npm run tauri build 验证构建通过
- [ ] 运行测试
- [ ] 最终 review
- **Status:** pending

## Key Questions
1. Git 仓库未初始化 — 需要确认远程仓库 URL 和初始化方式
2. HEIC 解码方案选择 — 需要调研后向用户确认
3. 是否需要 CI/CD 配置 (GitHub Actions)？

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| 工作流程: 直接在 main 分支改 | 用户选择 A，改好由用户 review |
| HEIC: 引入 libheif 真正实现 | 用户选择 A，功能完整优先 |
| 优先级: 1→2→3→4→5 | 按评审建议顺序执行 |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| Git 仓库未初始化 | 1 | 待用户确认远程仓库信息 |

## Notes
- 用户是跨平台开发新手，这是第一个跨平台项目
- 项目目前只有用户一人使用，后面可能通过博客 https://www.91hym.cn/ 推广
- 用户要求在过程中尽量多问，不要自己猜
