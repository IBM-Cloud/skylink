// Libraries
var express = require( 'express' );
var jsonfile = require( 'jsonfile' );
var request = require( 'request' );
var watson = require('watson-developer-cloud');
var fs = require('fs');
var Cloudant = require('cloudant');
var gm = require('gm').subClass({
      imageMagick: true
    });
var archiver = require('archiver');

// Load credentials
// From Bluemix configuration or local file
var environment, cloudantCredentials, vrCredentials;
if( process.env.VCAP_SERVICES ) {
    environment = JSON.parse( process.env.VCAP_SERVICES );    
} else {
    environment = jsonfile.readFileSync( 'configuration.json' );
}

cloudantCredentials = environment['cloudantNoSQLDB'][0].credentials
vrCredentials = environment['watson_vision_combined'][0].credentials

// Initialize Cloudant DB
var cloudant = Cloudant(cloudantCredentials.url);
var db
var dbName = "overwatch"

cloudant.db.create(dbName, function() {
    // Specify the database we are going to use (alice)...
    db = cloudant.db.use(dbName)
});

// Web server
var app = express();
app.set('view engine', 'jade');


app.use( '/public', express.static( __dirname + '/public' ) );


app.get('/', function (req, res) {
    //for now just returning all images.  
    //in the real world you would want to filter this list or truncate/page it
    
    db.view( 'overwatch.images',  'overwatch.images', function(err, body) {
        if (err) {
            res.status(404).send(err.toString());
            return;
        }
        //this should really be sorted on the database 
        body.rows = body.rows.sort(sortList)
        res.render("list", { body:body});
    })
});

app.get('/:id?/', function (req, res) {
    var id = req.params.id;
    db.get(id,function(err, body) {
        if (err) {
            res.status(404).send(err.toString());
            return;
        }
        res.render("detail", { body:body});
    });
});

app.get('/:id?/attachments/:fileName?', function (req, res) {
    var id = req.params.id;
    var fileName = req.params.fileName;
    db.attachment.get(id, fileName).pipe(res);
});

function sortList(a, b) {
    //return newest first
    if (a.key.sort > b.key.sort) {
        return -1;
    }
    if (a.key.sort < b.key.sort) {
        return 1;
    }
    return 0;
}


//handle custom classifier retrain request
app.post('/:id?/retrain/:posneg?/:classifierId?/:classifierClass?', function (req, res) {
    var id = req.params.id;
    var posneg = req.params.posneg;
    var classifierId = req.params.classifierId;
    var classifierClass = req.params.classifierClass;
    var currentTime = new Date().getTime()

    if (posneg == "positive" || posneg == "negative"){
        //console.log(id, posneg, classifierId, classifierClass)
        console.log("retraining")

        var rootDir = './temp';
        var dir = rootDir + "/" + currentTime;

        if (!fs.existsSync(rootDir)){
            fs.mkdirSync(rootDir);
        }
        if (!fs.existsSync(dir)){
            fs.mkdirSync(dir);
        }

        var tempFile = dir + "/" + id + ".jpg";
        var resizedFile = dir + "/" + id + "-resize.jpg";
        var zipFile = dir + "/" + id + ".zip";

        var cleanup = function() {
            console.log("cleanup");
            fs.unlink(tempFile, function (err) { })
            fs.unlink(resizedFile, function (err) { })
            fs.unlink(zipFile, function (err) { })
            fs.rmdir(dir, function (err) { })
        }

        db.attachment.get(id, "image.jpg", function(err, attachmentBody) {
            if (err) {
                res.status(500).send(err.toString());
                cleanup();
            } else {
                //write image to disk
                fs.writeFileSync(tempFile, attachmentBody);

                //resize image
                gm(tempFile).define("jpeg:extent=900KB").write(resizedFile,
                function (err) {
                    if (err) {
                        res.status(500).send(err.toString());
                        cleanup();
                    } 

                    //create zip containing the image so we can send it to watson
                    var output = fs.createWriteStream(zipFile);
                    var archive = archiver('zip');
                    archive.pipe(output);

                    archive.on('error', function(err) {
                        res.status(500).send(err.toString());
                        cleanup();
                    });

                    archive.on('finish', function(err) {

                        //post positive-reinforcement data to Visual Recognition classifier
                        var formData = {
                            api_key:vrCredentials.api_key,
                            version:"2016-05-20"
                        };

                        if (posneg == "positive") {
                            formData[classifierClass + "_positive_examples"] = fs.createReadStream(zipFile);
                        }
                        else {
                            formData[classifierClass + "_positive_examples"] = fs.createReadStream("./training/tennis_positive.zip");
                            formData["negative_examples"] = fs.createReadStream(zipFile);
                        }
                        var url = "https://gateway-a.watsonplatform.net/visual-recognition/api/v3/classifiers/" + classifierId +"?api_key=" + vrCredentials.api_key + "&version=2016-05-20";

                        request.post({url:url, formData: formData}, function optionalCallback(err, httpResponse, body) {
                            if (err) {
                                res.status(500).send(err.toString());
                            } else {
                                var response = body.toString();
                                res.status(200).send(response);
                                console.log(response);
                            }
                            cleanup();
                        });

                    });

                    archive.file(resizedFile, { name: 'image.jpg' });
                    archive.finalize();
                });
            }
        });
    } else {
        res.status(500).send();
    }
});




// Start listening
var port = ( process.env.PORT || 3000 );
app.listen( port );
console.log( 'Application is listening at: ' + port );



require("cf-deployment-tracker-client").track();
