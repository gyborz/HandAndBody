//
//  CameraViewController.swift
//  HandAndBody
//
//  Created by Gyorgy Borz on 2021. 11. 22..
//

import AVFoundation
import UIKit
import Vision

class CameraViewController: UIViewController {
    private var cameraView: CameraView { view as! CameraView }

    private let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInteractive)
    private var cameraFeedSession: AVCaptureSession?
    private var handPoseRequest = VNDetectHumanHandPoseRequest()

    private let drawOverlay = CAShapeLayer()
    private let drawPath = UIBezierPath()
    private var evidenceBuffer = [HandGestureProcessor.PointsPair]()
    private var lastDrawPoint: CGPoint?
    private var isFirstSegment = true
    private var lastObservationTimestamp = Date()

    private var gestureProcessor = HandGestureProcessor()

    override func viewDidLoad() {
        super.viewDidLoad()
        drawOverlay.frame = view.layer.bounds
        drawOverlay.lineWidth = 5
        drawOverlay.strokeColor = #colorLiteral(red: 0.6, green: 0.1, blue: 0.3, alpha: 1).cgColor
        drawOverlay.fillColor = #colorLiteral(red: 0.9999018312, green: 1, blue: 0.9998798966, alpha: 0).cgColor
        drawOverlay.lineCap = .round
        view.layer.addSublayer(drawOverlay)
        // This sample app detects one hand only.
        handPoseRequest.maximumHandCount = 1
        // Add state change handler to hand gesture processor.
        gestureProcessor.didChangeStateClosure = { [weak self] state in
            self?.handleGestureStateChange(state: state)
        }
        // Add double tap gesture recognizer for clearing the draw path.
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        recognizer.numberOfTouchesRequired = 1
        recognizer.numberOfTapsRequired = 2
        view.addGestureRecognizer(recognizer)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do {
            if cameraFeedSession == nil {
                cameraView.previewLayer.videoGravity = .resizeAspectFill
                try setupAVSession()
                cameraView.previewLayer.session = cameraFeedSession
            }
            cameraFeedSession?.startRunning()
        } catch {
            AppError.display(error, inViewController: self)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        cameraFeedSession?.stopRunning()
        super.viewWillDisappear(animated)
    }

    func setupAVSession() throws {
        // Select a front facing camera, make an input.
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw AppError.captureSessionSetup(reason: "Could not find a front facing camera.")
        }

        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            throw AppError.captureSessionSetup(reason: "Could not create video device input.")
        }

        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSession.Preset.high

        // Add a video input.
        guard session.canAddInput(deviceInput) else {
            throw AppError.captureSessionSetup(reason: "Could not add video device input to the session")
        }
        session.addInput(deviceInput)

        let dataOutput = AVCaptureVideoDataOutput()
        if session.canAddOutput(dataOutput) {
            session.addOutput(dataOutput)
            // Add a video data output.
            dataOutput.alwaysDiscardsLateVideoFrames = true
            dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            dataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            throw AppError.captureSessionSetup(reason: "Could not add video data output to the session")
        }
        session.commitConfiguration()
        cameraFeedSession = session
    }

    func processPoints(thumbTip: CGPoint?, indexTip: CGPoint?) {
        // Check that we have both points.
        guard let thumbPoint = thumbTip, let indexPoint = indexTip else {
            // If there were no observations for more than 2 seconds reset gesture processor.
            if Date().timeIntervalSince(lastObservationTimestamp) > 2 {
                gestureProcessor.reset()
            }
            cameraView.showPoints([], color: .clear)
            return
        }

        // Convert points from AVFoundation coordinates to UIKit coordinates.
        let previewLayer = cameraView.previewLayer
        let thumbPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: thumbPoint)
        let indexPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: indexPoint)

        // Process new points
        gestureProcessor.processPointsPair((thumbPointConverted, indexPointConverted))
    }

    func processPoints(wrist: CGPoint?, thumb: [CGPoint], index: [CGPoint], middle: [CGPoint], ring: [CGPoint], little: [CGPoint]) {
        guard let wrist = wrist else {
            cameraView.showPoints([], color: .clear)
            return
        }

        let convertedThumb = thumb.map { cameraView.previewLayer.layerPointConverted(fromCaptureDevicePoint: $0) }
        let convertedIndex = index.map { cameraView.previewLayer.layerPointConverted(fromCaptureDevicePoint: $0) }
        let convertedMiddle = middle.map { cameraView.previewLayer.layerPointConverted(fromCaptureDevicePoint: $0) }
        let convertedRing = ring.map { cameraView.previewLayer.layerPointConverted(fromCaptureDevicePoint: $0) }
        let convertedLittle = little.map { cameraView.previewLayer.layerPointConverted(fromCaptureDevicePoint: $0) }
        let convertedWrist = cameraView.previewLayer.layerPointConverted(fromCaptureDevicePoint: wrist)

        cameraView.showPoints(wrist: convertedWrist, thumb: convertedThumb, index: convertedIndex, middle: convertedMiddle, ring: convertedRing, little: convertedLittle)
    }

    private func handleGestureStateChange(state: HandGestureProcessor.State) {
        let pointsPair = gestureProcessor.lastProcessedPointsPair
        var tipsColor: UIColor
        switch state {
        case .possiblePinch, .possibleApart:
            // We are in one of the "possible": states, meaning there is not enough evidence yet to determine
            // if we want to draw or not. For now, collect points in the evidence buffer, so we can add them
            // to a drawing path when required.
            evidenceBuffer.append(pointsPair)
            tipsColor = .orange
        case .pinched:
            // We have enough evidence to draw. Draw the points collected in the evidence buffer, if any.
            for bufferedPoints in evidenceBuffer {
                updatePath(with: bufferedPoints, isLastPointsPair: false)
            }
            // Clear the evidence buffer.
            evidenceBuffer.removeAll()
            // Finally, draw the current point.
            updatePath(with: pointsPair, isLastPointsPair: false)
            tipsColor = .green
        case .apart, .unknown:
            // We have enough evidence to not draw. Discard any evidence buffer points.
            evidenceBuffer.removeAll()
            // And draw the last segment of our draw path.
            updatePath(with: pointsPair, isLastPointsPair: true)
            tipsColor = .red
        }
        cameraView.showPoints([pointsPair.thumbTip, pointsPair.indexTip], color: tipsColor)
    }

    private func updatePath(with points: HandGestureProcessor.PointsPair, isLastPointsPair: Bool) {
        // Get the mid point between the tips.
        let (thumbTip, indexTip) = points
        let drawPoint = CGPoint.midPoint(p1: thumbTip, p2: indexTip)

        if isLastPointsPair {
            if let lastPoint = lastDrawPoint {
                // Add a straight line from the last midpoint to the end of the stroke.
                drawPath.addLine(to: lastPoint)
            }
            // We are done drawing, so reset the last draw point.
            lastDrawPoint = nil
        } else {
            if lastDrawPoint == nil {
                // This is the beginning of the stroke.
                drawPath.move(to: drawPoint)
                isFirstSegment = true
            } else {
                let lastPoint = lastDrawPoint!
                // Get the midpoint between the last draw point and the new point.
                let midPoint = CGPoint.midPoint(p1: lastPoint, p2: drawPoint)
                if isFirstSegment {
                    // If it's the first segment of the stroke, draw a line to the midpoint.
                    drawPath.addLine(to: midPoint)
                    isFirstSegment = false
                } else {
                    // Otherwise, draw a curve to a midpoint using the last draw point as a control point.
                    drawPath.addQuadCurve(to: midPoint, controlPoint: lastPoint)
                }
            }
            // Remember the last draw point for the next update pass.
            lastDrawPoint = drawPoint
        }
        // Update the path on the overlay layer.
        drawOverlay.path = drawPath.cgPath
    }

    @IBAction func handleGesture(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else {
            return
        }
        evidenceBuffer.removeAll()
        drawPath.removeAllPoints()
        drawOverlay.path = drawPath.cgPath
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

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        var thumbFinger: [CGPoint] = []
        var indexFinger: [CGPoint] = []
        var middleFinger: [CGPoint] = []
        var ringFinger: [CGPoint] = []
        var littleFinger: [CGPoint] = []
        var wrist: CGPoint?

        defer {
            DispatchQueue.main.sync {
                self.processPoints(wrist: wrist, thumb: thumbFinger, index: indexFinger, middle: middleFinger, ring: ringFinger, little: littleFinger)
            }
        }

        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        do {
            // Perform VNDetectHumanHandPoseRequest
            try handler.perform([handPoseRequest])
            // Continue only when a hand was detected in the frame.
            // Since we set the maximumHandCount property of the request to 1, there will be at most one observation.
            guard let observation = handPoseRequest.results?.first else {
                return
            }

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

        } catch {
            cameraFeedSession?.stopRunning()
            let error = AppError.visionError(error: error)
            DispatchQueue.main.async {
                error.displayInViewController(self)
            }
        }
    }
}
