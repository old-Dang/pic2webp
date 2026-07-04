# Pic2WebP

跨平台图片转 WebP 工具（Tauri 版）

把 JPG / PNG / WebP 一键压成更小的 WebP，质量 75-85 通常比原图小 25-50%。

## 特性

- 🖼️ **拖拽即用** — 把图片拖到窗口，剩下交给它
- 📁 **递归子目录** — 勾上后整棵目录树一并处理
- 🗑️ **删除源文件** — 转换成功可自动清理原图
- 📊 **实时统计** — 节省了多少 MB、压缩比多少
- 🎯 **质量可调** — 10-100 滑块，建议 75-85
- 🛠️ **本地 cwebp 工具链**
- 🔒 **完全离线** — 不发任何网络请求
- 🍎 **macOS** + 🪟 **Windows** 双平台

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
cd pic2webp/tauri

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
| macOS | `src-tauri/target/release/bundle/dmg/Pic2WebP_1.0.0_x64.dmg` |
| Windows | `src-tauri/target/release/bundle/msi/Pic2WebP_1.0.0_x64.msi` |

## 发布版本

构建时，cwebp 二进制会自动打包进应用：

- **macOS**：`tools/cwebp` → 嵌入 `.app/Contents/Resources/`
- **Windows**：`tools/cwebp.exe` → 嵌入安装包

Windows 版 `cwebp.exe` 可从 [Google libwebp 发布页](https://github.com/webmproject/libwebp/releases) 下载，
放到 `tools/` 目录下。

## 隐私

100% 本地工具。**不收集任何数据，不发起任何网络请求。**

## 协议

MIT
