var fieldDisplayMap;
var mapMarkers = [];
var currentInfoWindow = null;

// This function is called by Google Maps API when it finishes loading (see callback parameter in script URL)
function initFieldsDisplayMap() {
    var centerLat = 33.74546268819135;
    var centerLng = -84.39027837091692;

    var mapElement = document.getElementById('fieldsMap');

    fieldDisplayMap = new google.maps.Map(mapElement, {
        center: { lat: centerLat, lng: centerLng },
        zoom: 12,
        zoomControl: true,
        zoomControlOptions: {
            position: google.maps.ControlPosition.TOP_LEFT
        },
        panControl: false,
        streetViewControl: false,
        mapTypeControl: true,
        fullscreenControl: false
    });

    $(".fieldsite").each(function (index, val) {
        var fieldDiv = $(val);
        var infoWindowDiv = fieldDiv.find(".info-window");

        if (fieldDiv.data("lat") && fieldDiv.data("lng")) {
            var marker = new google.maps.Marker({
                position: {
                    lat: fieldDiv.data("lat"),
                    lng: fieldDiv.data("lng")
                },
                map: fieldDisplayMap,
                title: fieldDiv.data("name")
            });

            var infoWindow = new google.maps.InfoWindow({
                content: infoWindowDiv.html()
            });

            marker.addListener('click', function() {
                if (currentInfoWindow) {
                    currentInfoWindow.close();
                }
                infoWindow.open(fieldDisplayMap, marker);
                currentInfoWindow = infoWindow;
            });

            mapMarkers.push({
                _id: fieldDiv.data("id"),
                marker: marker,
                infoWindow: infoWindow
            });
        }
    });

    $("#fieldSitesList").delegate("i.icon-map-marker", "click", function() {
        var fieldDiv = $(this).parents('div.fieldsite');

        if (fieldDiv.data("lat") != "" && fieldDiv.data("lng") != "") {
            if (currentInfoWindow) {
                currentInfoWindow.close();
            }
            fieldDisplayMap.setCenter({
                lat: fieldDiv.data("lat"),
                lng: fieldDiv.data("lng")
            });

            triggerMarker(fieldDiv.data("id"));
        }
    });

    if (window.location.hash) {
        triggerMarker(window.location.hash.substring(1));
    }
}

function triggerMarker(siteId) {
    for (var i = 0; i < mapMarkers.length; i++) {
        if (mapMarkers[i]._id == siteId) {
            if (currentInfoWindow) {
                currentInfoWindow.close();
            }
            mapMarkers[i].infoWindow.open(fieldDisplayMap, mapMarkers[i].marker);
            currentInfoWindow = mapMarkers[i].infoWindow;
            fieldDisplayMap.setZoom(15);
            fieldDisplayMap.setCenter(mapMarkers[i].marker.getPosition());
            break;
        }
    }
}
