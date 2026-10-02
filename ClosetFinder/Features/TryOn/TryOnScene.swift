import SceneKit
import UIKit

/// Aspecto del maniquí y de la prenda.
struct TryOnAppearance {
    /// Tono de piel sacado de la foto, o el color de maniquí por defecto.
    var skinColor = UIColor(red: 0.85, green: 0.82, blue: 0.78, alpha: 1)
    /// Cara recortada de la foto (ya fundida con el tono de piel en los bordes).
    var faceTexture: UIImage?
    var garmentPhoto: UIImage?
    var garmentColor: UIColor = .gray
    var isDark = false
}

/// Construye la escena de SceneKit del probador.
enum TryOnSceneBuilder {
    static let garmentNodeName = "garment"
    static let cameraNodeName = "camera"

    static func makeScene(body: BodyShape, shell: GarmentShell?, appearance: TryOnAppearance) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = appearance.isDark
            ? UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
            : UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
        scene.rootNode.addChildNode(makeAvatar(body: body, appearance: appearance))
        if let shell {
            let garment = makeGarment(shell: shell, body: body, appearance: appearance)
            garment.name = garmentNodeName
            scene.rootNode.addChildNode(garment)
        }
        addFloor(to: scene, isDark: appearance.isDark)
        addLights(to: scene)
        addCamera(to: scene, body: body)
        return scene
    }

    // MARK: Maniquí

    private static func makeAvatar(body: BodyShape, appearance: TryOnAppearance) -> SCNNode {
        let avatar = SCNNode()
        let skin = material(color: appearance.skinColor, roughness: 0.65)

        // Torso
        let torsoRings = stride(from: body.yCrotch - 0.01, through: body.yNeckBase, by: 0.01).map {
            Ring(y: $0, shape: body.torsoShape(at: $0))
        }
        avatar.addChildNode(SCNNode(geometry: loft(torsoRings, capBottom: true, materials: [skin])))

        // Cuello
        let neckRadius = 0.034 * body.height
        let neckRings = stride(from: body.yNeckBase - 0.03, through: body.yChin + 0.02, by: 0.01).map {
            Ring(y: $0, shape: .circle(neckRadius))
        }
        avatar.addChildNode(SCNNode(geometry: loft(neckRings, materials: [skin])))

        // Cabeza: elipsoide. Si hay cara, se proyecta de frente sobre la mitad delantera.
        let r = body.headRadius
        let (rx, ry, rz) = (r * 0.82, r * 1.12, r * 0.96)
        let headRings = (0...28).map { i -> Ring in
            let t = Float(i) / 28
            let angle = Float.pi * (t - 0.5)
            let y = body.headCenterY + ry * sin(angle)
            let k = max(cos(angle), 0.001)
            return Ring(y: y, shape: Ellipse(a: rx * k, b: rz * k))
        }
        let head: SCNGeometry
        if let face = appearance.faceTexture {
            let faceMaterial = material(color: appearance.skinColor, image: face, roughness: 0.6)
            let top = body.headCenterY + ry
            head = loft(headRings, materials: [faceMaterial, skin], splitFrontBack: true) { p in
                SIMD2((p.x + rx) / (2 * rx), (top - p.y) / (2 * ry))
            }
        } else {
            head = loft(headRings, materials: [skin])
        }
        avatar.addChildNode(SCNNode(geometry: head))

        // Brazos y manos
        for side: Float in [1, -1] {
            let joint = body.shoulderJoint
            let arm = SCNNode()
            arm.position = SCNVector3(joint.x * side, joint.y, joint.z)
            arm.eulerAngles.z = body.armAngle * side
            let armRings = stride(from: Float(0), through: body.armLength, by: 0.02).map {
                Ring(y: -$0, shape: .circle(body.armRadius(atDistance: $0)))
            }
            arm.addChildNode(SCNNode(geometry: loft(armRings, materials: [skin])))
            let shoulder = SCNNode(geometry: SCNSphere(radius: CGFloat(body.armRadius(atDistance: 0))))
            shoulder.geometry?.firstMaterial = skin
            arm.addChildNode(shoulder)
            let hand = SCNNode(geometry: SCNSphere(radius: CGFloat(0.05 * body.height / 1.75)))
            hand.geometry?.firstMaterial = skin
            hand.scale = SCNVector3(0.6, 1.5, 0.35)
            hand.position = SCNVector3(0, -(body.armLength + 0.06 * body.height / 1.75), 0)
            arm.addChildNode(hand)
            avatar.addChildNode(arm)
        }

        // Piernas y pies
        for side: Float in [1, -1] {
            let legRings = stride(from: body.yAnkle - 0.01, through: body.yCrotch + 0.08, by: 0.015).map {
                Ring(y: $0, shape: .circle(body.legRadius(at: $0)))
            }
            let leg = SCNNode(geometry: loft(legRings, capBottom: true, materials: [skin]))
            leg.position = SCNVector3(body.legOffsetX * side, 0, 0)
            avatar.addChildNode(leg)
            avatar.addChildNode(foot(body: body, side: side, material: skin, scale: 1))
        }
        return avatar
    }

    private static func foot(body: BodyShape, side: Float, material: SCNMaterial, scale: Float) -> SCNNode {
        let width = CGFloat(0.095 * body.height / 1.75 * scale)
        let height = CGFloat(0.06 * scale)
        let length = CGFloat(body.foot * scale)
        let box = SCNBox(width: width, height: height, length: length, chamferRadius: min(width, height) * 0.45)
        box.firstMaterial = material
        let node = SCNNode(geometry: box)
        node.position = SCNVector3(body.legOffsetX * side, Float(height) / 2, body.foot * 0.28)
        return node
    }

    // MARK: Prenda

    private static func makeGarment(shell: GarmentShell, body: BodyShape, appearance: TryOnAppearance) -> SCNNode {
        let node = SCNNode()
        let solid = material(color: appearance.garmentColor, roughness: 0.85)

        if shell.style == .shoes {
            for side: Float in [1, -1] {
                node.addChildNode(foot(body: body, side: side, material: solid, scale: 1.08))
            }
            return node
        }

        let textured: SCNMaterial
        if let photo = appearance.garmentPhoto,
           let texture = garmentTexture(photo, fill: appearance.garmentColor, cropWidth: shell.photoCropWidth) {
            textured = material(color: appearance.garmentColor, image: texture, roughness: 0.85)
        } else {
            textured = solid
        }

        // Proyección de frente: la foto se ve tal cual mirando el maniquí de cara.
        let (minX, maxX, top, hem) = (shell.photoMinX, shell.photoMaxX, shell.yTop, shell.yHem)
        func frontUV(_ p: SIMD3<Float>) -> SIMD2<Float> {
            SIMD2((p.x - minX) / max(maxX - minX, 0.01), (top - p.y) / max(top - hem, 0.01))
        }

        if !shell.shell.isEmpty {
            node.addChildNode(SCNNode(geometry: loft(shell.shell, materials: [textured], uv: frontUV)))
        }
        for tube in shell.tubes {
            let tubeNode = SCNNode()
            tubeNode.position = SCNVector3(tube.origin.x, tube.origin.y, tube.origin.z)
            tubeNode.eulerAngles.z = tube.angle
            let origin = tube.origin
            let geometry = shell.tubesUsePhoto
                ? loft(tube.rings, materials: [textured]) { frontUV($0 + origin) }
                : loft(tube.rings, materials: [solid])
            tubeNode.geometry = geometry
            node.addChildNode(tubeNode)
        }
        return node
    }

    /// Recorta la parte central de la foto y rellena lo transparente con el color de la prenda,
    /// para que no queden huecos donde la silueta de la foto no llega.
    static func garmentTexture(_ photo: UIImage, fill: UIColor, cropWidth: Float) -> UIImage? {
        guard let cgImage = photo.cgImage else { return nil }
        let width = CGFloat(cgImage.width), height = CGFloat(cgImage.height)
        let cropW = width * CGFloat(cropWidth)
        let crop = CGRect(x: (width - cropW) / 2, y: 0, width: cropW, height: height).integral
        guard let cropped = cgImage.cropping(to: crop) else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: crop.size, format: format).image { context in
            fill.setFill()
            context.fill(CGRect(origin: .zero, size: crop.size))
            UIImage(cgImage: cropped).draw(in: CGRect(origin: .zero, size: crop.size))
        }
    }

    // MARK: Entorno

    private static func addFloor(to scene: SCNScene, isDark: Bool) {
        let floor = SCNFloor()
        floor.reflectivity = 0
        let floorMaterial = SCNMaterial()
        floorMaterial.diffuse.contents = scene.background.contents
        floorMaterial.lightingModel = .constant
        floor.firstMaterial = floorMaterial
        let node = SCNNode(geometry: floor)
        node.castsShadow = false
        scene.rootNode.addChildNode(node)

        // Sombra suave bajo los pies.
        let shadow = SCNNode(geometry: SCNPlane(width: 0.9, height: 0.7))
        let shadowMaterial = SCNMaterial()
        shadowMaterial.diffuse.contents = radialShadow(isDark: isDark)
        shadowMaterial.lightingModel = .constant
        shadowMaterial.writesToDepthBuffer = false
        shadow.geometry?.firstMaterial = shadowMaterial
        shadow.eulerAngles.x = -.pi / 2
        shadow.position = SCNVector3(0, 0.002, 0.04)
        scene.rootNode.addChildNode(shadow)
    }

    private static func radialShadow(isDark: Bool) -> UIImage {
        let size = CGSize(width: 256, height: 256)
        return UIGraphicsImageRenderer(size: size).image { context in
            let colors = [UIColor.black.withAlphaComponent(isDark ? 0.5 : 0.22).cgColor, UIColor.black.withAlphaComponent(0).cgColor]
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            context.cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: size.width / 2, options: [])
        }
    }

    private static func addLights(to scene: SCNScene) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 420
        ambient.light?.color = UIColor(white: 1, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 1100
        key.eulerAngles = SCNVector3(-0.6, 0.5, 0)
        scene.rootNode.addChildNode(key)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .directional
        fill.light?.intensity = 450
        fill.eulerAngles = SCNVector3(-0.2, -0.9, 0)
        scene.rootNode.addChildNode(fill)

        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .directional
        rim.light?.intensity = 500
        rim.eulerAngles = SCNVector3(-0.3, .pi, 0)
        scene.rootNode.addChildNode(rim)
    }

    private static func addCamera(to scene: SCNScene, body: BodyShape) {
        let camera = SCNNode()
        camera.name = cameraNodeName
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 30
        camera.camera?.zNear = 0.05
        // Encuadre de cuerpo entero dejando sitio abajo para el panel: con 30° de campo vertical,
        // a 2,7 alturas de distancia se ven unas 1,45 alturas.
        let centerY = body.height * 0.34
        camera.position = SCNVector3(0, centerY, body.height * 2.7)
        camera.look(at: SCNVector3(0, centerY, 0))
        scene.rootNode.addChildNode(camera)
    }

    static func material(color: UIColor, image: UIImage? = nil, roughness: CGFloat) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = image ?? color
        material.roughness.contents = roughness
        material.metalness.contents = 0.0
        material.isDoubleSided = true
        return material
    }

    // MARK: Mallas

    /// Superficie que une una serie de secciones elípticas horizontales (de abajo arriba).
    /// - `uv`: coordenadas de textura a partir de la posición (local) de cada vértice.
    /// - `splitFrontBack`: usa `materials[0]` para la mitad delantera y `materials[1]` para la trasera.
    static func loft(_ rings: [Ring], segments: Int = 48, capBottom: Bool = false, materials: [SCNMaterial],
                     splitFrontBack: Bool = false, uv: ((SIMD3<Float>) -> SIMD2<Float>)? = nil) -> SCNGeometry {
        let mesh = LoftMesh(rings: rings, segments: segments, capBottom: capBottom)
        let coordinates = mesh.positions.enumerated().map { index, p -> CGPoint in
            let value = uv?(p) ?? mesh.defaultUV[index]
            return CGPoint(x: CGFloat(value.x), y: CGFloat(value.y))
        }
        let sources = [
            SCNGeometrySource(vertices: mesh.positions.map { SCNVector3($0.x, $0.y, $0.z) }),
            SCNGeometrySource(normals: mesh.normals.map { SCNVector3($0.x, $0.y, $0.z) }),
            SCNGeometrySource(textureCoordinates: coordinates),
        ]

        let elements: [SCNGeometryElement]
        if splitFrontBack {
            let (front, back) = mesh.splitIndicesFrontBack()
            elements = [SCNGeometryElement(indices: front, primitiveType: .triangles),
                        SCNGeometryElement(indices: back, primitiveType: .triangles)]
        } else {
            elements = [SCNGeometryElement(indices: mesh.indices, primitiveType: .triangles)]
        }
        let geometry = SCNGeometry(sources: sources, elements: elements)
        geometry.materials = materials
        return geometry
    }
}

/// Malla de un «loft» (secciones unidas) calculada sin SceneKit, para poder probarla.
nonisolated struct LoftMesh: Sendable {
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var defaultUV: [SIMD2<Float>] = []
    var indices: [UInt32] = []

    init(rings: [Ring], segments: Int, capBottom: Bool = false) {
        guard rings.count >= 2, segments >= 3 else { return }
        let columns = segments + 1 // el primer vértice se repite al final para cerrar la textura
        let yMin = rings.first!.y, yMax = rings.last!.y
        for ring in rings {
            for i in 0..<columns {
                // Empieza por detrás (-z) para que la costura de la textura quede en la espalda.
                let theta = -Float.pi / 2 + 2 * Float.pi * Float(i) / Float(segments)
                positions.append(SIMD3(ring.shape.a * cos(theta), ring.y, ring.shape.b * sin(theta)))
                defaultUV.append(SIMD2(Float(i) / Float(segments), (yMax - ring.y) / max(yMax - yMin, 0.0001)))
            }
        }
        for j in 0..<(rings.count - 1) {
            for i in 0..<segments {
                let a = UInt32(j * columns + i), b = UInt32((j + 1) * columns + i)
                indices += [a, b, a + 1, a + 1, b, b + 1]
            }
        }
        if capBottom {
            let center = UInt32(positions.count)
            positions.append(SIMD3(0, rings[0].y, 0))
            defaultUV.append(SIMD2(0.5, 1))
            for i in 0..<segments {
                indices += [center, UInt32(i + 1), UInt32(i)]
            }
        }
        computeNormals(columns: columns, ringCount: rings.count)
    }

    private mutating func computeNormals(columns: Int, ringCount: Int) {
        var accumulated = [SIMD3<Float>](repeating: .zero, count: positions.count)
        for t in stride(from: 0, to: indices.count, by: 3) {
            let (i0, i1, i2) = (Int(indices[t]), Int(indices[t + 1]), Int(indices[t + 2]))
            let n = simd_cross(positions[i1] - positions[i0], positions[i2] - positions[i0])
            accumulated[i0] += n
            accumulated[i1] += n
            accumulated[i2] += n
        }
        // Une las normales de la costura (primer y último vértice de cada anillo).
        for j in 0..<ringCount {
            let first = j * columns, last = j * columns + columns - 1
            let sum = accumulated[first] + accumulated[last]
            accumulated[first] = sum
            accumulated[last] = sum
        }
        normals = accumulated.map { simd_length($0) > 0 ? simd_normalize($0) : SIMD3(0, 1, 0) }
        // Que apunten hacia fuera: se comprueba en un vértice del anillo central.
        let probe = (ringCount / 2) * columns + columns / 4
        if probe < positions.count {
            let radial = SIMD3(positions[probe].x, 0, positions[probe].z)
            if simd_dot(normals[probe], radial) < 0 { normals = normals.map { -$0 } }
        }
    }

    /// Triángulos de la mitad delantera (z ≥ 0) y de la trasera.
    func splitIndicesFrontBack() -> (front: [UInt32], back: [UInt32]) {
        var front: [UInt32] = [], back: [UInt32] = []
        for t in stride(from: 0, to: indices.count, by: 3) {
            let triangle = indices[t..<(t + 3)]
            let z = triangle.reduce(Float(0)) { $0 + positions[Int($1)].z }
            if z >= 0 { front += triangle } else { back += triangle }
        }
        return (front, back)
    }
}
