(function(global, undefined){

    function buildMarkerPopupHtml(location_title) {
        return [
            "<div class='location-popup'>",
                "<div class='row'>", 
                    "<div class='four columns location-label'> Name </div>", 
                    "<div class='eight columns'>", location_title, "</div>",
                "</div>",
                //"<div class='row'>", 
                //    "<div class='four columns location-label'> Precision </div>", 
                //    "<div class='eight columns'>", location.precision, "</div>",
                //"</div>",
                //"<div class='row'>", 
                //    "<div class='four columns location-label'> Type </div>", 
                //    "<div class='eight columns'>", location["type"], "</div>",
                //"</div>",
            "</div>"
        ].join("")
    }

    function buildClusterPopupHtml(locations) {
        var items = [];
        for(var i = 0; i < locations.length; i++) {
            var location = locations[i];
            items.push([
                "<div class='row'>", 
                    "<div class='five columns location-label'>", 
                        "<a href='/projects/", location.id ,"'>", location.id, "</a>",
                    "</div>", 
                    "<div class='seven columns'>", location.title, "</div>",
                "</div>"
            ].join(""));
        }

        return [
            "<div class='location-popup large'>",
                items.join(""),
            "</div>"
        ].join("")
    }

    var countryName = $("#countryName").val();
    var countryCode = $("#countryCode").val();
    var projectType = $("#projectType").val();
    var map;
 
 // TODO Remove alert
    //alert("country map" + projectType);

    var osmHOT = L.tileLayer('http://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png', {
                              maxZoom: 19,
                              attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>, Tiles courtesy of <a href="http://hot.openstreetmap.org/" target="_blank">Humanitarian OpenStreetMap Team</a>'
                             });
    
    var mqTilesAttr = 'Tiles &copy; <a href="http://www.mapquest.com/" target="_blank">MapQuest</a> <img src="http://developer.mapquest.com/content/osm/mq_logo.png" />';
    var mapQuestOSM = L.tileLayer('http://otile{s}.mqcdn.com/tiles/1.0.0/{type}/{z}/{x}/{y}.png', {
        options: {
            subdomains: '1234',
            type: 'osm',
            attribution: 'Map data ' + L.TileLayer.OSM_ATTR + ', ' + mqTilesAttr
        }
    });

    var cartoDB = L.tileLayer('http://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png', {
        attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors, &copy; <a href="http://cartodb.com/attributions">CartoDB</a>'
    });

    var mapBox = L.tileLayer('https://api.mapbox.com/v4/mapbox.emerald/{z}/{x}/{y}.png?access_token=pk.eyJ1IjoiZGV2dHJhY2tlciIsImEiOiJjaWhzdnplbzUwMDJ3dzRrcGVyN2licGFpIn0.a3sZ1t6v-N1nxFCDIiGblQ', {
        attribution: '&copy; <a href="https://www.mapbox.com/map-feedback/">Mapbox</a> &copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>'
    });

    if (projectType == "global") {

        map = new L.Map('countryMap', {
            center: new L.LatLng(7.79,21.28), 
            zoom: 1,
            layers: [mapBox]
        });

        //map.addLayer(new L.Google('ROADMAP'));


    } else if (projectType == "country" && countryName && countryCode) {  
        map = new L.Map('countryMap', {
            center: new L.LatLng(countryBounds[countryCode][0], countryBounds[countryCode][1]), 
            zoom: countryBounds[countryCode][2] || 6,
            layers: [mapBox]
        });
        //map.addLayer(new L.Google('ROADMAP'));

    } else if (projectType == "region" && countryCode) {
        var bounds = regionBounds[countryCode];
        var boundary = new L.LatLngBounds(
            new L.LatLng(bounds.southwest.lat, bounds.southwest.lng),
            new L.LatLng(bounds.northeast.lat, bounds.northeast.lng)            
        );

        map = new L.Map('countryMap',
            {
                layers: [mapBox]
            });
        //map.addLayer(new L.Google('ROADMAP'))
        map.fitBounds(boundary);
        map.panInsideBounds(boundary);
    } else {
        $('#countryMap').hide();
        $('#countryMapDisclaimer').hide();
    }

    // create the geopoints if any are defined
    if(map && global.locations) {
        //alert("start processing datapoints");

        var markers = new L.MarkerClusterGroup({ 
            spiderfyOnMaxZoom: false, 
            showCoverageOnHover: false,
            singleMarkerMode: true,
            iconCreateFunction: function(cluster) {
                var count = cluster.getChildCount();
                var additional = ""
                if(count > 99) {
                    count = "+";
                    additional = "large-value";
                }

                return new L.DivIcon({ html: '<div class="marker cluster ' + additional + '">' + count+ '</div>' });
            } 
        });

        markers.on('clusterclick', function (a) {
         var atMax = a.target._zoom == a.target._maxZoom
         if(atMax) {
            var clusterLocations = [];
            for(var i = 0; i < a.layer._markers.length; i++) {
                clusterLocations.push(a.layer._markers[i].options.data)
            }
            
            var html = buildClusterPopupHtml(clusterLocations)
            var popup = L.popup()
                         .setLatLng(a.layer._latlng)
                         .setContent(html)
                         .openOn(map);
         }
        });

        for(var i = 0; i < locations.length; i++){
            var location = locations[i];
            //console.log(location.point.point.latitude);
            //var latlng   = new L.LatLng(location.latitude, location.longitude)
            var latlng, marker_title;
            try {
                marker_title = location.name[0].narratives[0].text;
            }
            catch(e){
                marker_title = ProjectTitle;   
            }
            try {
                latlng = new L.LatLng(location.point.pos.latitude,location.point.pos.longitude);
                var marker = new L.Marker(latlng, { 
                    title: marker_title, 
                    //data:  location
                });
                switch(mapType) {
                    case "country": 
                        marker.bindPopup(buildClusterPopupHtml([location]))
                        break;
                    case "project": 
                        marker.bindPopup(buildMarkerPopupHtml(marker_title))
                        break;
                }
                markers.addLayer(marker);
            }
            catch(e){
                latlng = new L.LatLng(0,0);   
            }
            //var latlng   = new L.LatLng(location.point.pos.latitude,location.point.pos.longitude);
            /*var marker   = new L.Marker(latlng, { 
                title: location.name[0].narratives[0].text, 
                data:  location
            });*/

            // mapType is a global variable that is used to
            /*switch(mapType) {
                case "country": 
                    marker.bindPopup(buildClusterPopupHtml([location]))
                    break;
                case "project": 
                    marker.bindPopup(buildMarkerPopupHtml(location))
                    break;
            }*/
            
            //markers.addLayer(marker);
        }

        map.addLayer(markers);
    }

})(this)
