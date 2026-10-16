import AppKit
import SpriteKit

final class OnboardingScene: SKScene, SKPhysicsContactDelegate {
    private var tiles: [SKSpriteNode] = []
    private var floor: SKNode?
    private let reduceMotion: Bool

    init(size: CGSize, reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .resizeFill
        physicsWorld.gravity = CGVector(dx: 0, dy: -8)
        physicsWorld.contactDelegate = self
    }

    required init?(coder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        view.allowsTransparency = true
        let walls = SKNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: size.height * 4))
        path.addLine(to: .zero)
        path.addLine(to: CGPoint(x: size.width, y: 0))
        path.addLine(to: CGPoint(x: size.width, y: size.height * 4))
        walls.physicsBody = SKPhysicsBody(edgeChainFrom: path)
        walls.physicsBody?.friction = 0.7
        addChild(walls)
        floor = walls
    }

    func tileCount(fill: CGFloat) -> Int {
        Int(min(48, max(12, size.width * size.height * fill / 19_000)))
    }

    func rain(_ images: [CGImage], count: Int, interval: Double = 0.07) {
        guard !images.isEmpty else { return }
        let pool = images.shuffled()
        if reduceMotion {
            for index in 0..<count { placeStill(pool[index % pool.count]) }
            return
        }
        var index = 0
        let spawn = SKAction.run { [weak self] in
            guard let self else { return }
            self.drop(pool[index % pool.count])
            index += 1
        }
        let wait = SKAction.wait(forDuration: interval, withRange: interval * 0.8)
        run(.repeat(.sequence([spawn, wait]), count: count))
    }

    private func makeTile(_ image: CGImage) -> SKSpriteNode {
        let width = CGFloat.random(in: 104...190)
        let natural = CGFloat(image.width) / CGFloat(max(image.height, 1))
        let aspect = image.width == image.height ? [0.75, 0.8, 1.0, 1.25, 1.33].randomElement()! : min(1.6, max(0.62, natural))
        let size = CGSize(width: width, height: (width / aspect).rounded())
        let node = SKSpriteNode(texture: TileArt.texture(image, size: size))
        node.size = CGSize(width: size.width + TileArt.margin * 2, height: size.height + TileArt.margin * 2)
        node.userData = ["w": size.width, "h": size.height]
        let body = SKPhysicsBody(rectangleOf: size)
        body.restitution = 0.16
        body.friction = 0.6
        body.density = 1
        body.angularDamping = 0.5
        body.linearDamping = 0.1
        body.categoryBitMask = 1
        body.contactTestBitMask = 1
        node.physicsBody = body
        return node
    }

    private func drop(_ image: CGImage) {
        let node = makeTile(image)
        let width = node.size.width
        node.position = CGPoint(x: .random(in: width...(size.width - width)), y: size.height + node.size.height)
        node.zRotation = .random(in: -0.6...0.6)
        node.physicsBody?.angularVelocity = .random(in: -3...3)
        node.physicsBody?.velocity = CGVector(dx: .random(in: -60...60), dy: .random(in: -260 ... -80))
        addChild(node)
        tiles.append(node)
    }

    private func placeStill(_ image: CGImage) {
        let node = makeTile(image)
        node.physicsBody = nil
        node.position = CGPoint(x: .random(in: 0...size.width), y: .random(in: 0...(size.height * 0.32)))
        node.zRotation = .random(in: -0.35...0.35)
        node.alpha = 0
        addChild(node)
        tiles.append(node)
        node.run(.fadeIn(withDuration: 0.45))
    }

    func drain(completion: @escaping @MainActor () -> Void) {
        removeAllActions()
        SoundEngine.shared.play(.whoosh, volume: 0.8)
        guard !reduceMotion else {
            tiles.forEach { $0.run(.fadeOut(withDuration: 0.3)) }
            run(.wait(forDuration: 0.35)) { MainActor.assumeIsolated { completion() } }
            return
        }
        floor?.removeFromParent()
        for (index, node) in tiles.enumerated() {
            node.physicsBody?.contactTestBitMask = 0
            node.physicsBody?.applyImpulse(CGVector(dx: .random(in: -40...40), dy: .random(in: 60...180)))
            node.physicsBody?.applyAngularImpulse(.random(in: -0.5...0.5))
            node.run(.sequence([.wait(forDuration: 0.45 + Double(index % 7) * 0.02), .fadeOut(withDuration: 0.45)]))
        }
        physicsWorld.gravity = CGVector(dx: 0, dy: -16)
        run(.wait(forDuration: 1.05)) { MainActor.assumeIsolated { completion() } }
    }

    override func mouseDown(with event: NSEvent) {
        let point = event.location(in: self)
        guard let node = nodes(at: point).first(where: { $0.physicsBody != nil && $0 is SKSpriteNode }) else { return }
        node.physicsBody?.applyImpulse(CGVector(dx: .random(in: -80...80), dy: .random(in: 320...520)))
        node.physicsBody?.applyAngularImpulse(.random(in: -0.9...0.9))
        SoundEngine.shared.tap(intensity: 0.8, size: 0.5)
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let impulse = contact.collisionImpulse
        guard impulse > 30 else { return }
        let width = contact.bodyA.node?.frame.width ?? 100
        SoundEngine.shared.tap(intensity: Double(min(1, impulse / 460)), size: Double(width / 200))
    }
}

enum TileArt {
    static let margin: CGFloat = 20
    static let radius: CGFloat = 10

    static func texture(_ image: CGImage, size: CGSize) -> SKTexture {
        let picture = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        return SKTexture(image: render(size: size) { rect in
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
            let scale = max(rect.width / picture.size.width, rect.height / picture.size.height)
            let drawn = NSSize(width: picture.size.width * scale, height: picture.size.height * scale)
            picture.draw(in: NSRect(x: rect.midX - drawn.width / 2, y: rect.midY - drawn.height / 2,
                                    width: drawn.width, height: drawn.height))
            NSGraphicsContext.restoreGraphicsState()
            NSColor(white: 1, alpha: 0.18).setStroke()
            let rim = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: radius, yRadius: radius)
            rim.lineWidth = 1
            rim.stroke()
        })
    }

    @concurrent
    static func load(_ urls: [URL], maxPixel: Int) async -> [CGImage] {
        urls.compactMap { ImageFiles.downsample($0, maxPixel: maxPixel) }
    }

    static var wallpaperThumbnails: [URL] {
        let folder = URL(filePath: "/System/Library/Desktop Pictures/.thumbnails", directoryHint: .isDirectory)
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { ImageFiles.isImage($0) && !$0.lastPathComponent.contains("Dark") }.shuffled()
    }

    private static func render(size: CGSize, draw: (NSRect) -> Void) -> NSImage {
        let canvas = NSSize(width: size.width + margin * 2, height: size.height + margin * 2)
        let scale: CGFloat = 2
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(canvas.width * scale), pixelsHigh: Int(canvas.height * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: rep) else { return NSImage(size: canvas) }
        rep.size = canvas
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let rect = NSRect(x: margin, y: margin, width: size.width, height: size.height)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(white: 0, alpha: 0.28)
        shadow.shadowBlurRadius = 16
        shadow.shadowOffset = NSSize(width: 0, height: -7)
        shadow.set()
        NSColor(white: 0.85, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
        NSGraphicsContext.restoreGraphicsState()
        draw(rect)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: canvas)
        image.addRepresentation(rep)
        return image
    }
}
