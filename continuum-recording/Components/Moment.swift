//
//  Moment.swift
//  continuum-recording
//
//  Created by Tyler Angert on 1/18/19.
//  Copyright © 2019 Tyler Angert. All rights reserved.
//

import Foundation
import SceneKit

// A moment can be a photo node, audio node, or
// Initially just a plane

// How will this work? record audio and assign an ID to the audio file (associated with each begin/end)
// Then each moment frame gets tagged with the ID of the audio file and the moment in time it refers to

class Moment: SCNNode {
    
    var id: Int!
    var image: UIImage!
    var timestamp: TimeInterval!
    
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
