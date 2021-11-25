//
//  CameraView.swift
//  HandAndBody
//
//  Created by Gyorgy Borz on 2021. 11. 22..
//

import AVFoundation
import UIKit

class CameraView: UIView {
    private var overlayLayer = CAShapeLayer()
    private var jointsLayer = CAShapeLayer()
    private var pointsPath = UIBezierPath()
    private var linePath = UIBezierPath()
    private var jointsPath = UIBezierPath()

    var previewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }

    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupOverlay()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOverlay()
    }

    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        if layer == previewLayer {
            overlayLayer.frame = layer.bounds
            jointsLayer.frame = layer.bounds
        }
    }

    private func setupOverlay() {
        previewLayer.addSublayer(jointsLayer)
        previewLayer.addSublayer(overlayLayer)
    }

    func showPoints(_ points: [CGPoint], color: UIColor) {
        pointsPath.removeAllPoints()
        for point in points {
            pointsPath.move(to: point)
            pointsPath.addArc(withCenter: point, radius: 5, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        }
        overlayLayer.fillColor = color.cgColor
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        overlayLayer.path = pointsPath.cgPath
        CATransaction.commit()
    }

    func showPoints(wrist: CGPoint, thumb: [CGPoint], index: [CGPoint], middle: [CGPoint], ring: [CGPoint], little: [CGPoint]) {
        linePath.removeAllPoints()
        jointsPath.removeAllPoints()

        linePath.move(to: wrist)
        jointsPath.move(to: wrist)
        jointsPath.addArc(withCenter: wrist, radius: 5, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        for point in thumb {
            jointsPath.move(to: point)
            jointsPath.addArc(withCenter: point, radius: 5, startAngle: 0, endAngle: 2 * .pi, clockwise: true)

            linePath.addLine(to: point)
            linePath.move(to: point)
        }

        linePath.move(to: wrist)
        for point in index {
            jointsPath.move(to: point)
            jointsPath.addArc(withCenter: point, radius: 5, startAngle: 0, endAngle: 2 * .pi, clockwise: true)

            linePath.addLine(to: point)
            linePath.move(to: point)
        }

        linePath.move(to: wrist)
        for point in middle {
            jointsPath.move(to: point)
            jointsPath.addArc(withCenter: point, radius: 5, startAngle: 0, endAngle: 2 * .pi, clockwise: true)

            linePath.addLine(to: point)
            linePath.move(to: point)
        }

        linePath.move(to: wrist)
        for point in ring {
            jointsPath.move(to: point)
            jointsPath.addArc(withCenter: point, radius: 5, startAngle: 0, endAngle: 2 * .pi, clockwise: true)

            linePath.addLine(to: point)
            linePath.move(to: point)
        }

        linePath.move(to: wrist)
        for point in little {
            jointsPath.move(to: point)
            jointsPath.addArc(withCenter: point, radius: 5, startAngle: 0, endAngle: 2 * .pi, clockwise: true)

            linePath.addLine(to: point)
            linePath.move(to: point)
        }

        overlayLayer.lineWidth = 2
        overlayLayer.strokeColor = UIColor.green.cgColor
        jointsLayer.fillColor = UIColor.red.cgColor
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        overlayLayer.path = linePath.cgPath
        jointsLayer.path = jointsPath.cgPath
        CATransaction.commit()
    }
}
