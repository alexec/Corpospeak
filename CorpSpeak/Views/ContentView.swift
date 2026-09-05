import SwiftUI

struct ContentView: View {
    let model: CorpSpeakModel

    var body: some View {
        ZStack {
            Backdrop(phase: model.phase, level: model.listener.audioLevel)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 8) {
                    StatusPill(model: model)
                    MuteButton(model: model)
                    Spacer()
                    VoiceMenu(model: model)
                    VoiceHelpButton(model: model)
                }
                .padding(.top, 8)

                Transcript(model: model)
                    .padding(.top, 16)
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

// MARK: - Type scale

private enum Type {
    static let label = Font.system(size: 10, weight: .semibold, design: .rounded)
    static let heard = Font.system(size: 21, weight: .regular, design: .rounded)
    static let reply = Font.system(size: 34, weight: .medium, design: .serif)
    static let control = Font.system(size: 12, weight: .medium, design: .rounded)
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

                    if model.phase == .setup {
                        setup
                    } else if heard.isEmpty && sentences.isEmpty {
                        emptyState
                    } else {
                        if !heard.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionLabel(isLive ? "HEARING" : "YOU SAID")
                                WordFlow(text: heard, font: Type.heard, opacity: isLive ? 0.55 : 0.72, italic: isLive)
                            }
                        }

                        if !sentences.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(sentences.enumerated()), id: \.offset) { index, sentence in
                                    Text(sentence)
                                        .font(Type.reply)
                                        .foregroundStyle(.white)
                                        .opacity(current == nil || current == index ? 1 : 0.32)
                                        .textSelection(.enabled)
                                        .lineSpacing(4)
                                        .id(Anchor.sentence(index))
                                        // Sentences rise in one after another.
                                        .transition(
                                            .opacity.combined(with: .offset(y: 18))
                                                .animation(.spring(duration: 0.55, bounce: 0.18).delay(Double(index) * 0.09))
                                        )
                                }
                            }
                            .frame(maxWidth: 720, alignment: .leading)
                            .animation(.easeInOut(duration: 0.3), value: current)
                            .id(model.translated)

                            CopyButton(text: model.translated)
                                .padding(.top, 2)
                        }
                    }

                    Spacer(minLength: 0)
                }
                // Short content sits vertically centred; long content scrolls.
                .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .leading)
                .animation(.spring(duration: 0.55, bounce: 0.15), value: model.translated)
                .animation(.easeInOut(duration: 0.35), value: model.phase)
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

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 22) {
            Waveform(level: model.listener.audioLevel, isActive: isReadyToListen && !model.isMuted)
                .frame(height: 56)
            // Only invite the user to talk once the app is actually listening.
            Text("Say something in plain English.")
                .font(.system(size: 30, weight: .regular, design: .serif))
                .foregroundStyle(.white.opacity(0.3))
                .opacity(isReadyToListen ? 1 : 0)
        }
        .transition(.opacity)
    }

    private var setup: some View {
        let status = model.speaker.voiceStatus
        return VStack(alignment: .leading, spacing: 14) {
            SectionLabel("FIRST, CORPSPEAK NEEDS YOUR VOICE")
            Text(setupTitle(for: status))
                .font(.system(size: 30, weight: .medium, design: .serif))
                .foregroundStyle(.white)
                .lineSpacing(4)
            Text(setupDetail(for: status))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .lineSpacing(3)
            if status != .unsupported {
                HStack(spacing: 10) {
                    SetupButton("Use my Personal Voice", systemImage: "person.wave.2", prominent: true) {
                        Task { await model.authorizeVoice() }
                    }
                    SetupButton("Open System Settings", systemImage: "gear", prominent: false) {
                        model.openVoiceSettings()
                    }
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: 720, alignment: .leading)
        .transition(.opacity)
    }

    private func setupTitle(for status: Speaker.VoiceStatus) -> String {
        switch status {
        case .checking: "Looking for your Personal Voice…"
        case .unsupported: "This Mac can't offer a Personal Voice."
        case .notDetermined: "Corpospeak speaks in your own voice."
        case .denied: "Corpospeak isn't allowed to use your Personal Voice."
        case .noVoice: "You don't have a Personal Voice yet."
        case .ready: "Your voice is ready."
        }
    }

    private func setupDetail(for status: Speaker.VoiceStatus) -> String {
        switch status {
        case .checking:
            ""
        case .unsupported:
            "Corpospeak speaks only in your own voice, and macOS can't create one on this Mac."
        case .notDetermined:
            "macOS clones it as a Personal Voice: System Settings → Accessibility → Personal Voice, ten phrases, about a minute. Then let Corpospeak use it. Nothing you say leaves the Mac."
        case .denied:
            "In System Settings → Accessibility → Personal Voice, turn on “Allow Apps to Request to Use”, then try again."
        case .noVoice:
            "Create one in System Settings → Accessibility → Personal Voice (ten phrases, about a minute). Corpospeak will notice as soon as it's ready."
        case .ready:
            ""
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

    private var isReadyToListen: Bool {
        model.phase == .listening || model.phase == .muted
    }
}

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Type.label)
            .tracking(3)
            .foregroundStyle(.white.opacity(0.38))
    }
}

/// A capsule button for the setup step.
private struct SetupButton: View {
    let title: String
    let systemImage: String
    let prominent: Bool
    let action: () -> Void

    init(_ title: String, systemImage: String, prominent: Bool, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.prominent = prominent
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(prominent ? Color.black : .white.opacity(0.8))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(prominent ? Color.white.opacity(0.92) : .white.opacity(0.08), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(prominent ? 0 : 0.12)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Copy

/// Puts the reply on the clipboard. ⌘⇧C does the same.
private struct CopyButton: View {
    let text: String
    @State private var copiedAt: Date?

    private var isCopied: Bool {
        copiedAt.map { Date().timeIntervalSince($0) < 1.6 } ?? false
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.4)) { _ in
            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                copiedAt = Date()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    Text(isCopied ? "Copied" : "Copy")
                }
                .font(Type.control)
                .foregroundStyle(isCopied ? Color.green : .white.opacity(0.55))
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(.white.opacity(0.05), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.07)))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .help("Copy the Corpospeak text (⇧⌘C)")
            .animation(.easeInOut(duration: 0.2), value: isCopied)
        }
        .fixedSize()
    }
}

// MARK: - Word flow

/// Text laid out word by word so new words can fade in as the recogniser delivers them.
private struct WordFlow: View {
    let text: String
    let font: Font
    let opacity: Double
    let italic: Bool

    var body: some View {
        let words = text.split(separator: " ").map(String.init)
        FlowLayout(spacing: 6, lineSpacing: 4) {
            ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                Text(word)
                    .font(font)
                    .italic(italic)
                    .foregroundStyle(.white.opacity(opacity))
                    .transition(.opacity.combined(with: .offset(y: 5)))
            }
        }
        .textSelection(.enabled)
        .animation(.easeOut(duration: 0.28), value: words.count)
        .animation(.easeInOut(duration: 0.2), value: opacity)
    }
}

/// A left-to-right, wrapping layout.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, in: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + CGFloat(max(0, rows.count - 1)) * lineSpacing
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, in: bounds.width) {
            var x = bounds.minX
            for (index, size) in row.items {
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var items: [(Int, CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, in maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            var row = rows[rows.count - 1]
            let needed = row.items.isEmpty ? size.width : row.width + spacing + size.width
            if needed > maxWidth, !row.items.isEmpty {
                rows.append(Row())
                row = rows[rows.count - 1]
            }
            row.items.append((index, size))
            row.width = row.items.isEmpty ? size.width : (row.width == 0 ? size.width : row.width + spacing + size.width)
            row.height = max(row.height, size.height)
            rows[rows.count - 1] = row
        }
        return rows
    }
}

// MARK: - Waveform

/// A row of bars that idles gently when quiet and swells with the microphone.
private struct Waveform: View {
    let level: Float
    let isActive: Bool

    private let barCount = 36

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isActive)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let loudness = Double(level)
            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<barCount, id: \.self) { index in
                    let position = Double(index) / Double(barCount - 1)
                    let envelope = sin(position * .pi) // quiet at the ends, full in the middle
                    let idle = 0.12 + 0.08 * (1 + sin(t * 1.4 + Double(index) * 0.5)) / 2
                    let excited = loudness * envelope * (0.55 + 0.45 * abs(sin(t * 11 + Double(index) * 0.9)))
                    let height = min(1, idle + excited)
                    Capsule()
                        .fill(.white.opacity(isActive ? 0.22 + 0.55 * loudness * envelope : 0.1))
                        .frame(width: 3, height: 4 + 48 * height)
                }
            }
            .animation(.easeOut(duration: 0.08), value: level)
        }
        .opacity(isActive ? 1 : 0.5)
        .animation(.easeInOut(duration: 0.3), value: isActive)
    }
}

// MARK: - Backdrop

/// Dark gradient with a glow that drifts slowly, breathes with the microphone, and pulses with
/// the phase.
private struct Backdrop: View {
    let phase: CorpSpeakModel.Phase
    let level: Float

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let pulse = isPulsing ? 0.5 + 0.5 * sin(t * 2.4) : 0
            let loudness = Double(level)
            let scale = 1 + (isPulsing ? 0.22 * pulse : 1.3 * loudness)
            let opacity = 0.42 + (isPulsing ? 0.32 * pulse : 0.6 * loudness)

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
                                colors: [glowColor.opacity(opacity), glowColor.opacity(0.1), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 340
                            )
                        )
                        .frame(width: 680, height: 680)
                        .scaleEffect(scale)
                        .blur(radius: 34)
                        .position(
                            x: geo.size.width - 60 + 50 * sin(t * 0.21),
                            y: geo.size.height + 40 + 36 * cos(t * 0.16)
                        )
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
        case .setup: Color(hue: 0.92, saturation: 0.7, brightness: 1.0)
        case .listening: Color(hue: 0.42, saturation: 0.7, brightness: 0.9)
        case .muted: Color(hue: 0.62, saturation: 0.2, brightness: 0.5)
        case .translating: Color(hue: 0.09, saturation: 0.8, brightness: 1.0)
        case .speaking: Color(hue: 0.58, saturation: 0.8, brightness: 1.0)
        case .error: Color(hue: 0.0, saturation: 0.75, brightness: 0.95)
        }
    }
}

// MARK: - Status

/// Shows what the app is doing. While it is translating or speaking, clicking it (or Escape) stops.
private struct StatusPill: View {
    let model: CorpSpeakModel
    @State private var isHovering = false

    private var phase: CorpSpeakModel.Phase { model.phase }
    private var silenceDeadline: Date? { model.listener.silenceDeadline }
    private var silenceInterval: TimeInterval { model.listener.silenceInterval }
    private var canStop: Bool { model.canStop }

    var body: some View {
        Button {
            model.stopSpeaking()
        } label: {
            HStack(spacing: 8) {
                if canStop && isHovering {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 14, height: 14)
                } else {
                    dot
                }
                Text(canStop && isHovering ? "Stop" : text)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(canStop && isHovering ? Color.red.opacity(0.7) : .white.opacity(0.11), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.14)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!canStop)
        .keyboardShortcut(.escape, modifiers: [])
        .onHover { isHovering = $0 }
        .help(canStop ? "Stop translating and speaking (Esc)" : "")
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .animation(.easeInOut(duration: 0.25), value: phase)
    }

    /// The dot, wrapped in a ring that closes as the pause runs out. When the ring completes,
    /// what was said so far is sent off.
    private var dot: some View {
        let isCountingDown = silenceDeadline != nil && phase == .listening
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
        case .setup: "Needs your voice"
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
        case .setup: .pink
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
                .foregroundStyle(model.isMuted ? Color.orange : .white.opacity(0.6))
                .frame(width: 30, height: 30)
                .background(.white.opacity(model.isMuted ? 0.12 : 0.05), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.07)))
        }
        .buttonStyle(.plain)
        .keyboardShortcut("m", modifiers: .command)
        .help(model.isMuted ? "Unmute the microphone (⌘M)" : "Mute the microphone (⌘M)")
        .disabled(model.phase == .starting)
    }
}

// MARK: - Voice button

/// Shows which voice is in use and offers the ways to set it up.
private struct VoiceMenu: View {
    let model: CorpSpeakModel

    var body: some View {
        Menu {
            Button("Use my Personal Voice…") {
                Task { await model.authorizeVoice() }
            }
            Button("Open Personal Voice settings…") {
                model.openVoiceSettings()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label)
            }
            .font(Type.control)
            .foregroundStyle(.white.opacity(0.65))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.white.opacity(0.05), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.07)))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("The voice Corpospeak speaks with")
    }

    private var label: String {
        switch model.speaker.voiceStatus {
        case .checking: "Checking voice…"
        case .unsupported: "No Personal Voice on this Mac"
        case .notDetermined: "No voice yet"
        case .denied: "Voice not allowed"
        case .noVoice: "No Personal Voice yet"
        case .ready(let name): "Your voice · \(name)"
        }
    }

    private var icon: String {
        model.speaker.isReady ? "person.wave.2" : "person.crop.circle.badge.questionmark"
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
                .foregroundStyle(.white.opacity(model.speaker.isReady ? 0.45 : 0.85))
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.05), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.07)))
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

            Text("Corpospeak speaks in **your voice**: the Personal Voice that macOS creates in System Settings → Accessibility → Personal Voice. Nothing you say leaves the Mac.")
            Text(statusLine)
                .foregroundStyle(.secondary)
            Text("To change how it sounds, record a new Personal Voice in System Settings. You can withdraw Corpospeak's access in the same place at any time.")
                .foregroundStyle(.secondary)

            Divider()

            Link(destination: URL(string: "https://www.youtube.com/shorts/JNRDj799VK4")!) {
                Label("Got the job. No one asked what it was.", systemImage: "play.rectangle")
            }
            .foregroundStyle(.secondary)
        }
        .font(.callout)
        .padding(18)
        .frame(width: 340)
    }

    private var statusLine: String {
        switch speaker.voiceStatus {
        case .checking: "Looking for your Personal Voice…"
        case .unsupported: "This Mac can't offer a Personal Voice, so nothing can be spoken."
        case .notDetermined: "Corpospeak hasn't asked to use your Personal Voice yet. Choose “Use my Personal Voice…” from the voice menu."
        case .denied: "Corpospeak isn't allowed to use your Personal Voice. Turn on “Allow Apps to Request to Use” in System Settings."
        case .noVoice: "No Personal Voice has been created yet."
        case .ready(let name): "Speaking with “\(name)”."
        }
    }
}

#Preview {
    ContentView(model: CorpSpeakModel())
}
