import MapKit
import SwiftUI

/// Native Apple Maps (MapKit) surface with 3D buildings and heading-follow camera.
struct AppleMapView: UIViewRepresentable {
    var coordinate: CLLocationCoordinate2D?
    var heading: CLLocationDirection
    var pitch: CGFloat = 58
    var altitude: CLLocationDistance = 420

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.mapType = .standard
        map.pointOfInterestFilter = .excludingAll
        map.showsCompass = false
        map.showsScale = false
        map.showsTraffic = false
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.isScrollEnabled = false
        map.isZoomEnabled = false
        map.isUserInteractionEnabled = false
        map.overrideUserInterfaceStyle = .dark
        // Prefer muted roads + visible 3D building massing (Numa-like).
        if #available(iOS 16.0, *) {
            map.preferredConfiguration = MKStandardMapConfiguration(
                elevationStyle: .realistic,
                emphasisStyle: .muted
            )
        }
        map.showsBuildings = true
        map.register(
            VehicleAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: VehicleAnnotationView.reuseID
        )
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let center = coordinate ?? CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784)
        let camera = MKMapCamera(
            lookingAtCenter: center,
            fromDistance: altitude,
            pitch: pitch,
            heading: heading
        )
        map.setCamera(camera, animated: true)

        // Keep a single vehicle annotation.
        let existing = map.annotations.compactMap { $0 as? VehicleAnnotation }
        if let annotation = existing.first {
            annotation.coordinate = center
            annotation.heading = heading
            if let view = map.view(for: annotation) as? VehicleAnnotationView {
                view.applyHeading(heading)
            }
        } else {
            let annotation = VehicleAnnotation(coordinate: center, heading: heading)
            map.addAnnotation(annotation)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let vehicle = annotation as? VehicleAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: VehicleAnnotationView.reuseID,
                for: vehicle
            ) as? VehicleAnnotationView ?? VehicleAnnotationView(
                annotation: vehicle,
                reuseIdentifier: VehicleAnnotationView.reuseID
            )
            view.applyHeading(vehicle.heading)
            return view
        }
    }
}

final class VehicleAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    var heading: CLLocationDirection

    init(coordinate: CLLocationCoordinate2D, heading: CLLocationDirection) {
        self.coordinate = coordinate
        self.heading = heading
    }
}

final class VehicleAnnotationView: MKAnnotationView {
    static let reuseID = "soc.vehicle.annotation"

    private let arrow = UIImageView(image: UIImage(systemName: "location.north.fill"))

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 28, height: 28)
        centerOffset = CGPoint(x: 0, y: 0)
        canShowCallout = false
        arrow.tintColor = UIColor(red: 0.95, green: 0.22, blue: 0.22, alpha: 1)
        arrow.contentMode = .scaleAspectFit
        arrow.frame = bounds
        addSubview(arrow)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.55
        layer.shadowRadius = 3
        layer.shadowOffset = CGSize(width: 0, height: 2)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func applyHeading(_ heading: CLLocationDirection) {
        // SF Symbol points up; MapKit annotation rotation is clockwise degrees.
        arrow.transform = CGAffineTransform(rotationAngle: CGFloat(heading * .pi / 180))
    }
}
