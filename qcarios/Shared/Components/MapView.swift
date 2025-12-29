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
        // 更新中心点（智能判断，避免频繁移动）
        if shouldUpdateCenter(newCenter: centerCoordinate, context: context) {
            mapView.setCenter(centerCoordinate, animated: true)
            context.coordinator.lastCenterCoordinate = centerCoordinate
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

    /// 判断是否需要更新地图中心点
    private func shouldUpdateCenter(newCenter: CLLocationCoordinate2D, context: Context) -> Bool {
        // 如果是首次设置，直接更新
        guard let lastCenter = context.coordinator.lastCenterCoordinate else {
            return true
        }

        // 计算两个坐标之间的距离（使用简单的度数差值）
        let latDiff = abs(newCenter.latitude - lastCenter.latitude)
        let lngDiff = abs(newCenter.longitude - lastCenter.longitude)

        // 只有当移动距离超过阈值时才更新（约50米）
        // 经度1度约111km，纬度1度约111km，0.0005度约55米
        let threshold = 0.0005

        return latDiff > threshold || lngDiff > threshold
    }

    private func updateAnnotations(mapView: MAMapView, context: Context) {
        // 获取现有标注
        let existingAnnotations = mapView.annotations as? [MAPointAnnotation] ?? []

        // 创建新标注
        let newAnnotations = annotations.map { annotation -> MAPointAnnotation in
            let pointAnnotation = MAPointAnnotation()
            pointAnnotation.coordinate = annotation.coordinate
            pointAnnotation.title = annotation.title
            pointAnnotation.subtitle = annotation.subtitle
            return pointAnnotation
        }

        // 比较是否需要更新（避免不必要的重绘）
        let needsUpdate = existingAnnotations.count != newAnnotations.count ||
            zip(existingAnnotations, newAnnotations).contains { existing, new in
                existing.coordinate.latitude != new.coordinate.latitude ||
                existing.coordinate.longitude != new.coordinate.longitude ||
                existing.title != new.title
            }

        if needsUpdate {
            mapView.removeAnnotations(existingAnnotations)
            mapView.addAnnotations(newAnnotations)
        }
    }

    private func updatePolyline(mapView: MAMapView, context: Context) {
        let newCount = polyline?.count ?? 0

        // 只有当路线实际发生变化时才更新（避免不必要的重绘）
        if newCount != context.coordinator.currentPolylineCount {
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

            context.coordinator.currentPolylineCount = newCount
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MAMapViewDelegate {
        var parent: MapView
        var currentPolylineCount: Int = 0
        var lastCenterCoordinate: CLLocationCoordinate2D?

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
                // 只在创建时播放动画
                annotationView?.animatesDrop = true
            } else {
                // 重用时不播放动画
                annotationView?.annotation = annotation
            }

            // 根据标注标题设置不同颜色
            if let title = annotation.title, title == "上车点" {
                annotationView?.pinColor = .green
            } else if let title = annotation.title, title == "目的地" {
                annotationView?.pinColor = .red
            } else {
                annotationView?.pinColor = .purple
            }

            return annotationView
        }

        // 路线渲染
        func mapView(_ mapView: MAMapView!, rendererFor overlay: MAOverlay!) -> MAOverlayRenderer! {
            if overlay is MAPolyline {
                let renderer = MAPolylineRenderer(overlay: overlay)
                renderer!.lineWidth = 8
                renderer!.strokeColor = UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 0.9)
                renderer!.lineJoinType = kMALineJoinRound
                renderer!.lineCapType = kMALineCapRound
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
