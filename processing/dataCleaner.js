/**
 * Copyright 2016 IBM Corp. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the “License”);
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *  https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an “AS IS” BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * Called by Whisk.
 * 
 * It expects the following parameters as attributes of "args"
 * - cloudantUrl: "https://username:password@host"
 * - cloudantDbName: "openwhisk-darkvision"
 * - watsonKey: "123456"
 */
function main(args) {
  if (mainImpl(args, function (err, result) {
      if (err) {
        whisk.error(err);
      } else {
        whisk.done(result, null);
      }
    })) {
    return whisk.async();
  }
}

/**
 * Uses a callback so that this same code can be imported in another JavaScript
 * to test the function outside of OpenWhisk.
 * 
 * mainCallback(err, analysis)
 */
function mainImpl(args, mainCallback) {
    var fs = require('fs')
    var request = require('request')
    var async = require('async')

    var cloudant = require("cloudant")(args.cloudantUrl);
    var db = cloudant.db.use(args.cloudantDbName);

    var incremental = false;
    if (args["incremental"]) {
        incremental = true;
    }

    db.view( 'overwatch.images',  'overwatch.images', function(err, body) {
    //db.list(function(err, body) {
        console.log("row count: " + body.rows.length)

        if (!err) {
            var targetRequests = body.rows.length;
            var completedRequests = 0;
            var activeRequest = 0;
            var waterfallRequets = []
            
            body.rows.forEach(function(row) {
                activeRequest++;
                console.log("-------------------------------------------------");
                
                var doc = row.key
                
                if (!incremental || (!doc.analysis && incremental)) {

                    if (doc.analysis)
                        delete doc.analysis

                    var att = doc['_attachments']
                    doc._attachments = {
                        'image.jpg': att['image.jpg']
                    }
                    console.log(doc)

                    waterfallRequets.push(function(callback){
                        db.insert(doc, function(err, insertBody) {
                            completedRequests++;
                            console.log("completed " + completedRequests)

                            if (err) {
                                console.log("ERROR!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
                                console.log(err)
                                callback(err);
                            } else {
                                callback(null);
                            }
                        })
                    })
                }

                setTimeout( function(){
                    
                }, activeRequest*400)
            });

            async.waterfall(waterfallRequets, function (err, fileName) {
                console.log("DONE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
                whisk.done()
            });
        }

        
    });

    return whisk.async()

}
