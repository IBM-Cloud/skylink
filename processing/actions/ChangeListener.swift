/**
  *
  * main() will be invoked when you Run This Action.
  * 
  * @param Whisk actions accept a single parameter,
  *        which must be a JSON object.
  *
  * In this case, the params variable will look like:
  *     { "message": "xxxx" }
  *
  * @return The return value must also be JSON.
  *         It will be the output of this action.
  *
  * This uses the experimental KituraNet networking libraries for Swift on Linux
  */

import KituraNet
import Dispatch
import Foundation

func main(args:[String:Any]) -> [String:Any] {


    let type: String? = args["type"] as? String

    if (type! == "overwatch.image" && args["analysis"] == nil) {

      let targetNamespace: String? = args["targetNamespace"] as? String
      let imageId: String? = args["_id"] as? String
      print("begin analysis for document: \(imageId!)")

      Whisk.invoke(actionNamed: "/\(targetNamespace!)/skylink-swift/processImage", withParameters: ["imageId": imageId!])
    } 
    
    
    return args
}