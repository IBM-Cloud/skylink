
//put your mapbox api token here
//get an api token from: https://www.mapbox.com/help/create-api-access-token/
L.mapbox.accessToken = 'pk.eyJ1IjoiYW10cmljZSIsImEiOiJjaXJxcnk5b2kwaGlzZmttNmx6NmJ2cnUwIn0.Dmm3imuypGoQ5d2s_JS3ug';


// MIT-licensed code by Benjamin Becquet
// https://github.com/bbecquet/Leaflet.PolylineDecorator
L.RotatedMarker = L.Marker.extend({
options: { angle: 0 },
_setPos: function(pos) {
    L.Marker.prototype._setPos.call(this, pos);
    if (L.DomUtil.TRANSFORM) {
    // use the CSS transform rule if available
    this._icon.style[L.DomUtil.TRANSFORM] += ' rotate(' + this.options.angle + 'deg)';
    } else if (L.Browser.ie) {
    // fallback for IE6, IE7, IE8
    var rad = this.options.angle * L.LatLng.DEG_TO_RAD,
    costheta = Math.cos(rad),
    sintheta = Math.sin(rad);
    this._icon.style.filter += ' progid:DXImageTransform.Microsoft.Matrix(sizingMethod=\'auto expand\', M11=' +
        costheta + ', M12=' + (-sintheta) + ', M21=' + sintheta + ', M22=' + costheta + ')';
    }
}
});
L.rotatedMarker = function(pos, options) {
    return new L.RotatedMarker(pos, options);
};


function loadMap(document) {
    var map = L.mapbox.map('map', 'mapbox.streets').setView([document.latitude, document.longitude], 14);

    var marker = L.rotatedMarker(new L.LatLng(document.latitude, document.longitude), {
        icon: L.icon({
            iconUrl:"/static/assets/map-marker.png",
            iconSize: [32, 32], // size of the icon
            iconAnchor: [16, 16], // point of the icon which will correspond to marker's location
            popupAnchor: [0, -25] // point from which the popup should open relative to the iconAnchor
        }),
        draggable: false
    });
    
    var angle = document.hideCameraDetail ? document.heading : document.cameraHeading;

    marker.options.angle = angle;
    marker.addTo(map);
}
