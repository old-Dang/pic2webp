# Pic2WebP

把 JPG / PNG / WebP 一键压成更小的 WebP，质量 75-85 通常比原图小 25-50%。

macOS 原生桌面工具，Tauri 跨平台，完全离线，无网络请求。

> **[⬇️ 下载最新版](https://github.com/old-Dang/pic2webp/releases)**

## 特性

- 🖼️ **拖拽即用** — 把图片拖到窗口，剩下交给它
- 📁 **递归子目录** — 勾上后整棵目录树一并处理，保持原目录结构
- 🗑️ **删除源文件** — 转换成功可自动清理原图
- 📊 **实时统计** — 节省了多少 MB、压缩比多少
- 🎯 **质量可调** — 10-100 滑块，建议 75-85
- 🛠️ **本地 cwebp 工具链** — jpegoptim / pngquant / oxipng 可选增强
- 🔒 **完全离线** — 不发任何网络请求
- 🍎 **macOS 14+** · **Windows 10+**

## 下载

前往 [Releases](https://github.com/old-Dang/pic2webp/releases) 下载对应平台的安装包。

| 平台 | 安装包 | 大小 |
|------|--------|------|
| macOS (Apple Silicon) | `.dmg` | ~5 MB |
| Windows (x64) | `.msi` | ~5 MB |

### 首次打开（macOS）

右键点击 App 选「打开」即可（macOS Gatekeeper 安全提示，未签名 App 正常现象）。

## 开发

### 前提条件

- [Rust](https://rustup.rs/) 1.70+
- [Node.js](https://nodejs.org/) 18+
- [cwebp](https://developers.google.com/speed/webp/docs/precompiled) （macOS: `brew install webp`）
- 可选：jpegoptim / pngquant / oxipng（macOS: `brew install`）

### 国内镜像加速（可选）

项目已预配国内源，如需手动设置：

**npm**（已配 npmmirror）：
```bash
npm config set registry https://registry.npmmirror.com
```

**Cargo**（已配 rsproxy）：
```toml
# ~/.cargo/config.toml
[source.crates-io]
replace-with = "rsproxy-sparse"

[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"
```

### 启动

```bash
cd tauri

# 安装前端依赖
npm install

# 开发模式（热更新）
npm run tauri dev

# 构建发布版
npm run tauri build
```

### 产物

| 平台 | 路径 |
|---|---|
| macOS | `src-tauri/target/release/bundle/dmg/Pic2WebP_1.1.2_aarch64.dmg` |
| Windows | `src-tauri/target/release/bundle/msi/Pic2WebP_1.1.2_x64.msi` |

## 隐私

100% 本地工具。**不收集任何数据，不发起任何网络请求。**

## 协议

MIT
