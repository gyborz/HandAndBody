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

    private let bottomStack = UIStackView()
    private let handButton = UIButton()
    private let bodyButton = UIButton()
    private let switchCameraButton = UIButton()

    private enum VisisonMode {
        case handPose
        case bodyPose
    }

    private var visionMode: VisisonMode = .handPose {
        didSet {
            switch visionMode {
            case .handPose:
                handButton.setImage(UIImage(systemName: "hand.raised.fill"), for: .normal)
                bodyButton.setImage(UIImage(systemName: "person"), for: .normal)
            case .bodyPose:
                handButton.setImage(UIImage(systemName: "hand.raised"), for: .normal)
                bodyButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
            }
        }
    }

    private var isFrontFacingCamera: Bool = true {
        didSet {
            if isFrontFacingCamera {
                print("todo")
            } else {
                print("todo")
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.shared.isIdleTimerDisabled = true
        setupUI()

        handPoseRequest.maximumHandCount = 2
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

    private func setupUI() {
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        bottomStack.axis = .horizontal
        bottomStack.spacing = 2
        bottomStack.distribution = .equalSpacing
        view.addSubview(bottomStack)
        NSLayoutConstraint.activate([
            bottomStack.widthAnchor.constraint(equalToConstant: 250),
            bottomStack.heightAnchor.constraint(equalToConstant: 120),
            bottomStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            bottomStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])

        handButton.translatesAutoresizingMaskIntoConstraints = false
        handButton.tag = 1
        handButton.setImage(UIImage(systemName: "hand.raised.fill"), for: .normal)
        handButton.tintColor = .white
        handButton.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 26), forImageIn: .normal)
        handButton.addTarget(self, action: #selector(handleHandButtonEvent), for: .touchUpInside)

        bodyButton.translatesAutoresizingMaskIntoConstraints = false
        bodyButton.tag = 2
        bodyButton.setImage(UIImage(systemName: "person"), for: .normal)
        bodyButton.tintColor = .white
        bodyButton.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 26), forImageIn: .normal)
        bodyButton.addTarget(self, action: #selector(handleBodyButtonEvent), for: .touchUpInside)

        switchCameraButton.translatesAutoresizingMaskIntoConstraints = false
        switchCameraButton.setImage(UIImage(systemName: "arrow.triangle.2.circlepath.camera"), for: .normal)
        switchCameraButton.tintColor = .white
        switchCameraButton.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 26), forImageIn: .normal)
        switchCameraButton.addTarget(self, action: #selector(handleCameraButtonEvent), for: .touchUpInside)

        bottomStack.addArrangedSubview(handButton)
        bottomStack.addArrangedSubview(bodyButton)
        bottomStack.addArrangedSubview(switchCameraButton)
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

    @objc func handleHandButtonEvent(_ sender: UIButton) {
        visionMode = .handPose
    }

    @objc func handleBodyButtonEvent(_ sender: UIButton) {
        visionMode = .bodyPose
    }

    @objc func handleCameraButtonEvent(_ sender: UIButton) {
        isFrontFacingCamera.toggle()
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
        var hands: [Hand] = []
        var thumbFinger: [CGPoint] = []
        var indexFinger: [CGPoint] = []
        var middleFinger: [CGPoint] = []
        var ringFinger: [CGPoint] = []
        var littleFinger: [CGPoint] = []
        var wrist: CGPoint?

        defer {
            DispatchQueue.main.sync {
                self.processPoints(hands: hands)
            }
        }

        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        do {
            // Perform VNDetectHumanHandPoseRequest
            try handler.perform([handPoseRequest])
            // Continue only when a hand was detected in the frame.
            // Since we set the maximumHandCount property of the request to 1, there will be at most one observation.
            guard let observations = handPoseRequest.results else { return }

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
        } catch {
            cameraFeedSession?.stopRunning()
            let error = AppError.visionError(error: error)
            DispatchQueue.main.async {
                error.displayInViewController(self)
            }
        }
    }
}
