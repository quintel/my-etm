import { Controller } from "@hotwired/stimulus";
import "leaflet-css";

export default class extends Controller {
    static targets = [ "map" ]
    static values = { url: String };

    connect(){
      import("leaflet").then( L => {
          this.map = L.map(
            this.mapTarget, {
            center: [52.3639175,4.8922245],
            zoom: 13
          });
          L.tileLayer(
            'https://tile.openstreetmap.org/{z}/{x}/{y}.png?{foo}', {
              foo: 'bar',
              attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          }).addTo(this.map);

          var QIcon = L.icon({
            iconUrl:      this.urlValue,
            iconSize:     [36, 41], // size of the icon
            iconAnchor:   [0, 41], // point of the icon which will correspond to marker's location
            popupAnchor:  [-3, -76] // point from which the popup should open relative to the iconAnchor
          });

          L.marker([52.3639175,4.8922245], {icon: QIcon}).addTo(this.map);
      });
    }

    disconnect(){
      this.map.remove()
    }
}
