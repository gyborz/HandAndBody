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
                if value.confidence > confidenceLevel {
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
                if value.confidence > confidenceLevel {
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
                if value.confidence > confidenceLevel {
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
                if value.confidence > confidenceLevel {
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
                if value.confidence > confidenceLevel {
                    let index = getArrayIndexFromFingerPoint(fingerPointType: key)
                    let point = CGPoint(x: value.location.x, y: 1 - value.location.y)
                    littleDict[index] = point
                }
            }
            littleFinger = littleDict.sorted(by: { $0.key < $1.key }).map { $0.value }

            if wristPoint.confidence > confidenceLevel {
                wrist = CGPoint(x: wristPoint.location.x, y: 1 - wristPoint.location.y)
            }

            let hand = Hand(thumbFinger: thumbFinger, indexFinger: indexFinger, middleFinger: middleFinger, ringFinger: ringFinger, littleFinger: littleFinger, wrist: wrist)
            hands.append(hand)
        }
    }

    private func getPointsFromBodyObservation(observations: [VNHumanBodyPoseObservation], bodies: inout [Body]) throws {
        var face: [CGPoint] = []
        var rightArm: [CGPoint] = []
        var leftArm: [CGPoint] = []
        var torso: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        var rightLeg: [CGPoint] = []
        var leftLeg: [CGPoint] = []

        for observation in observations {
            let facePoints = try observation.recognizedPoints(.face)
            let rightArmPoints = try observation.recognizedPoints(.rightArm)
            let leftArmPoints = try observation.recognizedPoints(.leftArm)
            let torsoPoints = try observation.recognizedPoints(.torso)
            let rightLegPoints = try observation.recognizedPoints(.rightLeg)
            let leftLegPoints = try observation.recognizedPoints(.leftLeg)

            var faceDict: [Int: CGPoint] = [:]
            for keyValuePair in facePoints {
                let key = keyValuePair.key
                let value = keyValuePair.value
                if value.confidence > confidenceLevel {
                    let index = getArrayIndexFromBodyPointFace(bodyPoint: key)
                    let point = CGPoint(x: value.location.x, y: 1 - value.location.y)
                    faceDict[index] = point
                }
            }
            face = faceDict.sorted(by: { $0.key < $1.key }).map { $0.value }

            var rightArmDict: [Int: CGPoint] = [:]
            for keyValuePair in rightArmPoints {
                let key = keyValuePair.key
                let value = keyValuePair.value
                if value.confidence > confidenceLevel {
                    let index = getArrayIndexFromBodyPointArm(bodyPoint: key)
                    let point = CGPoint(x: value.location.x, y: 1 - value.location.y)
                    rightArmDict[index] = point
                }
            }
            rightArm = rightArmDict.sorted(by: { $0.key < $1.key }).map { $0.value }

            var leftArmDict: [Int: CGPoint] = [:]
            for keyValuePair in leftArmPoints {
                let key = keyValuePair.key
                let value = keyValuePair.value
                if value.confidence > confidenceLevel {
                    let index = getArrayIndexFromBodyPointArm(bodyPoint: key)
                    let point = CGPoint(x: value.location.x, y: 1 - value.location.y)
                    leftArmDict[index] = point
                }
            }
            leftArm = leftArmDict.sorted(by: { $0.key < $1.key }).map { $0.value }

            for keyValuePair in torsoPoints {
                let key = keyValuePair.key
                let value = keyValuePair.value
                if value.confidence > confidenceLevel {
                    let point = CGPoint(x: value.location.x, y: 1 - value.location.y)
                    torso[key] = point
                }
            }

            var rightLegDict: [Int: CGPoint] = [:]
            for keyValuePair in rightLegPoints {
                let key = keyValuePair.key
                let value = keyValuePair.value
                if value.confidence > confidenceLevel {
                    let index = getArrayIndexFromBodyPointLeg(bodyPoint: key)
                    let point = CGPoint(x: value.location.x, y: 1 - value.location.y)
                    rightLegDict[index] = point
                }
            }
            rightLeg = rightLegDict.sorted(by: { $0.key < $1.key }).map { $0.value }

            var leftLegDict: [Int: CGPoint] = [:]
            for keyValuePair in leftLegPoints {
                let key = keyValuePair.key
                let value = keyValuePair.value
                if value.confidence > confidenceLevel {
                    let index = getArrayIndexFromBodyPointLeg(bodyPoint: key)
                    let point = CGPoint(x: value.location.x, y: 1 - value.location.y)
                    leftLegDict[index] = point
                }
            }
            leftLeg = leftLegDict.sorted(by: { $0.key < $1.key }).map { $0.value }

            let body = Body(face: face, rightArm: rightArm, leftArm: leftArm, torso: torso, rightLeg: rightLeg, leftLeg: leftLeg)
            bodies.append(body)
        }
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
        var processedBodies: [Body] = []
        bodies.forEach { body in
            let convertedFace = body.face.map { cameraView.previewLayer.layerPointConverted(fromCaptureDevicePoint: $0) }
            let convertedRightArm = body.rightArm.map { cameraView.previewLayer.layerPointConverted(fromCaptureDevicePoint: $0) }
            let convertedLeftArm = body.leftArm.map { cameraView.previewLayer.layerPointConverted(fromCaptureDevicePoint: $0) }
            let convertedRightLeg = body.rightLeg.map { cameraView.previewLayer.layerPointConverted(fromCaptureDevicePoint: $0) }
            let convertedLeftLeg = body.leftLeg.map { cameraView.previewLayer.layerPointConverted(fromCaptureDevicePoint: $0) }

            var convertedTorso: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
            for keyValuePair in body.torso {
                convertedTorso[keyValuePair.key] = cameraView.previewLayer.layerPointConverted(fromCaptureDevicePoint: keyValuePair.value)
            }
            processedBodies.append(Body(face: convertedFace, rightArm: convertedRightArm, leftArm: convertedLeftArm, torso: convertedTorso, rightLeg: convertedRightLeg, leftLeg: convertedLeftLeg))
        }
        cameraView.showPoints(for: processedBodies)
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

    private func getArrayIndexFromBodyPointFace(bodyPoint: VNHumanBodyPoseObservation.JointName) -> Int {
        switch bodyPoint {
        case .leftEar: return 4
        case .leftEye: return 3
        case .nose: return 2
        case .rightEye: return 1
        case .rightEar: return 0
        default: return 0
        }
    }

    private func getArrayIndexFromBodyPointArm(bodyPoint: VNHumanBodyPoseObservation.JointName) -> Int {
        switch bodyPoint {
        case .rightShoulder, .leftShoulder: return 2
        case .rightElbow, .leftElbow: return 1
        case .rightWrist, .leftWrist: return 0
        default: return 0
        }
    }

    private func getArrayIndexFromBodyPointLeg(bodyPoint: VNHumanBodyPoseObservation.JointName) -> Int {
        switch bodyPoint {
        case .rightHip, .leftHip: return 2
        case .rightKnee, .leftKnee: return 1
        case .rightAnkle, .leftAnkle: return 0
        default: return 0
        }
    }
}
