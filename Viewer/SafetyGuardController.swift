//
//  SafetyGuardController.swift
//  Viewer
//

import UIKit

class SafetyGuardController: UIViewController {
    
    var fingerDown = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.becomeFirstResponder()
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        fingerDown = true
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        fingerDown = false
    }
    
    override func motionBegan(motion: UIEventSubtype, withEvent event: UIEvent?) {
        if motion == .MotionShake {
            print("shaken!")
            
            if fingerDown {
                performSegueWithIdentifier("showApp", sender: self)
            }
        }
    }
    
}

