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
    
    private let radiusConstant: CGFloat = 5

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
            pointsPath.addArc(withCenter: point, radius: radiusConstant, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        }
        overlayLayer.fillColor = color.cgColor
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        overlayLayer.path = pointsPath.cgPath
        CATransaction.commit()
    }

    func showPoints(for hands: [Hand]) {
        linePath.removeAllPoints()
        jointsPath.removeAllPoints()

        for hand in hands {
            if let wrist = hand.wrist {
                linePath.move(to: wrist)
                jointsPath.move(to: wrist)
                jointsPath.addArc(withCenter: wrist, radius: radiusConstant, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
                for point in hand.thumbFinger {
                    jointsPath.move(to: point)
                    jointsPath.addArc(withCenter: point, radius: radiusConstant, startAngle: 0, endAngle: 2 * .pi, clockwise: true)

                    linePath.addLine(to: point)
                    linePath.move(to: point)
                }

                linePath.move(to: wrist)
                for point in hand.indexFinger {
                    jointsPath.move(to: point)
                    jointsPath.addArc(withCenter: point, radius: radiusConstant, startAngle: 0, endAngle: 2 * .pi, clockwise: true)

                    linePath.addLine(to: point)
                    linePath.move(to: point)
                }

                linePath.move(to: wrist)
                for point in hand.middleFinger {
                    jointsPath.move(to: point)
                    jointsPath.addArc(withCenter: point, radius: radiusConstant, startAngle: 0, endAngle: 2 * .pi, clockwise: true)

                    linePath.addLine(to: point)
                    linePath.move(to: point)
                }

                linePath.move(to: wrist)
                for point in hand.ringFinger {
                    jointsPath.move(to: point)
                    jointsPath.addArc(withCenter: point, radius: radiusConstant, startAngle: 0, endAngle: 2 * .pi, clockwise: true)

                    linePath.addLine(to: point)
                    linePath.move(to: point)
                }

                linePath.move(to: wrist)
                for point in hand.littleFinger {
                    jointsPath.move(to: point)
                    jointsPath.addArc(withCenter: point, radius: radiusConstant, startAngle: 0, endAngle: 2 * .pi, clockwise: true)

                    linePath.addLine(to: point)
                    linePath.move(to: point)
                }
            }
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

    func showPoints(for bodies: [Body]) {
        linePath.removeAllPoints()
        jointsPath.removeAllPoints()

        for body in bodies {
            guard let neck = body.torso.first(where: { $0.key == .neck })?.value,
                  let rightShoulder = body.torso.first(where: { $0.key == .rightShoulder })?.value,
                  let leftShoulder = body.torso.first(where: { $0.key == .leftShoulder })?.value,
                  let root = body.torso.first(where: { $0.key == .root })?.value,
                  let rightHip = body.torso.first(where: { $0.key == .rightHip })?.value,
                  let leftHip = body.torso.first(where: { $0.key == .leftHip })?.value else {
                return
            }

            // neck
            jointsPath.move(to: neck)
            jointsPath.addArc(withCenter: neck, radius: radiusConstant, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
            linePath.move(to: neck)

            // right shoulder
            jointsPath.move(to: rightShoulder)
            jointsPath.addArc(withCenter: rightShoulder, radius: radiusConstant, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
            linePath.addLine(to: rightShoulder)

            // left shoulder
            jointsPath.move(to: leftShoulder)
            jointsPath.addArc(withCenter: leftShoulder, radius: radiusConstant, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
            linePath.move(to: neck)
            linePath.addLine(to: leftShoulder)

            // root
            jointsPath.move(to: root)
            jointsPath.addArc(withCenter: root, radius: radiusConstant, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
            linePath.move(to: neck)
            linePath.addLine(to: root)

            // right hip
            jointsPath.move(to: rightHip)
            jointsPath.addArc(withCenter: rightHip, radius: radiusConstant, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
            linePath.addLine(to: rightHip)

            // left hip
            jointsPath.move(to: leftHip)
            jointsPath.addArc(withCenter: leftHip, radius: radiusConstant, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
            linePath.move(to: root)
            linePath.addLine(to: leftHip)

            for point in body.face {
                jointsPath.move(to: point)
                jointsPath.addArc(withCenter: point, radius: radiusConstant, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
            }

            for (idx, point) in body.rightArm.enumerated() {
                jointsPath.move(to: point)
                jointsPath.addArc(withCenter: point, radius: radiusConstant, startAngle: 0, endAngle: 2 * .pi, clockwise: true)

                if idx == 0 {
                    linePath.move(to: point)
                } else {
                    linePath.addLine(to: point)
                    linePath.move(to: point)
                }
            }

            for (idx, point) in body.leftArm.enumerated() {
                jointsPath.move(to: point)
                jointsPath.addArc(withCenter: point, radius: radiusConstant, startAngle: 0, endAngle: 2 * .pi, clockwise: true)

                if idx == 0 {
                    linePath.move(to: point)
                } else {
                    linePath.addLine(to: point)
                    linePath.move(to: point)
                }
            }

            for (idx, point) in body.rightLeg.enumerated() {
                jointsPath.move(to: point)
                jointsPath.addArc(withCenter: point, radius: radiusConstant, startAngle: 0, endAngle: 2 * .pi, clockwise: true)

                if idx == 0 {
                    linePath.move(to: point)
                } else {
                    linePath.addLine(to: point)
                    linePath.move(to: point)
                }
            }

            for (idx, point) in body.leftLeg.enumerated() {
                jointsPath.move(to: point)
                jointsPath.addArc(withCenter: point, radius: radiusConstant, startAngle: 0, endAngle: 2 * .pi, clockwise: true)

                if idx == 0 {
                    linePath.move(to: point)
                } else {
                    linePath.addLine(to: point)
                    linePath.move(to: point)
                }
            }
        }

        overlayLayer.lineWidth = 4
        overlayLayer.strokeColor = UIColor.green.cgColor
        jointsLayer.fillColor = UIColor.red.cgColor
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        overlayLayer.path = linePath.cgPath
        jointsLayer.path = jointsPath.cgPath
        CATransaction.commit()
    }
}
