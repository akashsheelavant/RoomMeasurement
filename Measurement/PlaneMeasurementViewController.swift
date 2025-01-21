//
//  PlaneMeasurementViewController.swift
//  Measurement
//
//  Created by Akash Sheelavant on 12/16/24.
//

import UIKit
import ARKit
import SceneKit

class PlaneMeasurementViewController: UIViewController, ARSCNViewDelegate {
    
    var referenceImageNode: SCNNode?
    var startingNode: SCNNode?
    var planeNode: SCNNode?
    
    private var currentPlaneWidth: CGFloat = 0.0
    private var planeHeight: CGFloat = 0.0
    private var isMeasuringComplete = false
    
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var finishButton: UIButton!
    
    let messageLabel = UILabel()
    
    let textView = UITextView()
    var widths: [CGFloat] = []
    var wallWidth = 0.0
    var area = 0.0
    
    private var currentState = CurrentState.loading {
        didSet {
            showMessage(currentState.description)
        }
    }
    
    enum CurrentState: String {
        case loading
        case loaded
        case firstCornerAdded
        case secondCornerAdded
        
        var description: String {
            switch self {
            case .loading:
                return "Aim the camera on a floor!"
            case .loaded:
                return "Target the corner of the room and mark the first node"
            case .firstCornerAdded:
                return "Great job! Keep marking the corners of the room"
            case .secondCornerAdded:
                return ""
            }
        }
    }
    
    func wallHeight(height: CGFloat) {
        planeHeight = height
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateUI()
        currentState = .loading
        sceneView.delegate = self
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        sceneView.session.run(configuration)
        
        placeReferenceImageOnGroundExtremeBottom()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.session.pause()
    }
    
    @IBAction func startButtonPressed(_ sender: Any) {
        startButton.isHidden = true
        addButton.isHidden = false
        finishButton.isHidden = false
        
        markCorner()
        addPlaneNode()
        currentState = .firstCornerAdded
    }
    
    
    @IBAction func addButtonPressed(_ sender: Any) {
        widths.append(currentPlaneWidth)
        if !isMeasuringComplete {
            markCorner()
            textUpdate()
            addPlaneNode()
        }
        currentState = .secondCornerAdded
    }
    
    @IBAction func finishButtonPressed(_ sender: Any) {
        isMeasuringComplete = true
        referenceImageNode?.isHidden = true
        
        widths.append(currentPlaneWidth)
        textUpdate()
    }
    
    func createTextView() {
        
        // Configure the textView properties
        
        textView.font = UIFont.systemFont(ofSize: 12)
        textView.textColor = UIColor.white
        textView.textAlignment = .left
        textView.backgroundColor = UIColor(red: 144/255.0, green: 184/255.0, blue: 96/255.0, alpha: 1)
        textView.isEditable = false
        
        // Add the textView to the view hierarchy
        view.addSubview(textView)
        
        // Enable Auto Layout for the textView
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            textView.widthAnchor.constraint(equalToConstant: 130),       // Fixed width
            textView.heightAnchor.constraint(equalToConstant: 100),      // Fixed height
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), // Align to left edge with padding
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -65)
        ])
    }
    
    func textUpdate() {
        for i in 0..<widths.count {
            let height = String(format: "%.1f", planeHeight)
            if i == 0 {
                createTextView()
                let wid = String(format: "%.1f", widths[i])
                textView.text = "Wall\(i+1): \(height) m X \(wid) m"
                area = planeHeight * Double(widths[i])
            }
            else {
                area += planeHeight * Double(widths[i])
                
                let wid = String(format: "%.1f", widths[i])
                textView.text += "\nWall\(i+1): \(height) m X \(wid) m"
            }
        }
        
        if isMeasuringComplete {
            let areaVal = String(format: "%.2f", area )
            textView.text += "\nArea: \(areaVal) sq. mtrs."
        }
    }
    
    private func addMeasurements() {
        if let planeNode {
            let width = String(format: "%.1f m", currentPlaneWidth)
            let height = String(format: "%.1f m", planeHeight)
            placeMeasurementText("\(width) x \(height)", at: SCNVector3(0, 0, 0), in: planeNode)
        }
    }
    
    private func updateUI() {
        messageLabel.frame = CGRect(x: 20, y: 100, width: 300, height: 70)
        messageLabel.center.x = view.center.x
        
        messageLabel.font = .systemFont(ofSize: 14)
        
        messageLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        messageLabel.textColor = .white
        messageLabel.textAlignment = .center
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.numberOfLines = 0
        
        messageLabel.layer.cornerRadius = 20.0
        messageLabel.clipsToBounds = true
        
        view.addSubview(messageLabel)
    }
    
    func showMessage(_ message: String) {
        DispatchQueue.main.async {
            self.messageLabel.isHidden = message.isEmpty
            self.messageLabel.text = message
        }
    }
    
    func placeReferenceImageOnGroundExtremeBottom() {
        let screenCenter = CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY)
        
        // Perform a raycast from the center of the screen
        guard let query = sceneView.raycastQuery(from: screenCenter, allowing: .existingPlaneInfinite, alignment: .horizontal) else { return }
        
        let results = sceneView.session.raycast(query)
        if let result = results.last {
            placeReferenceImage(at: result.worldTransform)
            currentState = .loaded
        } else {
            print("No valid surface detected to place the image.")
        }
    }
    
    // MARK: - Place the reference image on the detected ground point
    func placeReferenceImage(at transform: simd_float4x4) {
        guard let image = UIImage(named: "target") else { return }
        
        let planeGeometry = SCNPlane(width: 0.12, height: 0.12)
        planeGeometry.firstMaterial?.diffuse.contents = image
        
        let node = SCNNode(geometry: planeGeometry)
        
        let position = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
        
        node.position = SCNVector3(position.x, position.y - 0.1, position.z)
        node.eulerAngles.x = -.pi / 2
        
        sceneView.scene.rootNode.addChildNode(node)
        referenceImageNode = node
    }
    
    func placeReferenceImage(position: SCNVector3) {
        guard let image = UIImage(named: "target") else { return }
        
        let planeGeometry = SCNPlane(width: 0.12, height: 0.12)
        planeGeometry.firstMaterial?.diffuse.contents = image
        
        let node = SCNNode(geometry: planeGeometry)
        
        node.position = SCNVector3(position.x, position.y, position.z)
        node.eulerAngles.x = -.pi / 2
        
        sceneView.scene.rootNode.addChildNode(node)
        referenceImageNode = node
    }
    
    private func markCorner() {
        guard let position = referenceImageNode?.position else { return }
        
        let sphereNode = createMarker(at: position)
        startingNode = sphereNode
        sceneView.scene.rootNode.addChildNode(sphereNode)
        
        let lineNode = createLine(at: position, height: planeHeight)
        sceneView.scene.rootNode.addChildNode(lineNode)
    }
    
    func createMarker(at position: SCNVector3) -> SCNNode {
        let sphere = SCNSphere(radius: 0.02)
        let node = SCNNode(geometry: sphere)
        node.position = position
        node.geometry?.firstMaterial?.diffuse.contents = UIColor.white
        return node
    }
    
    func createLine(at position: SCNVector3, height: CGFloat) -> SCNNode {
        let verticalLine = SCNCylinder(radius: 0.005, height: height)
        verticalLine.firstMaterial?.diffuse.contents = UIColor.white
        let midpoint = SCNVector3(position.x, position.y + Float(height/2) , position.z)
        
        let lineNode = SCNNode(geometry: verticalLine)
        
        lineNode.position = midpoint
        
        return lineNode
    }
    
    func addPlaneNode() {
        let plane = SCNPlane(width: 0, height: 0)
        plane.firstMaterial?.diffuse.contents = UIColor.white
        plane.firstMaterial?.isDoubleSided = true
        
        planeNode = SCNNode(geometry: plane)
        if let planeNode {
            sceneView.scene.rootNode.addChildNode(planeNode)
        }
    }
    
    func drawPlane(from start: SCNVector3, to end: SCNVector3) {
        if let planeNode {
            //            let direction = end - start
            //            let distance = CGFloat((start - end).length())
            
            
            let direction = end - start
            let distance = CGFloat(direction.length())
            
            
            //let distance = CGFloat(abs(end.x - start.x))
            currentPlaneWidth = distance
            
            var plane = planeNode.geometry
            plane = SCNPlane(width: distance, height: planeHeight)
            plane?.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.8)
            
            plane?.firstMaterial?.isDoubleSided = true
            planeNode.geometry = plane
            
            //            planeNode.position = SCNVector3(start.x,
            //                                            start.y + Float(planeHeight / 2),
            //                                            start.z)
            
            
            planeNode.position = SCNVector3(start.x,
                                            start.y + Float(planeHeight / 2),
                                            start.z)
            
            planeNode.pivot = SCNMatrix4MakeTranslation(-Float(distance) / 2, 0, 0)
            
            //            let angleY = atan2(end.z - start.z, end.x - start.x)
            //            planeNode.eulerAngles.y = -angleY
            
            let angle = atan2(direction.z, direction.x)
            planeNode.eulerAngles = SCNVector3(0, -angle, 0)
        }
    }
    
    
    func placeMeasurementText(_ text: String, at position: SCNVector3, in node: SCNNode) {
        let textGeometry = SCNText(string: text, extrusionDepth: 0.01)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.black
        
        let textNode = SCNNode(geometry: textGeometry)
        textNode.position = position
        textNode.scale = SCNVector3(0.005, 0.005, 0.005) // Scale down the text
        
        // Adjust so it's visible
        //textNode.eulerAngles.x = -.pi / 2
        //textNode.eulerAngles.x = -.pi
        node.addChildNode(textNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !isMeasuringComplete else { return }
            // <<<< this is changed
            let screenCenter = CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY)
            
            if let rayCastResult = self.performRaycast(at: screenCenter) {
                let worldPoint = rayCastResult.worldTransform.columns.3
                let worldPosition = SCNVector3(x: worldPoint.x, y: worldPoint.y, z: worldPoint.z)
                self.referenceImageNode?.isHidden = false
                if let referenceImageNode = self.referenceImageNode {
                    referenceImageNode.position = worldPosition
                    
                    if let startingNode = self.startingNode, let endNode = self.referenceImageNode {
                        drawPlane(from: startingNode.position, to: endNode.position)
                    }
                } else {
                    self.placeReferenceImageOnGroundExtremeBottom()
                }
                
            }
        }
    }
    
    func performRaycast(at location: CGPoint) -> ARRaycastResult? {
        guard let raycastQuery = sceneView.raycastQuery(from: location, allowing: .existingPlaneInfinite, alignment: .horizontal) else {
            return nil
        }
        
        let results = sceneView.session.raycast(raycastQuery)
        return results.first
    }
}

extension SCNVector3 {
    static func -(left: SCNVector3, right: SCNVector3) -> SCNVector3 {
        return SCNVector3(left.x - right.x, left.y - right.y, left.z - right.z)
    }
    
    func length() -> Float {
        return sqrtf(x * x + y * y + z * z)
    }
}
