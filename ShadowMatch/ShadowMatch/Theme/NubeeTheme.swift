//
//  NubeeTheme.swift
//  ShadowMatch (copied from scrambledUI/Kid/NubeeTheme.swift — keep both in sync)
//
//  Design tokens + reusable building blocks for the Nubee UI:
//  palette, background, chunky "toy" buttons, stat pills, surfaces,
//  parental gate and a tiny text-to-speech helper.
//

import SwiftUI
import AVFoundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// ======================================================
// MARK: - Palette
// ======================================================

enum NubeePalette {
    // Brand
    static let purple = Color(red: 0.45, green: 0.36, blue: 0.96)
    static let coral  = Color(red: 1.00, green: 0.47, blue: 0.36)
    static let orange = Color(red: 1.00, green: 0.66, blue: 0.16)
    static let sun    = Color(red: 1.00, green: 0.82, blue: 0.22)
    static let mint   = Color(red: 0.20, green: 0.80, blue: 0.56)
    static let teal   = Color(red: 0.12, green: 0.70, blue: 0.80)
    static let sky    = Color(red: 0.30, green: 0.62, blue: 1.00)
    static let pink   = Color(red: 0.96, green: 0.40, blue: 0.66)
    static let slate  = Color(red: 0.42, green: 0.47, blue: 0.60)

    // Feedback
    static let correct = mint
    static let wrong   = Color(red: 0.96, green: 0.33, blue: 0.36)
    static let hint    = sun

    /// Rotating accents for topic cards.
    static let accents: [Color] = [coral, teal, purple, orange, pink, sky, mint]

    // Adaptive surfaces & text
    static let surface = Color.nubeeDynamic(
        light: Color.white.opacity(0.92),
        dark: Color(red: 0.17, green: 0.17, blue: 0.27)
    )
    static let surfaceSunken = Color.nubeeDynamic(
        light: Color(red: 0.93, green: 0.94, blue: 0.99),
        dark: Color(red: 0.12, green: 0.12, blue: 0.20)
    )
    static let ink = Color.nubeeDynamic(
        light: Color(red: 0.16, green: 0.15, blue: 0.30),
        dark: Color.white
    )
    static let inkSoft = Color.nubeeDynamic(
        light: Color(red: 0.40, green: 0.40, blue: 0.55),
        dark: Color.white.opacity(0.72)
    )
    static let stroke = Color.nubeeDynamic(
        light: Color.black.opacity(0.06),
        dark: Color.white.opacity(0.10)
    )

    static func accent(for key: String) -> Color {
        let sum = key.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return accents[abs(sum) % accents.count]
    }
}

extension Color {
    /// Light/dark adaptive color without needing an asset catalog entry.
    static func nubeeDynamic(light: Color, dark: Color) -> Color {
        #if os(iOS)
        return Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #elseif os(macOS)
        return Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
        })
        #else
        return light
        #endif
    }

    /// Slightly darker variant used for the 3D "base" of chunky buttons.
    func nubeeShade(_ amount: Double = 0.22) -> Color {
        #if os(iOS)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: Double(s), brightness: max(0, Double(b) - amount), opacity: Double(a))
        #elseif os(macOS)
        guard let c = NSColor(self).usingColorSpace(.deviceRGB) else { return self.opacity(0.8) }
        return Color(hue: Double(c.hueComponent), saturation: Double(c.saturationComponent),
                     brightness: max(0, Double(c.brightnessComponent) - amount), opacity: Double(c.alphaComponent))
        #else
        return self.opacity(0.8)
        #endif
    }
}

// ======================================================
// MARK: - Metrics
// ======================================================

enum NubeeMetrics {
    static let gutter: CGFloat = 20
    static let cardRadius: CGFloat = 26
    static let tileRadius: CGFloat = 20
    static let iconButton: CGFloat = 50
    static let chunkDepth: CGFloat = 5
    static let contentMaxWidth: CGFloat = 760
}

// ======================================================
// MARK: - Background
// ======================================================

struct NubeeBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: scheme == .dark
                    ? [Color(red: 0.10, green: 0.10, blue: 0.20), Color(red: 0.17, green: 0.12, blue: 0.28)]
                    : [Color(red: 1.00, green: 0.96, blue: 0.88), Color(red: 0.86, green: 0.94, blue: 1.00)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Soft decorative bubbles — purely visual.
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                Circle().fill(NubeePalette.sun.opacity(scheme == .dark ? 0.10 : 0.28))
                    .frame(width: w * 0.55).blur(radius: 30)
                    .position(x: w * 0.05, y: h * 0.08)
                Circle().fill(NubeePalette.sky.opacity(scheme == .dark ? 0.14 : 0.22))
                    .frame(width: w * 0.6).blur(radius: 40)
                    .position(x: w * 0.95, y: h * 0.92)
                Circle().fill(NubeePalette.pink.opacity(scheme == .dark ? 0.10 : 0.14))
                    .frame(width: w * 0.35).blur(radius: 30)
                    .position(x: w * 0.9, y: h * 0.2)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// ======================================================
// MARK: - Surfaces
// ======================================================

private struct NubeeSurfaceModifier: ViewModifier {
    var radius: CGFloat
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(NubeePalette.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(NubeePalette.stroke))
            .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
    }
}

extension View {
    /// White rounded card used for panels across Nubee screens.
    func nubeeSurface(radius: CGFloat = NubeeMetrics.cardRadius, padding: CGFloat = 16) -> some View {
        modifier(NubeeSurfaceModifier(radius: radius, padding: padding))
    }
}

// ======================================================
// MARK: - Chunky (3D toy) button style
// ======================================================

struct NubeeChunkyButtonStyle: ButtonStyle {
    var color: Color
    var radius: CGFloat = NubeeMetrics.tileRadius
    var depth: CGFloat = NubeeMetrics.chunkDepth
    var isCircle: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape: AnyShape = isCircle
            ? AnyShape(Circle())
            : AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))

        return configuration.label
            .foregroundStyle(.white)
            .background(
                shape.fill(
                    LinearGradient(colors: [color.opacity(0.92), color], startPoint: .top, endPoint: .bottom)
                )
            )
            .overlay(shape.stroke(Color.white.opacity(0.25), lineWidth: 1))
            .offset(y: pressed ? depth : 0)
            .background(
                shape.fill(color.nubeeShade())
                    .offset(y: depth)
            )
            .padding(.bottom, depth)
            .shadow(color: color.opacity(0.28), radius: pressed ? 2 : 8, y: pressed ? 2 : 6)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: pressed)
    }
}

/// Uniform round icon button (same size everywhere so toolbars align).
struct NubeeIconButton: View {
    let symbol: String
    var color: Color = NubeePalette.purple
    var size: CGFloat = NubeeMetrics.iconButton
    var badge: String? = nil
    var accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .bold))
                .frame(width: size, height: size)
        }
        .buttonStyle(NubeeChunkyButtonStyle(color: color, depth: 4, isCircle: true))
        .overlay(alignment: .topTrailing) {
            if let badge {
                Text(badge)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(NubeePalette.ink)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(NubeePalette.surface))
                    .overlay(Capsule().stroke(NubeePalette.stroke))
                    .offset(x: 6, y: -4)
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Wide pill button with icon + title.
struct NubeePillButton: View {
    let title: String
    var symbol: String? = nil
    var color: Color = NubeePalette.purple
    var fullWidth: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .padding(.horizontal, 24)
            .frame(minHeight: 52)
            .frame(maxWidth: fullWidth ? .infinity : nil)
        }
        .buttonStyle(NubeeChunkyButtonStyle(color: color, radius: 26))
    }
}

// ======================================================
// MARK: - Stat pill
// ======================================================

struct NubeeStatPill: View {
    let symbol: String
    let value: String
    var tint: Color
    var accessibilityLabel: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(NubeePalette.ink)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(NubeePalette.surface, in: Capsule())
        .overlay(Capsule().stroke(NubeePalette.stroke))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(accessibilityLabel): \(value)")
    }
}

/// Thin rounded progress bar.
struct NubeeProgressBar: View {
    var value: Double // 0...1
    var tint: Color = NubeePalette.mint
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(NubeePalette.surfaceSunken)
                Capsule().fill(tint)
                    .frame(width: max(height, geo.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: value)
    }
}

// ======================================================
// MARK: - Shake effect (wrong answer)
// ======================================================

struct NubeeShakeEffect: GeometryEffect {
    var travel: CGFloat = 8
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(animatableData * .pi * shakes), y: 0))
    }
}

// ======================================================
// MARK: - Speech (read words aloud)
// ======================================================

final class NubeeSpeech {
    static let shared = NubeeSpeech()
    private let synth = AVSpeechSynthesizer()

    static let enabledKey = "shadow.readAloud"
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    func speak(_ text: String, force: Bool = false) {
        guard force || Self.isEnabled else { return }
        guard !ProcessInfo.processInfo.arguments.contains("-uiTesting") else { return }
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let u = AVSpeechUtterance(string: text.lowercased())
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.8
        u.pitchMultiplier = 1.15
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        synth.speak(u)
    }
}

// ======================================================
// MARK: - Parental gate (required for Kids category links/purchases)
// ======================================================

/// Shows a simple "grown-ups only" multiplication question before revealing `content`.
struct NubeeParentalGate<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    @ViewBuilder var content: () -> Content

    @State private var unlocked = ProcessInfo.processInfo.arguments.contains("-uiTesting")
    @State private var a = Int.random(in: 4...9)
    @State private var b = Int.random(in: 3...9)
    @State private var typed = ""
    @State private var shake: CGFloat = 0

    var body: some View {
        if unlocked {
            content()
        } else {
            gate
        }
    }

    private var gate: some View {
        ZStack {
            NubeeBackground()
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(NubeePalette.inkSoft)
                                .frame(width: 40, height: 40)
                                .background(NubeePalette.surface, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                    }

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(NubeePalette.purple)

                    Text("Grown-ups only")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(NubeePalette.ink)

                    Text("Please answer to continue")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(NubeePalette.inkSoft)

                    Text("\(a) × \(b) = \(typed.isEmpty ? "?" : typed)")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(NubeePalette.ink)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                        .nubeeSurface(radius: 20, padding: 14)
                        .modifier(NubeeShakeEffect(animatableData: shake))

                    keypad
                }
                .padding(NubeeMetrics.gutter)
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var keypad: some View {
        let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "OK"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(keys, id: \.self) { key in
                Button { tap(key) } label: {
                    Text(key)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(NubeeChunkyButtonStyle(
                    color: key == "OK" ? NubeePalette.mint : (key == "⌫" ? NubeePalette.slate : NubeePalette.sky),
                    radius: 16, depth: 4
                ))
                .accessibilityLabel(key == "⌫" ? "Delete" : key)
            }
        }
    }

    private func tap(_ key: String) {
        switch key {
        case "⌫":
            if !typed.isEmpty { typed.removeLast() }
        case "OK":
            if Int(typed) == a * b {
                withAnimation(.easeInOut) { unlocked = true }
            } else {
                withAnimation(.linear(duration: 0.4)) { shake += 1 }
                typed = ""
                a = Int.random(in: 4...9)
                b = Int.random(in: 3...9)
            }
        default:
            if typed.count < 3 { typed.append(key) }
        }
    }
}
