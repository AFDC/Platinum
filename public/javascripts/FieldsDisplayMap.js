var fieldDisplayMap;

$(function(){
    var centerLat = 33.74546268819135;
    var centerLng = -84.39027837091692;

    fieldDisplayMap = new GMaps({
        div: '#fieldsMap',
        lat: centerLat,
        lng: centerLng,
        height: '400px',
        zoom: 12,
        zoomControl : true,
        zoomControlOpt: {
            style : 'SMALL',
            position: 'TOP_LEFT'
        },
        panControl : false,
        streetViewControl : false,
        mapTypeControl: true,
        overviewMapControl: false
    });

    $(".fieldsite").each(function (index, val) {
        var fieldDiv = $(val);
        var infoWindowDiv = fieldDiv.find(".info-window");

        if (fieldDiv.data("lat") && fieldDiv.data("lng")) {
            fieldDisplayMap.addMarker({
                _id: fieldDiv.data("id"),
                lat: fieldDiv.data("lat"),
                lng: fieldDiv.data("lng"),
                title: fieldDiv.data("name"),
                infoWindow: {
                    content: infoWindowDiv.html()
                }
            });
        }
    });

    $("#fieldSitesList").delegate("i.icon-map-marker", "click", function() {
        var fieldDiv = $(this).parents('div.fieldsite');

        if (fieldDiv.data("lat") != "" && fieldDiv.data("lng") != "") {
            fieldDisplayMap.hideInfoWindows();
            fieldDisplayMap.setCenter(fieldDiv.data("lat"), fieldDiv.data("lng"));

            triggerMarker(fieldDisplayMap, fieldDiv.data("id"));
        }
    });

    if (window.location.hash) {
        triggerMarker(fieldDisplayMap, window.location.hash.substring(1));
    }
});

function triggerMarker(map, siteId) {
    var markerList = map.markers;
    var thisMarker = null;

    for (m in markerList) {
        if (markerList[m]._id == siteId) {
            thisMarker = markerList[m];
            thisMarker.infoWindow.open(map, thisMarker);
            map.setZoom(15);
        }
    }
}
