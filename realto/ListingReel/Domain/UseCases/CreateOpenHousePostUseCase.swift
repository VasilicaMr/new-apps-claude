import Foundation

/// Turns an existing listing project into an open house announcement: same footage,
/// template, music and branding, with the open house time on the title card, and — where
/// Apple Intelligence is available — a fresh narration and social caption written for it.
struct CreateOpenHousePostUseCase {
    let writeVoiceover: WriteVoiceoverScriptUseCase
    let writeCaption: WritePostCaptionUseCase

    struct Result {
        var project: Project
        /// Set when part of the AI copy couldn't be written; the post is still usable.
        var notice: String?
    }

    /// True when the post will come with AI-written copy, for the sheet to say so up front.
    var writesWithAppleIntelligence: Bool { writeCaption.isAvailable || writeVoiceover.isAvailable }

    func create(from source: Project, schedule: OpenHouseSchedule, brand: BrandProfile?) async -> Result {
        var project = Self.makeProject(from: source, schedule: schedule)
        var notices: [String] = []

        if writeVoiceover.isAvailable {
            do {
                let script = try await writeVoiceover.write(project: project, brand: brand)
                project.voiceover = Voiceover(script: script, voiceID: project.voiceover?.voiceID)
            } catch {
                notices.append((error as? VoiceoverScriptError)?.errorDescription
                    ?? VoiceoverScriptError.failed.errorDescription ?? "")
            }
        }

        if writeCaption.isAvailable {
            do {
                project.socialCaption = try await writeCaption.write(project: project, brand: brand)
            } catch {
                notices.append((error as? PostCaptionError)?.errorDescription
                    ?? PostCaptionError.failed.errorDescription ?? "")
            }
        }
        if project.socialCaption == nil {
            project.socialCaption = WritePostCaptionUseCase.basicCaption(project: project, brand: brand)
        }

        return Result(project: project, notice: notices.compactMap(\.nilIfBlank).joined(separator: "\n").nilIfBlank)
    }

    /// The new project, before any AI copy. The listing's old narration and caption are
    /// dropped (they'd describe a "just listed" video); the chosen narration voice is kept.
    static func makeProject(from source: Project, schedule: OpenHouseSchedule, now: Date = .now) -> Project {
        var info = source.propertyInfo
        info.headline = schedule.badge()
        let place = info.address.nilIfBlank ?? source.name
        return Project(
            name: String(localized: "Open House – \(place)", comment: "Name of a project made with New Open House Post"),
            propertyInfo: info,
            clips: source.clips,
            templateID: source.templateID,
            musicTrackID: source.musicTrackID,
            brandProfileID: source.brandProfileID,
            exportSettings: source.exportSettings,
            voiceover: source.voiceover.map { Voiceover(script: "", voiceID: $0.voiceID) },
            openHouse: schedule,
            socialCaption: nil,
            createdAt: now,
            updatedAt: now)
    }
}
