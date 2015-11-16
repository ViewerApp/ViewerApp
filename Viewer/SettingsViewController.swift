//
//  SettingsViewController.swift
//  Viewer
//

import UIKit

class SettingsViewController: UIViewController {
    
    @IBOutlet weak var safetyGuardSwitch: UISwitch!
    
    let defaults = NSUserDefaults.standardUserDefaults()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let color = UIColor(red: (0.0/100.0), green: (17.0/100.0), blue: (34.0/100.0), alpha: 1)
        
        self.view.backgroundColor = color
        
        safetyGuardSwitch.on = defaults.boolForKey("showSafetyGuard")
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
    
    @IBAction func donePressed(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func safetyGuardToggled(sender: AnyObject) {
        defaults.setBool(safetyGuardSwitch.on, forKey: "showSafetyGuard")
    }
    
}
