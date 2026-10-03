import AVFoundation
import QuartzCore
import CoreText

/// Builds the Core Animation overlay tree (title cards, lower-third, branding,
/// watermark) that `AVVideoCompositionCoreAnimationTool` composites onto video.
///
/// Two hard-won gotchas from the spec (§4.2) are handled here:
///  • every animation's `beginTime` uses `AVCoreAnimationBeginTimeAtZero`, never 0,
///    or nothing renders in the export.
///  • all timing is driven off the composition timeline — no wall-clock, no UIView.
struct OverlayLayerFactory {

    struct Input {
        let template: Template
        let brand: BrandProfile?
        let property: PropertyInfo
        let logo: PlatformImage?
        let renderSize: CGSize
        let introDuration: TimeInterval
        let outroDuration: TimeInterval
        let totalDuration: TimeInterval
        let includeWatermark: Bool
    }

    /// Returns the overlay layer sized to `renderSize`, ready to be added above the
    /// video layer inside the animation tool's parent layer.
    func makeOverlayLayer(_ input: Input) -> CALayer {
        let root = CALayer()
        root.frame = CGRect(origin: .zero, size: input.renderSize)
        root.isGeometryFlipped = true   // match UIKit's top-left origin for layout math

        let scale = min(input.renderSize.width, input.renderSize.height) / 1080
        let colors = input.template.colorTokens
        let fonts = input.template.fontTokens

        let introEnd = input.introDuration
        let outroStart = max(introEnd, input.totalDuration - input.outroDuration)

        // Intro title card — headline + address + specs, centered.
        let intro = introCard(input, scale: scale, colors: colors, fonts: fonts)
        intro.add(Self.visibility(start: 0, end: introEnd, total: input.totalDuration),
                  forKey: "vis")
        root.addSublayer(intro)

        // Outro contact card — agent + phone + brokerage + logo.
        let outro = outroCard(input, scale: scale, colors: colors, fonts: fonts)
        outro.add(Self.visibility(start: outroStart, end: input.totalDuration, total: input.totalDuration),
                  forKey: "vis")
        root.addSublayer(outro)

        // Persistent lower-third branding strip during the body clips.
        if input.template.body.showLowerThird, let brand = input.brand, brand.isComplete {
            let strip = lowerThird(brand, input: input, scale: scale, colors: colors, fonts: fonts)
            strip.add(Self.visibility(start: introEnd, end: outroStart, total: input.totalDuration),
                      forKey: "vis")
            root.addSublayer(strip)
        }

        // Free-tier watermark across the entire timeline.
        if input.includeWatermark {
            root.addSublayer(watermark(input, scale: scale))
        }

        return root
    }

    // MARK: - Cards

    private func introCard(_ input: Input, scale: CGFloat, colors: ColorTokens, fonts: FontTokens) -> CALayer {
        let card = CALayer()
        card.frame = CGRect(origin: .zero, size: input.renderSize)

        // Scrim so text is legible over any first frame.
        let scrim = CALayer()
        scrim.frame = card.bounds
        scrim.backgroundColor = PlatformColor(hex: colors.backgroundHex).withAlphaComponent(0.45).cgColor
        card.addSublayer(scrim)

        let w = input.renderSize.width * 0.86
        let x = (input.renderSize.width - w) / 2
        var y = input.renderSize.height * 0.30

        if let headline = input.property.headline, !headline.isEmpty {
            let badge = textLayer(headline.uppercased(),
                                  font: fonts.displayFontName, size: fonts.bodySize * 0.9 * scale,
                                  color: PlatformColor(hex: colors.accentHex), align: .center)
            badge.frame = CGRect(x: x, y: y, width: w, height: fonts.bodySize * 1.4 * scale)
            card.addSublayer(badge)
            y += fonts.bodySize * 2.2 * scale
        }

        let address = textLayer(input.property.address.isEmpty
                                ? String(localized: "Your Address Here", comment: "Placeholder shown on the video title card when no address was entered")
                                : input.property.address,
                                font: fonts.displayFontName, size: fonts.displaySize * scale,
                                color: PlatformColor(hex: colors.primaryTextHex), align: .center)
        address.frame = CGRect(x: x, y: y, width: w, height: fonts.displaySize * 3 * scale)
        card.addSublayer(address)
        y += fonts.displaySize * 3.2 * scale

        if let price = input.property.price, !price.isEmpty {
            let priceLayer = textLayer(price,
                                       font: fonts.displayFontName, size: fonts.displaySize * 0.9 * scale,
                                       color: PlatformColor(hex: colors.accentHex), align: .center)
            priceLayer.frame = CGRect(x: x, y: y, width: w, height: fonts.displaySize * 1.4 * scale)
            card.addSublayer(priceLayer)
            y += fonts.displaySize * 1.6 * scale
        }

        let specs = input.property.specsLine
        if !specs.isEmpty {
            let specLayer = textLayer(specs,
                                      font: fonts.bodyFontName, size: fonts.bodySize * scale,
                                      color: PlatformColor(hex: colors.primaryTextHex), align: .center)
            specLayer.frame = CGRect(x: x, y: y, width: w, height: fonts.bodySize * 1.5 * scale)
            card.addSublayer(specLayer)
        }
        return card
    }

    private func outroCard(_ input: Input, scale: CGFloat, colors: ColorTokens, fonts: FontTokens) -> CALayer {
        let card = CALayer()
        card.frame = CGRect(origin: .zero, size: input.renderSize)

        let bg = CALayer()
        bg.frame = card.bounds
        bg.backgroundColor = PlatformColor(hex: colors.backgroundHex).cgColor
        card.addSublayer(bg)

        let brand = input.brand
        let w = input.renderSize.width * 0.86
        let x = (input.renderSize.width - w) / 2
        var y = input.renderSize.height * 0.34

        if let logo = input.logo {
            let logoLayer = CALayer()
            let side = 220 * scale
            logoLayer.frame = CGRect(x: (input.renderSize.width - side) / 2, y: y, width: side, height: side)
            logoLayer.contents = logo.cgImage
            logoLayer.contentsGravity = .resizeAspect
            card.addSublayer(logoLayer)
            y += side + 40 * scale
        }

        let name = brand?.agentName.isEmpty == false
            ? brand!.agentName
            : String(localized: "Your Name", comment: "Placeholder shown on the video contact card when no agent name was entered")
        let nameLayer = textLayer(name, font: fonts.displayFontName, size: fonts.displaySize * scale,
                                  color: PlatformColor(hex: colors.primaryTextHex), align: .center)
        nameLayer.frame = CGRect(x: x, y: y, width: w, height: fonts.displaySize * 1.6 * scale)
        card.addSublayer(nameLayer)
        y += fonts.displaySize * 1.8 * scale

        var contactBits: [String] = []
        if let phone = brand?.phone, !phone.isEmpty { contactBits.append(phone) }
        if let brokerage = brand?.brokerage, !brokerage.isEmpty { contactBits.append(brokerage) }
        if !contactBits.isEmpty {
            let contact = textLayer(contactBits.joined(separator: "   ·   "),
                                    font: fonts.bodyFontName, size: fonts.bodySize * scale,
                                    color: PlatformColor(hex: colors.accentHex), align: .center)
            contact.frame = CGRect(x: x, y: y, width: w, height: fonts.bodySize * 1.6 * scale)
            card.addSublayer(contact)
        }
        return card
    }

    private func lowerThird(_ brand: BrandProfile, input: Input, scale: CGFloat,
                            colors: ColorTokens, fonts: FontTokens) -> CALayer {
        let container = CALayer()
        let height = 130 * scale
        container.frame = CGRect(x: 0, y: input.renderSize.height - height,
                                 width: input.renderSize.width, height: height)

        let bar = CALayer()
        bar.frame = container.bounds
        bar.backgroundColor = PlatformColor(hex: colors.backgroundHex).withAlphaComponent(0.72).cgColor
        container.addSublayer(bar)

        let label = textLayer(brand.agentName, font: fonts.bodyFontName, size: fonts.bodySize * scale,
                              color: PlatformColor(hex: colors.primaryTextHex), align: .left)
        label.frame = CGRect(x: 48 * scale, y: (height - fonts.bodySize * 1.4 * scale) / 2,
                             width: input.renderSize.width - 96 * scale, height: fonts.bodySize * 1.4 * scale)
        container.addSublayer(label)
        return container
    }

    private func watermark(_ input: Input, scale: CGFloat) -> CALayer {
        let text = textLayer(String(localized: "Made with Realto", comment: "Free-tier watermark burned into exported videos"),
                             font: "HelveticaNeue-Medium",
                             size: 34 * scale, color: .white, align: .right)
        text.opacity = 0.85
        let w = 520 * scale
        text.frame = CGRect(x: input.renderSize.width - w - 40 * scale,
                            y: 40 * scale, width: w, height: 46 * scale)
        return text
    }

    // MARK: - Primitives

    private func textLayer(_ string: String, font: String, size: CGFloat,
                           color: PlatformColor, align: CATextLayerAlignmentMode) -> CATextLayer {
        let layer = CATextLayer()
        layer.string = string
        layer.font = CTFontCreateWithName(font as CFString, size, nil)
        layer.fontSize = size
        layer.foregroundColor = color.cgColor
        layer.alignmentMode = align
        layer.isWrapped = true
        layer.truncationMode = .end
        layer.contentsScale = 1
        layer.shadowColor = PlatformColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 2)
        return layer
    }

    /// Opacity keyframe that shows a layer only within [start, end] on the
    /// composition timeline, with short fades. Uses `AVCoreAnimationBeginTimeAtZero`.
    private static func visibility(start: TimeInterval, end: TimeInterval,
                                   total: TimeInterval, fade: TimeInterval = 0.4) -> CAKeyframeAnimation {
        let anim = CAKeyframeAnimation(keyPath: "opacity")
        anim.beginTime = AVCoreAnimationBeginTimeAtZero
        anim.duration = max(total, 0.1)
        anim.isRemovedOnCompletion = false
        anim.fillMode = .both
        anim.calculationMode = .linear

        let t0 = max(0, start)
        let t1 = min(total, end)
        let fIn = min(fade, (t1 - t0) / 2)

        func k(_ time: TimeInterval) -> NSNumber { NSNumber(value: time / max(total, 0.1)) }
        anim.keyTimes = [k(0), k(t0), k(t0 + fIn), k(t1 - fIn), k(t1), k(total)]
        anim.values   = [0,     0,     1,           1,           0,     0]
        return anim
    }
}
