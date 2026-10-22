import AppKit
import AVFoundation
import Observation
import SwiftUI

enum MotionKind {
    case video, gif
}

extension Save {
    var motion: MotionKind? {
        guard kind == .image, let ext = original?.split(separator: ".").last?.lowercased() else { return nil }
        if ImageFiles.videoExtensions.contains(ext) { return .video }
        if ext == "gif" { return .gif }
        return nil
    }
}

@Observable
final class VideoPlayback {
    var paused = false
    var muted = UserDefaults.standard.bool(forKey: "pool.video.muted") {
        didSet { UserDefaults.standard.set(muted, forKey: "pool.video.muted") }
    }
    var progress: Double = 0
    var duration: Double = 0
    var scrubbing = false
    @ObservationIgnored fileprivate var seeker: ((Double) -> Void)?

    func seek(to fraction: Double) {
        let clamped = min(1, max(0, fraction))
        progress = clamped
        seeker?(clamped)
    }
}

struct SaveMedia: View {
    @Environment(AppModel.self) private var model
    let save: Save
    var maxPixel: Int
    var contentMode: ContentMode = .fill
    var playing: Bool
    var cornerRadius: CGFloat
    var playback: VideoPlayback?
    var posterFromOriginal = false

    var body: some View {
        let original = model.store.url(for: save, file: save.original)
        let thumb = model.store.url(for: save, file: save.thumbnail)
        let motion = save.motion
        ZStack {
            Thumb(url: motion == nil && posterFromOriginal ? original ?? thumb : thumb, maxPixel: maxPixel, contentMode: contentMode, tint: save.tint)
            if playing, let original, let motion {
                switch motion {
                case .video:
                    VideoSurface(url: original, fill: contentMode == .fill, cornerRadius: cornerRadius, playback: playback)
                case .gif:
                    GIFSurface(url: original, fill: contentMode == .fill, cornerRadius: cornerRadius)
                }
            }
        }
    }
}

private struct VideoSurface: NSViewRepresentable {
    let url: URL
    let fill: Bool
    let cornerRadius: CGFloat
    let playback: VideoPlayback?

    func makeNSView(context: Context) -> VideoSurfaceView {
        let view = VideoSurfaceView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: VideoSurfaceView, context: Context) {
        view.cornerRadius = cornerRadius
        view.fill = fill
        view.playback = playback
        view.muted = playback?.muted ?? true
        view.held = (playback?.paused ?? false) || (playback?.scrubbing ?? false)
        view.load(url)
    }

    static func dismantleNSView(_ view: VideoSurfaceView, coordinator: ()) {
        view.teardown()
    }
}

final class VideoSurfaceView: NSView {
    private let playerLayer = AVPlayerLayer()
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var clock: Any?
    private var url: URL?
    private var revealed = false

    weak var playback: VideoPlayback?

    var cornerRadius: CGFloat = 0 {
        didSet { layer?.cornerRadius = cornerRadius }
    }

    var fill = true {
        didSet { playerLayer.videoGravity = fill ? .resizeAspectFill : .resizeAspect }
    }

    var muted = true {
        didSet { player?.isMuted = muted }
    }

    var held = false {
        didSet { if held != oldValue { applyRate() } }
    }

    private var windowVisible = false {
        didSet { if windowVisible != oldValue { applyRate() } }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.cornerCurve = .continuous
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.opacity = 0
        layer?.addSublayer(playerLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override var isOpaque: Bool { false }

    func load(_ next: URL) {
        guard next != url else { return }
        teardown()
        url = next
        let item = AVPlayerItem(asset: AVURLAsset(url: next))
        let player = AVQueuePlayer()
        player.isMuted = muted
        player.preventsDisplaySleepDuringVideoPlayback = false
        looper = AVPlayerLooper(player: player, templateItem: item)
        playerLayer.player = player
        self.player = player
        clock = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
            MainActor.assumeIsolated { self?.tick(time) }
        }
        applyRate()
    }

    func teardown() {
        if let clock { player?.removeTimeObserver(clock) }
        clock = nil
        player?.pause()
        looper?.disableLooping()
        looper = nil
        playerLayer.player = nil
        player = nil
        url = nil
        revealed = false
        playerLayer.opacity = 0
        playback?.seeker = nil
    }

    private func tick(_ time: CMTime) {
        if !revealed, playerLayer.isReadyForDisplay {
            revealed = true
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.toValue = 1
            fade.duration = 0.18
            playerLayer.opacity = 1
            playerLayer.add(fade, forKey: "reveal")
        }
        guard let playback, let item = player?.currentItem, !playback.scrubbing else { return }
        let duration = item.duration.seconds
        guard duration.isFinite, duration > 0 else { return }
        if playback.duration != duration { playback.duration = duration }
        let fraction = min(1, max(0, time.seconds / duration))
        if abs(fraction - playback.progress) > 0.001 { playback.progress = fraction }
        if playback.seeker == nil {
            playback.seeker = { [weak self] fraction in self?.seek(to: fraction) }
        }
    }

    private func seek(to fraction: Double) {
        guard let player, let item = player.currentItem else { return }
        let duration = item.duration.seconds
        guard duration.isFinite, duration > 0 else { return }
        player.seek(to: CMTime(seconds: duration * fraction, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func applyRate() {
        guard let player else { return }
        if windowVisible, !held { player.play() } else { player.pause() }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didChangeOcclusionStateNotification, object: nil)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else {
            windowVisible = false
            return
        }
        NotificationCenter.default.addObserver(self, selector: #selector(occlusionChanged), name: NSWindow.didChangeOcclusionStateNotification, object: window)
        windowVisible = window.occlusionState.contains(.visible)
    }

    @objc private func occlusionChanged(_ note: Notification) {
        windowVisible = window?.occlusionState.contains(.visible) ?? false
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }
}

private struct GIFSurface: NSViewRepresentable {
    let url: URL
    let fill: Bool
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> GIFSurfaceView {
        let view = GIFSurfaceView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: GIFSurfaceView, context: Context) {
        view.cornerRadius = cornerRadius
        view.fill = fill
        view.load(url)
    }

    static func dismantleNSView(_ view: GIFSurfaceView, coordinator: ()) {
        view.teardown()
    }
}

final class GIFSurfaceView: NSView {
    private let imageView = NSImageView()
    private var url: URL?
    private var loader: Task<Void, Never>?

    var cornerRadius: CGFloat = 0 {
        didSet { layer?.cornerRadius = cornerRadius }
    }

    var fill = true {
        didSet { if fill != oldValue { needsLayout = true } }
    }

    private var windowVisible = false {
        didSet { imageView.animates = windowVisible }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.cornerCurve = .continuous
        imageView.imageScaling = .scaleAxesIndependently
        imageView.animates = false
        imageView.alphaValue = 0
        addSubview(imageView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func load(_ next: URL) {
        guard next != url else { return }
        teardown()
        url = next
        loader = Task { [weak self] in
            let data = await Self.read(next)
            guard let self, !Task.isCancelled, self.url == next, let data, let image = NSImage(data: data) else { return }
            self.imageView.image = image
            self.imageView.animates = self.windowVisible
            self.needsLayout = true
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.18
                self.imageView.animator().alphaValue = 1
            }, completionHandler: nil)
        }
    }

    @concurrent
    private static func read(_ url: URL) async -> Data? {
        try? Data(contentsOf: url, options: .mappedIfSafe)
    }

    func teardown() {
        loader?.cancel()
        loader = nil
        url = nil
        imageView.animates = false
        imageView.image = nil
        imageView.alphaValue = 0
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didChangeOcclusionStateNotification, object: nil)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else {
            windowVisible = false
            return
        }
        NotificationCenter.default.addObserver(self, selector: #selector(occlusionChanged), name: NSWindow.didChangeOcclusionStateNotification, object: window)
        windowVisible = window.occlusionState.contains(.visible)
    }

    @objc private func occlusionChanged(_ note: Notification) {
        windowVisible = window?.occlusionState.contains(.visible) ?? false
    }

    override func layout() {
        super.layout()
        guard let size = imageView.image?.size, size.width > 0, size.height > 0, bounds.width > 0, bounds.height > 0 else {
            imageView.frame = bounds
            return
        }
        let scale = fill
            ? max(bounds.width / size.width, bounds.height / size.height)
            : min(bounds.width / size.width, bounds.height / size.height)
        let width = size.width * scale
        let height = size.height * scale
        imageView.frame = NSRect(x: (bounds.width - width) / 2, y: (bounds.height - height) / 2, width: width, height: height)
    }
}

struct VideoControls: View {
    let playback: VideoPlayback
    let visible: Bool

    var body: some View {
        HStack(spacing: 10) {
            Button { playback.paused.toggle() } label: {
                Icon(playback.paused ? "play.fill" : "pause.fill", size: IconSize.sm)
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .contentShape(Circle())
            }
            .buttonStyle(PressStyle())
            .help(playback.paused ? L.Video.play : L.Video.pause)
            .accessibilityLabel(playback.paused ? L.Video.play : L.Video.pause)

            Scrubber(playback: playback)

            Text(Self.clock(playback.progress * playback.duration))
                .font(Theme.ui(11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.85))
                .frame(minWidth: 34, alignment: .trailing)

            Button { playback.muted.toggle() } label: {
                Icon(playback.muted ? "media.muted" : "media.sound", size: IconSize.sm)
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .contentShape(Circle())
            }
            .buttonStyle(PressStyle())
            .help(playback.muted ? L.Video.unmute : L.Video.mute)
            .accessibilityLabel(playback.muted ? L.Video.unmute : L.Video.mute)
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
        .background(Capsule().fill(.black.opacity(0.42)))
        .background(Capsule().fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
        .padding(12)
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(visible)
        .animation(Theme.hover, value: visible)
    }

    static func clock(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct Scrubber: View {
    let playback: VideoPlayback
    @State private var hovering = false

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.28))
                Capsule().fill(.white).frame(width: width * playback.progress)
            }
            .frame(height: hovering || playback.scrubbing ? 5 : 3)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        playback.scrubbing = true
                        playback.seek(to: value.location.x / width)
                    }
                    .onEnded { value in
                        playback.seek(to: value.location.x / width)
                        playback.scrubbing = false
                    }
            )
            .onHover { hovering = $0 }
            .animation(Theme.hover, value: hovering || playback.scrubbing)
        }
        .frame(height: 30)
        .accessibilityElement()
        .accessibilityLabel(L.Video.position)
        .accessibilityValue(VideoControls.clock(playback.progress * playback.duration))
        .accessibilityAdjustableAction { direction in
            let step = playback.duration > 0 ? 5 / playback.duration : 0.05
            playback.seek(to: playback.progress + (direction == .increment ? step : -step))
        }
    }
}
