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


// Priorities for having this be cool
// 1: Audio play at beginning of path
// 2: Rotating the mask with the appropriate
// Tutorial mode
// Guiding indicators
// 3: Selecting paths
// 3: Focusing / darening
// REDO IMAGES BEING STORED BY PATH ID
extension UIView {
    func makeCircular() {
        self.layer.cornerRadius = min(self.frame.size.height, self.frame.size.width) / 2.0
        self.clipsToBounds = true
    }
}

class MainViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    // MARK: Data management
    // Keep the data flat, using dependency injection with the image and audio data
    // image data
    // audio data
    // image, audio -> moments
    // image, audio -> preview
    
    // A path is made up arrays of moments!
    // Stored as a dictionary with the path ID?
    var paths: [[Moment]] = [[Moment]]()
    // How to store by ID?
    var frames: [UIImage] = [UIImage]()
    var audioFiles: [String] = [String]()
    
    // Store the currently recorded moments
    var allMoments: [Moment] = [Moment]()
    var currentMoments: [Moment] = [Moment]()
    
    var previousMoment: Moment! {
        didSet {
            // Checking if the change is happening from frame to frame
            if previousMoment != nil {
                if oldValue != nil {
                    if previousMoment.name != oldValue.name {
                        feedback.prepare()
                        feedback.impactOccurred()
                    }
                } else {
                    feedback.prepare()
                    feedback.impactOccurred()
                }
            }
        }
    }
    
    let feedback = UIImpactFeedbackGenerator(style: .light)
    var backgroundView: UIView!
    
    // How to store the data?
    
    // MARK: State
    var isTouching = false
    var isRecording = false
    var isPlaying = false
    
    // MARK: Recorder class
    var state: AGAudioRecorderState = .Ready
    var recorder: AGAudioRecorder = AGAudioRecorder(withFileName: "0")
    
    // MARK: IBOutlets
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    
    @IBOutlet weak var recordingCircle: UIView! {
        didSet {
            recordingCircle.makeCircular()
            var visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
            visualEffectView.frame = recordingCircle.bounds
            recordingCircle.addSubview(visualEffectView)
            self.recordingCircle.backgroundColor = UIColor.white
            self.recordingCircle.layer.opacity = 0.15
        }
    }
    
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var previewView: UIImageView! {
        didSet {
            let maskLayer = CAShapeLayer()
            let scaleFactor: CGFloat = 1.75
            
            let width = UIScreen.main.bounds.width/scaleFactor
            let height = UIScreen.main.bounds.height/scaleFactor
            
            let widthOffset = UIScreen.main.bounds.width - width
            let heightOffset = UIScreen.main.bounds.height - height
            
            let xOffset = widthOffset/3
            let yOffset = heightOffset/3
            
            let maskRect = CGRect(x: xOffset, y: yOffset, width: width, height: height)
            let path = CGPath(roundedRect: maskRect, cornerWidth: 5, cornerHeight: 5, transform: nil)
            maskLayer.path = path
            previewView.layer.mask = maskLayer
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        backgroundView = UIView(frame: UIScreen.main.bounds)
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        backgroundView.layer.opacity = 0
        view.bringSubviewToFront(backgroundView)
        view.addSubview(backgroundView)

        view.bringSubviewToFront(previewView)
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
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
    
    @IBAction func recordTapped(_ sender: Any) {
        // Pass in file name
        recorder.doRecord()
    }
    @IBAction func playTapped(_ sender: Any) {
        // Pass in file name
        recorder.doPlay()
    }
    
    // MARK: Main interaction handlers
    // Began is used to ADD content once the settings are adjusted
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isTouching = true
        recorder.changeFile(withFileName: "\(paths.count)")
        recorder.doRecord()
        
        UIView.animate(withDuration: 0.75, delay:0, options: [.repeat, .autoreverse], animations: {
            self.recordingCircle.backgroundColor = UIColor.red
            self.recordingCircle.layer.opacity = 1
        }, completion: nil)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        
    }
    
    // Access a frame by accessing path then frame index
    // So paths[0][5] is the 5th frame of the 0th path
    
    // Stops recording
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isTouching = false
        recorder.doStopRecording()
        // Store the current moments
        paths.append(currentMoments)
        currentMoments.removeAll()
        
        UIView.animate(withDuration: 0.25) {
            self.recordingCircle.backgroundColor = UIColor.white
            self.recordingCircle.layer.opacity = 0.25
        }
        recordingCircle.layer.removeAllAnimations()
    }
    
    // MARK: Helper methods for adding content
    func addContent(position: SCNVector3) {
        
        // Now add "moments"
        // Grab the frame
        guard let frame = sceneView.session.currentFrame else { return }
        
        // TODO: Don't just take snapshot
        // var currentImage = UIImage(pixelBuffer: frame.capturedImage)
        let currentImage = sceneView.snapshot()
        
        // Store the images separately
        frames.append(currentImage)
        
        // It's storing them inside the
        let moment = Moment(content: UIColor.white, doubleSided: true, horizontal: false)
        moment.position = position
        
        // Do better with IDs, maybe make a dictionary with UUIDs?
        moment.id = currentMoments.count
        moment.pathID = paths.count
        
        moment.name = "\(currentMoments.count)"
        moment.timestamp = frame.timestamp
        
        print(moment.timestamp)
        
        moment.simdTransform = frame.camera.transform
        
        self.sceneView.scene.rootNode.addChildNode(moment)
        
        if currentMoments.count == 0 {
            moment.isEdge = true
            moment.material.fillMode = .fill
        }
        
        allMoments.append(moment)
        currentMoments.append(moment)
    }
    
    func sceneSpacePosition(inFrontOf node: SCNNode, atDistance distance: Float) -> SCNVector3 {
        let localPosition = SCNVector3(x: 0, y: 0, z: -distance)
        let scenePosition = node.convertPosition(localPosition, to: nil)
        // to: nil is automatically scene space
        return scenePosition
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
    
    // Use this to validate adding new content when pressing down
    func canAddContent(position: SCNVector3) -> Bool {
        if currentMoments.count < 1 {
            return true
        }
        for m  in currentMoments {
            if distance(m.position, position) <= 0.05 {
                return false
            }
        }
        return true
    }
    
    // EVERY FRAME
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        // Add the content if touching the screen
            if let cameraNode = self.sceneView.pointOfView {

                // Adjusts for the distance
                let adjustedPos = SCNVector3(cameraNode.position.x, cameraNode.position.y, cameraNode.position.z - 0.05)

                if isTouching {
                    if canAddContent(position: adjustedPos) {
                        addContent(position: adjustedPos)
                    }
                } else {
                    // Need to check if camera position is touching one of the moments nodes
                    // distance between camera and position
                    // Need to make this less sensitive
                    guard let touchedMoment = allMoments.first(where: { distance($0.position, cameraNode.position) < 0.040 }) else {
                        self.previewView.image = nil
                        self.isPlaying = false
                        UIView.animate(withDuration: 0.25) {
                            self.backgroundView.layer.opacity = 0
                        }
                        return
                    }
                    
                    if backgroundView.layer.opacity == 0 {
                        UIView.animate(withDuration: 0.5) {
                            self.backgroundView.layer.opacity = 1
                        }
                    }
                    
                    // get ending
                    // lol u just discovered how to normalize from scratch
                    guard let endTime = paths[touchedMoment.pathID].last?.timestamp else { return }
                    guard let startTime = paths[touchedMoment.pathID].first?.timestamp else { return }
                    let duration = endTime - startTime
                    let currentTime = (touchedMoment.timestamp - startTime)/duration

                    if !isPlaying {
                        recorder.doPlay(fileID: String(touchedMoment.id), time: 0)
                    }
                    
                    isPlaying = true
                    
                    previousMoment = touchedMoment
                    let imgIdx = touchedMoment.id
                    
                    UIView.transition(with: self.previewView,
                                      duration: 0.5,
                                      options: .transitionCrossDissolve,
                                      animations: { self.previewView.image = self.frames[imgIdx!] },
                                      completion: nil)


                }
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

extension MainViewController: AGAudioRecorderDelegate {
    func agAudioRecorder(_ recorder: AGAudioRecorder, withStates state: AGAudioRecorderState) {
        switch state {
        case .error(let e): debugPrint(e)
        case .Failed(let s): debugPrint(s)
            
        case .Finish:
            recordButton.setTitle("Record", for: .normal)
            
        case .Recording:
            recordButton.setTitle("Record Finished", for: .normal)
            
        case .Pause:
            playButton.setTitle("Pause", for: .normal)
            
        case .Play:
            playButton.setTitle("Play", for: .normal)
            
        case .Ready:
            recordButton.setTitle("Recode", for: .normal)
            playButton.setTitle("Play", for: .normal)
        }
        debugPrint(state)
    }
    
    func agAudioRecorder(_ recorder: AGAudioRecorder, currentTime timeInterval: TimeInterval, formattedString: String) {
        debugPrint(formattedString)
    }
}

//extension MainViewController: AVAudioRecorderDelegate, AVAudioPlayerDelegate {
//    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
//        finishRecording(success: false)
//    }
//
//    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
//        if !flag {
//            finishRecording(success: false)
//        }
//    }
//
//    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
//
//    }
//}

