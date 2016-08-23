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
import KituraSys
import CouchDB
import LoggerAPI
import HeliumLogger
import SwiftyJSON
import CloudFoundryEnv

// Disable all buffering on stdout
setbuf(stdout, nil)

///
/// Because bridging is not complete in Linux, we must use Any objects for dictionaries
/// instead of AnyObject. The main branch SwiftyJSON takes as input AnyObject, however
/// our patched version for Linux accepts Any.
///
#if os(OSX)
typealias JSONDictionary = [String: AnyObject]
#else
typealias JSONDictionary = [String: Any]
#endif

// Logger
Log.logger = HeliumLogger()

// Define "global" variables for module
let router: Router = Router()
let couchDBConnProps: ConnectionProperties
let database: Database

do {
  // Create configuration objects
  let config = try Configuration()
  couchDBConnProps = try config.getCouchDBConnProps()

  // Create cloudant access database object
  let dbClient = CouchDBClient(connectionProperties: couchDBConnProps)
  database = dbClient.database("skylink")


  // Define routes
  Log.verbose("Defining routes for server...")
  defineRoutes()
  
  // Start server...
  Kitura.addHTTPServer(onPort: config.appEnv.port, with: router)
  Kitura.run()
} catch Configuration.Error.IO {
  Log.error("Oops, something went wrong... Server did not start!")
  exit(1)
}
