//
//  MapView.swift
//  qcarios
//
//  地图视图组件 - SwiftUI封装
//

import SwiftUI
import UIKit
import AMapNaviKit
import CoreLocation

// MARK: - Map View
struct MapView: UIViewRepresentable {

    // MARK: - Properties

    @Binding var centerCoordinate: CLLocationCoordinate2D
    @Binding var userLocation: CLLocationCoordinate2D?
    var annotations: [MapAnnotation]
    var polyline: [CLLocationCoordinate2D]?
    var showsUserLocation: Bool
    var onTap: ((CLLocationCoordinate2D) -> Void)?

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MAMapView {
        let mapView = MAMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showsUserLocation
        mapView.userTrackingMode = .follow
        mapView.zoomLevel = 15
        mapView.centerCoordinate = centerCoordinate

        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ mapView: MAMapView, context: Context) {
        // 更新中心点
        if mapView.centerCoordinate.latitude != centerCoordinate.latitude ||
           mapView.centerCoordinate.longitude != centerCoordinate.longitude {
            mapView.setCenter(centerCoordinate, animated: true)
        }

        // 更新标注
        updateAnnotations(mapView: mapView, context: context)

        // 更新路线
        updatePolyline(mapView: mapView, context: context)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Helper Methods

    private func updateAnnotations(mapView: MAMapView, context: Context) {
        // 移除旧标注
        if let oldAnnotations = mapView.annotations {
            mapView.removeAnnotations(oldAnnotations)
        }

        // 添加新标注
        let pointAnnotations = annotations.map { annotation -> MAPointAnnotation in
            let pointAnnotation = MAPointAnnotation()
            pointAnnotation.coordinate = annotation.coordinate
            pointAnnotation.title = annotation.title
            pointAnnotation.subtitle = annotation.subtitle
            return pointAnnotation
        }
        mapView.addAnnotations(pointAnnotations)
    }

    private func updatePolyline(mapView: MAMapView, context: Context) {
        // 移除旧路线
        if let overlays = mapView.overlays {
            mapView.removeOverlays(overlays)
        }

        // 添加新路线
        if let coords = polyline, !coords.isEmpty {
            var coordinates = coords
            let polyline = MAPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
            mapView.add(polyline)
            mapView.showOverlays([polyline], edgePadding: UIEdgeInsets(top: 100, left: 50, bottom: 100, right: 50), animated: true)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MAMapViewDelegate {
        var parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
        }

        // 用户位置更新
        func mapView(_ mapView: MAMapView!, didUpdate userLocation: MAUserLocation!, updatingLocation: Bool) {
            if updatingLocation {
                parent.userLocation = userLocation.coordinate
            }
        }

        // 标注视图
        func mapView(_ mapView: MAMapView!, viewFor annotation: MAAnnotation!) -> MAAnnotationView! {
            if annotation is MAUserLocation {
                return nil
            }

            let reuseIdentifier = "pin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as? MAPinAnnotationView

            if annotationView == nil {
                annotationView = MAPinAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
                annotationView?.canShowCallout = true
                annotationView?.animatesDrop = true
            } else {
                annotationView?.annotation = annotation
            }

            return annotationView
        }

        // 路线渲染
        func mapView(_ mapView: MAMapView!, rendererFor overlay: MAOverlay!) -> MAOverlayRenderer! {
            if overlay is MAPolyline {
                let renderer = MAPolylineRenderer(overlay: overlay)
                renderer!.lineWidth = 6
                renderer!.strokeColor = UIColor.systemBlue.withAlphaComponent(0.7)
                return renderer
            }
            return nil
        }

        // 地图点击
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MAMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onTap?(coordinate)
        }
    }
}

// MARK: - Map Annotation Model
struct MapAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?

    init(coordinate: CLLocationCoordinate2D, title: String? = nil, subtitle: String? = nil) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
    }
}

// MARK: - Preview
struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView(
            centerCoordinate: .constant(CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)),
            userLocation: .constant(nil),
            annotations: [
                MapAnnotation(
                    coordinate: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
                    title: "天安门",
                    subtitle: "北京市东城区"
                )
            ],
            polyline: nil,
            showsUserLocation: true
        )
    }
}
