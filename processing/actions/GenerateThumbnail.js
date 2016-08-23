/**
  * generate thumbnail image
  */

function main(args) {
  if (mainImpl(args, function (err, result) {
      if (err) {
        whisk.error(err);
      } else {
        whisk.done({"processing":"complete"}, null);
      }
    })) {
    return whisk.async();
  }
}



var latestDocument = undefined;
/**
 * Uses a callback so that this same code can be imported in another JavaScript
 * to test the function outside of OpenWhisk.
 * 
 * mainCallback(err, analysis)
 */
function mainImpl(args, mainCallback) {
    var fs = require('fs')
    var request = require('request')

    var imageDocumentId = args.imageId;
    console.log("[", imageDocumentId, "] Processing image.jpg from document");
    var cloudant = require("cloudant")(args.cloudantUrl);
    var db = cloudant.db.use(args.cloudantDbName);

    // use image id to build a unique filename
    var fileName = imageDocumentId + "-image.jpg";
    var docRef = undefined;
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
            callback(null, docRef);
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
                    callback(null, docRef);
                }
            });
        },

        //insert thumbnail into cloudant
        function (document, callback) {
        
        console.log("saving thumbnail: " + thumbFileName + " to:")
        console.log(callback)

        fs.readFile(thumbFileName, function(err, data) {
            if (err) {
                callback(err);
            } else {
                db.attachment.insert(docRef._id, 'thumbnail.jpg', data, 'image/jpg',
                    {rev:docRef._rev}, function(err, body) {
                    console.log("insert complete");

                    latestDocument = body;
                    console.log(body)
                    
                    //remove thumb file after saved to cloudant        
                    var fs = require('fs');
                        fs.unlink(thumbFileName);
                        
                    if (err) {
                        console.log(err);
                        callback(err, docRef) 
                    } else {
                        console.log("saved thumbnail");
                        callback(null, docRef);
                    }
                });
            } 
        });  
        },
        
        //generate thumbnails for each face that is detected
        function (newDocument, callback) {
            
            
            processFaces(newDocument, fileName, db, docRef.analysis, function (err) {
                var fs = require('fs');
                fs.unlink(fileName);
                callback(null);
            });    
        },
    ],
        
        

    function (err) {
        if (err) {
            console.log("[", imageDocumentId, "] KO", err);
            mainCallback(err);
        } else {
            console.log("[", imageDocumentId, "] OK");
            mainCallback(null, true);
        }
    });
    return true;
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
            facesToProcess = [];

        if (analysis.face_detection.images){
          if (analysis.face_detection.images.length > 0) {
            var images = analysis.face_detection.images;
            if (images[0].faces) { 
              facesToProcess = analysis.face_detection.images[0].faces;
            }
          }
        }
        
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
                                    console.log(latestDocument.id, latestDocument.rev, faceImageName)
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

    var face_location = faceData["face_location"];
    
    gm(fileName)
        .crop(face_location.width, face_location.height, face_location.left, face_location.top)
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
