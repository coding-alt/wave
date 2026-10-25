import Foundation
import AVFoundation
import AppKit

@MainActor
final class AppModel: ObservableObject {
    enum Selection: Hashable {
        case province(Int)
        case cate(Int)
    }

    @Published var provinces: [ILProvince] = []
    @Published var categories: [ILCategory] = []
    @Published var radios: [ILRadio] = []
    @Published var selection: Selection? = nil
    @Published var searchText: String = "" {
        didSet { scheduleSearch() }
    }
    @Published var isSearching = false
    @Published var isLoading = false
    @Published var errorText: String?

    @Published var current: ILRadio?
    @Published var isPlaying = false
    @Published var volume: Double = 0.8 {
        didSet { player.volume = Float(volume) }
    }
    @Published var useSecondLine = false

    private var baseRadios: [ILRadio] = []
    private var searchTask: Task<Void, Never>?

    private let player = AVPlayer()
    private var statusObs: NSKeyValueObservation?
    private var endObs: NSObjectProtocol?
    private var loadTask: Task<Void, Never>?

    var filteredRadios: [ILRadio] { radios }

    var isSearchingMode: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    var selectionTitle: String {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty { return "搜索“\(q)”" }
        switch selection {
        case .province(let pid): return provinces.first(where: { $0.pid == pid })?.title ?? "电台"
        case .cate(let cid): return categories.first(where: { $0.pid == cid })?.title ?? "电台"
        case .none: return "电台"
        }
    }

    init() {
        player.volume = Float(volume)
        statusObs = player.observe(\.timeControlStatus, options: [.new]) { [weak self] p, _ in
            Task { @MainActor in self?.isPlaying = (p.timeControlStatus == .playing) }
        }
        endObs = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handlePlaybackFailure() }
        }
    }

    deinit {
        if let o = endObs { NotificationCenter.default.removeObserver(o) }
    }

    // MARK: - Loading

    func start() async {
        guard provinces.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let (p, c) = try await ILAPI.categories()
            provinces = p
            categories = c
            if let first = p.first(where: { $0.title == "北京" }) ?? p.first {
                await select(.province(first.pid))
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    func select(_ s: Selection) async {
        selection = s
        loadTask?.cancel()
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            let list: [ILRadio]
            switch s {
            case .province(let pid): list = try await ILAPI.radios(provinceId: pid)
            case .cate(let cid): list = try await ILAPI.radios(cateId: cid)
            }
            if case .none = selection { return }
            baseRadios = list
            if !isSearchingMode { radios = list }
        } catch {
            radios = []
            errorText = error.localizedDescription
        }
    }

    // MARK: - Search

    private func scheduleSearch() {
        searchTask?.cancel()
        let q = searchText.trimmingCharacters(in: .whitespaces)
        if q.isEmpty {
            isSearching = false
            radios = baseRadios
            return
        }
        isSearching = true
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            guard let self else { return }
            do {
                let list = try await ILAPI.search(q)
                if Task.isCancelled { return }
                self.radios = list
            } catch {
                if Task.isCancelled { return }
                self.radios = []
            }
            self.isSearching = false
        }
    }

    // MARK: - Playback

    func togglePlay(_ radio: ILRadio) {
        if current?.id == radio.id {
            toggle()
        } else {
            Task { await play(radio) }
        }
    }

    func toggle() {
        guard player.currentItem != nil else {
            if let r = current { Task { await play(r, force: true) } }
            return
        }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    func play(_ radio: ILRadio, force: Bool = false) async {
        if !force, current?.id == radio.id, player.currentItem != nil {
            player.play()
            return
        }
        current = radio
        useSecondLine = false
        isPlaying = false
        var urlString = (radio.playUrl?.isEmpty == false ? radio.playUrl : radio.playUrl2) ?? ""
        // refresh the play url from the server, it expires over time
        if let fresh = try? await ILAPI.radio(id: radio.id) {
            current = fresh
            if let u = fresh.playUrl, !u.isEmpty { urlString = u }
        }
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            errorText = "该电台暂无可用播放源"
            return
        }
        startPlayer(url)
    }

    private func startPlayer(_ url: URL) {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.play()
    }

    private func handlePlaybackFailure() {
        guard let radio = current else { return }
        if !useSecondLine, let alt = radio.playUrl2, !alt.isEmpty, let url = URL(string: alt) {
            useSecondLine = true
            startPlayer(url)
        } else {
            isPlaying = false
            errorText = "播放失败，请稍后重试"
        }
    }

    func next() {
        let list = filteredRadios
        guard !list.isEmpty else { return }
        guard let cur = current, let idx = list.firstIndex(where: { $0.id == cur.id }) else {
            Task { await play(list[0]) }
            return
        }
        Task { await play(list[(idx + 1) % list.count]) }
    }

    func previous() {
        let list = filteredRadios
        guard !list.isEmpty else { return }
        guard let cur = current, let idx = list.firstIndex(where: { $0.id == cur.id }) else {
            Task { await play(list[0]) }
            return
        }
        Task { await play(list[(idx - 1 + list.count) % list.count]) }
    }
}

// MARK: - Image loader

@MainActor
final class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, NSImage>()

    func cached(_ url: String) -> NSImage? { cache.object(forKey: url as NSString) }

    func load(_ urlString: String) async -> NSImage? {
        guard let url = URL(string: urlString) else { return nil }
        if let img = cache.object(forKey: urlString as NSString) { return img }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let img = NSImage(data: data) else { return nil }
        cache.setObject(img, forKey: urlString as NSString)
        return img
    }
}
