//
//  ViewController.swift
//  Viewer
//

import UIKit
import Haneke
import Shimmer
import Alamofire
import SwiftyJSON

class ViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var tagsField: UITextField!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var suggestionsView: UIView!
    @IBOutlet weak var suggestionsTableView: UITableView!
    @IBOutlet weak var suggestionsHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var suggestionsBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var loadingLabel: UILabel!
    @IBOutlet weak var loadingShimmeringView: FBShimmeringView!
    
    let api = API()
    let currentVersion = 1
    
    var currentImages: [Image] = []
    var selectedImage: Image! = nil
    var seenImagesIDs: [String] = []
    var currentSuggestions: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let color = UIColor(red: (0.0/100.0), green: (17.0/100.0), blue: (34.0/100.0), alpha: 1)
        
        self.navigationController!.navigationBar.barTintColor = color
        self.collectionView!.backgroundColor = color
        self.navigationController!.navigationBar.barStyle = .Black
        
//        let tap = UITapGestureRecognizer(target: self, action: "dismissKeyboard")
//        view.addGestureRecognizer(tap)
        
        // Sets the height to (screen height - 64) (navigation) and the position above the screen
        suggestionsHeightConstraint.constant = view.frame.height - 64
        suggestionsBottomConstraint.constant = view.frame.height
        
        // Calls methods when the keyboard is shown and hidden
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
        
        suggestionsTableView.delegate = self
        suggestionsTableView.dataSource = self
        
        // Hide the loading label
        loadingLabel.hidden = true
        loadingShimmeringView.contentView = loadingLabel
        
        // Add target to tags field, to detect when the text changes
        tagsField.addTarget(self, action: "textChanged:", forControlEvents: .EditingChanged)
        
        checkVersion()
    }
    
    func checkVersion() {
        let url = NSURL(string: "https://raw.githubusercontent.com/ViewerApp/ViewerApp/master/version.json")!
        let request = Alamofire.request(.GET, url)
        
        print("Checking version.")
        
        request.responseJSON { response in
            if let data = response.data {
                
                print("Response recieved")
                print(data)
                
                let defaults = NSUserDefaults.standardUserDefaults()
                
                let json = JSON(data: data)
                
                print(json["version"].int!)
                
                if self.currentVersion != json["version"].int! && !defaults.boolForKey("cantBotherAboutUpdates") {
                    
                    let alert = UIAlertController(title: "New Version: \(json["semanticVersion"].stringValue)", message: json["message"].stringValue, preferredStyle: .Alert)
                    alert.addAction(UIAlertAction(title: "Maybe next time.", style: .Cancel, handler: nil))
                    alert.addAction(UIAlertAction(title: "Update", style: .Default) { action in
                        UIApplication.sharedApplication().openURL(NSURL(string: "https://github.com/ViewerApp/ViewerApp")!)
                    })
                    alert.addAction(UIAlertAction(title: "Don't bother me about the update", style: .Destructive) { action in
                        defaults.setBool(true, forKey: "cantBotherAboutUpdates")
                    })
                    
                    self.presentViewController(alert, animated: true, completion: nil)
                }
            }
        }
    }
    
    func keyboardWillShow(notification: NSNotification) {
        print("Keyboard will show!")
        if let keyboardRect = notification.userInfo?[UIKeyboardFrameBeginUserInfoKey]?.CGRectValue {
            suggestionsBottomConstraint.constant = keyboardRect.height
            suggestionsHeightConstraint.constant = view.frame.height - keyboardRect.height - 64
            UIView.animateWithDuration(0.4, delay: 0, options: .CurveEaseOut, animations: {
                self.view.layoutIfNeeded()
                }, completion: nil)
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        print("Keyboard will hide!")
        suggestionsHeightConstraint.constant = view.frame.height - 64
        suggestionsBottomConstraint.constant = view.frame.height
        UIView.animateWithDuration(0.4, delay: 0, options: .CurveEaseIn, animations: {
            self.view.layoutIfNeeded()
            }, completion: nil)
    }
    
    override func viewDidAppear(animated: Bool) {
        let value = UIInterfaceOrientation.Portrait.rawValue
        UIDevice.currentDevice().setValue(value, forKey: "orientation")
        darkenSeenCells()
    }
    
    func darkenSeenCells() {
        for rawCell in collectionView!.visibleCells() {
            if let cell = rawCell as? ImageCell {
                let indexPath = collectionView!.indexPathForCell(cell)!
                if currentImages[indexPath.row].id == seenImagesIDs.last {
                    cell.alpha = 0.6
                    collectionView!.performBatchUpdates( {
                        self.collectionView!.reloadItemsAtIndexPaths([indexPath])
                    }, completion: nil)
                }
            }
        }
    }
    
    func saveSeenImage(id id: String) {
        seenImagesIDs.append(id)
    }

    func dismissKeyboard() {
        print("Dismissing keyboard!")
        tagsField.resignFirstResponder()
    }
    
    func reloadImages() {
        collectionView!.reloadData()
    }
    
    func startLoadingAnimation() {
        loadingLabel.hidden = false
        loadingShimmeringView.shimmering = true
        loadingShimmeringView.shimmeringBeginFadeDuration = 0.6
        loadingShimmeringView.shimmeringOpacity = 0.85
    }
    
    func stopLoadingAnimation() {
        loadingLabel.hidden = true
        loadingShimmeringView.shimmering = false
    }
    
    func showDetail(index: Int) {
        selectedImage = currentImages[index]
        performSegueWithIdentifier("showDetail", sender: self)
    }
    
    func textChanged(_: UITextField) {
        suggestionsTableView.reloadData()
    }
    
    @IBAction func editingEnded(sender: AnyObject) {
        print("Enter pressed!")
        seenImagesIDs = []
        tagsField.resignFirstResponder()
        currentImages = []
        collectionView!.reloadData()
        startLoadingAnimation()
        api.getImages(tags: arrayWithString(tagsField.text!)) { (images) in
            self.currentImages = images
            self.stopLoadingAnimation()
            self.reloadImages()
        }
    }
    
    @IBAction func editingBegan(sender: AnyObject) {
        print("Editing began!")
    }
    
    private func arrayWithString(string: String) -> [String] {
        return string.characters.split{$0 == " "}.map(String.init)
    }
    
    private func getLastWord(sentence: String) -> String? {
        
        let sentenceArray = sentence.characters.split{$0 == " "}.map(String.init)
        
        if let word = sentenceArray.last {
            return word
        } else {
            return nil
        }
        
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if segue.identifier == "showDetail" {
            let destination = segue.destinationViewController as! DetailViewController
            
            destination.delegate = self
        }
        
    }

}

// MARK: - Collection Data Source

extension ViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("cell", forIndexPath: indexPath) as! ImageCell
        let image = currentImages[indexPath.row]
        
        cell.imageView.alpha = 1
        cell.imageView.image = nil
        cell.imageView.hnk_setImageFromURL(image.previewURL)
        
        if seenImagesIDs.contains(image.id) {
            cell.imageView.alpha = 0.6
        }
        
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return currentImages.count
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        print("Image selected!")
        
        let image = currentImages[indexPath.row]
        
        seenImagesIDs.append(image.id)
        
        collectionView.deselectItemAtIndexPath(indexPath, animated: false)
        showDetail(indexPath.row)
    }
    
}

extension ViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        
        let size = (view.bounds.width / 4) - 3.0
        
        return CGSize(width: size, height: size)
        
    }
    
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        currentSuggestions = []
        
        if !(tagsField.text!.characters.last == " " || tagsField.text! == "") {
            for suggestion in Tags.array {
                
                if let lastWord = getLastWord(tagsField.text!) {
                    if suggestion.hasPrefix(lastWord) {
                        currentSuggestions.append(suggestion)
                    }
                }
                
            }
            
            return currentSuggestions.count
        } else {
            return Tags.array.count
        }
        
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("suggestionCell")!
        
        cell.backgroundColor = UIColor.clearColor()
        cell.textLabel!.textColor = UIColor.whiteColor()
        cell.selectionStyle = .Gray
        
        if !(tagsField.text!.characters.last == " " || tagsField.text!.characters.last == "-" || tagsField.text!.characters.count == 0) {
            cell.textLabel!.text = currentSuggestions[indexPath.row]
        } else {
            cell.textLabel!.text = Tags.array[indexPath.row]
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let selectedTag = tableView.cellForRowAtIndexPath(indexPath)!.textLabel!.text!
        let currentText = tagsField.text!
        let lastWord = getLastWord(currentText)
        
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        if lastWord != nil && !(currentText.characters.last == " " || currentText.characters.last == "-") {
            tagsField.text = currentText.chopSuffix(lastWord!.characters.count) + selectedTag + " "
        } else {
            tagsField.text = currentText + selectedTag + " "
        }
        
        textChanged(tagsField)
        tableView.setContentOffset(CGPointZero, animated:true)
    }
    
}
