import AVFoundation
import SwiftUI

/// カメラ映像の中央付近の平均色を継続的に取得する
final class CameraManager: NSObject, ObservableObject {
    struct RGB: Equatable {
        var r: Double // 0-255
        var g: Double
        var b: Double

        var hex: String {
            String(format: "#%02X%02X%02X", Int(r), Int(g), Int(b))
        }

        var color: Color {
            Color(red: r / 255, green: g / 255, blue: b / 255)
        }
    }

    let session = AVCaptureSession()
    @Published var detectedColor = RGB(r: 128, g: 128, b: 128)
    @Published var isTorchOn = false
    @Published var permissionDenied = false

    private let queue = DispatchQueue(label: "colorlens.camera.queue")
    private var device: AVCaptureDevice?
    private var lastPublish = Date.distantPast

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            guard granted else {
                DispatchQueue.main.async { self.permissionDenied = true }
                return
            }
            self.queue.async {
                self.configure()
                self.session.startRunning()
            }
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        self.device = device
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        session.commitConfiguration()
    }

    /// 至近距離で測るときの照明ムラ対策にトーチを使う
    func toggleTorch() {
        guard let device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = device.torchMode == .on ? .off : .on
            device.unlockForConfiguration()
            let on = device.torchMode == .on
            DispatchQueue.main.async { self.isTorchOn = on }
        } catch {
            // トーチが使えない端末では無視
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // 更新は10回/秒に間引く
        guard Date().timeIntervalSince(lastPublish) > 0.1,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)

        // 中央の20x20pxを平均してノイズを抑える
        let half = 10
        let cx = width / 2
        let cy = height / 2
        var sumR = 0.0, sumG = 0.0, sumB = 0.0
        var count = 0.0

        let ptr = base.assumingMemoryBound(to: UInt8.self)
        for y in (cy - half)..<(cy + half) where y >= 0 && y < height {
            for x in (cx - half)..<(cx + half) where x >= 0 && x < width {
                let offset = y * bytesPerRow + x * 4 // BGRA
                sumB += Double(ptr[offset])
                sumG += Double(ptr[offset + 1])
                sumR += Double(ptr[offset + 2])
                count += 1
            }
        }
        guard count > 0 else { return }

        let rgb = RGB(r: sumR / count, g: sumG / count, b: sumB / count)
        lastPublish = Date()
        DispatchQueue.main.async {
            self.detectedColor = rgb
        }
    }
}
