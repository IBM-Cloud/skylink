// Libraries
var express = require( 'express' );
var jsonfile = require( 'jsonfile' );
var request = require( 'request' );
var watson = require('watson-developer-cloud');
var fs = require('fs');
var Cloudant = require('cloudant');

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



// Start listening
var port = ( process.env.VCAP_APP_PORT || 3000 );
app.listen( port );
console.log( 'Application is listening at: ' + port );



require("cf-deployment-tracker-client").track();