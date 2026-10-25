import SwiftUI
import AppKit

// MARK: - Palette

enum Theme {
    static let accent = Color(red: 0.94, green: 0.33, blue: 0.28)
    static let accentSoft = Color(red: 0.94, green: 0.33, blue: 0.28).opacity(0.14)
}

// MARK: - Remote image

struct RemoteImage: View {
    let url: String?
    var size: CGFloat
    var radius: CGFloat
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.primary.opacity(0.06))
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: size * 0.3, weight: .light))
                    .foregroundStyle(.secondary.opacity(0.55))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .task(id: url) {
            guard let url, !url.isEmpty else { return }
            if let cached = ImageCache.shared.cached(url) {
                image = cached
                return
            }
            image = await ImageCache.shared.load(url)
        }
    }
}

// MARK: - Equalizer

struct EqualizerBars: View {
    var active: Bool
    var color: Color = .white

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: !active)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2.5) {
                ForEach(0..<3, id: \.self) { i in
                    let phase = t * (2.4 + Double(i) * 0.7) + Double(i)
                    let h = active ? 3 + (sin(phase) * 0.5 + 0.5) * 9 : 3
                    Capsule().fill(color).frame(width: 2.5, height: h)
                }
            }
            .frame(height: 12, alignment: .bottom)
        }
    }
}

// MARK: - Station card

struct StationCard: View {
    let radio: ILRadio
    let isCurrent: Bool
    let isPlaying: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    RemoteImage(url: radio.imgUrl, size: 96, radius: 20)
                        .shadow(color: .black.opacity(hover ? 0.20 : 0.10),
                                radius: hover ? 12 : 6, x: 0, y: hover ? 6 : 3)
                    if isCurrent {
                        ZStack {
                            Circle().fill(Theme.accent).frame(width: 26, height: 26)
                            EqualizerBars(active: isPlaying)
                        }
                        .offset(x: 4, y: 4)
                    }
                }
                VStack(spacing: 3) {
                    Text(radio.name)
                        .font(.system(size: 12.5, weight: isCurrent ? .semibold : .medium))
                        .foregroundStyle(isCurrent ? Theme.accent : Color.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(height: 44, alignment: .top)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(hover ? Color.primary.opacity(0.05) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }

    private var subtitle: String {
        if let p = radio.currentProgramme, !p.isEmpty { return p }
        if let d = radio.desc, !d.isEmpty, d != "暂无节目信息" { return d }
        return "直播中"
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 21))
                    .foregroundStyle(Theme.accent)
                Text("小旋风收音机")
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 40)
            .padding(.bottom, 18)

            SearchField(text: $model.searchText)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    sectionLabel("省份")
                    ForEach(model.provinces) { p in
                        row(title: p.title, selected: model.selection == .province(p.pid)) {
                            Task { await model.select(.province(p.pid)) }
                        }
                    }
                    sectionLabel("类型")
                        .padding(.top, 10)
                    ForEach(model.categories) { c in
                        row(title: c.title, selected: model.selection == .cate(c.pid)) {
                            Task { await model.select(.cate(c.pid)) }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 16)
            }
        }
        .frame(width: 214)
        .background(
            ZStack {
                Rectangle().fill(.regularMaterial)
                LinearGradient(colors: [Theme.accent.opacity(0.07), .clear],
                               startPoint: .topLeading, endPoint: .center)
            }
        )
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.primary.opacity(0.07)).frame(width: 1)
        }
    }

    private func sectionLabel(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private func row(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 12.5, weight: selected ? .semibold : .regular))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? Theme.accentSoft : Color.clear)
            )
            .foregroundStyle(selected ? Theme.accent : Color.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SearchField: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("搜索电台", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($focused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }
}

// MARK: - Content

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            grid
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.35))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(model.selectionTitle)
                .font(.system(size: 19, weight: .bold))
            Text("\(model.filteredRadios.count) 个电台")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            Spacer()
            if model.isLoading || model.isSearching {
                ProgressView().controlSize(.small)
            } else if let sel = model.selection, !model.isSearchingMode {
                Button {
                    Task { await model.select(sel) }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("刷新")
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    private var grid: some View {
        ScrollView {
            if let err = model.errorText, model.radios.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(.secondary)
                    Text(err).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 120)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 146, maximum: 190), spacing: 14)],
                    spacing: 12
                ) {
                    ForEach(model.filteredRadios) { r in
                        StationCard(radio: r,
                                    isCurrent: model.current?.id == r.id,
                                    isPlaying: model.isPlaying) {
                            model.togglePlay(r)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }
}

// MARK: - Player bar

struct PlayerBar: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 14) {
            RemoteImage(url: model.current?.imgUrl, size: 50, radius: 12)
                .opacity(model.current == nil ? 0.35 : 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.current?.name ?? "未选择电台")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 230, alignment: .leading)

            Spacer(minLength: 8)

            HStack(spacing: 16) {
                Button(action: model.previous) {
                    Image(systemName: "backward.fill").font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("上一个")

                Button(action: model.toggle) {
                    ZStack {
                        Circle()
                            .fill(model.current == nil ? Color.primary.opacity(0.10) : Theme.accent)
                            .frame(width: 40, height: 40)
                        Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(model.current == nil ? Color.secondary : .white)
                            .offset(x: model.isPlaying ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(model.current == nil)

                Button(action: model.next) {
                    Image(systemName: "forward.fill").font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("下一个")
            }
            .foregroundStyle(.primary)

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Image(systemName: "speaker.fill").font(.system(size: 9)).foregroundStyle(.secondary)
                Slider(value: $model.volume, in: 0...1)
                    .frame(width: 84)
                    .controlSize(.mini)
                Image(systemName: "speaker.wave.3.fill").font(.system(size: 9)).foregroundStyle(.secondary)
            }
            .frame(width: 130, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .frame(height: 78)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 1)
        }
    }

    private var subtitle: String {
        if let p = model.current?.currentProgramme, !p.isEmpty { return p }
        if model.current == nil { return "从列表中选择一个电台开始收听" }
        return model.useSecondLine ? "直播中 · 备用线路" : "直播中"
    }
}
