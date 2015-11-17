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
        
        // Sets the height to (screen height - 64) (navigation) and the position above the screen
        suggestionsHeightConstraint.constant = view.frame.height - 64
        suggestionsBottomConstraint.constant = view.frame.height
        
        // Calls methods when the keyboard is shown and hidden
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
        
        // Sets up the suggestions table to communicate with this class
        suggestionsTableView.delegate = self
        suggestionsTableView.dataSource = self
        
        // Hide the loading label
        loadingLabel.hidden = true
        loadingShimmeringView.contentView = loadingLabel
        
        // Add target to tags field, to detect when the text changes
        tagsField.addTarget(self, action: "textChanged:", forControlEvents: .EditingChanged)
        
        // Checks the version for any updates
        checkVersion()
    }
    
    /// Checks the version, and shows an alert if there's a newer one.
    func checkVersion() {
        // This url points to a static page, which contains info about the latest version of the app
        let url = NSURL(string: "https://raw.githubusercontent.com/ViewerApp/ViewerApp/master/version.json")!
        let request = Alamofire.request(.GET, url)
        
        print("Checking version.")
        
        // This bit handles the response
        request.responseJSON { response in
            if let data = response.data {
                
                // Prints out any data recieved, for debugging purposes.
                print("Response recieved")
                print(data)
                
                // Accesses the app's defaults database. This is a simple way to persist data.
                let defaults = NSUserDefaults.standardUserDefaults()
                
                let json = JSON(data: data)
                
                print(json["version"].int!)
                
                // If the latest version number is different from the current version, and the user hasn't told us not to bother them about updates
                if self.currentVersion != json["version"].int! && !defaults.boolForKey("cantBotherAboutUpdates") {
                    
                    // All this just creates and shows the alert telling the user that there's an update available.
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
    
    /// Slides in the suggestions list when the keyboard is shown
    func keyboardWillShow(notification: NSNotification) {
        print("Keyboard will show!")
        if let keyboardRect = notification.userInfo?[UIKeyboardFrameBeginUserInfoKey]?.CGRectValue {
            // Makes sure the sizing is all correct for the suggestions, and slides it down to meet the keyboard
            suggestionsBottomConstraint.constant = keyboardRect.height
            suggestionsHeightConstraint.constant = view.frame.height - keyboardRect.height - 64
            UIView.animateWithDuration(0.4, delay: 0, options: .CurveEaseOut, animations: {
                self.view.layoutIfNeeded()
                }, completion: nil)
        }
    }
    
    /// Does the exact opposite of the above code
    func keyboardWillHide(notification: NSNotification) {
        print("Keyboard will hide!")
        suggestionsBottomConstraint.constant = view.frame.height
        suggestionsHeightConstraint.constant = view.frame.height - 64
        UIView.animateWithDuration(0.4, delay: 0, options: .CurveEaseIn, animations: {
            self.view.layoutIfNeeded()
            }, completion: nil)
    }
    
    /// Darkens seen images when the view appears
    override func viewDidAppear(animated: Bool) {
        darkenSeenCells()
    }
    
    /// This darkens all the images that have been seen
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
    
    /// "Sees" an image, so that it will be darkened next time 'round
    func saveSeenImage(id id: String) {
        seenImagesIDs.append(id)
    }
    
    /// Reloads the images, generally called after the completion of a search
    func reloadImages() {
        collectionView!.reloadData()
    }
    
    // Fairly self explanatory, this starts the loading animation
    func startLoadingAnimation() {
        loadingLabel.hidden = false
        loadingShimmeringView.shimmering = true
        loadingShimmeringView.shimmeringBeginFadeDuration = 0.6
        loadingShimmeringView.shimmeringOpacity = 0.85
    }
    
    // Opposite of above.
    func stopLoadingAnimation() {
        loadingLabel.hidden = true
        loadingShimmeringView.shimmering = false
    }
    
    // Called when the user taps on an image. This will show the view with a bigger version.
    func showDetail(index: Int) {
        selectedImage = currentImages[index]
        performSegueWithIdentifier("showDetail", sender: self)
    }
    
    /// Called when the text changes, and serves to reload the suggestions
    func textChanged(_: UITextField) {
        suggestionsTableView.reloadData()
    }
    
    /// Called when the user is done typing their query. Clears the images,
    /// starts the loading animation, and calls the api to get the images.
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
    
    /// Called when the editing begins. Really no purpose, so I'm marking it for
    /// removal when I can figure out what it's connected to in the interface.
    @IBAction func editingBegan(sender: AnyObject) {
        print("Editing began!")
    }
    
    /// Just a convenient shortcut for me. It makes an array out of a sentence.
    private func arrayWithString(string: String) -> [String] {
        return string.characters.split{$0 == " "}.map(String.init)
    }
    
    /// This gets the last word in a space separated sentence.
    private func getLastWord(sentence: String) -> String? {
        
        let sentenceArray = sentence.characters.split{$0 == " "}.map(String.init)
        
        if let word = sentenceArray.last {
            return word
        } else {
            return nil
        }
        
    }
    /// Prepares for the segue, setting the image that needs to be loaded in detail.
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if segue.identifier == "showDetail" {
            let destination = segue.destinationViewController as! DetailViewController
            
            destination.delegate = self
        }
        
    }

}

// TODO: Comment the rest of the class
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
