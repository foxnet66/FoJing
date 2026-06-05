@preconcurrency import AVFoundation
import SwiftUI

private enum ChantInstrument {
    case woodFish
    case bell
}

private final class ChantSoundEngine: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var isConfigured = false

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func play(_ instrument: ChantInstrument) {
        configureAudioSession()
        startEngineIfNeeded()

        let buffer = makeBuffer(for: instrument)
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
    }

    private func configureAudioSession() {
        guard !isConfigured else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        isConfigured = true
    }

    private func startEngineIfNeeded() {
        guard !engine.isRunning else { return }
        try? engine.start()
    }

    private func makeBuffer(for instrument: ChantInstrument) -> AVAudioPCMBuffer {
        switch instrument {
        case .woodFish:
            makeWoodFishBuffer()
        case .bell:
            makeBellBuffer()
        }
    }

    private func makeWoodFishBuffer() -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let duration = 0.16
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]
        var noiseSeed: UInt32 = 0x4D55_5955

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            noiseSeed = noiseSeed &* 1_664_525 &+ 1_013_904_223
            let noise = (Double(noiseSeed & 0xFFFF) / 32_768.0) - 1.0

            let attack = frame < 180 ? Double(180 - frame) / 180.0 : 0.0
            let cavity = exp(-t * 42.0)
            let shortResonance = exp(-t * 82.0)
            let body =
                sin(2.0 * .pi * 310.0 * t) * cavity * 0.22 +
                sin(2.0 * .pi * 620.0 * t) * shortResonance * 0.34 +
                sin(2.0 * .pi * 930.0 * t) * shortResonance * 0.16
            let woodenClick = noise * attack * 0.2

            samples[frame] = Float((body + woodenClick) * 0.82)
        }

        return buffer
    }

    private func makeBellBuffer() -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let duration = 1.25
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let shimmer = sin(2.0 * .pi * 1_320.0 * t) * exp(-t * 2.6)
            let overtone = sin(2.0 * .pi * 1_980.0 * t) * exp(-t * 3.4)
            let high = sin(2.0 * .pi * 2_640.0 * t) * exp(-t * 4.2)
            samples[frame] = Float((shimmer * 0.34) + (overtone * 0.2) + (high * 0.12))
        }

        return buffer
    }
}

struct ChantPracticeView: View {
    @Bindable var appModel: AppModel
    @State private var woodFishEnabled = true
    @State private var bellEnabled = false
    @State private var soundEngine = ChantSoundEngine()

    private var counterPractice: PracticeItem {
        appModel.practiceItems.first { $0.kind == .counter } ??
            PracticeItem(id: "practice-amitabha", title: "阿弥陀佛", scriptureID: nil, current: 0, target: 108, unit: "声", kind: .counter)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PaperCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("今日诵持")
                            .font(.headline)
                        HStack {
                            Text(counterPractice.title)
                            Spacer()
                            Text("\(counterPractice.current) / \(counterPractice.target)")
                                .monospacedDigit()
                                .foregroundStyle(AppTheme.secondaryInk)
                        }
                    }
                }

                VStack(spacing: 18) {
                    Text("今日目标")
                        .font(.headline)
                    Text("\(counterPractice.target) \(counterPractice.unit)")
                        .foregroundStyle(AppTheme.secondaryInk)
                    Text("\(counterPractice.current)")
                        .font(.system(size: 76, weight: .light, design: .serif))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.bamboo)
                    Button {
                        incrementCounter()
                    } label: {
                        Text(counterPractice.isComplete ? "已完成" : "记一声")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .foregroundStyle(.white)
                            .background(AppTheme.bamboo, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(counterPractice.isComplete)
                    .sensoryFeedback(.increase, trigger: counterPractice.current)
                }
                .frame(maxWidth: .infinity)
                .padding(22)
                .background(.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.paperDeep.opacity(0.7), lineWidth: 1)
                }

                PaperCard {
                    VStack(spacing: 14) {
                        Toggle(isOn: $woodFishEnabled) {
                            Label("木鱼", systemImage: "circle.hexagongrid")
                        }
                        Toggle(isOn: $bellEnabled) {
                            Label("引磬", systemImage: "bell")
                        }
                    }
                    .tint(AppTheme.bamboo)
                }

                NavigationLink {
                    DedicationView(appModel: appModel)
                } label: {
                    Label("进入回向", systemImage: "arrow.right.circle")
                        .font(.headline)
                        .foregroundStyle(appModel.firstIncompletePractice == nil ? AppTheme.bamboo : AppTheme.secondaryInk)
                }
                .disabled(appModel.firstIncompletePractice != nil)
            }
            .padding(20)
        }
        .navigationTitle("诵持")
        .sutraPageBackground()
    }

    private func incrementCounter() {
        let willComplete = counterPractice.current + 1 >= counterPractice.target
        appModel.incrementPractice(id: counterPractice.id)

        if woodFishEnabled {
            soundEngine.play(.woodFish)
        }

        if willComplete, bellEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                soundEngine.play(.bell)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChantPracticeView(appModel: AppModel())
    }
}
