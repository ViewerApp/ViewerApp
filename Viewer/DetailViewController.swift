//
//  DetailViewController.swift
//  Viewer
//

import UIKit

class DetailViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    
    var delegate: ViewController!
    var currentImage: Image!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let color = UIColor(red: (0.0/100.0), green: (17.0/100.0), blue: (34.0/100.0), alpha: 1)
        
        self.navigationController!.navigationBar.barTintColor = color
        self.view.backgroundColor = color
        self.navigationController!.navigationBar.barStyle = .Black
        self.title = ""
        
        currentImage = delegate.selectedImage
        imageView.hnk_setImageFromURL(currentImage.fileURL)
    }
    
}
