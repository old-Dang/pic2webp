import SwiftUI
import UniformTypeIdentifiers

// MARK: - Models

struct ImageItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var status: Status = .pending

    var fileName: String { url.lastPathComponent }
    var ext: String { url.pathExtension.lowercased() }
    var fileSize: Int64 { (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap(Int64.init) ?? 0 }

    enum Status: Equatable {
        case pending
        case compressing
        case converting
        case done(saved: Int64, savedPct: Int)
        case skipped(reason: String)
        case failed(error: String)

        var isDoneOrSkipped: Bool {
            if case .done = self { return true }
            if case .skipped = self { return true }
            return false
        }
    }
}

struct OutputStats {
    var totalOriginal: Int64 = 0
    var totalConverted: Int64 = 0
    var successCount = 0
    var skipCount = 0
    var failCount = 0

    var saved: Int64 { totalOriginal - totalConverted }
    var savedPct: Int {
        guard totalOriginal > 0 else { return 0 }
        return Int((saved * 100) / totalOriginal)
    }
}

// MARK: - Tool Path Resolution

enum Tool {
    case cwebp, jpegoptim, pngquant, oxipng

    var name: String {
        switch self {
        case .cwebp: return "cwebp"
        case .jpegoptim: return "jpegoptim"
        case .pngquant: return "pngquant"
        case .oxipng: return "oxipng"
        }
    }

    var brewPath: String { "/opt/homebrew/bin/\(name)" }
    var macportsPath: String { "/opt/local/bin/\(name)" }

    func resolve() -> String? {
        let candidates = [brewPath, macportsPath]
        for p in candidates {
            if FileManager.default.isExecutableFile(atPath: p) { return p }
        }
        // Fallback: which
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["which", name]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !path.isEmpty && FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    static func checkAll() -> [(Tool, String)] {
        var missing: [(Tool, String)] = []
        for tool in [Tool.cwebp, .jpegoptim, .pngquant, .oxipng] {
            if let path = tool.resolve() {
                print("[ToolCheck] \(tool.name): \(path)")
            } else {
                missing.append((tool, "\(tool.name) not found"))
            }
        }
        return missing
    }
}

// MARK: - Donation QR Images (loaded from bundle)

func findDonationURL(named name: String) -> URL? {
    let fm = FileManager.default
    if let resourcesURL = Bundle.main.resourceURL {
        // Directly in Resources/ (copied by make-app.sh)
        for ext in ["", "jpg"] {
            let url = resourcesURL.appendingPathComponent(name).appendingPathExtension(ext)
            if fm.fileExists(atPath: url.path) { return url }
        }
        // In the SwiftPM resource bundle's Resources/ subdir
        let bundleDir = resourcesURL.appendingPathComponent("pic2webp_pic2webp.bundle/Resources")
        for ext in ["", "jpg"] {
            let url = bundleDir.appendingPathComponent(name).appendingPathExtension(ext)
            if fm.fileExists(atPath: url.path) { return url }
        }
    }
    return nil
}

let donateAlipayImage: NSImage = {
    guard let url = findDonationURL(named: "alipay_donate"),
          let img = NSImage(contentsOf: url) else {
        return NSImage()
    }
    return img
}()

let donateWechatImage: NSImage = {
    guard let url = findDonationURL(named: "wechat_donate"),
          let img = NSImage(contentsOf: url) else {
        return NSImage()
    }
    return img
}()

// MARK: - WebP Logo

struct WebPLogo: View {
    var size: CGFloat = 28

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // 主体背景：圆角矩形，蓝渐变
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.20, green: 0.45, blue: 0.95),
                                 Color(red: 0.40, green: 0.30, blue: 0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: .blue.opacity(0.25), radius: 2, x: 0, y: 1)

            // webp 文字
            Text("webp")
                .font(.system(size: size * 0.42, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .offset(x: -size * 0.04, y: -size * 0.02)

            // 对号小圆章
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: size * 0.45, height: size * 0.45)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 0.5)
                Circle()
                    .stroke(
                        LinearGradient(colors: [.green, .mint],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: size * 0.05
                    )
                    .frame(width: size * 0.45, height: size * 0.45)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.25, weight: .heavy))
                    .foregroundStyle(
                        LinearGradient(colors: [.green, .mint],
                                       startPoint: .top, endPoint: .bottom)
                    )
            }
            .offset(x: size * 0.12, y: size * 0.12)
        }
        .frame(width: size * 1.1, height: size * 1.1)
    }
}

// MARK: - Content View

struct ContentView: View {
    @State private var items: [ImageItem] = []
    @State private var quality: Double = 80
    @State private var recursive = false
    @State private var deleteSource = false
    @State private var isConverting = false
    @State private var outputDir: URL?
    @State private var hasCustomOutputDir = false
    @State private var stats = OutputStats()
    @State private var isTargeted = false
    @State private var showFilePicker = false
    @State private var isAnimating = false
    @State private var toolPaths: [Tool: String] = [:]
    @State private var missingTools: [(Tool, String)] = []
    @State private var showToolAlert = false

    private let supportedExts = ["jpg", "jpeg", "png", "webp"]

    var body: some View {
        VStack(spacing: 0) {
            // ————— Header —————
            HStack {
                WebPLogo()
                Text("pic2webp")
                    .font(.headline)
                Spacer()
                Text("macOS 原生 · 本地处理")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)

            Divider()

            // ————— Main Content —————
            HSplitView {
                // LEFT: Drop Zone + File List
                leftPanel
                    .frame(minWidth: 320)

                // RIGHT: Controls + Output
                rightPanel
                    .frame(minWidth: 280)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Left Panel

    private var leftPanel: some View {
        VStack(spacing: 0) {
            // Drop zone
            dropZone
                .padding(16)

            // File list
            if items.isEmpty {
                whyUseWebPCard
            } else {
                List {
                    ForEach(items) { item in
                        FileRow(item: item)
                            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    }
                    .onDelete(perform: removeItems)
                }
                .disabled(isConverting)
                .listStyle(.plain)
                .scrollIndicators(.automatic)
            }
        }
    }

    // MARK: - Drop Zone

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                .foregroundStyle(isTargeted ? .blue : (items.isEmpty ? Color(white: 0.6, opacity: 0.4) : .clear))
                .frame(height: items.isEmpty ? 120 : 60)

            if items.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "plus.square.dashed")
                        .font(.title)
                        .foregroundStyle(isConverting ? Color(white: 0.6, opacity: 0.4) : Color.secondary)
                    Text("拖拽 JPG / PNG / WebP 图片到此处")
                        .font(.caption)
                        .foregroundStyle(isConverting ? Color(white: 0.7) : Color.secondary)
                    Text("或点击选择文件")
                        .font(.caption2)
                        .foregroundStyle(Color(white: 0.55))
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: isConverting ? "lock.fill" : "plus.circle.fill")
                        .foregroundStyle(isConverting ? Color.orange : Color.blue)
                    Text(isConverting ? "转换中，请稍候..." : "继续添加图片...")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                    Spacer()
                    Text("共 \(items.count) 个文件")
                        .font(.caption)
                        .foregroundStyle(Color(white: 0.55))
                }
                .padding(.horizontal, 20)
            }
        }
        .contentShape(Rectangle())
        .allowsHitTesting(!isConverting)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard !isConverting else { return false }
            handleDrop(providers: providers)
            return true
        }
        .onTapGesture {
            guard !isConverting else { return }
            showFilePicker = true
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                addFiles(urls)
            }
        }
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                // Quality
                Section {
                    VStack(spacing: 4) {
                        HStack {
                            Text("WebP 质量")
                                .font(.subheadline)
                                .help("数值越高画质越好，文件越大。推荐 75-85 获得最佳平衡。")
                            Spacer()
                            Text("\(Int(quality))")
                                .font(.title3.bold())
                                .foregroundStyle(quality < 50 ? .orange : (quality < 75 ? .yellow : .green))
                                .contentTransition(.numericText())
                        }
                        Slider(value: $quality, in: 10...100, step: 1)
                            .tint(qualityGradient)
                            .help("拖拽调节 WebP 编码质量参数")
                    }
                    .padding(.vertical, 4)

                    qualityDescription
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Options
                Section("选项") {
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle(isOn: $recursive) {
                            Label("递归子目录", systemImage: "folder.badge.gearshape")
                        }
                        .toggleStyle(.switch)
                        Text("连子文件夹里的图片一起处理")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 28)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Toggle(isOn: $deleteSource) {
                            Label("转换后删除源文件", systemImage: "trash")
                                .foregroundStyle(deleteSource ? .red : .primary)
                        }
                        .toggleStyle(.switch)
                        Text("⚠️ 不可恢复，谨慎使用")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 28)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Label("输出目录", systemImage: "folder")
                            Spacer()
                            Button(hasCustomOutputDir ? (outputDir?.lastPathComponent ?? "自定义") : "默认") {
                                selectOutputDir()
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.blue)
                            .font(.caption)
                        }
                        Text("默认在图片目录下创建 webp_out 文件夹")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 28)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            Spacer()

            // Stats
            if stats.successCount > 0 || stats.failCount > 0 {
                statsBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }

            // Donation & Convert
            VStack(spacing: 6) {
                // Donate button
                HStack {
                    Spacer()
                    Button(action: { showDonatePopover.toggle() }) {
                        Label {
                            Text("请开发者喝杯奶茶")
                                .font(.caption)
                        } icon: {
                            Image(systemName: "cup.and.saucer.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.orange.opacity(0.1))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.orange.opacity(0.3), lineWidth: 0.5))
                    )
                    .popover(isPresented: $showDonatePopover, arrowEdge: .trailing) {
                        donatePopover
                    }
                    .help("如果觉得这个工具帮到了你，欢迎请开发者喝杯奶茶 🧋")
                    Spacer()
                }
                .padding(.bottom, 4)

                Button(action: startConvert) {
                    HStack {
                        if isConverting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        Text(isConverting ? "转换中..." : "开始转换")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(items.isEmpty || isConverting)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

                if !items.isEmpty && !isConverting {
                    Button("清空列表") {
                        withAnimation { items.removeAll(); stats = OutputStats() }
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 12)
        }
    }

    // MARK: - Donation Popover

    @State private var showDonatePopover = false

    private var donatePopover: some View {
        VStack(spacing: 12) {
            Text("☕️ 请开发者喝杯奶茶")
                .font(.headline)

            Text("如果这个工具帮到了你，\n欢迎扫码支持一下 🧋")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                // Alipay
                VStack(spacing: 4) {
                    Image(nsImage: donateAlipayImage)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 100, height: 100)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.secondary.opacity(0.3), lineWidth: 0.5)
                        )
                    Text("支付宝")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }

                // WeChat
                VStack(spacing: 4) {
                    Image(nsImage: donateWechatImage)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 100, height: 100)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.secondary.opacity(0.3), lineWidth: 0.5)
                        )
                    Text("微信")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }

            HStack {
                Spacer()
                Button("关闭") {
                    showDonatePopover = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .frame(width: 280)
    }

    // MARK: - Quality Description

    private var qualityDescription: some View {
        let desc: String
        let icon: String
        switch quality {
        case ..<40: desc = "最大压缩，适合缩略图"; icon = "flame.fill"
        case ..<65: desc = "高压缩比，肉眼差异小"; icon = "leaf.fill"
        case ..<85: desc = "良好平衡，推荐默认"; icon = "hand.thumbsup.fill"
        default:    desc = "接近无损，保持高画质"; icon = "sparkles"
        }
        return Label(desc, systemImage: icon)
    }

    private var qualityGradient: Color {
        quality < 50 ? .orange : (quality < 75 ? .yellow : .green)
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        VStack(spacing: 4) {
            HStack {
                Label("完成 \(stats.successCount)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                if stats.skipCount > 0 {
                    Text("跳过 \(stats.skipCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if stats.failCount > 0 {
                    Text("失败 \(stats.failCount)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Spacer()
                Text("节省 \(stats.savedPct)%")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            }
            if stats.totalOriginal > 0 {
                ProgressView(value: Double(stats.saved), total: Double(stats.totalOriginal))
                    .tint(.green)
                HStack {
                    Text("\(formatBytes(stats.totalOriginal)) → \(formatBytes(stats.totalConverted))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("-\(formatBytes(stats.saved))")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                }
            }
        }
    }

    // MARK: - Why Use WebP (Empty State)

    private var whyUseWebPCard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // 标题
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(.green)
                    Text("为什么要用 WebP？")
                        .font(.headline)
                }

                Text("WebP 是 Google 开源的图片格式，在保证画质的前提下，\n文件大小通常比 JPG/PNG 小 25-50%。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                benefitRow(icon: "internaldrive.fill", color: .blue, title: "减少存储负担", desc: "同样的图库可省下一半空间，iCloud 月费也跟着少交")
                benefitRow(icon: "icloud.and.arrow.down.fill", color: .purple, title: "更快的上传/加载", desc: "图片体积变小，网页、相册、备份速度都更快")
                benefitRow(icon: "wifi", color: .indigo, title: "省流量 / 省钱", desc: "移动端用户少消耗流量，服务器少消耗带宽")
                benefitRow(icon: "leaf.arrow.circlepath", color: .green, title: "更环保 ♻️", desc: "数据中心少传一个字节，就少一点碳排放")
                benefitRow(icon: "globe", color: .teal, title: "全平台兼容", desc: "macOS 11+、iOS 14+、所有现代浏览器都支持")

                Divider()

                Text("💡 小提示：质量 75-85 是肉眼看不出差异的「甜点区」，\n想极限压可以试 60 看看效果。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func benefitRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 18)
                .font(.system(size: 13, weight: .semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.bold())
                Text(desc)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - File Row

    @ViewBuilder
    func FileRow(item: ImageItem) -> some View {
        HStack(spacing: 10) {
            // Thumbnail
            Group {
                if let nsImage = NSImage(contentsOf: item.url) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "doc.richtext")
                        .font(.title3)
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Info
            VStack(alignment: .leading, spacing: 1) {
                Text(item.fileName)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(formatBytes(item.fileSize))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status badge
            statusBadge(item.status)
        }
        .padding(.vertical, 2)
        .opacity(item.status.isDoneOrSkipped ? 0.7 : 1.0)
    }

    @ViewBuilder
    func statusBadge(_ status: ImageItem.Status) -> some View {
        switch status {
        case .pending:
            EmptyView()
        case .compressing:
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 20)
        case .converting:
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 20)
        case .done(let saved, let pct):
            VStack(spacing: 0) {
                Text("-\(pct)%")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                Text(formatBytes(saved))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .skipped(let reason):
            Text(reason)
                .font(.caption)
                .foregroundStyle(.secondary)
        case .failed(let error):
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(1)
        }
    }

    // MARK: - Actions

    func handleDrop(providers: [NSItemProvider]) {
        var handled = false
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async { self.addFile(url) }
                }
            }
            handled = true
        }
        if !handled {
            // fallback: try loading as image data
        }
    }

    func addFile(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        guard supportedExts.contains(ext) else { return }
        if items.contains(where: { $0.url == url }) { return }
        withAnimation {
            items.append(ImageItem(url: url))
        }
    }

    func addFiles(_ urls: [URL]) {
        for url in urls {
            addFile(url)
        }
    }

    func removeItems(at offsets: IndexSet) {
        withAnimation { items.remove(atOffsets: offsets) }
    }

    func selectOutputDir() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.message = "选择 WebP 输出目录"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                outputDir = url
                hasCustomOutputDir = true
            }
        }
    }

    // MARK: - Convert

    func toolPath(_ tool: Tool) -> String? {
        if let cached = toolPaths[tool] { return cached }
        if let path = tool.resolve() {
            toolPaths[tool] = path
            return path
        }
        return nil
    }

    func startConvert() {
        guard !items.isEmpty, !isConverting else { return }

        // Check tools first
        toolPaths.removeAll()
        var missingInstallCmd = ""
        for tool in [Tool.cwebp, .jpegoptim, .pngquant, .oxipng] {
            if toolPath(tool) == nil {
                let name = tool.name
                let brewPkg = (name == "cwebp") ? "webp" : name
                missingInstallCmd += "brew install \(brewPkg)\n"
            }
        }

        if !missingInstallCmd.isEmpty {
            let hint = missingInstallCmd.trimmingCharacters(in: .whitespacesAndNewlines)
            for item in items {
                let idx = items.firstIndex(where: { $0.id == item.id })!
                items[idx].status = .failed(error: "缺少工具: \(hint.replacingOccurrences(of: "\n", with: "; "))")
                stats.failCount += 1
                stats.totalOriginal += item.fileSize
            }
            isConverting = false
            return
        }

        // Drop zone disabled via .allowsHitTesting(!isConverting)

        isConverting = true
        stats = OutputStats()

        // Determine output base
        let outputBase: URL
        if let custom = outputDir {
            outputBase = custom
        } else if let first = items.first {
            outputBase = first.url.deletingLastPathComponent()
        } else {
            outputBase = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        }

        // Helper: scan a directory recursively for supported images
        func scanRecursive(_ dir: URL, baseDir: URL) -> [URL] {
            var found: [URL] = []
            guard let enumerator = FileManager.default.enumerator(
                at: dir,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { return found }
            for case let fileURL as URL in enumerator {
                // S3: skip symbolic links to prevent infinite recursion on symlink loops
                let isSymlink = (try? fileURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false
                if isSymlink { continue }
                let ext = fileURL.pathExtension.lowercased()
                guard supportedExts.contains(ext) else { continue }
                found.append(fileURL)
            }
            return found
        }

        // Collect all files (with recursion if enabled)
        var allFiles: [(source: URL, relativeDir: String)] = []
        if recursive {
            // Group items by parent directory and scan each parent's subtree
            var dirsToScan: [URL] = []
            for item in items {
                if item.url.hasDirectoryPath {
                    // User dragged a folder — scan the folder itself
                    dirsToScan.append(item.url)
                } else {
                    // Scan the parent directory so all siblings and sub-dirs are included
                    dirsToScan.append(item.url.deletingLastPathComponent())
                }
            }
            // Deduplicate directories
            dirsToScan = Array(Set(dirsToScan))

            for dir in dirsToScan {
                let filesInDir = scanRecursive(dir, baseDir: dir)
                for fileURL in filesInDir {
                    // Compute relative path inside this root dir
                    let rel = fileURL.path.dropFirst(dir.path.count)
                    let dirPart = rel.dropLast(fileURL.lastPathComponent.count)
                    allFiles.append((fileURL, String(dirPart)))
                }
            }
            // Add top-level items that might be directories themselves
            for item in items where item.url.hasDirectoryPath {
                if !allFiles.contains(where: { $0.source == item.url }) {
                    allFiles.append((item.url, ""))
                }
            }
        } else {
            for item in items {
                allFiles.append((item.url, ""))
            }
        }

        // Deduplicate
        var seen = Set<URL>()
        allFiles = allFiles.filter { seen.insert($0.source).inserted }

        // Process sequentially (updating UI)
        var index = 0

        func processNext() {
            guard index < allFiles.count else {
                DispatchQueue.main.async { self.isConverting = false }
                return
            }

            let (sourceURL, relDir) = allFiles[index]
            let destDir = outputBase
                .appendingPathComponent("webp_out")
                .appendingPathComponent(relDir)

            DispatchQueue.main.async {
                // Find and update matching item
                if let idx = self.items.firstIndex(where: { $0.url == sourceURL }) {
                    self.processFile(sourceURL, destDir: destDir, itemIdx: idx) {
                        index += 1
                        processNext()
                    }
                } else {
                    // File was added via recursion and isn't in the original list
                    // Process it silently
                    self.processFileSilent(sourceURL, destDir: destDir) {
                        index += 1
                        processNext()
                    }
                }
            }
        }

        processNext()
    }

    func processFile(_ url: URL, destDir: URL, itemIdx: Int, completion: @escaping () -> Void) {
        let ext = url.pathExtension.lowercased()
        let fileName = url.deletingPathExtension().lastPathComponent
        let dest = destDir.appendingPathComponent("\(fileName).webp")

        items[itemIdx].status = .converting

        do {
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        } catch {
            items[itemIdx].status = .failed(error: "创建目录失败")
            stats.failCount += 1
            completion()
            return
        }

        let srcSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap(Int64.init) ?? 0

        // Build cwebp args
        var args: [String] = []
        args += ["-q", "\(Int(quality))", "-mt", "-quiet"]
        // sharp_yuv for cwebp 1.3+
        args += ["-sharp_yuv"]

        // Pre-compress
        if ext == "jpg" || ext == "jpeg" {
            items[itemIdx].status = .compressing
            if let jpegoptimPath = toolPath(.jpegoptim) {
                _ = shell(jpegoptimPath, ["--strip-all", "--all-progressive", "--quiet", url.path])
            }
            items[itemIdx].status = .converting
        } else if ext == "png" {
            items[itemIdx].status = .compressing
            if let pngquantPath = toolPath(.pngquant) {
                _ = shell(pngquantPath, ["--speed", "1", "--quality=60-80", "--ext", ".png", "--force", url.path])
            }
            if let oxipngPath = toolPath(.oxipng) {
                _ = shell(oxipngPath, ["-o", "3", "-q", "--strip", "safe", url.path])
            }
            items[itemIdx].status = .converting
        }

        args += [url.path, "-o", dest.path]

        guard let cwebpPath = toolPath(.cwebp) else {
            items[itemIdx].status = .failed(error: "cwebp 未找到")
            stats.failCount += 1
            completion()
            return
        }
        let result = shell(cwebpPath, args)

        DispatchQueue.main.async {
            if result.status == 0, FileManager.default.fileExists(atPath: dest.path) {
                let newSize = (try? dest.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap(Int64.init) ?? 0
                let saved = srcSize - newSize
                let pct = srcSize > 0 ? Int((saved * 100) / srcSize) : 0
                items[itemIdx].status = .done(saved: saved, savedPct: pct)

                stats.totalOriginal += srcSize
                stats.totalConverted += newSize
                stats.successCount += 1

                if deleteSource && ext != "webp" {
                    try? FileManager.default.removeItem(at: url)
                }
            } else {
                let errMsg: String
                if result.output.isEmpty {
                    errMsg = "转换失败 (exit \(result.status))"
                } else {
                    errMsg = "转换失败: \(result.output.prefix(120))"
                }
                items[itemIdx].status = .failed(error: errMsg)
                stats.failCount += 1
                stats.totalOriginal += srcSize
            }
            completion()
        }
    }

    func processFileSilent(_ url: URL, destDir: URL, completion: @escaping () -> Void) {
        let ext = url.pathExtension.lowercased()
        let fileName = url.deletingPathExtension().lastPathComponent
        let dest = destDir.appendingPathComponent("\(fileName).webp")

        do {
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        } catch {
            stats.failCount += 1
            stats.totalOriginal += (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap(Int64.init) ?? 0
            completion()
            return
        }

        let srcSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap(Int64.init) ?? 0

        var args: [String] = ["-q", "\(Int(quality))", "-mt", "-quiet", "-sharp_yuv"]

        if ext == "jpg" || ext == "jpeg" {
            if let jpegoptimPath = toolPath(.jpegoptim) {
                _ = shell(jpegoptimPath, ["--strip-all", "--all-progressive", "--quiet", url.path])
            }
        } else if ext == "png" {
            if let pngquantPath = toolPath(.pngquant) {
                _ = shell(pngquantPath, ["--speed", "1", "--quality=60-80", "--ext", ".png", "--force", url.path])
            }
            if let oxipngPath = toolPath(.oxipng) {
                _ = shell(oxipngPath, ["-o", "3", "-q", "--strip", "safe", url.path])
            }
        }

        args += [url.path, "-o", dest.path]

        guard let cwebpPath = toolPath(.cwebp) else {
            stats.failCount += 1
            stats.totalOriginal += srcSize
            completion()
            return
        }
        let result = shell(cwebpPath, args)

        DispatchQueue.main.async {
            if result.status == 0, FileManager.default.fileExists(atPath: dest.path) {
                let newSize = (try? dest.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap(Int64.init) ?? 0
                stats.totalOriginal += srcSize
                stats.totalConverted += newSize
                stats.successCount += 1
                if deleteSource && ext != "webp" {
                    try? FileManager.default.removeItem(at: url)
                }
            } else {
                stats.failCount += 1
                stats.totalOriginal += srcSize
            }
            completion()
        }
    }

    // MARK: - Helpers

    func shell(_ path: String, _ args: [String]) -> (status: Int, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [path] + args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (Int(process.terminationStatus), output)
        } catch {
            return (-1, error.localizedDescription)
        }
    }

    func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }
}
