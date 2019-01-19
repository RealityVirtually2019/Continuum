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

// A moment can be a photo node, audio node, or
// Initially just a plane

// How will this work? record audio and assign an ID to the audio file (associated with each begin/end)
// Then each moment frame gets tagged with the ID of the audio file and the moment in time it refers to
class Moment: SCNNode {
    
    // TODO: Add constraints
    
    // Make width and height based on the screen proportions
    // Keep the same aspect ratio of the screen
    init(width: CGFloat = 0.035, height: CGFloat = 0.02, content: Any, doubleSided: Bool, horizontal: Bool) {
        
        super.init()
        
        //1. Create The Plane Geometry With Our Width & Height Parameters
        let plane = SCNPlane(width: width, height: height)
        plane.cornerRadius = 0.01/2
        self.geometry = plane
        
        //2. Create A New Material
        let material = SCNMaterial()
        
        if let colour = content as? UIColor{
            
            //The Material Will Be A UIColor
            material.diffuse.contents = colour
            
        } else if let image = content as? UIImage{
            
            //The Material Will Be A UIImage
            material.diffuse.contents = image
            
        }else{
            
            //Set Our Material Colour To Cyan
            material.diffuse.contents = UIColor.cyan
            
        }
        
        //3. Set The 1st Material Of The Plane
        self.geometry?.firstMaterial = material
        
        //4. If We Want Our Material To Be Applied On Both Sides The Set The Property To True
        if doubleSided{
            material.isDoubleSided = true
        }
        
        //5. By Default An SCNPlane Is Rendered Vertically So If We Need It Horizontal We Need To Rotate It
        if horizontal{
            self.transform = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)
        }
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

class Plane: SCNNode {
    
}

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

class MainViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    // MARK: Data management
    // TODO: Move into singleton
    var spheres: [Sphere] = [Sphere]()
    
    // Keep the data flat, using dependency injection with the image and audio data
    
    // image data
    // audio data
    // image, audio -> moments
    // image, audio -> preview
    
    //
    // Store moments
    var moments: [Moment] = [Moment]()
    var previousMoment: Moment! {
        didSet {
            // Checking if the change is happening from frame to frame
            if previousMoment != nil && oldValue != nil {
                if previousMoment.name != oldValue.name {
                    print("changing")
                    feedback.prepare()
                    feedback.impactOccurred()
                }
            }
        }
    }
    var images: [UIImage] = [UIImage]()
    
    let feedback = UIImpactFeedbackGenerator(style: .light)

    
    // How to store the data?
    
    // MARK: State
    var isTouching = false
    
    // MARK: IBOutlets
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var previewView: UIImageView! {
        didSet {
            previewView.layer.cornerRadius = 2.5
            previewView.clipsToBounds = true
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Rendering speed optimization
//        sceneView.preferredFramesPerSecond = 24
//        sceneView.rendersContinuously = false
        
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
        
//        guard let touch = touches.first else { return }
//        let touchLocation: CGPoint = touch.location(in: sceneView)
//        let hits = self.sceneView.hitTest(touchLocation, options: nil)
        
    }
    
    // MARK: Helper methods for adding content
    func addContent(position: SCNVector3) {
        print("adding sphere at point: \(position)")
        
        // Initially, add the sphere
//        let sphere: Sphere = Sphere(position: position)
//        self.sceneView.scene.rootNode.addChildNode(sphere)
        
        // Now add "moments"
        //1. Create Our Plane Node
        guard let frame = sceneView.session.currentFrame else { return }
        
//        var currentImage = UIImage(pixelBuffer: frame.capturedImage)
        let currentImage = sceneView.snapshot()
        
        // Store the images separately
        images.append(currentImage)
        
        let moment = Moment(content: currentImage, doubleSided: false, horizontal: false)
        moment.position = position
        
        // ID, figute this out
        moment.name = "\(moments.count)"
        
        // This causes AWFUL memory issues
//        moment.geometry?.firstMaterial?.diffuse.contents = sceneView.snapshot()

        self.sceneView.scene.rootNode.addChildNode(moment)
        moments.append(moment)
        
        // if we keep an array of these babies, then calling
        // sphere.clear() on each will remove them from the scene
//        spheres.append(sphere)
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
        isTouching = false
    }
    
    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func distance(_ vec1: SCNVector3, _ vec2: SCNVector3) ->  Float {
        let node1Pos = SCNVector3ToGLKVector3(vec1)
        let node2Pos = SCNVector3ToGLKVector3(vec2)
        return GLKVector3Distance(node1Pos, node2Pos)
    }
    
    // EVERY FRAME
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        // Add the content if touching the screen
            if let cameraNode = self.sceneView.pointOfView {
                
                // Adjusts for the distance
                let adjustedPos = SCNVector3(cameraNode.position.x, cameraNode.position.y, cameraNode.position.z - 0.05)
                
                if isTouching {
                    addContent(position: adjustedPos)
                } else {
                    // Need to check if camera position is touching one of the moments nodes
                    // distance between camera and position
                    guard let touchedMoment = moments.first(where: { distance($0.position, adjustedPos) < 0.025 }) else {
                        self.previewView.image = nil
                        return
                    }
                    
                    // Protects against first case
                    if previousMoment != nil {
                        previousMoment.isHidden = false
                    }
                    
                    previousMoment = touchedMoment
                    
                    let imgIdx = Int(touchedMoment.name!)!
//
                    UIView.transition(with: self.previewView,
                                      duration: 0.5,
                                      options: .transitionCrossDissolve,
                                      animations: { self.previewView.image = self.images[imgIdx] },
                                      completion: nil)
                    
//                      self.previewView.image = images[imgIdx]
//                    touchedMoment.isHidden = true
                    previousMoment.isHidden = true

                }
            
//                if !hits.isEmpty {
//                    let detectedFrame = hits.
//                }
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
