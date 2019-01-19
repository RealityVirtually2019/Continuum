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

extension CGRect {
//    func / {
//        return CGRect(x: self.x/, y: <#T##CGFloat#>, width: <#T##CGFloat#>, height: <#T##CGFloat#>)
//    }
}
class MainViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    // MARK: Data management
    // Keep the data flat, using dependency injection with the image and audio data
    // image data
    // audio data
    // image, audio -> moments
    // image, audio -> preview
    // Store moments
    var moments: [Moment] = [Moment]()
    
    // Store the image frames separately
    var frames: [UIImage] = [UIImage]()
    var previousMoment: Moment! {
        didSet {
            // Checking if the change is happening from frame to frame
            if previousMoment != nil && oldValue != nil {
                if previousMoment.name != oldValue.name {
                    feedback.prepare()
                    feedback.impactOccurred()
                }
            }
        }
    }
    let feedback = UIImpactFeedbackGenerator(style: .light)

    
    // How to store the data?
    
    // MARK: State
    let recorder = Recorder()
    
    var isTouching = false
    var audioRecorder: AVAudioRecorder! = AVAudioRecorder()
    var audioPlayer : AVAudioPlayer! = AVAudioPlayer()
    var meterTimer:Timer!
    var isAudioRecordingGranted: Bool!
    var isRecording = false
    var isPlaying = false
    
    // MARK: IBOutlets
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var previewView: UIImageView! {
        didSet {
            previewView.layer.cornerRadius = 5
            previewView.clipsToBounds = true
            
//            let mask = UIView.init(frame: UIScreen.main.bounds/2)
            
//            // Create a mutable path and add a rectangle that will be h
//            let mutablePath = CGMutablePath()
//            mutablePath.addRect(previewView.bounds)
//            mutablePath.addRect(previewMask.bounds)
//
//            // Create a shape layer and cut out the intersection
//            let mask = CAShapeLayer()
//            mask.path = mutablePath
//            mask.fillRule = CAShapeLayerFillRule.evenOdd
//
//            previewView.layer.mask = mask
        }
    }
    @IBOutlet weak var previewMask: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Audio setup
//        audioPlayer.delegate = self
//        audioRecorder.delegate = self
        
        checkRecordPermission()
        
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
        view.bringSubviewToFront(previewView)
        view.bringSubviewToFront(previewMask)
        
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
    
    // MARK: Audio handling
    func checkRecordPermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case AVAudioSession.RecordPermission.granted:
            isAudioRecordingGranted = true
            break
        case AVAudioSession.RecordPermission.denied:
            isAudioRecordingGranted = false
            break
        case AVAudioSession.RecordPermission.undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission({ (allowed) in
                if allowed {
                    self.isAudioRecordingGranted = true
                } else {
                    self.isAudioRecordingGranted = false
                }
            })
            break
        default:
            break
        }
    }
    
    // Generating audio file paths
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    func getFileUrl(fileID: String) -> URL {
        let filename = "\(fileID).m4a"
        let filePath = getDocumentsDirectory().appendingPathComponent(filename)
        return filePath
    }
    
    func setupRecorder(fileID: String)
    {
        if isAudioRecordingGranted
        {
            let session = AVAudioSession.sharedInstance()
            do
            {
                try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
                try session.setActive(true)
                let settings = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 2,
                    AVEncoderAudioQualityKey:AVAudioQuality.high.rawValue
                ]
                audioRecorder = try AVAudioRecorder(url: getFileUrl(fileID: fileID), settings: settings)
                audioRecorder.delegate = self
                audioRecorder.isMeteringEnabled = true
                audioRecorder.prepareToRecord()
            }
            catch let error {
                displayAlert(messageTitle: "Error", description: error.localizedDescription, actionTitle: "OK")
            }
        }
        else {
            displayAlert(messageTitle: "Error", description: "Don't have access to use your microphone.", actionTitle: "OK")
        }
    }
    
    func displayAlert(messageTitle : String , description : String ,actionTitle : String) {
        let ac = UIAlertController(title: messageTitle, message: description, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: actionTitle, style: .default)
        {
            (result : UIAlertAction) -> Void in
            _ = self.navigationController?.popViewController(animated: true)
        })
        present(ac, animated: true)
    }
    
    // Recording
    func startRecording() {
        if isRecording {
            finishRecording(success: true)
            isRecording = false
        } else {
            audioRecorder.record()
            meterTimer = Timer.scheduledTimer(timeInterval: 0.1, target:self, selector:#selector(self.updateAudioMeter(timer:)), userInfo:nil, repeats:true)
            isRecording = true
        }
    }
    
    @objc func updateAudioMeter(timer: Timer) {
        if audioRecorder.isRecording {
            audioRecorder.updateMeters()
        }
    }

    
    func finishRecording(success: Bool) {
        if success {
            audioRecorder.stop()
            audioRecorder = nil
            meterTimer.invalidate()
            print("Successfully recorded!")
        } else {
            displayAlert(messageTitle: "Error", description: "Recording failed.", actionTitle: "OK")
        }
    }
    
    // Playback
    func prepareToPlay(fileID: String) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: getFileUrl(fileID: fileID))
            audioPlayer.delegate = self
            audioPlayer.prepareToPlay()
        } catch{
            print("Error")
        }
    }
    
    func playRecording(fileID: String) {
        if isPlaying  {
            audioPlayer.stop()
            isPlaying = false
        } else {
            if FileManager.default.fileExists(atPath: getFileUrl(fileID: fileID).path) {
                prepareToPlay(fileID: fileID)
                audioPlayer.play()
                isPlaying = true
            } else {
                displayAlert(messageTitle: "Error", description: "Audio file is missing", actionTitle: "Ok?")
            }
        }
    }
    
    
    // MARK: Main interaction handlers
    // Began is used to ADD content once the settings are adjusted
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("Began")
        isTouching = true
    }
    
    // Stops recording
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("Ended")
        isTouching = false
    }
    
    // MARK: Helper methods for adding content
    func addContent(position: SCNVector3) {
        // Initially, add the sphere
//        let sphere: Sphere = Sphere(position: position)
//        self.sceneView.scene.rootNode.addChildNode(sphere)
        
        // Now add "moments"
        //1. Create Our Plane Node
        guard let frame = sceneView.session.currentFrame else { return }
        
//        var currentImage = UIImage(pixelBuffer: frame.capturedImage)
//        print(currentImage)
        
        let currentImage = sceneView.snapshot()
        
        // Store the images separately
        frames.append(currentImage)
        
        // It's storing them inside the
        
        let moment = Moment(content: UIColor.white.withAlphaComponent(0.25), doubleSided: false, horizontal: false)
        moment.position = position
        
        print("Moment count: \(moments.count)")
        
        // ID, figute this out
        // Tag the moment
        // Add an id to it
        //
        moment.name = "\(moments.count)"
        moment.simdTransform = frame.camera.transform
        
        self.sceneView.scene.rootNode.addChildNode(moment)
        moments.append(moment)
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
        if moments.count < 1 {
            return true
        }
        for m  in moments {
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
                    guard let touchedMoment = moments.first(where: { distance($0.position, cameraNode.position) < 0.01 }) else {
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
                                      animations: { self.previewView.image = self.frames[imgIdx] },
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

extension MainViewController: AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        finishRecording(success: false)
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        
    }
}
