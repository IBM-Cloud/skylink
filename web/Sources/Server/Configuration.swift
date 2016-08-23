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
import CouchDB
import SwiftyJSON
import LoggerAPI
import CloudFoundryEnv

public struct Configuration {

  /**
   Enum used for Configuration errors

   - IO: case to indicate input/output error
   */
  public enum Error: ErrorProtocol {
    case IO(String)
  }

  // Instance constants
  let configurationFile = "cloud_config.json"
  let appEnv: AppEnv

  init() throws {
    let path = Configuration.getAbsolutePath(relativePath: "/\(configurationFile)", useFallback: false)

    if let finalPath = path, configData = NSData(contentsOfFile: finalPath) {
      let configJson = JSON(data: configData)
      appEnv = try CloudFoundryEnv.getAppEnv(options: configJson)
      Log.info("Using configuration values from '\(configurationFile)'.")
    } else {
      Log.warning("Could not find '\(configurationFile)'.")
      appEnv = try CloudFoundryEnv.getAppEnv()
    }
  }

  /**
   Method to get CouchDB credentials in a consumable form

   - throws: error when method can't get credentials

   - returns: Encapsulated ConnectionProperties object with the necessary info
   */
  func getCouchDBConnProps() throws -> ConnectionProperties {
    if let couchDBCredentials = appEnv.getService(spec: "Skylink-Cloudant")?.credentials {
      if let host = couchDBCredentials["host"].string,
      user = couchDBCredentials["username"].string,
      password = couchDBCredentials["password"].string,
      port = couchDBCredentials["port"].int {
        let connProperties = ConnectionProperties(host: host, port: Int16(port), secured: true, username: user, password: password)
        return connProperties
      }
    }
    throw Error.IO("Failed to obtain database service and/or its credentials.")
  }

  private static func getAbsolutePath(relativePath: String, useFallback: Bool) -> String? {
    let initialPath = #file
    let components = initialPath.characters.split(separator: "/").map(String.init)
    let notLastThree = components[0..<components.count - 3]
    var filePath = "/" + notLastThree.joined(separator: "/") + relativePath

    #if os(Linux)
      let fileManager = NSFileManager.defaultManager()
    #else
      let fileManager = FileManager.default()
    #endif

    if fileManager.fileExists(atPath: filePath) {
      return filePath
    } else if useFallback {
      // Get path in alternate way, if first way fails
      let currentPath = fileManager.currentDirectoryPath
      filePath = currentPath + relativePath
      if fileManager.fileExists(atPath: filePath) {
        return filePath
      } else {
        return nil
      }
    } else {
      return nil
    }
  }

}
