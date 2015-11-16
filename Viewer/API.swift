//
//  File.swift
//

import UIKit
import Alamofire
import SwiftyJSON

class Image: NSObject {
    
    let id: String
    let tags: [String]
    let previewURL: NSURL
    let fileURL: NSURL
    
    init (id: String, tags: [String], previewURL: NSURL, fileURL: NSURL) {
        self.id = id
        self.tags = tags
        self.previewURL = previewURL
        self.fileURL = fileURL
    }
    
    func printContents() {
        print("\(id)")
        print(tags)
        print(previewURL.absoluteString)
        print(fileURL.absoluteString)
    }
    
}

class API {
    
    let basePosts = NSURL(string: "https://e621.net/post/index.json")
    var currentRequest: Request?
    
    private func encodeString(string: String) -> String {
        return string.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
    }
    
    private func arrayWithString(string: String) -> [String] {
        return string.characters.split{$0 == " "}.map(String.init)
    }
    
    func getImages(tags tags: [String], completionHandler: (images: [Image]) -> ()) {
        
        print("getImages called")
        
        self.currentRequest?.cancel()
        
        var tagsString = ""
        
        for tag in tags {
            tagsString += encodeString(tag + " ")
        }
        
        let tagsQuery = "?tags=\(tagsString)"
        
        let url = NSURL(string: tagsQuery, relativeToURL: basePosts)!
        
        print("Sending Alamofire req. using this url: \(url.absoluteString)")
        let currentRequest = Alamofire.request(.GET, url)
        
        currentRequest.progress { bytesRead, totalBytesRead, totalBytesExpectedToRead in
            print("\(totalBytesRead) out of \(totalBytesExpectedToRead) bytes read")
        }
        
        currentRequest.responseJSON { response in
            
            guard response.response != nil else {
                print("Oops, something went wrong. Could be an issue with ATS?")
                return
            }
            
            if let code = response.response?.statusCode where code != 200 {
                print("Oops! Error: \(code)")
                return
            }
            
            let json = JSON(data: response.data!)
            var images: [Image] = []
            
            // print("Response recieved, here's the payload:")
            // print(response.data!)
            
            for (_, subJson): (String, JSON) in json {
                
                if subJson["file_ext"] == "jpg" || subJson["file_ext"] == "png" || subJson["file_ext"] == "jpeg" {
                    // I'm so, so sorry about this. I'll try to break it up into
                    // manageable chunks for you. Sorry again
                    images.append( Image(id: subJson["id"].stringValue,
                        tags: self.arrayWithString(subJson["tags"].stringValue),
                        previewURL: NSURL(string: subJson["preview_url"].stringValue)!,
                        fileURL: NSURL(string: subJson["file_url"].stringValue)!))
                }
            }
            
            // print("These are the images created from the response")
            // print("")
            
            // for image in images {
            //     image.printContents()
            //     print("")
            // }
            
            print("Passing to completion handler")
            
            completionHandler(images: images)
            
        }
    }
    
}
