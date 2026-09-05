import SwiftUI

struct ContentView: View {
    let model: CorpospeakModel
    @State private var width: CGFloat = 720

    var body: some View {
        // Phones, and iPads in a narrow split, get tighter spacing and smaller type.
        let compact = width < 600
        ZStack {
            Backdrop(phase: model.phase, level: model.listener.audioLevel)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 8) {
                    StatusPill(model: model)
                    MuteButton(model: model)
                    Spacer()
                    VoiceMenu(model: model, compact: compact)
                    VoiceHelpButton(model: model)
                }
                .padding(.top, 8)

                Transcript(model: model, compact: compact)
                    .padding(.top, 16)
            }
            .padding(.horizontal, compact ? 20 : 36)
            .padding(.vertical, compact ? 12 : 28)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .windowChrome()
        .preferredColorScheme(.dark)
    }
}

private extension View {
    /// On the Mac the window is a borderless rounded card that can be dragged from anywhere.
    /// On iPhone and iPad the app fills the screen and the system draws the edges.
    @ViewBuilder
    func windowChrome() -> some View {
        #if os(macOS)
        self
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.07))
            )
            .gesture(WindowDragGesture())
            .ignoresSafeArea()
        #else
        self
        #endif
    }
}

// MARK: - Type scale

private struct Type {
    static let label = Font.system(size: 10, weight: .semibold, design: .rounded)
    static let control = Font.system(size: 12, weight: .medium, design: .rounded)

    /// Smaller sizes for narrow screens.
    let compact: Bool

    var heard: Font { .system(size: compact ? 17 : 21, weight: .regular, design: .rounded) }
    var reply: Font { .system(size: compact ? 26 : 34, weight: .medium, design: .serif) }
    var title: Font { .system(size: compact ? 24 : 30, weight: .medium, design: .serif) }
    var prompt: Font { .system(size: compact ? 24 : 30, weight: .regular, design: .serif) }
}

// MARK: - Transcript

/// What was heard and what Corpospeak made of it. While speaking, the current sentence is lit
/// and scrolled into view, teleprompter style.
private struct Transcript: View {
    let model: CorpospeakModel
    let compact: Bool

    private var type: Type { Type(compact: compact) }

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

                    if heard.isEmpty && sentences.isEmpty {
                        emptyState
                    } else {
                        if !heard.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionLabel(isLive ? "HEARING" : "YOU SAID")
                                WordFlow(text: heard, font: type.heard, opacity: isLive ? 0.55 : 0.72, italic: isLive)
                            }
                        }

                        if !sentences.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(sentences.enumerated()), id: \.offset) { index, sentence in
                                    Text(sentence)
                                        .font(type.reply)
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
                            .id(model.replyID)

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
            .onChange(of: model.replyID) {
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
                .font(type.prompt)
                .foregroundStyle(.white.opacity(0.3))
                .opacity(isReadyToListen ? 1 : 0)
            // Until the app speaks in the user's own voice, say why that would be better. Only
            // here, before the first sentence, so it never nags mid-conversation.
            if isReadyToListen, model.canImprovePersonalVoice {
                PersonalVoiceNudge(model: model, compact: compact)
                    .transition(.opacity)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: model.canImprovePersonalVoice)
    }

    /// While speaking, the speaker's own sentences lead (so the highlight lines up with
    /// playback), followed by whatever the model has written since; otherwise the finished text.
    private var displayedSentences: [String] {
        guard !model.translated.isEmpty else { return [] }
        let written = Speaker.split(model.translated)
        guard model.speaker.isSpeaking else { return written }
        let queued = model.speaker.sentences
        return queued + written.dropFirst(queued.count)
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
                Platform.copy(text)
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
            .accessibilityLabel("Copy the Corpospeak text")
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
    let phase: CorpospeakModel.Phase
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
        case .listening: Color(hue: 0.42, saturation: 0.7, brightness: 0.9)
        case .muted: Color(hue: 0.62, saturation: 0.2, brightness: 0.5)
        case .translating: Color(hue: 0.09, saturation: 0.8, brightness: 1.0)
        case .speaking: Color(hue: 0.58, saturation: 0.8, brightness: 1.0)
        case .error: Color(hue: 0.0, saturation: 0.75, brightness: 0.95)
        }
    }
}

// MARK: - Status

/// Shows what the app is doing. While it is translating or speaking, tapping it (or Escape) stops.
private struct StatusPill: View {
    let model: CorpospeakModel
    @State private var isHovering = false

    private var phase: CorpospeakModel.Phase { model.phase }
    private var silenceDeadline: Date? { model.listener.silenceDeadline }
    private var silenceInterval: TimeInterval { model.listener.silenceInterval }
    private var canStop: Bool { model.canStop }

    /// With a pointer, the pill turns into a Stop button on hover. On a touch screen there is
    /// no hover, so it shows the stop mark whenever there is something to stop.
    private var offersStop: Bool {
        #if os(macOS)
        canStop && isHovering
        #else
        canStop
        #endif
    }

    var body: some View {
        Button {
            model.stopSpeaking()
        } label: {
            HStack(spacing: 8) {
                if offersStop {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 14, height: 14)
                } else {
                    dot
                }
                Text(offersStop && isHovering ? "Stop" : text)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(offersStop ? Color.red.opacity(isHovering ? 0.7 : 0.35) : .white.opacity(0.11), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.14)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!canStop)
        .keyboardShortcut(.escape, modifiers: [])
        .onHover { isHovering = $0 }
        .help(canStop ? "Stop translating and speaking (Esc)" : "")
        .accessibilityLabel(canStop ? "Stop" : text)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .animation(.easeInOut(duration: 0.25), value: phase)
    }

    /// The dot, wrapped in a ring that closes as the pause runs out. When the ring completes,
    /// what was said so far is sent off.
    private var dot: some View {
        let isCountingDown = silenceDeadline != nil && phase == .listening
        return TimelineView(.animation(paused: !isCountingDown)) { context in
            // Read the deadline afresh on every tick: the listener clears it the moment an
            // utterance is sent, and a tick can land after that while the captured
            // `isCountingDown` is still true.
            let remaining = silenceDeadline.map { max(0, $0.timeIntervalSince(context.date)) } ?? 0
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
    let model: CorpospeakModel

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
        .accessibilityLabel(model.isMuted ? "Unmute microphone" : "Mute microphone")
        .disabled(model.phase == .starting)
    }
}

// MARK: - Voice button

/// Lets the user pick which voice Corpospeak speaks with, and offers to turn on their Personal
/// Voice when it isn't already an option.
private struct VoiceMenu: View {
    let model: CorpospeakModel
    /// Icon only, for narrow screens.
    let compact: Bool

    var body: some View {
        Menu {
            // The user's own voice comes first, or the one step that would make it available.
            if offersPersonalVoice {
                Section("Your Voice") {
                    ForEach(model.speaker.personalVoiceOptions, content: voiceButton)
                    personalVoiceAction
                }
            }
            Section("System Voices") {
                ForEach(model.speaker.systemVoiceOptions, content: voiceButton)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                if !compact {
                    Text(label)
                }
            }
            .font(Type.control)
            .foregroundStyle(.white.opacity(0.65))
            .padding(.horizontal, compact ? 9 : 12)
            .padding(.vertical, 7)
            .background(.white.opacity(0.05), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.07)))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("The voice Corpospeak speaks with")
        .accessibilityLabel("Voice: \(label)")
    }

    private func voiceButton(_ option: Speaker.VoiceOption) -> some View {
        Button {
            model.selectVoice(id: option.id)
        } label: {
            if option.id == model.speaker.selectedVoiceID {
                Label(option.name, systemImage: "checkmark")
            } else {
                Text(option.name)
            }
        }
    }

    /// False only where a Personal Voice is out of the question, such as the Simulator.
    private var offersPersonalVoice: Bool {
        switch model.speaker.personalVoiceStatus {
        case .checking, .unsupported: false
        case .notDetermined, .denied, .noVoice, .available: true
        }
    }

    /// The one thing standing between the user and their own voice, if anything.
    @ViewBuilder
    private var personalVoiceAction: some View {
        switch model.speaker.personalVoiceStatus {
        case .notDetermined:
            Button("Use my Personal Voice…") {
                Task { await model.authorizeVoice() }
            }
        case .denied:
            Button("Allow Personal Voice in \(Platform.settings)…") {
                model.openVoiceSettings()
            }
        case .noVoice:
            Button("Create a Personal Voice in \(Platform.settings)…") {
                model.openVoiceSettings()
            }
        case .checking, .unsupported, .available:
            EmptyView()
        }
    }

    private var label: String {
        model.speaker.selectedVoice?.name ?? "Voice"
    }

    private var icon: String {
        model.speaker.selectedVoice?.isPersonalVoice == true ? "person.wave.2" : "waveform"
    }
}

// MARK: - Personal Voice nudge

/// A line under the empty-state prompt that says the app is better in the user's own voice, with
/// the one tap that gets them there: allow it, set it up in Settings, or switch to it.
private struct PersonalVoiceNudge: View {
    let model: CorpospeakModel
    let compact: Bool

    var body: some View {
        let layout = compact ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(spacing: 14))
        layout {
            HStack(spacing: 8) {
                Image(systemName: "person.wave.2")
                    .foregroundStyle(.cyan.opacity(0.8))
                Text(message)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .font(.system(size: compact ? 13 : 14, design: .rounded))

            Button(action: act) {
                Text(actionTitle)
                    .font(Type.control)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.cyan.opacity(0.22), in: Capsule())
                    .overlay(Capsule().strokeBorder(.cyan.opacity(0.35)))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .accessibilityElement(children: .combine)
    }

    private var message: String {
        switch model.speaker.personalVoiceStatus {
        case .notDetermined, .denied:
            "Corpospeak is better in your own voice."
        case .noVoice:
            "Corpospeak is better in your own voice. Create one in \(Platform.voiceSettingsPath)."
        case .available:
            "Your Personal Voice “\(model.speaker.personalVoiceOptions.first?.name ?? "")” is ready."
        case .checking, .unsupported:
            ""
        }
    }

    private var actionTitle: String {
        switch model.speaker.personalVoiceStatus {
        case .notDetermined: "Use my Personal Voice"
        case .denied, .noVoice: "Open \(Platform.settings)"
        case .available: "Speak in my voice"
        case .checking, .unsupported: ""
        }
    }

    private func act() {
        switch model.speaker.personalVoiceStatus {
        case .notDetermined: Task { await model.authorizeVoice() }
        case .denied, .noVoice: model.openVoiceSettings()
        case .available: model.selectPersonalVoice()
        case .checking, .unsupported: break
        }
    }
}

// MARK: - Voice help

private struct VoiceHelpButton: View {
    let model: CorpospeakModel
    @State private var isShowingHelp = false

    var body: some View {
        Button {
            isShowingHelp.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.05), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.07)))
        }
        .buttonStyle(.plain)
        .help("About the voice")
        .accessibilityLabel("About the voice")
        .popover(isPresented: $isShowingHelp, arrowEdge: .bottom) {
            VoiceHelp(speaker: model.speaker)
                .presentationCompactAdaptation(.popover)
        }
    }
}

private struct VoiceHelp: View {
    let speaker: Speaker

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voice")
                .font(.headline)

            Text("Corpospeak is at its best in your own voice. Create a Personal Voice in \(Platform.voiceSettingsPath) (ten phrases, about a minute) and allow Corpospeak to use it. It then speaks as you by default; the system voices are there as a fallback so the app works right away regardless.")
            Text(statusLine)
                .foregroundStyle(.secondary)
            Text("Your voice leads the voice menu, with the system voices below it. Nothing you say leaves your \(Platform.device).")
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
        switch speaker.personalVoiceStatus {
        case .checking: "Looking for a Personal Voice…"
        case .unsupported: "This \(Platform.device) can't offer a Personal Voice, so only system voices are available."
        case .notDetermined: "You haven't let Corpospeak use your Personal Voice yet. Choose “Use my Personal Voice…” at the top of the voice menu."
        case .denied: "Corpospeak isn't allowed to use your Personal Voice. Turn on “Allow Apps to Request to Use” in \(Platform.voiceSettingsPath)."
        case .noVoice: "You haven't created a Personal Voice yet. Set one up in \(Platform.voiceSettingsPath) and Corpospeak will switch to it."
        case .available:
            speaker.selectedVoice?.isPersonalVoice == true
                ? "Speaking with your Personal Voice, “\(speaker.selectedVoice?.name ?? "")”."
                : "Your Personal Voice is ready at the top of the voice menu."
        }
    }
}

#Preview {
    ContentView(model: CorpospeakModel())
}
