import Foundation
import AVFoundation
import UIKit

/// Speaks guidance changes, debounced so the operator is not talked over.
@MainActor
final class VoiceGuidance {
    var isEnabled = true {
        didSet { if !isEnabled { synthesizer.stopSpeaking(at: .immediate) } }
    }

    private let synthesizer = AVSpeechSynthesizer()
    private var lastInstruction: Instruction?
    private var lastSpokenAt: TimeInterval = 0
    private let minimumInterval: TimeInterval = 1.8

    func announce(_ instruction: Instruction, force: Bool = false) {
        guard isEnabled else { return }
        let now = CACurrentMediaTime()
        if !force {
            guard instruction != lastInstruction, now - lastSpokenAt >= minimumInterval else { return }
        }
        lastInstruction = instruction
        lastSpokenAt = now
        synthesizer.stopSpeaking(at: .word)
        let utterance = AVSpeechUtterance(string: spokenText(for: instruction))
        utterance.rate = 0.5
        utterance.volume = 0.9
        synthesizer.speak(utterance)
    }

    func reset() {
        lastInstruction = nil
        lastSpokenAt = 0
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func spokenText(for instruction: Instruction) -> String {
        switch instruction {
        case .searching: return "Point the camera at the eye."
        case .moveCloser(let slightly): return slightly ? "Slightly closer." : "Move closer."
        case .moveBack(let slightly): return slightly ? "Slightly back." : "Move back."
        case .move(let dx, let dy):
            if abs(dx) >= abs(dy) { return dx < 0 ? "Move left." : "Move right." }
            return dy < 0 ? "Move up." : "Move down."
        case .moreLight: return "More light needed."
        case .tooBright: return "Too bright. Reduce glare."
        case .holdStill: return "Hold still."
        case .focusing: return "Focusing."
        case .aligned: return "Aligned. Hold."
        case .captured: return "Captured."
        }
    }
}

enum Haptics {
    static func shutter() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    static func tick() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
