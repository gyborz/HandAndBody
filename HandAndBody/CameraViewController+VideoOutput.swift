//
//  CameraViewController+VideoOutput.swift
//  HandAndBody
//
//  Created by Gyorgy Borz on 2021. 11. 27..
//

import AVFoundation
import UIKit
import Vision

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        var hands: [Hand] = []
        var bodies: [Body] = []

        defer {
            DispatchQueue.main.sync {
                switch self.visionMode {
                case .handPose: self.processPoints(hands: hands)
                case .bodyPose: self.processPoints(bodies: bodies)
                }
            }
        }

        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        do {
            switch visionMode {
            case .handPose:
                try handler.perform([handPoseRequest])
                guard let observations = handPoseRequest.results else { return }
                try getPointsFromHandObservation(observations: observations, hands: &hands)
            case .bodyPose:
                try handler.perform([bodyPoseRequest])
                guard let observations = bodyPoseRequest.results else { return }
                try getPointsFromBodyObservation(observations: observations, bodies: &bodies)
            }

        } catch {
            cameraFeedSession.stopRunning()
            let error = AppError.visionError(error: error)
            DispatchQueue.main.async {
                error.displayInViewController(self)
            }
        }
    }

    private func getPointsFromHandObservation(observations: [VNHumanHandPoseObservation], hands: inout [Hand]) throws {
        var thumbFinger: [CGPoint] = []
        var indexFinger: [CGPoint] = []
        var middleFinger: [CGPoint] = []
        var ringFinger: [CGPoint] = []
        var littleFinger: [CGPoint] = []
        var wrist: CGPoint?

        for observation in observations {
            let thumbPoints = try observation.recognizedPoints(.thumb)
            let indexFingerPoints = try observation.recognizedPoints(.indexFinger)
            let middleFingerPoints = try observation.recognizedPoints(.middleFinger)
            let ringFingerPoints = try observation.recognizedPoints(.ringFinger)
            let littleFingerPoints = try observation.recognizedPoints(.littleFinger)
            let wristPoint = try observation.recognizedPoint(.wrist)

            var thumbDict: [Int: CGPoint] = [:]
            for keyValuePair in thumbPoints {
                let key = keyValuePair.key
                let value = keyValuePair.value
                if value.confidence > 0.3 {
                    let index = getArrayIndexFromFingerPoint(fingerPointType: key)
                    let point = CGPoint(x: value.location.x, y: 1 - value.location.y)
                    thumbDict[index] = point
                }
            }
            thumbFinger = thumbDict.sorted(by: { $0.key < $1.key }).map { $0.value }

            var indexDict: [Int: CGPoint] = [:]
            for keyValuePair in indexFingerPoints {
                let key = keyValuePair.key
                let value = keyValuePair.value
                if value.confidence > 0.3 {
                    let index = getArrayIndexFromFingerPoint(fingerPointType: key)
                    let point = CGPoint(x: value.location.x, y: 1 - value.location.y)
                    indexDict[index] = point
                }
            }
            indexFinger = indexDict.sorted(by: { $0.key < $1.key }).map { $0.value }

            var middleDict: [Int: CGPoint] = [:]
            for keyValuePair in middleFingerPoints {
                let key = keyValuePair.key
                let value = keyValuePair.value
                if value.confidence > 0.3 {
                    let index = getArrayIndexFromFingerPoint(fingerPointType: key)
                    let point = CGPoint(x: value.location.x, y: 1 - value.location.y)
                    middleDict[index] = point
                }
            }
            middleFinger = middleDict.sorted(by: { $0.key < $1.key }).map { $0.value }

            var ringDict: [Int: CGPoint] = [:]
            for keyValuePair in ringFingerPoints {
                let key = keyValuePair.key
                let value = keyValuePair.value
                if value.confidence > 0.3 {
                    let index = getArrayIndexFromFingerPoint(fingerPointType: key)
                    let point = CGPoint(x: value.location.x, y: 1 - value.location.y)
                    ringDict[index] = point
                }
            }
            ringFinger = ringDict.sorted(by: { $0.key < $1.key }).map { $0.value }

            var littleDict: [Int: CGPoint] = [:]
            for keyValuePair in littleFingerPoints {
                let key = keyValuePair.key
                let value = keyValuePair.value
                if value.confidence > 0.3 {
                    let index = getArrayIndexFromFingerPoint(fingerPointType: key)
                    let point = CGPoint(x: value.location.x, y: 1 - value.location.y)
                    littleDict[index] = point
                }
            }
            littleFinger = littleDict.sorted(by: { $0.key < $1.key }).map { $0.value }

            if wristPoint.confidence > 0.3 {
                wrist = CGPoint(x: wristPoint.location.x, y: 1 - wristPoint.location.y)
            }

            let hand = Hand(thumbFinger: thumbFinger, indexFinger: indexFinger, middleFinger: middleFinger, ringFinger: ringFinger, littleFinger: littleFinger, wrist: wrist)
            hands.append(hand)
        }
    }

    private func getPointsFromBodyObservation(observations: [VNHumanBodyPoseObservation], bodies: inout [Body]) throws {
    }

    func processPoints(hands: [Hand]) {
        var processedHands: [Hand] = []
        hands.forEach { hand in
            if let wrist = hand.wrist {
                let convertedThumb = hand.thumbFinger.map { cameraView.previewLayer.layerPointConverted(fromCaptureDevicePoint: $0) }
                let convertedIndex = hand.indexFinger.map { cameraView.previewLayer.layerPointConverted(fromCaptureDevicePoint: $0) }
                let convertedMiddle = hand.middleFinger.map { cameraView.previewLayer.layerPointConverted(fromCaptureDevicePoint: $0) }
                let convertedRing = hand.ringFinger.map { cameraView.previewLayer.layerPointConverted(fromCaptureDevicePoint: $0) }
                let convertedLittle = hand.littleFinger.map { cameraView.previewLayer.layerPointConverted(fromCaptureDevicePoint: $0) }
                let convertedWrist = cameraView.previewLayer.layerPointConverted(fromCaptureDevicePoint: wrist)

                processedHands.append(Hand(thumbFinger: convertedThumb, indexFinger: convertedIndex, middleFinger: convertedMiddle, ringFinger: convertedRing, littleFinger: convertedLittle, wrist: convertedWrist))
            } else {
                cameraView.showPoints([], color: .clear)
            }
        }
        cameraView.showPoints(for: processedHands)
    }

    func processPoints(bodies: [Body]) {
    }

    private func getArrayIndexFromFingerPoint(fingerPointType: VNHumanHandPoseObservation.JointName) -> Int {
        switch fingerPointType {
        case .thumbTip, .indexTip, .middleTip, .ringTip, .littleTip: return 3
        case .thumbIP, .indexDIP, .middleDIP, .ringDIP, .littleDIP: return 2
        case .thumbMP, .indexPIP, .middlePIP, .ringPIP, .littlePIP: return 1
        case .thumbCMC, .indexMCP, .middleMCP, .ringMCP, .littleMCP: return 0
        default: return 0
        }
    }
}
