//
//  TestViewController.swift
//  Measurement
//
//  Created by Akash Sheelavant on 12/13/24.
//

import UIKit
import ARKit
import SceneKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    
    var referenceImageNode: SCNNode?
    var startingNode: SCNNode?
    var verticalLineNode: SCNNode?
    var textNode: SCNNode?
    var isMeasurementFrozen = false
    var measurement = ""
    let messageLabel = UILabel()
    let startButton = UIButton(type: .system)
    let endButton = UIButton(type: .system)
    var distance = 0.0
    @IBOutlet weak var bottomButton: UIButton!
    
    @IBAction func buttonPressed(_ sender: Any) {
    }
    
    
    private var isGroundDetected = false
    private var isReferenceFound = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        sceneView.session.run(configuration)
        createLabel()
        createStartButton()
        createEndButton()
        hidestartButton()
        endButton.isHidden = true
        updateUI()
        
        self.navigationController?.isNavigationBarHidden = true
         
    }
    
    override func viewWillAppear(_ animated: Bool) {
        //showMessage("Move your camera to the wall's corner where it meets the floor to measure the height.")
        showMessage("Aim at the junction of the floor and the wall")
    }
    
    
    func showMessage(_ message: String) {
            DispatchQueue.main.async {
                self.messageLabel.text = message
            }
        }
    
    func createLabel() {
        self.messageLabel.frame = CGRect(x: 20, y: 100, width: 300, height: 90)
        self.messageLabel.center.x = view.center.x
        self.messageLabel.numberOfLines = 0
        self.messageLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        self.messageLabel.textColor = .white
        self.messageLabel.textAlignment = .center
                
        self.messageLabel.layer.cornerRadius = 20.0
        self.messageLabel.clipsToBounds = true
                
        view.addSubview(self.messageLabel)
    }
    
    @IBAction func endClicked(_ sender: UIButton) {
        isMeasurementFrozen = true
           verticalLineNode?.geometry?.firstMaterial?.diffuse.contents = UIColor.red
           textNode?.geometry?.firstMaterial?.diffuse.contents = UIColor.green
        endButton.isEnabled = false
        endButton.backgroundColor = UIColor.gray
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let viewcontroller = storyboard.instantiateViewController(withIdentifier: "PlaneMeasurementViewController") as? PlaneMeasurementViewController {
            viewcontroller.wallHeight(height: distance)
            navigationController?.pushViewController(viewcontroller, animated: true)
        }
        
    }
    
    func createStartButton() {
      
        startButton.setTitle("Start Measurement", for: .normal)
        startButton.setTitleColor(.white, for: .normal)
        startButton.backgroundColor = UIColor.systemBlue
        startButton.layer.cornerRadius = 10
        startButton.clipsToBounds = true
        startButton.addTarget(self, action: #selector(startClicked), for: .touchUpInside)
           
        startButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(startButton)
        NSLayoutConstraint.activate([
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            startButton.widthAnchor.constraint(equalToConstant: 200),
            startButton.heightAnchor.constraint(equalToConstant: 50)
           ])
    }
    
    func createEndButton() {
      
        endButton.setTitle("End Measurement", for: .normal)
        endButton.setTitleColor(.white, for: .normal)
        endButton.backgroundColor = UIColor.systemBlue
        endButton.layer.cornerRadius = 10
        endButton.clipsToBounds = true
        endButton.addTarget(self, action: #selector(endClicked), for: .touchUpInside)
           
        endButton.translatesAutoresizingMaskIntoConstraints = false
           
        view.addSubview(endButton)
          NSLayoutConstraint.activate([
            endButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            endButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            endButton.widthAnchor.constraint(equalToConstant: 200),
            endButton.heightAnchor.constraint(equalToConstant: 50)
           ])
    }
    
    @IBAction func startClicked(_ sender: UIButton) {
        guard let position = rayCasting(at: sceneView.center) else { return }
        isReferenceFound = true
        let sphereNode = createMarker(at: position)
        startingNode = sphereNode
        sceneView.scene.rootNode.addChildNode(sphereNode)
        hidestartButton()
        endButton.isHidden = false
    }
    // MARK: - Perform a raycast to find the farthest intersection on the ground
    func placeReferenceImageOnGroundExtremeBottom() {
        let screenCenter = CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY)
        
        // Perform a raycast from the center of the screen
        guard let query = sceneView.raycastQuery(from: screenCenter, allowing: .estimatedPlane, alignment: .any) else { return }
        
        let results = sceneView.session.raycast(query)
        if let result = results.last {
            isGroundDetected = true
            messageLabel.isHidden = true
            
            showstartButton()
            placeReferenceImage(at: result.worldTransform)
        } else {
            isGroundDetected = false
            messageLabel.isHidden = false
            hidestartButton()
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
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
        
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//        guard let position = rayCasting(at: sceneView.center) else { return }
//        isReferenceFound = true
//                
//        
//        let sphereNode = createMarker(at: position)
//        startingNode = sphereNode
//        sceneView.scene.rootNode.addChildNode(sphereNode)
    }
        
    func createMarker(at position: SCNVector3) -> SCNNode {
        let sphere = SCNSphere(radius: 0.02)
        let node = SCNNode(geometry: sphere)
        node.position = position
        node.geometry?.firstMaterial?.diffuse.contents = UIColor.white
        return node
    }
            
    func nodeWithPosition(_ position: SCNVector3) -> SCNNode {
        let sphere = SCNSphere(radius: 0.01)
        sphere.firstMaterial?.diffuse.contents = UIColor.white
                
        sphere.firstMaterial?.lightingModel = .constant
        sphere.firstMaterial?.isDoubleSided = true
        
        let node = SCNNode(geometry: sphere)
        node.position = position
        
        return node
    }
    
    // MARK: - Place the reference image at a position on the ground plane
    func placeReferenceImage(on position: SCNVector3) {
        guard let image = UIImage(named: "target") else { return }
        
        let planeGeometry = SCNPlane(width: 0.15, height: 0.15)
        planeGeometry.firstMaterial?.diffuse.contents = image
        
        let node = SCNNode(geometry: planeGeometry)
        node.position = SCNVector3(x: position.x, y: position.y, z: position.z)
        node.eulerAngles.x = -.pi / 2
        
        sceneView.scene.rootNode.addChildNode(node)
        referenceImageNode = node
    }
    
    func rayCasting(at point: CGPoint) -> SCNVector3? {
        let raycastQuery = sceneView.raycastQuery(from: point, allowing: .estimatedPlane, alignment: .horizontal)
        
        guard let query = raycastQuery,
              let result = sceneView.session.raycast(query).first else { return nil }
        let worldPoint = result.worldTransform.columns.3
        return SCNVector3(x: worldPoint.x, y: worldPoint.y, z: worldPoint.z)
    }
    
    func rayCastingForWall(at point: CGPoint) -> SCNVector3? {
        let raycastQuery = sceneView.raycastQuery(from: point, allowing: .existingPlaneInfinite, alignment: .vertical)
        
        guard let query = raycastQuery,
              let result = sceneView.session.raycast(query).first else { return nil }
        let worldPoint = result.worldTransform.columns.3
        return SCNVector3(x: worldPoint.x, y: worldPoint.y, z: worldPoint.z)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Stop updating if the measurement is frozen
        if isMeasurementFrozen { return }

        if !isReferenceFound {
            DispatchQueue.main.async {
                if let worldPosition = self.rayCasting(at: self.sceneView.center) {
                    self.referenceImageNode?.isHidden = false
                    if let referenceImageNode = self.referenceImageNode {
                        referenceImageNode.position = worldPosition
                    } else {
                        self.placeReferenceImageOnGroundExtremeBottom()
                    }
                } else {
                    self.referenceImageNode?.isHidden = true
                }
            }
        } else {
            DispatchQueue.main.async {
                guard let linePosition = self.rayCastingForWall(at: self.sceneView.center),
                      let startingNode = self.startingNode else { return }

                self.verticalLineNode?.removeFromParentNode()
                self.textNode?.removeFromParentNode()

                if linePosition.y > startingNode.position.y {
                    self.verticalLineNode = self.drawLineBetweenVectors(from: startingNode.position, to: linePosition)
                    self.sceneView.scene.rootNode.addChildNode(self.verticalLineNode!)

                    let distance = self.distanceInMeters(pos1: startingNode.position, pos2: linePosition)
                    self.measurement = distance
                    self.distance = self.distanceBetween(A: startingNode.position, B: linePosition)
                    self.textNode = self.createTextNode(distance, at: linePosition)
                    self.sceneView.scene.rootNode.addChildNode(self.textNode!)
                }
            }
        }
    }

    
//    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
//        if(!isReferenceFound) {
//            DispatchQueue.main.async {
//                
//                if let worldPosition = self.rayCasting(at: self.sceneView.center) {
//                    self.referenceImageNode?.isHidden = false
//                    if let referenceImageNode = self.referenceImageNode {
//                        referenceImageNode.position = worldPosition
//                    } else {
//                        self.placeReferenceImageOnGroundExtremeBottom()
//                    }
//                    
//                } else {
//                    self.referenceImageNode?.isHidden = true
//                }
//            }
//        } else {
//            DispatchQueue.main.async {
//                
//                
//                //let screenCenter = CGPoint(x: self.sceneView.bounds.midX, y: self.sceneView.bounds.midY + 100)
//                guard let linePositon = self.rayCastingForWall(at: self.sceneView.center),
//                      let startingNode = self.startingNode else { return }
//                self.verticalLineNode?.removeFromParentNode()
//                self.textNode?.removeFromParentNode()
//                
//                if(linePositon.y > startingNode.position.y) {
//                    self.verticalLineNode = self.drawLineBetweenVectors(from: startingNode.position, to: linePositon)
//                    self.sceneView.scene.rootNode.addChildNode(self.verticalLineNode!)
//                    
//                    let distance = self.distanceInMeters(pos1: startingNode.position, pos2: linePositon)
//                    let textNode = self.createTextNode(distance, at: linePositon)
//                    self.textNode = textNode
//                    self.sceneView.scene.rootNode.addChildNode(textNode)
//                }
//            }
//        }
//    }
        
    func drawLineBetweenVectors(from startPoint: SCNVector3, to endPoint: SCNVector3, lineThickness: CGFloat = 0.012) -> SCNNode {
        
        // Calculate the midpoint between the two points
        let midpoint = SCNVector3(
            (startPoint.x),
            (startPoint.y + endPoint.y) / 2,
            (startPoint.z)
        )
        
        // Calculate the distance between the two points (height of the vertical line)
        let height = abs(CGFloat(endPoint.y - startPoint.y))
        
        // Create the geometry to represent the vertical line (SCNCylinder)
        let verticalLine = SCNCylinder(radius: lineThickness, height: height)
        verticalLine.firstMaterial?.diffuse.contents = UIColor.white
        
        // Create the SCNNode for the geometry
        let lineNode = SCNNode(geometry: verticalLine)
        
        // Set the position of the line node to the midpoint
        lineNode.position = midpoint
        
        return lineNode
    }
    
    func createTextNode(_ text: String, at position: SCNVector3) -> SCNNode {
        let textGeometry = SCNText(string: text, extrusionDepth: 0.0)
        
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.red
        textGeometry.materials = [material]
        textGeometry.font = UIFont.systemFont(ofSize: 19.0, weight: .semibold)
        
        let textNode = SCNNode(geometry: textGeometry)
        
        // Scale the text down
        let scaleFactor: Float = 0.005
        textNode.scale = SCNVector3(scaleFactor, scaleFactor, scaleFactor)
        
        // Position the text above the line
        textNode.position = position
        textNode.constraints = [SCNBillboardConstraint()] // Ensure the text faces the user
        
        return textNode
    }
}

extension ViewController {
    private func updateUI() {
        bottomButton.isHidden = true
    }
    
    func hidestartButton() {
        startButton.isHidden = true
    }
    
    func showstartButton() {
        startButton.isHidden = false
    }
}
