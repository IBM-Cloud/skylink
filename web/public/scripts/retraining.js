

$(document).ready(function(){
    $("#positive").click(handleRetrain);
    $("#negative").click(handleRetrain);
})


function handleRetrain(event)  {
    var action = $(event.target).attr("id");
    var recordId = $(event.target).attr("data-id");
    var classifierId = $(event.target).attr("data-classifier-id");
    var classifierClass = $(event.target).attr("data-classifier-class");

    console.log(action, recordId, classifierId, classifierClass)
    var query = `#${classifierId}_${classifierClass} button`;
    $( query ).prop('disabled', true);
    $.ajax({
        url:`/${recordId}/retrain/${action}/${classifierId}/${classifierClass}`,
        type: "POST"
    }).done(function() {
        console.log("done")
    });
}