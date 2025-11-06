var fieldDisplayMap;

// This function is called by Google Maps API when it finishes loading (see callback parameter in script URL)
function initFieldViewMap() {
    var fieldDiv = $("#fieldsite");

    if (fieldDiv.data('lat') && fieldDiv.data('lng')) {
        var centerLat = fieldDiv.data('lat');
        var centerLng = fieldDiv.data('lng');

        var mapElement = document.getElementById('map');

        fieldDisplayMap = new google.maps.Map(mapElement, {
            center: { lat: centerLat, lng: centerLng },
            zoom: 15,
            zoomControl: true,
            zoomControlOptions: {
                position: google.maps.ControlPosition.TOP_LEFT
            },
            panControl: false,
            streetViewControl: false,
            mapTypeControl: false,
            fullscreenControl: false
        });

        var marker = new google.maps.Marker({
            position: { lat: centerLat, lng: centerLng },
            map: fieldDisplayMap,
            title: 'Field Location'
        });

        // When marker is clicked, open Google Maps directions
        marker.addListener('click', function() {
            var directionsUrl = 'https://www.google.com/maps/dir/?api=1&destination=' + centerLat + ',' + centerLng;
            window.open(directionsUrl, '_blank');
        });
    } else {
        $("#mapHeader").html("Map not available because no field location is defined.");
    }
}
