# Pic2WebP

把 JPG / PNG / WebP 一键压成 WebP 格式，本地处理，不联网，免费。

质量 75-85 时通常比原图小 25-50%。

## 下载

去 [Releases](https://github.com/old-Dang/pic2webp/releases) 下载对应平台的安装包，开箱即用。

| 平台 | 安装包 | 大小 |
|------|--------|------|
| Windows | `.msi` 安装包 | ~5 MB |
| macOS | `.dmg` 安装包 | ~5 MB |
| macOS（开发版） | SwiftUI 源码，自行编译 | — |

## 截图

（待补充）

## 功能

- 拖拽即用，支持多文件
- 质量滑块 10-100
- 递归子目录
- 可选删除源文件
- 自定义输出目录
- 实时节省统计
- 支持 cwebp / jpegoptim / pngquant / oxipng 工具链（可选）
- 100% 离线，不发任何网络请求

## 项目结构

```
pic2webp/
├── mac/        ← 原生 macOS SwiftUI 版
│   ├── Package.swift
│   └── Sources/Pic2WebP/
│
└── tauri/      ← 跨平台 Tauri 版 (macOS + Windows)
    ├── src/           ← 前端 (HTML/CSS/JS)
    ├── src-tauri/     ← 后端 (Rust)
    ├── tools/         ← cwebp.exe (已打包)
    └── package.json
```

## 自行构建

本项目已配置 GitHub Actions，推送 tag 自动构建两个平台的安装包。

```bash
git tag v1.0.1
git push origin v1.0.1
```

或者手动构建：

### macOS (Tauri)

```bash
cd tauri
brew install webp
npm install
npm run tauri build
```

### macOS (原生 SwiftUI)

```bash
cd mac
swift build -c release
```

### Windows

```bash
cd tauri
npm install
npm run tauri build
```

## 隐私

100% 本地处理。不收集任何数据，不发起任何网络请求。

## 协议

MIT
