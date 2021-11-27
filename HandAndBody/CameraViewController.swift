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
    var cameraView: CameraView { view as! CameraView }

    let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInteractive)
    var cameraFeedSession = AVCaptureSession()
    let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
                                                                       mediaType: .video, position: .unspecified)
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    @objc dynamic var videoDeviceOutput: AVCaptureVideoDataOutput!

    var handPoseRequest = VNDetectHumanHandPoseRequest()
    var bodyPoseRequest = VNDetectHumanBodyPoseRequest()

    private let bottomStack = UIStackView()
    private let handButton = UIButton()
    private let bodyButton = UIButton()
    private let switchCameraButton = UIButton()

    enum VisisonMode {
        case handPose
        case bodyPose
    }

    var visionMode: VisisonMode = .handPose {
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
            changeCamera()
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
            cameraView.previewLayer.videoGravity = .resizeAspectFill
            try setupAVSession()
            cameraView.previewLayer.session = cameraFeedSession
            cameraFeedSession.startRunning()
        } catch {
            AppError.display(error, inViewController: self)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        cameraFeedSession.stopRunning()
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
        cameraFeedSession.beginConfiguration()

        // Add video input.
        do {
            var defaultVideoDevice: AVCaptureDevice?

            // Choose the back dual camera, if available, otherwise default to a wide angle camera.

            if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                defaultVideoDevice = dualCameraDevice
            } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                // If a rear dual camera is not available, default to the rear wide angle camera.
                defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                // If the rear wide angle camera isn't available, default to the front wide angle camera.
                defaultVideoDevice = frontCameraDevice
            }
            guard let videoDevice = defaultVideoDevice else {
                print("Default video device is unavailable.")
                cameraFeedSession.commitConfiguration()
                return
            }
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)

            if cameraFeedSession.canAddInput(videoDeviceInput) {
                cameraFeedSession.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput

                DispatchQueue.main.async {
                    let initialVideoOrientation: AVCaptureVideoOrientation = .portrait
                    self.cameraView.previewLayer.connection?.videoOrientation = initialVideoOrientation
                }
            } else {
                print("Couldn't add video device input to the session.")
                cameraFeedSession.commitConfiguration()
                return
            }

            let videoDeviceOutput = AVCaptureVideoDataOutput()
            if cameraFeedSession.canAddOutput(videoDeviceOutput) {
                cameraFeedSession.addOutput(videoDeviceOutput)
                // Add a video data output.
                videoDeviceOutput.alwaysDiscardsLateVideoFrames = true
                videoDeviceOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
                videoDeviceOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
            } else {
                cameraFeedSession.commitConfiguration()
                throw AppError.captureSessionSetup(reason: "Could not add video data output to the session")
            }
        } catch {
            print("Couldn't create video device input: \(error)")
            cameraFeedSession.commitConfiguration()
            return
        }

        cameraFeedSession.commitConfiguration()
    }

    func changeCamera() {
        switchCameraButton.isEnabled = false
        videoDataOutputQueue.async {
            let currentVideoDevice = self.videoDeviceInput.device
            let currentPosition = currentVideoDevice.position

            let preferredPosition: AVCaptureDevice.Position
            let preferredDeviceType: AVCaptureDevice.DeviceType

            switch currentPosition {
            case .unspecified, .front:
                preferredPosition = .back
                preferredDeviceType = .builtInDualCamera

            case .back:
                preferredPosition = .front
                preferredDeviceType = .builtInTrueDepthCamera

            @unknown default:
                print("Unknown capture position. Defaulting to back, dual-camera.")
                preferredPosition = .back
                preferredDeviceType = .builtInDualCamera
            }
            let devices = self.videoDeviceDiscoverySession.devices
            var newVideoDevice: AVCaptureDevice?

            // First, seek a device with both the preferred position and device type. Otherwise, seek a device with only the preferred position.
            if let device = devices.first(where: { $0.position == preferredPosition && $0.deviceType == preferredDeviceType }) {
                newVideoDevice = device
            } else if let device = devices.first(where: { $0.position == preferredPosition }) {
                newVideoDevice = device
            }

            if let videoDevice = newVideoDevice {
                do {
                    let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)

                    self.cameraFeedSession.beginConfiguration()

                    // Remove the existing device input first, because AVCaptureSession doesn't support
                    // simultaneous use of the rear and front cameras.
                    self.cameraFeedSession.removeInput(self.videoDeviceInput)

                    if self.cameraFeedSession.canAddInput(videoDeviceInput) {
                        self.cameraFeedSession.addInput(videoDeviceInput)
                        self.videoDeviceInput = videoDeviceInput
                    } else {
                        self.cameraFeedSession.addInput(self.videoDeviceInput)
                    }

                    self.cameraFeedSession.outputs.forEach { self.cameraFeedSession.removeOutput($0) }
                    self.videoDeviceOutput = AVCaptureVideoDataOutput()
                    if self.cameraFeedSession.canAddOutput(self.videoDeviceOutput) {
                        self.cameraFeedSession.addOutput(self.videoDeviceOutput)
                        // Add a video data output.
                        self.videoDeviceOutput.alwaysDiscardsLateVideoFrames = true
                        self.videoDeviceOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
                        self.videoDeviceOutput.setSampleBufferDelegate(self, queue: self.videoDataOutputQueue)
                    } else {
                        self.cameraFeedSession.commitConfiguration()
                        throw AppError.captureSessionSetup(reason: "Could not add video data output to the session")
                    }

                    self.cameraFeedSession.commitConfiguration()
                } catch {
                    print("Error occurred while creating video device input: \(error)")
                }
            }

            DispatchQueue.main.async {
                self.switchCameraButton.isEnabled = true
            }
        }
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
}
