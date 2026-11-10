//
//  ResetProgressUseCase.swift
//  TrailDomain
//

import Foundation

public struct ResetProgressUseCase {
    private let progress: ProgressRepository

    public init(progress: ProgressRepository) {
        self.progress = progress
    }

    public func execute() { progress.reset() }
}
