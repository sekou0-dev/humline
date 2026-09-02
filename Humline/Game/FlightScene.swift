import SpriteKit

final class FlightScene: SKScene {
    weak var controller: FlightController?

    private let landLayer = SKNode()
    private let corridorFill = SKShapeNode()
    private let corridorStroke = SKShapeNode()
    private let staffLayer = SKNode()
    private let craftNode = SKShapeNode(circleOfRadius: FlightRules.craftRadius)
    private let ghostNode = SKShapeNode(circleOfRadius: FlightRules.craftRadius * 0.85)
    private let targetTick = SKShapeNode(rectOf: CGSize(width: 18, height: 3), cornerRadius: 1)

    private var worldWidth: CGFloat = 1
    private var duration: TimeInterval = 1
    private var lastTime: TimeInterval = 0
    private var playfield = CGRect.zero

    override func didMove(to view: SKView) {
        backgroundColor = HumlineTheme.skySK
        anchorPoint = .zero

        staffLayer.zPosition = 4
        landLayer.zPosition = 0

        if landLayer.parent == nil {
            addChild(staffLayer)
            addChild(landLayer)
            addChild(corridorFill)
            addChild(corridorStroke)
            addChild(ghostNode)
            addChild(craftNode)
            addChild(targetTick)
        }

        corridorFill.strokeColor = .clear
        corridorFill.fillColor = HumlineTheme.corridorSK.withAlphaComponent(0.22)
        corridorFill.zPosition = 2

        corridorStroke.strokeColor = HumlineTheme.corridorSK
        corridorStroke.fillColor = .clear
        corridorStroke.lineWidth = 2
        corridorStroke.zPosition = 3

        craftNode.fillColor = HumlineTheme.craftSK
        craftNode.strokeColor = .white
        craftNode.lineWidth = 1.5
        craftNode.zPosition = 10

        ghostNode.fillColor = HumlineTheme.ghostSK
        ghostNode.strokeColor = .white.withAlphaComponent(0.3)
        ghostNode.lineWidth = 1
        ghostNode.zPosition = 8
        ghostNode.isHidden = true

        targetTick.fillColor = HumlineTheme.corridorSK
        targetTick.strokeColor = .clear
        targetTick.zPosition = 9
    }

    func configure(controller: FlightController) {
        self.controller = controller
    }

    func rebuild(melody: Melody, terrain: TerrainGeometry) {
        duration = max(terrain.duration, 0.01)
        let secondsPerBeat = 60.0 / max(melody.tempo, 1)
        worldWidth = max(size.width * 1.4, FlightRules.pixelsPerBeat * melody.totalBeats * secondsPerBeat / secondsPerBeat)
        worldWidth = max(size.width * 1.5, CGFloat(melody.totalBeats) * FlightRules.pixelsPerBeat)
        playfield = paddedPlayfield()

        drawStaff()
        drawCorridor(terrain)
        resetPlayhead()
    }

    func resetPlayhead() {
        lastTime = 0
        updatePlayhead(time: 0, craftPitch: 0.5, ghostPitch: nil, targetPitch: 0.5)
    }

    func updatePlayhead(time: TimeInterval, craftPitch: Double, ghostPitch: Double?, targetPitch: Double) {
        guard size.width > 1, size.height > 1 else { return }
        playfield = paddedPlayfield()
        let x = xPosition(for: time)
        craftNode.position = CGPoint(x: x, y: yPosition(for: craftPitch))
        targetTick.position = CGPoint(x: x + 28, y: yPosition(for: targetPitch))

        if let ghostPitch {
            ghostNode.isHidden = false
            ghostNode.position = CGPoint(x: x, y: yPosition(for: ghostPitch))
        } else {
            ghostNode.isHidden = true
        }

        let cameraX = x - size.width * FlightRules.craftXFraction
        landLayer.position.x = 0
        let shift = -cameraX
        for node in [staffLayer, landLayer, corridorFill, corridorStroke] {
            node.position.x = shift
        }
        craftNode.position.x = x + shift
        ghostNode.position.x = x + shift
        targetTick.position.x = x + 28 + shift
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard let controller, size.width > 1 else { return }
        rebuild(melody: controller.melody, terrain: controller.terrain)
    }

    override func update(_ currentTime: TimeInterval) {
        if lastTime == 0 {
            lastTime = currentTime
            return
        }
        let dt = currentTime - lastTime
        lastTime = currentTime
        Task { @MainActor in
            controller?.tick(dt: dt)
        }
    }

#if targetEnvironment(simulator)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        applyTouchPitch(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        applyTouchPitch(touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        Task { @MainActor in
            controller?.setManualPitch(nil)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func applyTouchPitch(_ touches: Set<UITouch>) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let normalized = normalizedPitch(forY: location.y)
        Task { @MainActor in
            controller?.setManualPitch(normalized)
        }
    }
#endif

    private func paddedPlayfield() -> CGRect {
        let padY = size.height * 0.14
        let padX: CGFloat = 40
        return CGRect(x: padX, y: padY, width: worldWidth, height: size.height - padY * 2)
    }

    private func xPosition(for time: TimeInterval) -> CGFloat {
        playfield.minX + CGFloat(time / duration) * playfield.width
    }

    private func yPosition(for normalized: Double) -> CGFloat {
        playfield.minY + CGFloat(normalized) * playfield.height
    }

    private func normalizedPitch(forY y: CGFloat) -> Double {
        guard playfield.height > 0 else { return 0.5 }
        return min(1, max(0, Double((y - playfield.minY) / playfield.height)))
    }

    private func drawStaff() {
        staffLayer.removeAllChildren()
        for step in 0...4 {
            let line = SKShapeNode()
            let y = playfield.minY + playfield.height * CGFloat(step) / 4
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: worldWidth + 80, y: y))
            line.path = path
            line.strokeColor = SKColor.white.withAlphaComponent(0.08)
            line.lineWidth = 1
            staffLayer.addChild(line)
        }
    }

    private func drawCorridor(_ terrain: TerrainGeometry) {
        landLayer.removeAllChildren()
        let samples = densify(terrain)
        guard samples.count >= 2 else { return }

        let fill = CGMutablePath()
        let stroke = CGMutablePath()
        let land = CGMutablePath()

        let first = samples[0]
        fill.move(to: CGPoint(x: xPosition(for: first.time), y: yPosition(for: first.center - first.halfWidth)))
        for sample in samples {
            fill.addLine(to: CGPoint(x: xPosition(for: sample.time), y: yPosition(for: sample.center - sample.halfWidth)))
        }
        for sample in samples.reversed() {
            fill.addLine(to: CGPoint(x: xPosition(for: sample.time), y: yPosition(for: sample.center + sample.halfWidth)))
        }
        fill.closeSubpath()

        stroke.move(to: CGPoint(x: xPosition(for: first.time), y: yPosition(for: first.center)))
        for sample in samples.dropFirst() {
            stroke.addLine(to: CGPoint(x: xPosition(for: sample.time), y: yPosition(for: sample.center)))
        }

        land.move(to: CGPoint(x: 0, y: 0))
        land.addLine(to: CGPoint(x: worldWidth + 80, y: 0))
        land.addLine(to: CGPoint(x: worldWidth + 80, y: size.height))
        land.addLine(to: CGPoint(x: 0, y: size.height))
        land.closeSubpath()

        let landFill = SKShapeNode(path: land)
        landFill.fillColor = HumlineTheme.landSK
        landFill.strokeColor = .clear
        landFill.zPosition = 0
        landLayer.addChild(landFill)

        // Cut the corridor out visually by drawing it on top of land.
        corridorFill.path = fill
        corridorStroke.path = stroke
    }

    private func densify(_ terrain: TerrainGeometry) -> [CorridorSample] {
        guard terrain.duration > 0 else { return terrain.samples }
        let step = max(1.0 / 40.0, terrain.duration / 400)
        var time: TimeInterval = 0
        var points: [CorridorSample] = []
        while time <= terrain.duration {
            points.append(terrain.sample(at: time))
            time += step
        }
        if let last = terrain.samples.last {
            points.append(last)
        }
        return points
    }
}
