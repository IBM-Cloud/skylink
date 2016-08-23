/**
 * Run alchemy analysis
 */

import KituraNet
import Dispatch
import Foundation

func main(args:[String:Any]) -> [String:Any] {
       
    let watsonKey: String? = args["watsonKey"] as? String
    let imageUrl: String? = args["imageUrl"] as? String

    let classifyURL = "https://watson-api-explorer.mybluemix.net/visual-recognition/api/v3/classify?api_key=\(watsonKey!)&url=\(imageUrl!)&version=2016-05-19"
    let facesURL = "https://watson-api-explorer.mybluemix.net/visual-recognition/api/v3/detect_faces?api_key=\(watsonKey!)&url=\(imageUrl!)&version=2016-05-19"

    print(classifyURL)

    var classifyResponse = ""
    var facesResponse = ""

    HTTP.get(classifyURL) { response in
        do {
            classifyResponse = try response!.readString()!
        } catch {
            print("Error \(error)")
        }
    }

    HTTP.get(facesURL) { response in
        do {
            facesResponse = try response!.readString()!
        } catch {
            print("Error \(error)")
        }
    }


    let result:[String:Any] = [
        "image_classify": classifyResponse,
        "face_detection": facesResponse,
    ]

    
    return result
}
