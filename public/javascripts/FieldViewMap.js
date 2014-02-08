var fieldDisplayMap;

$(function(){
    var fieldDiv = $("#fieldsite");

    if (fieldDiv.data('lat') && fieldDiv.data('lng')) {
        centerLat = fieldDiv.data('lat');
        centerLng = fieldDiv.data('lng');

        fieldDisplayMap = new GMaps({
            div: '#map',
            lat: centerLat,
            lng: centerLng,
            height: '400px',
            zoomControl : true,
            zoomControlOpt: {
                style : 'SMALL',
                position: 'TOP_LEFT'
            },
            panControl : false,
            streetViewControl : false,
            mapTypeControl: false,
            overviewMapControl: false
        });

        fieldDisplayMap.addMarker({
            lat: centerLat,
            lng: centerLng,
            title: 'Field Location'
        });
    } else {
        $("#mapHeader").html("Map not available because no field location is defined.");
    }
});
