import SwiftUI

struct ContentView: View {
    let model: CorpSpeakModel

    var body: some View {
        ZStack {
            Backdrop(phase: model.phase, level: model.listener.audioLevel)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    StatusPill(phase: model.phase)
                    Spacer()
                    VoiceMenu(model: model)
                }
                .padding(.top, 8)

                Spacer(minLength: 24)

                transcript

                Spacer(minLength: 24)

                Link(destination: URL(string: "https://www.youtube.com/shorts/JNRDj799VK4")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.rectangle")
                        Text("Got the job. No one asked what it was.")
                    }
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
                .help("Watch on YouTube")
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 28)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.07))
        )
        .gesture(WindowDragGesture())
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    // MARK: Transcript

    @ViewBuilder
    private var transcript: some View {
        let heard = isLive ? model.listener.liveTranscript : model.heard

        VStack(alignment: .leading, spacing: 18) {
            if heard.isEmpty && model.translated.isEmpty {
                Text("Say something.")
                    .font(.system(size: 30, weight: .regular, design: .serif))
                    .foregroundStyle(.white.opacity(0.28))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isLive ? "HEARING" : "YOU SAID")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.35))
                    Text(heard)
                        .font(.system(size: 19, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(isLive ? 0.55 : 0.7))
                        .italic(isLive)
                        .contentTransition(.opacity)
                }
                .animation(.easeOut(duration: 0.2), value: heard)

                if !model.translated.isEmpty {
                    Text(model.translated)
                        .font(.system(size: 34, weight: .medium, design: .serif))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .textSelection(.enabled)
                        .lineSpacing(4)
                        .id(model.translated)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                }
            }
        }
        .frame(maxWidth: 720, alignment: .leading)
        .animation(.spring(duration: 0.55, bounce: 0.15), value: model.translated)
    }

    private var isLive: Bool {
        !model.listener.liveTranscript.isEmpty
    }
}

// MARK: - Backdrop

/// Dark gradient with a glow in the corner that breathes with the microphone and the phase.
private struct Backdrop: View {
    let phase: CorpSpeakModel.Phase
    let level: Float

    var body: some View {
        TimelineView(.animation(paused: !isPulsing)) { context in
            let pulse = isPulsing ? 0.5 + 0.5 * sin(context.date.timeIntervalSinceReferenceDate * 2.4) : 0
            let scale = 1 + (isPulsing ? 0.18 * pulse : 0.8 * Double(level))
            let opacity = 0.35 + (isPulsing ? 0.3 * pulse : 0.55 * Double(level))

            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.07, green: 0.08, blue: 0.13), Color(red: 0.01, green: 0.01, blue: 0.03)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                GeometryReader { geo in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [glowColor.opacity(opacity), glowColor.opacity(0.08), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 320
                            )
                        )
                        .frame(width: 640, height: 640)
                        .scaleEffect(scale)
                        .blur(radius: 30)
                        .position(x: geo.size.width - 80, y: geo.size.height + 60)
                }
                .animation(.easeOut(duration: 0.1), value: level)
                .animation(.easeInOut(duration: 0.6), value: phase)
            }
        }
    }

    private var isPulsing: Bool {
        phase == .translating || phase == .speaking
    }

    private var glowColor: Color {
        switch phase {
        case .starting: Color(hue: 0.62, saturation: 0.4, brightness: 0.7)
        case .listening: Color(hue: 0.42, saturation: 0.7, brightness: 0.9)
        case .translating: Color(hue: 0.09, saturation: 0.8, brightness: 1.0)
        case .speaking: Color(hue: 0.58, saturation: 0.8, brightness: 1.0)
        case .error: Color(hue: 0.0, saturation: 0.75, brightness: 0.95)
        }
    }
}

// MARK: - Status

private struct StatusPill: View {
    let phase: CorpSpeakModel.Phase

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.9), radius: 4)
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.white.opacity(0.06), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.08)))
        .animation(.easeInOut(duration: 0.25), value: phase)
    }

    private var text: String {
        switch phase {
        case .starting: "Starting…"
        case .listening: "Listening"
        case .translating: "Translating…"
        case .speaking: "Speaking"
        case .error(let message): message
        }
    }

    private var color: Color {
        switch phase {
        case .starting: .gray
        case .listening: .green
        case .translating: .orange
        case .speaking: .cyan
        case .error: .red
        }
    }
}

// MARK: - Voice picker

private struct VoiceMenu: View {
    let model: CorpSpeakModel

    var body: some View {
        let voices = Speaker.availableVoices()
        let tiers = Speaker.VoiceOption.Tier.allCases.filter { tier in voices.contains { $0.tier == tier } }
        let selection = Binding(
            get: { model.speaker.voiceIdentifier },
            set: { model.selectVoice($0) }
        )

        Menu {
            Picker("Voice", selection: selection) {
                ForEach(tiers, id: \.self) { tier in
                    Section(tier.title) {
                        ForEach(voices.filter { $0.tier == tier }) { voice in
                            Text(voice.name).tag(voice.id)
                        }
                    }
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                Text(model.speaker.voice?.name ?? "Voice")
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.8))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.white.opacity(0.06), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.08)))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Choose the voice CorpSpeak speaks with")
    }
}

#Preview {
    ContentView(model: CorpSpeakModel())
}
