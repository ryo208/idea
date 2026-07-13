import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var camera = CameraManager()
    private let speech = AVSpeechSynthesizer()

    private var colorName: String {
        let c = camera.detectedColor
        return ColorClassifier.name(r: c.r, g: c.g, b: c.b)
    }

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            // 中央の照準マーク
            Circle()
                .strokeBorder(.white, lineWidth: 2)
                .frame(width: 28, height: 28)
                .shadow(radius: 2)

            VStack {
                Spacer()
                resultPanel
            }

            if camera.permissionDenied {
                Text("設定アプリでカメラへのアクセスを許可してください")
                    .padding()
                    .background(.black.opacity(0.7))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .onAppear { camera.start() }
    }

    private var resultPanel: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12)
                .fill(camera.detectedColor.color)
                .frame(width: 64, height: 64)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.5)))

            VStack(alignment: .leading, spacing: 4) {
                Text(colorName)
                    .font(.title.bold())
                Text(camera.detectedColor.hex)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    speak(colorName)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title2)
                }
                .accessibilityLabel("色名を読み上げる")

                Button {
                    camera.toggleTorch()
                } label: {
                    Image(systemName: camera.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.title2)
                }
                .accessibilityLabel("ライトの切り替え")
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding()
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        speech.speak(utterance)
    }
}

/// AVCaptureSessionの映像をSwiftUIに表示する
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
