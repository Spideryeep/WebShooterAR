import SwiftUI
import RealityKit
import ARKit
import Vision

struct ContentView: View {
    var body: some View {
        ZStack(alignment: .top) {
            WebShooterView().ignoresSafeArea()
            VStack {
                HStack {
                    Text("🕷 WEB SHOOTER AR").font(.system(size: 14, weight: .black)).tracking(1.5)
                    Spacer()
                    Text("REAL-WORLD AR").font(.caption2.bold())
                }.padding()
                Spacer()
                Text("Aim at a wall and make the Spider-Man hand sign to attach a web. Tap Clear webs to remove them.")
                    .font(.footnote).multilineTextAlignment(.center)
                    .padding().background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
                    .padding()
            }.allowsHitTesting(false)
        }
    }
}

struct WebShooterView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        context.coordinator.arView = view
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.vertical, .horizontal]
        config.environmentTexturing = .automatic
        view.session.run(config)
        view.session.delegate = context.coordinator
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.addClearButton(to: view)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    final class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?
        private var anchors: [AnchorEntity] = []
        private let visionQueue = DispatchQueue(label: "webshooter.vision")
        private var lastVision = Date.distantPast
        private var lastShot = Date.distantPast
        private var gestureActive = false

        func addClearButton(to view: ARView) {
            let button = UIButton(type: .system)
            button.setTitle("Clear webs", for: .normal)
            button.tintColor = .white
            button.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            button.layer.cornerRadius = 18
            button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
            button.addTarget(self, action: #selector(clearWebs), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(button)
            NSLayoutConstraint.activate([
                button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
                button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80)
            ])
        }

        @objc func clearWebs() {
            guard let view = arView else { return }
            anchors.forEach { view.scene.removeAnchor($0) }
            anchors.removeAll()
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = arView else { return }
            placeWeb(at: gesture.location(in: view))
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            let now = Date()
            guard now.timeIntervalSince(lastVision) > 0.15 else { return }
            lastVision = now
            let buffer = frame.capturedImage
            visionQueue.async { [weak self] in
                guard let self else { return }
                let request = VNDetectHumanHandPoseRequest()
                request.maximumHandCount = 1
                do {
                    try VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .right).perform([request])
                    let active = request.results?.first.map(self.isWebGesture) ?? false
                    DispatchQueue.main.async {
                        if active && !self.gestureActive && Date().timeIntervalSince(self.lastShot) > 0.7,
                           let view = self.arView {
                            self.lastShot = Date()
                            self.placeWeb(at: CGPoint(x: view.bounds.midX, y: view.bounds.midY))
                        }
                        self.gestureActive = active
                    }
                } catch { }
            }
        }

        private func isWebGesture(_ hand: VNHumanHandPoseObservation) -> Bool {
            guard let points = try? hand.recognizedPoints(.all) else { return false }
            func y(_ joint: VNHumanHandPoseObservation.JointName) -> CGFloat? {
                guard let p = points[joint], p.confidence > 0.35 else { return nil }
                return p.location.y
            }
            guard let iT = y(.indexTip), let iP = y(.indexPIP),
                  let mT = y(.middleTip), let mP = y(.middlePIP),
                  let rT = y(.ringTip), let rP = y(.ringPIP),
                  let pT = y(.littleTip), let pP = y(.littlePIP) else { return false }
            return iT > iP + 0.03 && pT > pP + 0.03 && mT < mP + 0.02 && rT < rP + 0.02
        }

        private func placeWeb(at point: CGPoint) {
            guard let view = arView else { return }
            let hit = view.raycast(from: point, allowing: .existingPlaneGeometry, alignment: .vertical).first
                ?? view.raycast(from: point, allowing: .estimatedPlane, alignment: .vertical).first
            guard let hit else { return }
            let anchor = AnchorEntity(world: hit.worldTransform)
            let strand = ModelEntity(
                mesh: .generateCylinder(height: 0.45, radius: 0.004),
                materials: [SimpleMaterial(color: .white, roughness: 0.25, isMetallic: false)]
            )
            strand.position = [0, 0, 0.225]
            strand.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            let tip = ModelEntity(mesh: .generateSphere(radius: 0.018),
                                  materials: [SimpleMaterial(color: .white, isMetallic: false)])
            tip.position = [0, 0, 0.45]
            strand.addChild(tip)
            anchor.addChild(strand)
            view.scene.addAnchor(anchor)
            anchors.append(anchor)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}
