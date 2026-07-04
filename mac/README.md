# pic2webp

macOS 原生图片转 WebP 工具 · SwiftUI · 本地处理 · 无网络请求

把 JPG / PNG / WebP 一键压成更小的 WebP。质量 75-85 通常比原图小 25-50%。

## 特性

- 🖼️ **拖拽即用** — 把图片拖到窗口，剩下交给它
- 📁 **递归子目录** — 勾上后整棵目录树一并处理，保持原结构
- 🗑️ **删除源文件** — 转换成功可自动清理原图
- 📊 **实时统计** — 节省了多少 MB、压缩比多少
- 🎯 **质量可调** — 1-100 滑块，建议 75-85
- 🛠️ **本地工具链** — 调用 `cwebp` / `jpegoptim` / `pngquant` / `oxipng`
- 🔒 **完全离线** — 不发任何网络请求
- 🍎 **macOS 14+** 原生 SwiftUI App
- 💚 **免费 + 捐赠** — MIT 协议，喜欢请作者喝杯奶茶

## 安装

### 方式 1：下载 Release（普通用户）

前往 [Releases 页面](https://github.com/jubuzz/pic2webp/releases) 下载最新 `pic2webp.dmg`，双击挂载后把 `pic2webp.app` 拖进 `/Applications`。

> **首次打开**：右键点击 App 选「打开」即可（macOS Gatekeeper 安全提示，未签名 App 正常现象）。

### 方式 2：从源码编译（开发者）

需要 macOS 14+ 和 Xcode Command Line Tools。

```bash
# 1. 安装依赖工具
brew install webp jpegoptim pngquant oxipng

# 2. 克隆并编译
git clone https://github.com/jubuzz/pic2webp.git
cd pic2webp
swift build -c release

# 3. 打包成 App
./scripts/make-app.sh
```

## 系统要求

- macOS 14 Sonoma 或更新
- 依赖外部工具（任一缺失会有友好提示）：
  - `cwebp`（Homebrew: `brew install webp`）
  - `jpegoptim`（`brew install jpegoptim`）
  - `pngquant`（`brew install pngquant`）
  - `oxipng`（`brew install oxipng`）

## 使用说明

1. 把图片拖到窗口（支持多选 + 文件夹）
2. 调整右侧选项：
   - **质量**：WebP 编码质量 1-100，建议 75-85
   - **递归子目录**：处理子文件夹内图片并保留结构
   - **删除源文件**：转换成功后删除原图（**谨慎！**）
   - **输出目录**：默认与源文件同目录
3. 点「开始转换」
4. 完成后查看每张图的节省情况

## 隐私

pic2webp 是 100% 本地工具。**不收集任何数据，不发起任何网络请求**。所有图片处理都在你的 Mac 上完成。

## 协议

MIT

## 致谢

用了这些开源工具：
- [webp](https://developers.google.com/speed/webp) — Google 的 WebP 编解码器
- [jpegoptim](https://github.com/tjko/jpegoptim) — JPEG 压缩
- [pngquant](https://pngquant.org/) — PNG 有损压缩
- [oxipng](https://github.com/oxipng/oxipng) — PNG 无损优化
