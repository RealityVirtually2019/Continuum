//
//  ViewController.swift
//  continuum-recording
//
//  Created by Tyler Angert on 1/18/19.
//  Copyright © 2019 Tyler Angert. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class Sphere: SCNNode {
    
    static let radius: CGFloat = 0.01
    
    let sphereGeometry: SCNSphere
    
    // Required but unused
    required init?(coder aDecoder: NSCoder) {
        sphereGeometry = SCNSphere(radius: Sphere.radius)
        super.init(coder: aDecoder)
    }
    
    // The real action happens here
    init(position: SCNVector3) {
        self.sphereGeometry = SCNSphere(radius: Sphere.radius)
        
        super.init()
        
        let sphereNode = SCNNode(geometry: self.sphereGeometry)
        sphereNode.position = position
        
        self.addChildNode(sphereNode)
    }
    
    func clear() {
        self.removeFromParentNode()
    }
    
}

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    // MARK: Data management
    // TODO: Move into singleton
    var spheres: [Sphere] = [Sphere]()
    
    // MARK: State
    var isTouching = false
    
    // MARK: IBOutlets
    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: Main interaction handlers
    // Began is used to ADD content once the settings are adjusted
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("Began")
        
        isTouching = true
        
        guard let touch = touches.first else { return }
        let touchLocation: CGPoint = touch.location(in: sceneView)
        let hits = self.sceneView.hitTest(touchLocation, options: nil)
        
        
        if let cameraNode = self.sceneView.pointOfView {
            let adjustedPos = SCNVector3(cameraNode.position.x, cameraNode.position.y, cameraNode.position.z - 0.05)
            addSphere(position: adjustedPos)
            
//            let width = sceneView.frame.size.width;
//            let height = sceneView.frame.size.height;
//
//            guard let touch = touches.first else { return }
//            let touchLocation: CGPoint = touch.location(in: sceneView)
////            let hits = self.sceneView.hitTest(touchLocation, options: nil) else { return}
//            let hits = sceneView.hitTest(touchLocation, types: [.existingPlaneUsingExtent, .featurePoint])
//
//            if !hits.isEmpty {
//                let distance = hits.first!.distance
//                let pos = sceneSpacePosition(inFrontOf: cameraNode, atDistance: Float(distance))
//
//                // Add the sphere
//                addSphere(position: pos)
//
//            }
        }
    }
    
    // MARK: Helper methods for adding content
    func addSphere(position: SCNVector3) {
        print("adding sphere at point: \(position)")
        let sphere: Sphere = Sphere(position: position)
        self.sceneView.scene.rootNode.addChildNode(sphere)
        
        // if we keep an array of these babies, then calling
        // sphere.clear() on each will remove them from the scene
        spheres.append(sphere)
    }
    
    func sceneSpacePosition(inFrontOf node: SCNNode, atDistance distance: Float) -> SCNVector3 {
        let localPosition = SCNVector3(x: 0, y: 0, z: -distance)
        let scenePosition = node.convertPosition(localPosition, to: nil)
        // to: nil is automatically scene space
        return scenePosition
    }
    
    // Stops recording
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("Ended")
        
    }
    
    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    // EVERY FRAME
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        print("frame")
        
        // Add the content if touching the screen
        if isTouching {
            
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}
