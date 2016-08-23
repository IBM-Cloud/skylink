/**
 * Orchestration/workflow for image processing using OpenWhisk actions
 */

import KituraNet
import Dispatch
import Foundation
import SwiftyJSON

func main(args: [String:Any]) -> [String:Any] {

    var error:String = "";
    var returnValue:String = "";
    let imageId: String? = String(args["imageId"]!)
    let targetNamespace: String? = args["targetNamespace"] as? String

    let cloudantReadInvocation = Whisk.invoke(actionNamed: "/\(targetNamespace!)/skylink-swift/cloudantRead", withParameters: ["cloudantId": imageId!])
    let response = cloudantReadInvocation["response"] as! [String:Any]

    let payload = response["result"] as! [String:Any]
    let documentString:String = payload["document"] as! String

    print("[\(imageId!)] Processing");
    

    let documentData = documentString.data(using: NSUTF8StringEncoding, allowLossyConversion: true)!
    var document = JSON(data: documentData)

    // check if document was read from cloudant successfully
    // there *should not* be a value for documnet["error"] because if that key exists, 
    // then there is an error message being returned from cloudant
    if (document.exists() && !document["error"].exists()) {


        let cloudantUrl: String? = args["cloudantUrl"] as? String
        let dbName: String? = args["cloudantDbName"] as? String

        let attachmentImageUrl = "\(cloudantUrl!)/\(dbName!)/\(imageId!)/image.jpg"

        let watsonInvocation = Whisk.invoke(actionNamed: "/\(targetNamespace!)/skylink-swift/watsonAnalysis", withParameters: [
            "imageUrl": attachmentImageUrl
        ])
        let watsonResponse = watsonInvocation["response"] as! [String:Any]
        let watsonPayload = watsonResponse["result"] as! [String:Any]
        let classifyString:String = watsonPayload["image_classify"] as! String
        let facesString:String = watsonPayload["face_detection"] as! String

        let classifyData = classifyString.data(using: NSUTF8StringEncoding, allowLossyConversion: true)!
        let facesData = facesString.data(using: NSUTF8StringEncoding, allowLossyConversion: true)!

        document["analysis"] = JSON([:])
        document["analysis"]["image_classify"] = JSON(data: classifyData)
        document["analysis"]["face_detection"] = JSON(data: facesData)
        
        // write the results back to cloudant
        let cloudantWriteInvocation = Whisk.invoke(actionNamed: "/\(targetNamespace!)/skylink-swift/cloudantWrite", withParameters: [
            "cloudantId": imageId!,
            "cloudantBody": document.rawString()
        ])
        let writeResponse = cloudantWriteInvocation["response"] as! [String:Any]
        let writePayload = writeResponse["result"] as! [String:Any]
        let writeResultString:String = writePayload["cloudantResult"] as! String
        let writeData = writeResultString.data(using: NSUTF8StringEncoding, allowLossyConversion: true)!
        let writeJSON = JSON(data: writeData)

        if (writeJSON.exists() && !writeJSON["error"].exists()) {
            if(writeJSON["ok"] != true) {
                error = "Error writing to Cloudant: \(writeResultString)"
            }
            else {
                returnValue = "Processed image and wrote restults back to cloudant"
            }
        }

        // kickoff process to generate thumbnail(s)
        Whisk.invoke(actionNamed: "/\(targetNamespace!)/skylink-swift/generateThumbnails", withParameters: ["imageId": imageId!])

    } else {
        error = "Unable to fetch document from Cloudant"
        if (document["error"].exists()) {
            error = "\(error): \(documentString)"
        }
    }

    var result:[String:Any] = [
        "success":(error == ""),
        "response":returnValue
    ]
    if (error != "") {
        result["error"] = error;
    }

    return result
}
