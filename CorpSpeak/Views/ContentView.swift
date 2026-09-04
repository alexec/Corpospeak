import SwiftUI

struct ContentView: View {
    let model: CorpSpeakModel

    var body: some View {
        ZStack {
            Backdrop(phase: model.phase, level: model.listener.audioLevel)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 8) {
                    StatusPill(
                        phase: model.phase,
                        silenceDeadline: model.listener.silenceDeadline,
                        silenceInterval: model.listener.silenceInterval
                    )
                    MuteButton(model: model)
                    Spacer()
                    VoiceMenu(model: model)
                    VoiceHelpButton(model: model)
                }
                .padding(.top, 8)
                .background {
                    // Escape cuts off whatever is being spoken.
                    Button("Stop speaking") { model.stopSpeaking() }
                        .keyboardShortcut(.escape, modifiers: [])
                        .hidden()
                }

                Transcript(model: model)
                    .padding(.vertical, 16)

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
}

// MARK: - Transcript

/// What was heard and what CorpSpeak made of it. While speaking, the current sentence is lit
/// and scrolled into view, teleprompter style.
private struct Transcript: View {
    let model: CorpSpeakModel

    private enum Anchor: Hashable {
        case top
        case sentence(Int)
    }

    var body: some View {
        let heard = isLive ? model.listener.liveTranscript : model.heard
        let sentences = displayedSentences
        let current = model.speaker.isSpeaking ? model.speaker.currentSentence : nil

        GeometryReader { geo in
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 18) {
                    Color.clear.frame(height: 1).id(Anchor.top)
                    Spacer(minLength: 0)

                    if model.phase == .enrolling {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("FIRST, LET ME LEARN YOUR VOICE. SAY THIS:")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .tracking(2)
                                .foregroundStyle(.white.opacity(0.45))
                            Text(VoiceSample.phrase)
                                .font(.system(size: 30, weight: .medium, design: .serif))
                                .foregroundStyle(.white)
                                .lineSpacing(4)
                            if !model.enrollmentHint.isEmpty {
                                Text(model.enrollmentHint)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.orange)
                            }
                            if isLive {
                                Text(model.listener.liveTranscript)
                                    .font(.system(size: 17, weight: .regular, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .italic()
                            }
                        }
                        .frame(maxWidth: 720, alignment: .leading)
                    } else if heard.isEmpty && sentences.isEmpty {
                        Text("Say something in plain English.")
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

                        if !sentences.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(sentences.enumerated()), id: \.offset) { index, sentence in
                                    Text(sentence)
                                        .font(.system(size: 34, weight: .medium, design: .serif))
                                        .foregroundStyle(.white)
                                        .opacity(current == nil || current == index ? 1 : 0.32)
                                        .textSelection(.enabled)
                                        .lineSpacing(4)
                                        .id(Anchor.sentence(index))
                                }
                            }
                            .frame(maxWidth: 720, alignment: .leading)
                            .animation(.easeInOut(duration: 0.3), value: current)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                            .id(model.translated)
                        }
                    }

                    Spacer(minLength: 0)
                }
                // Short content sits vertically centred; long content scrolls.
                .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .leading)
                .animation(.spring(duration: 0.55, bounce: 0.15), value: model.translated)
            }
            .scrollIndicators(.hidden)
            .mask(
                // Fade the top and bottom edges so long text scrolls under a soft edge.
                LinearGradient(
                    stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.06),
                            .init(color: .black, location: 0.94), .init(color: .clear, location: 1)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .onChange(of: model.translated) {
                withAnimation(.easeOut(duration: 0.4)) { proxy.scrollTo(Anchor.top, anchor: .top) }
            }
            .onChange(of: current) {
                guard let current else { return }
                withAnimation(.easeInOut(duration: 0.45)) {
                    proxy.scrollTo(Anchor.sentence(current), anchor: .center)
                }
            }
        }
        }
    }

    /// The speaker's own sentence split while speaking, otherwise the same split of the text.
    private var displayedSentences: [String] {
        guard !model.translated.isEmpty else { return [] }
        if model.speaker.isSpeaking, !model.speaker.sentences.isEmpty {
            return model.speaker.sentences
        }
        return Speaker.split(model.translated)
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
        case .enrolling: Color(hue: 0.92, saturation: 0.7, brightness: 1.0)
        case .listening: Color(hue: 0.42, saturation: 0.7, brightness: 0.9)
        case .muted: Color(hue: 0.62, saturation: 0.2, brightness: 0.5)
        case .translating: Color(hue: 0.09, saturation: 0.8, brightness: 1.0)
        case .speaking: Color(hue: 0.58, saturation: 0.8, brightness: 1.0)
        case .error: Color(hue: 0.0, saturation: 0.75, brightness: 0.95)
        }
    }
}

// MARK: - Status

private struct StatusPill: View {
    let phase: CorpSpeakModel.Phase
    let silenceDeadline: Date?
    let silenceInterval: TimeInterval

    var body: some View {
        HStack(spacing: 8) {
            dot
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

    /// The dot, wrapped in a ring that closes as the pause runs out. When the ring completes,
    /// what was said so far is sent off.
    private var dot: some View {
        let isCountingDown = silenceDeadline != nil && (phase == .listening || phase == .enrolling)
        return TimelineView(.animation(paused: !isCountingDown)) { context in
            let remaining = isCountingDown ? max(0, silenceDeadline!.timeIntervalSince(context.date)) : 0
            let fraction = isCountingDown && silenceInterval > 0 ? remaining / silenceInterval : 0
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                    .shadow(color: color.opacity(0.9), radius: 4)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(color.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 14, height: 14)
                    .opacity(isCountingDown ? 1 : 0)
            }
            .frame(width: 14, height: 14)
        }
    }

    private var text: String {
        switch phase {
        case .starting: "Starting…"
        case .enrolling: "Recording your voice"
        case .listening: silenceDeadline == nil ? "Listening" : "Listening… pause to send"
        case .muted: "Muted"
        case .translating: "Translating…"
        case .speaking: "Speaking"
        case .error(let message): message
        }
    }

    private var color: Color {
        switch phase {
        case .starting: .gray
        case .enrolling: .pink
        case .listening: .green
        case .muted: .gray
        case .translating: .orange
        case .speaking: .cyan
        case .error: .red
        }
    }
}

// MARK: - Mute

private struct MuteButton: View {
    let model: CorpSpeakModel

    var body: some View {
        Button {
            model.toggleMute()
        } label: {
            Image(systemName: model.isMuted ? "mic.slash.fill" : "mic.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(model.isMuted ? Color.orange : .white.opacity(0.7))
                .frame(width: 30, height: 30)
                .background(.white.opacity(model.isMuted ? 0.12 : 0.06), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .keyboardShortcut("m", modifiers: .command)
        .help(model.isMuted ? "Unmute the microphone (⌘M)" : "Mute the microphone (⌘M)")
        .disabled(model.phase == .starting)
    }
}

// MARK: - Voice button

/// Shows which voice is in use and offers to record again.
private struct VoiceMenu: View {
    let model: CorpSpeakModel

    var body: some View {
        Menu {
            Button(model.speaker.hasOwnVoice ? "Record my voice again…" : "Record my voice…") {
                model.beginEnrollment()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label)
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
        .help("The voice CorpSpeak speaks with")
    }

    private var label: String {
        switch model.speaker.modelStore.state {
        case .downloading(_, let progress): "Downloading voice cloning \(Int(progress * 100))%"
        case .unpacking: "Preparing voice cloning…"
        default:
            switch model.speaker.engine {
            case .ownVoice: "Your voice"
            case .apple: model.speaker.hasOwnVoice ? "Loading your voice…" : "Built-in voice"
            }
        }
    }

    private var icon: String {
        switch model.speaker.modelStore.state {
        case .downloading, .unpacking: "arrow.down.circle"
        default: model.speaker.engine == .ownVoice ? "person.wave.2" : "waveform"
        }
    }
}

// MARK: - Voice help

private struct VoiceHelpButton: View {
    let model: CorpSpeakModel
    @State private var isShowingHelp = false

    var body: some View {
        Button {
            isShowingHelp.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(model.speaker.engine == .apple ? 0.85 : 0.5))
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.06), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .help("About the voice")
        .popover(isPresented: $isShowingHelp, arrowEdge: .bottom) {
            VoiceHelp(speaker: model.speaker)
        }
    }
}

private struct VoiceHelp: View {
    let speaker: Speaker

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voice")
                .font(.headline)

            switch speaker.modelStore.state {
            case .downloading(_, let progress):
                Text("Downloading the voice cloning model (about 160 MB, once). Apple's built-in voice is used until it arrives.")
                ProgressView(value: progress)
            case .unpacking:
                Text("Unpacking the voice cloning model. Nearly there.")
            case .failed(let message):
                Text("The voice cloning model could not be installed: \(message)")
                Text("Relaunch to try the download again.")
                    .foregroundStyle(.secondary)
            default:
                EmptyView()
            }

            Text("CorpSpeak speaks in **your voice**, cloned on this Mac by ZipVoice from the phrase you read on first launch. Nothing you say leaves the Mac.")
            Text("If it does not sound like you, choose *Record my voice again…* and read the phrase in one go, at a natural pace, in a quiet room.")
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .padding(18)
        .frame(width: 340)
    }
}

#Preview {
    ContentView(model: CorpSpeakModel())
}
