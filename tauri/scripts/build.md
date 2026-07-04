# Pic2WebP 构建脚本

## macOS

```bash
# 本机开发（已配好国内源）
cd pic2webp/tauri
npm install
npm run tauri dev     # 开发模式
npm run tauri build   # 打包成 .dmg
```

## Windows

```powershell
# 先装 .NET 运行时（Tauri v2 需要 WebView2，Win10+ 自带）
cd pic2webp/tauri

# 装前端依赖
npm install

# 打包前确认 tools/cwebp.exe 存在
# 下载地址: https://github.com/webmproject/libwebp/releases

npm run tauri build
# 产物: src-tauri/target/release/bundle/msi/Pic2WebP_1.0.0_x64.msi
# 或:   src-tauri/target/release/bundle/nsis/Pic2WebP_1.0.0_x64-setup.exe
```

## 注意事项

1. **cwebp** 是唯一必需的依赖，打包前需放入 `tools/` 目录
2. macOS 下 `brew install webp` 后自动在 PATH 中
3. Windows 下需手动下载 cwebp.exe
4. 可选工具（jpegoptim/pngquant/oxipng）缺失时自动跳过，不影响核心功能
