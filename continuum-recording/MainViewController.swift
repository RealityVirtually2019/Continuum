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

extension SCNNode {
    func cleanup() {
        for child in childNodes {
            child.cleanup()
        }
        geometry = nil
    }
}

enum InteractionState {
    case ready
    case recording
    case finished
    case viewing
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
    var frames: [Int: [UIImage]] = [Int: [UIImage]]()
    var audioFiles: [String] = [String]()
    
    // Store the currently recorded moments
    var allMoments: [Moment] = [Moment]()
    var currentMoments: [Moment] = [Moment]()
    var currentTouchedMoment: Moment!
    var selectedPath: Int! = 0
    
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
    
    @IBOutlet weak var filter1: UIButton! {
        didSet {
            filter1.tag = 1
        }
    }
    
    @IBOutlet weak var filter2: UIButton! {
        didSet {
            filter2.tag = 2
        }
    }
    @IBOutlet weak var filter3: UIButton! {
        didSet {
            filter3.tag = 3
        }
    }
    @IBOutlet weak var filter4: UIButton! {
        didSet {
            filter4.tag = 4
        }
    }
    @IBOutlet weak var filter5: UIButton! {
        didSet {
            filter5.tag = 5
        }
    }
    
    @IBAction func pressFilter(_ sender: UIButton) {
        let ciContext = CIContext(options: nil)
        
        // grab the images from the selctd path
        
        for img in frames[selectedPath]! {
            let coreImage = CIImage(image: img)
            let filter = CIFilter(name: "\(CIFilterNames[sender.tag-1])" )
            filter!.setDefaults()
            filter!.setValue(coreImage, forKey: kCIInputImageKey)
            let filteredImageData = filter!.value(forKey: kCIOutputImageKey) as! CIImage
            let filteredImageRef = ciContext.createCGImage(filteredImageData, from: filteredImageData.extent)
//            img = UIImage(CGImage: filteredImageRef!)
        }
    }
    
    // MARK: Filters???
    var CIFilterNames = [
        "CIPhotoEffectChrome",
        "CIPhotoEffectFade",
        "CIPhotoEffectNoir",
        "CIPhotoEffectTonal",
        "CISepiaTone"
    ]
    
    let feedback = UIImpactFeedbackGenerator(style: .light)
    var backgroundView: UIView!
    
    // How to store the data?
    
    // MARK: State
    var interactionState: InteractionState = .ready
    var isTouching = false
    var isRecording = false
    var isPlaying = false
    
    // MARK: Recorder class
    var state: AGAudioRecorderState = .Ready
    var recorder: AGAudioRecorder = AGAudioRecorder(withFileName: "0")
    
    // MARK: IBOutlets
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    var recordingCircle: UIView!
    
    @IBOutlet weak var statusLabel: UILabel! {
        didSet {
            statusLabel.text = "Hold and move forward to record"
            statusLabel.backgroundColor = UIColor.white.withAlphaComponent(0.5)
            statusLabel.layer.cornerRadius = 10
            statusLabel.clipsToBounds = true
            
//            var blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.light))
//            blurEffectView.clipsToBounds = true
//            blurEffectView.frame = CGRect(x: statusLabel.bounds.minX, y: statusLabel.bounds.minY, width: statusLabel.bounds.width*2, height: statusLabel.bounds.height*2)
//            statusLabel.addSubview(blurEffectView)
////
//            let label = UILabel()
//            label.frame = statusLabel.bounds
//            label.text = "Hold and move forward"
//            label.textColor = [UIColor colorWithWhite:0.4f alpha:1.0f];
            
            // add the label to effect view
//            [blurView.contentView addSubview:label];
            
        }
    }
    
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
        
        recordingCircle = UIView(frame: CGRect(x: 0, y: 0, width: 150, height: 150))
        recordingCircle.center = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
        recordingCircle.makeCircular()
        
        var colorView = UIView(frame: recordingCircle.bounds)
        colorView.backgroundColor = UIColor.red.withAlphaComponent(0.5)
        recordingCircle.addSubview(colorView)
        
        var blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.light))
        blurEffectView.clipsToBounds = true
        blurEffectView.frame = recordingCircle.bounds
        recordingCircle.addSubview(blurEffectView)
        
        recordingCircle.backgroundColor = UIColor.clear
        recordingCircle.layer.opacity = 0
        view.addSubview(recordingCircle)
        view.bringSubviewToFront(recordingCircle)
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        // Show statistics such as fps and timing information
//        sceneView.showsStatistics = true
        
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
    
    
    // Add a bool for when you finished but you are still holding down
    
    // MARK: Main interaction handlers
    // Began is used to ADD content once the settings are adjusted
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isTouching = true
        
        if allMoments.count < 90 {
            stateChanged(state: .recording)
            recorder.changeFile(withFileName: "\(paths.count)")
            recorder.doRecord()
        
        
        let touch = touches.first as! UITouch
        if(touch.view == self.sceneView){
            let viewTouchLocation:CGPoint = touch.location(in: sceneView)
            UIView.animate(withDuration: 0.25) {
                self.recordingCircle.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
                self.recordingCircle.center = viewTouchLocation
                self.recordingCircle.layer.opacity = 1
            }
        }
//
//            UIView.animate(withDuration: 0.75, delay:0, options: [.repeat, .autoreverse], animations: {
//                self.recordingCircle.layer.opacity = 1
//            }, completion: nil)
//
        }
    }
    
    // Access a frame by accessing path then frame index
    // So paths[0][5] is the 5th frame of the 0th path
    
    // Stops recording
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isTouching = false
        endRecording()
        stateChanged(state: .ready)
    }
    
    func stateChanged(state: InteractionState) {
        self.interactionState = state
        switch(self.interactionState){
        case .ready:
            print("ready")
//            UIView.animate(withDuration: 0.25, animations: {
//                self.statusLabel.layer.opacity = 1
//                self.statusLabel.text = "Hold and move forward to record"
//            })
            break
        case .finished:
            print("finished")
            UIView.animate(withDuration: 0.25, animations: {
                self.statusLabel.layer.opacity = 1
                self.statusLabel.text = "Check out what you made!"
            }) { (finished) in
                print("Finished, going to ready")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.stateChanged(state: .ready)
                }
            }
            break
        case .recording:
            print("recording")
            UIView.animate(withDuration: 0.25, animations: {
                self.statusLabel.layer.opacity = 0
            }, completion: nil)
            break
        case .viewing:
            print("viewing")
            UIView.animate(withDuration: 0.25, animations: {
                self.statusLabel.layer.opacity = 0
            }, completion: nil)
            break
        default:
            print("ready")
            break
        }
    }
    
    func endRecording() {
        stateChanged(state: .finished)
        recorder.doStopRecording()
        // Store the current moments
        paths.append(currentMoments)
        currentMoments.removeAll()
        
        
        UIView.animate(withDuration: 0.25, animations: {
            
            self.recordingCircle.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
            self.recordingCircle.layer.opacity = 0
            
        }) { (finished) in
            
            self.recordingCircle.layer.removeAllAnimations()
        }
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
        
        // It's storing them inside the
        let moment = Moment(content: UIColor.white, doubleSided: true, horizontal: false)
        moment.position = position
        
        // Do better with IDs, maybe make a dictionary with UUIDs?
        moment.id = currentMoments.count
        moment.pathID = paths.count
        
        // First frame
        if moment.id == 0 {
//            let animLoop = SCNAction.repeatForever(SCNAction.sequence([SCNAction.scale(to: 1.5, duration: 0.25), SCNAction.scale(to: 0.75, duration: 0.25)]))
//            moment.runAction(animLoop)
//
            
            
            let pulseSize:CGFloat = 0.1
            let pulsePlane = SCNPlane(width: pulseSize, height: pulseSize)
            pulsePlane.firstMaterial?.isDoubleSided = true
            pulsePlane.firstMaterial?.diffuse.contents = UIColor.white
            let pulseNode = SCNNode(geometry: pulsePlane)
            
            let pulseShaderModifier =
                "#pragma transparent; \n" +
                    "vec4 originalColour = _surface.diffuse; \n" +
                    "vec4 transformed_position = u_inverseModelTransform * u_inverseViewTransform * vec4(_surface.position, 1.0); \n" +
                    "vec2 xy = vec2(transformed_position.x, transformed_position.y); \n" +
                    "float xyLength = length(xy); \n" +
                    "float xyLengthNormalised = xyLength/" + String(describing: pulseSize / 2) + "; \n" +
                    "float speedFactor = 1.5; \n" +
                    "float maxDist = fmod(u_time, speedFactor) / speedFactor; \n" +
                    "float distbasedalpha = step(maxDist, xyLengthNormalised); \n" +
                    "distbasedalpha = max(distbasedalpha, maxDist); \n" +
            "_surface.diffuse = mix(originalColour, vec4(0.0), distbasedalpha);"
            
            pulsePlane.firstMaterial?.shaderModifiers = [SCNShaderModifierEntryPoint.surface:pulseShaderModifier]
            moment.addChildNode(pulseNode)
            
        }
        
        // Initialize the frames moment array
        if frames[moment.pathID] == nil {
            frames[moment.pathID] = [UIImage]()
        }
        
        frames[moment.pathID]!.append(currentImage)
        
        moment.name = "\(currentMoments.count)"
        moment.timestamp = frame.timestamp
        
//        print(moment.timestamp)
        
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
        
        if currentMoments.count > 30 {
            endRecording()
            return false
        }
        
//        let currScale: CGFloat = CGFloat((50 - currentMoments.count)/50)
//        print(currScale)
//        // Animate the circle
//        UIView.animate(withDuration: 0.25, animations: {
//            self.recordingCircle.transform = CGAffineTransform(scaleX: currScale, y: currScale)
//        }, completion: nil)
//
        for m  in currentMoments {
            if distance(m.position, position) <= 0.06 {
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

                if isTouching && interactionState == .recording {
                    if canAddContent(position: adjustedPos) {
                        if allMoments.count < 90 {
                            addContent(position: adjustedPos)
                        }
                    }
                } else {
                    
                    // REMEMBER: isPlaying is for the audio
                    // Need to check if camera position is touching one of the moments nodes
                    guard let currentTouchedMoment = allMoments.last(where: { distance($0.position, cameraNode.position) < 0.06*1.5 }) else {
                        
                        print("Nil: \(self.interactionState)")
                        
                        // Found nil
                        if interactionState != .ready {
                            stateChanged(state: .ready)
                        }
                        for m in allMoments {
                            m.material.fillMode = .lines
                        }
                        isPlaying = false
                        return
                    }
                    
                    // Viewing if you get a movement
                    if interactionState != .viewing {
                        stateChanged(state: .viewing)
                        isPlaying = true
                    }
                    
                    if previousMoment != nil {
                        previousMoment.material.fillMode = .lines
                        previousMoment.material.diffuse.contents = UIColor.white
                    }
                    
                    if !isPlaying {
                        recorder.doPlay(fileID: String(currentTouchedMoment.pathID), time: 0)
                    }
                    
                    currentTouchedMoment.material.diffuse.contents = frames[currentTouchedMoment.pathID]![currentTouchedMoment.id]
                    currentTouchedMoment.material.fillMode = .fill
                    previousMoment = currentTouchedMoment

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
//        debugPrint(state)
    }
    
    func agAudioRecorder(_ recorder: AGAudioRecorder, currentTime timeInterval: TimeInterval, formattedString: String) {
//        debugPrint(formattedString)
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

