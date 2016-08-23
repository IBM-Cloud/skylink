/**
* Copyright IBM Corporation 2016
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import Foundation
import Kitura
import KituraNet
import CouchDB
import LoggerAPI
import SwiftyJSON
import KituraSys

enum DataAccessError: ErrorProtocol {
    case Document(String)
    case Attachment(String)
}

struct Skylink {
    static let Domain = "Skylink-Server"
    /**
     Enum error specifically for Domain app
     
     - Internal: used to indicate internal error of some sort
     - Other:    any other type of error
     */
    enum Error: Int {
        case Internal = 1
        case Other
    }
}

func generateInternalError() -> NSError {
    return NSError(domain: "Skylink", code: 500, userInfo: [NSLocalizedDescriptionKey: String(Skylink.Error.Internal)])
}

/**
* Function for setting up the different routes for this app.
*/
func defineRoutes() {
    
    router.all("/static", middleware: StaticFileServer(path: "./web-static"))

    router.get("/") { request, response, next in
        do {
            try response.redirect("/static/index.html")
        } catch {
            Log.error("Problem redirecting static content.")
        }
    }
    
    router.get("/list") { request, response, next in
        let queryParams: [Database.QueryParameters] = []
        database.queryByView("overwatch.images", ofDesign: "overwatch.images", usingParameters: queryParams) { (document, error) in
            
            if let document = document where error == nil {
                do {
                    // Get rows from JSON result document
                    guard var docs: [JSON] = document["rows"].array else {
                        throw DataAccessError.Document("Documents could not be retrieved from database!")
                    }
                    
                    docs.sort {
                        let doc1: JSON = $0
                        let doc2: JSON = $1
                        return doc1["key"]["sort"].intValue > doc2["key"]["sort"].intValue
                    }
                    
                    var result = [JSONDictionary]()
                    
                    for doc: JSON in docs {
                        var item : JSONDictionary = JSONDictionary()
                        item["id"] = doc["id"].string
                        item["analysis"] = (doc["key"]["analysis"] == nil) ? false : true
                        item["timestamp"] = doc["key"]["timestamp"].string
                        result.append(item)
                    }
                    
                    // Send list to client
                    var resultDocument = JSON([:])
                    resultDocument["records"] = JSON(result)
                    resultDocument["number_of_records"].int = result.count
                    response.status(HTTPStatusCode.OK).send(json: resultDocument)
                } catch {
                    Log.error("Failed to obtain tags from database.")
                    response.error = generateInternalError()
                }
            } else {
                Log.error("Failed to obtain docs list from database.")
                response.error = generateInternalError()
            }
            next()
        }
    }
    
    
    router.get("/detail/:documentId") { request, response, next in
        guard let documentId = request.parameters["documentId"] else {
            response.error = generateInternalError()
            next()
            return
        }
        
        database.retrieve( documentId )
            { (document, error) in
            
            if let document = document where error == nil {
                response.status(HTTPStatusCode.OK).send(json: document)
            } else {
                Log.error("Failed to obtain docus list from database.")
                response.error = generateInternalError()
            }
            next()
        }
    }
    
    
    
    
    router.get("/detail/:documentId/attachments/:fileName") { request, response, next in
        guard let documentId = request.parameters["documentId"], let fileName = request.parameters["fileName"] else {
            response.error = generateInternalError()
            next()
            return
        }
        
        print(documentId, fileName)
        
        database.retrieveAttachment( documentId, attachmentName:fileName )
        { (attachment, error, contentType) in
            if let attachment = attachment where error == nil {
                do {
                    print("writing response")
                    response.status(HTTPStatusCode.OK).send(data: attachment)
                } catch {
                    Log.error("Failed to retrieve attachment.")
                    response.error = generateInternalError()
                }
            } else {
                Log.error("Failed to retrieve attachment.")
                response.error = generateInternalError()
            }
            next()
        }
    }

}
