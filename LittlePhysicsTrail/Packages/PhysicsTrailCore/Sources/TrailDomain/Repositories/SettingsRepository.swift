//
//  SettingsRepository.swift
//  TrailDomain
//

import Foundation

/// Grown-ups settings.
public protocol SettingsRepository: AnyObject {
    var readAloud: Bool { get set }
}
