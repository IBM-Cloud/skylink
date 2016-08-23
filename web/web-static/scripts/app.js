
var templates = {};

function loadTemplate(target) {
    var template = $('#' + target).html();
    templates[target] = template
    Mustache.parse( template );
}

var listData = {}
var currentDoc = {}

function fetchList() {
    showLoadingAnimation();
    console.log( "fetching list..." );
    $.ajax( {
        type: 'GET',
        url:"/list"
    } )
    .done(function(result) {

        listData = result;
        var rendered = Mustache.render(templates['listTemplate'], listData); 
        $("#content").html(rendered)
        $("img.lazy").lazyload();
        $("div.listCell").click(onListCellClick)
    })
    .fail(function( jqXHR, status, error ) {
        console.log( "Request failed: " + status );
        var rendered = Mustache.render(templates['errorTemplate'], {
            error:"Request failed: " + error.toString()
        }); 
        $("#content").html(rendered)
    });
}


function onListCellClick(event) {
    var docId = $(event.currentTarget).attr("id");
    appendHistory(docId);
    fetchDetail(docId);
}

function fetchDetail(docId) {
    showLoadingAnimation();
    console.log(docId);
    $.ajax( {
        type: 'GET',
        url:"/detail/"+docId
    } )
    .done(function(result) {

        currentDoc = result;

        currentDoc.hideCameraDetail = (currentDoc.cameraPitch == 0.0 && currentDoc.cameraHeading == 0.0 && currentDoc.heading != 0.0);
        currentDoc.cameraPitch = currentDoc.cameraPitch * -1;

        if (currentDoc.analysis && currentDoc.analysis.face_detection && currentDoc.analysis.face_detection.images && currentDoc.analysis.face_detection.images.length > 0 && currentDoc.analysis.face_detection.images[0].faces) {
            var faces = currentDoc.analysis.face_detection.images[0].faces;
            faces.forEach(function(name, index) {
                faces[index].index = index;
            });
        }

        console.log(result)
        var rendered = Mustache.render(templates['detailTemplate'], currentDoc); 
        $("#content").html(rendered)
        loadMap(currentDoc)
    })
    .fail(function( jqXHR, status, error ) {
        console.log( "Request failed: " + status );
        var rendered = Mustache.render(templates['errorTemplate'], {
            error:"Request failed: " + error.toString()
        }); 
        $("#content").html(rendered)
    });
}

function showLoadingAnimation() {
    var rendered = Mustache.render(templates['loadingTemplate'], currentDoc); 
    $("#content").html(rendered)
}




function appendHistory(docId) {
    if (docId) {
        history.pushState(undefined, undefined, "index.html?docId="+docId)
    } else {
        history.pushState(undefined, undefined, "index.html")
    }
}

function headerLinkClick(event){

    appendHistory();
    fetchList();

    event.preventDefault();
    return false;
}

function onPopState(event) {
    console.log(event, window.location.search);

    var docId = findDocId();
    if (docId) {
        fetchDetail(docId);
    } else {
        fetchList();
    }
}

function findDocId() {
    var docId = window.location.search.replace("?docId=", "");
    if (docId && docId.length > 0) {
        return docId;
    } 
    return undefined;
}

$(document).ready(function(){
    loadTemplate("listTemplate");
    loadTemplate("detailTemplate");
    loadTemplate("loadingTemplate");
    loadTemplate("errorTemplate");

    $("#headerLink").click(headerLinkClick);
    $(window).on("popstate", onPopState);

    var docId = findDocId();
    if (docId) {
        fetchDetail(docId);
    } else {
        fetchList();
    }
})
