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
 * - alchemyKey: "123456"
 * - watsonUsername: "username"
 * - watsonPassword: "password"
 * - doc: "image document in cloudant"
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

  if (args.hasOwnProperty("doc")) {
    var imageDocumentId = args.doc._id;
    console.log("[", imageDocumentId, "] Processing image.jpg from document");
    var cloudant = require("cloudant")(args.cloudantUrl);
    var db = cloudant.db.use(args.cloudantDbName);

    // use image id to build a unique filename
    var fileName = imageDocumentId + "-image.jpg";
    var docRef = undefined
    var thumbFileName = imageDocumentId + "-thumbnail.jpg";

    var async = require('async')
    async.waterfall([
      // get the image document from the db
      function (callback) {
        console.log("retrieving document from cloudant")
        db.get(imageDocumentId, {
          include_docs: true
        }, function (err, document) {
          console.log("RETRIEVED DOCUMENT: " + JSON.stringify(document))
          docRef = document
          callback(err, document);
        });
      },
      
      // get the image binary
      function (document, callback) {
        console.log("retrieving image binary")
        db.attachment.get(document._id, "image.jpg").pipe(fs.createWriteStream(fileName))
          .on("finish", function () {
            callback(null, document);
          })
          .on("error", function (err) {
            callback(err);
          });
      },
      
      // generate the thumbnail image
      function (document, callback) {
        console.log("generating thumbnail")
          processThumbnail(args, fileName, thumbFileName, function (err) {
          if (err) {
            callback(err);
          } else {
            callback(null, document);
          }
        });
      },
        
      // trigger the analysis on the image file (only on un-analyzed document changes)
      function (document, callback) {
        console.log("processing & analyzing image")
          processImage(args, fileName, function (err, analysis) {
          if (err) {
            callback(err);
          } else {
            callback(null, document, analysis);
          }
        });
      },
      // write result in the db
      function (document, analysis, callback) {
          docRef.analysis = analysis
          //document._rev = document.rev
          console.log("Updating document: " + docRef._id + ", rev: " + docRef._rev)
          db.insert(docRef, function (err, body, headers) {
            
            if (err) {
              callback(err);
            } else {
              callback(null, body, analysis);
            }
          });
      },
    
      //insert thumbnail into cloudant
      function (document, analysis, callback) {
        
        console.log("saving thumbnail: " + thumbFileName + " to:")
        console.log(document)
        
        fs.readFile(thumbFileName, function(err, data) {
        if (err) {
            callback(err);
        } else {
                db.attachment.insert(document.id, 'thumbnail.jpg', data, 'image/jpg',
            {rev:document.rev}, function(err, body) {
                    console.log("insert complete");
                    console.log(body);
                    
                    //remove thumb file after saved to cloudant        
                    var fs = require('fs');
                        fs.unlink(thumbFileName);
                        
                    if (err) {
                        console.log(err);
                        callback(err, body, analysis);
                    } else {
                        console.log("saved thumbnail");
                        callback(null, body, analysis);
                    }
                });
            } 
        });  
     },
     
     //generate thumbnails for each face that is detected
     function (newDocument, analysis, callback) {
          
          /*setTimeout(function() {
            console.log("generate faces");
            callback(null, analysis);    
          }, 500)*/
          
          processFaces(newDocument, fileName, db, analysis, function (err) {
              var fs = require('fs');
              fs.unlink(fileName);
              callback(null, analysis);
          });    
      },
    ],
     
      
    
     function (err, analysis) {
      if (err) {
        console.log("[", imageDocumentId, "] KO", err);
        mainCallback(err);
      } else {
        console.log("[", imageDocumentId, "] OK");
        mainCallback(null, analysis);
      }
    });
    return true;
  } else {
    console.log("Parameter 'doc' not found", args);
    mainCallback("Parameter 'doc' not found");
    return false;
  }
}


/**
 * Prepares and analyzes the image.
 * processCallback = function(err, analysis);
 */
function processFaces(document, fileName, db, analysis, processCallback) {
    console.log("processing detected faces...");
         
    var fs = require('fs');
    
    if (analysis && analysis.hasOwnProperty("face_detection")) {
        console.log("analysis has face_detection");
            
        var faceIndex = -1,
            facesToProcess = analysis.face_detection.imageFaces,
            latestDocument = document;
        
        //iteratively create images for each face that is detected
        var inProgressCallback = function (err) {
            console.log("inside inProgressCallback");
            faceIndex++;
        
            if (err) {
                processCallback( err );
                console.log(err)
            } else {
                if (faceIndex < facesToProcess.length) {
                    console.log('generating face ' + (faceIndex+1) + " of " + facesToProcess.length);
                    generateFaceImage(fileName, facesToProcess[faceIndex], "face" + faceIndex +".jpg", function(err, faceImageName) {
                        
                        if (err) {
                            inProgressCallback(err);
                        } else {
                        
                        //save to cloudant
                        console.log("saving face image: " + faceImageName)
                            fs.readFile(faceImageName, function(readErr, data) {
                            if (readErr) {
                                inProgressCallback(err);
                            } else {
                                    db.attachment.insert(latestDocument.id, faceImageName, data, 'image/jpg',
                                {rev:latestDocument.rev}, function(saveErr, body) {
                                        console.log("insert complete");
                                        console.log(body);
                                        latestDocument = body;
                                        
                                        //remove thumb file after saved to cloudant        
                                        var fs = require('fs');
                                            fs.unlink(faceImageName);
                                            
                                        console.log("saved thumbnail");
                                        inProgressCallback(saveErr);
                                        
                                    });
                                } 
                            });  
                        
                        }     
                    });
                } else {
                    processCallback(null)
                }
            }
        }
        
        inProgressCallback(null);
    }  ;
}

/**
 * Prepares the image, resizing it if it is too big for Watson or Alchemy.
 * prepareCallback = function(err, fileName);
 */
function generateFaceImage(fileName, faceData, faceImageName, callback) {
   
    console.log('inside generateFaceImage');
    var
        fs = require('fs'),
        async = require('async'),
        gm = require('gm').subClass({
        imageMagick: true
        });
    
    gm(fileName)
        .crop(faceData.width, faceData.height, faceData.positionX, faceData.positionY)
        .write(faceImageName, function (err) {
            if (err) {
                console.log(err);
                callback( err );
            } else {
                console.log('face image generation done: ' + faceImageName);
                callback(null, faceImageName);
            }
        });
}


/**
 * Prepares and analyzes the image.
 * processCallback = function(err, analysis);
 */
function processThumbnail(args, fileName, thumbFileName, processCallback) {
    generateThumbnail(fileName, thumbFileName, function (err) {
             
        //save to cloudant
        processCallback(err, thumbFileName);
  });
}

/**
 * Prepares the image, resizing it if it is too big for Watson or Alchemy.
 * prepareCallback = function(err, fileName);
 */
function generateThumbnail(fileName, thumbFileName, callback) {
    var
        fs = require('fs'),
        async = require('async'),
        gm = require('gm').subClass({
        imageMagick: true
        });
    
    gm(fileName)
        .resize(200, 200)
        .write(thumbFileName, function (err) {
            if (err) {
                callback( err );
                console.log(err)
            } else {
                
                console.log('thumb generation done');
                callback(null, thumbFileName);
            }
        });
}


/**
 * Prepares and analyzes the image.
 * processCallback = function(err, analysis);
 */
function processImage(args, fileName, processCallback) {
  prepareImage(fileName, function (prepareErr, prepareFileName) {
    if (prepareErr) {
      processCallback(prepareErr, null);
    } else {
        analyzeImage(args, prepareFileName, function (err, analysis) {
            processCallback(err, analysis);
        });
    }
  });
}

/**
 * Prepares the image, resizing it if it is too big for Watson or Alchemy.
 * prepareCallback = function(err, fileName);
 */
function prepareImage(fileName, prepareCallback) {
  var
    fs = require('fs'),
    async = require('async'),
    gm = require('gm').subClass({
      imageMagick: true
    });

  async.waterfall([
    function (callback) {
      // Retrieve the file size
      fs.stat(fileName, function (err, stats) {
        if (err) {
          callback(err);
        } else {
          callback(null, stats);
        }
      });
    },
    // Check if size is OK
    function (fileStats, callback) {
      if (fileStats.size > 900 * 1024) {
        // Resize the file
        gm(fileName).define("jpeg:extent=900KB").write(fileName + ".jpg",
          function (err) {
            if (err) {
              callback(err);
            } else {
              // Process the modified file
              callback(null, fileName + ".jpg");
            }
          });
      } else {
        callback(null, fileName);
      }
    }
  ], function (err, fileName) {
    prepareCallback(err, fileName);
  });
}

/**
 * Analyzes the image stored at fileName with the callback onAnalysisComplete(err, analysis).
 * analyzeCallback = function(err, analysis);
 */
function analyzeImage(args, fileName, analyzeCallback) {
  var
    request = require('request'),
    async = require('async'),
    fs = require('fs'),
    gm = require('gm').subClass({
      imageMagick: true
    }),
    analysis = {};

  async.parallel([
    function (callback) {
        // Write down meta data about the image
        gm(fileName).size(function (err, size) {
          if (err) {
            console.log("Image size", err);
          } else {
            analysis.size = size;
          }
          callback(null);
        });
    },
    function (callback) {
        // Call AlchemyAPI Face Detection passing the image in the request
        fs.createReadStream(fileName).pipe(
          request({
              method: "POST",
              url: "https://access.alchemyapi.com/calls" +
                "/image/ImageGetRankedImageFaceTags" +
                "?apikey=" + args.alchemyKey +
                "&imagePostMode=raw" +
                "&outputMode=json" +
                "&knowledgeGraph=1",
              headers: {
                'Content-Length': fs.statSync(fileName).size
              },
              json: true

            },
            function (err, response, body) {
              if (err) {
                console.log("Face Detection", err);
              } else {
                console.log("Face Detection:")
                console.log(body)
                analysis.face_detection = body;
              }
              callback(null);
            }))
    },
    function (callback) {
        // Call AlchemyAPI Image Keywords passing the image in the request
        fs.createReadStream(fileName).pipe(
          request({
              method: "POST",
              url: "https://access.alchemyapi.com/calls" +
                "/image/ImageGetRankedImageKeywords" +
                "?apikey=" + args.alchemyKey +
                "&imagePostMode=raw" +
                "&outputMode=json" +
                "&knowledgeGraph=1",
              headers: {
                'Content-Length': fs.statSync(fileName).size
              },
              json: true

            },
            function (err, response, body) {
              if (err) {
                console.log("Image Keywords", err);
              } else {
                console.log("Image Keywords:")
                console.log(body)
                analysis.image_keywords = body;
              }
              callback(null);
            }))
    },
    function (callback) {
        // Call Watson Visual Recognition passing the image in the request
        var params = {
          image_file: fs.createReadStream(fileName)
        }

        var watson = require('watson-developer-cloud')
        var visual_recognition = watson.visual_recognition({
          username: args.watsonUsername,
          password: args.watsonPassword,
          version: 'v1'
        })

        visual_recognition.recognize(params, function (err, body) {
          if (err) {
            console.log("Watson", err);
          } else {
            console.log("Watson:")
            console.log(body)
            analysis.visual_recognition = body;
          }
          callback(null);
        });
    }
  ],
    function (err, result) {
      analyzeCallback(err, analysis);
    }
  )
}
