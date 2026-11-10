//
//  LessonFlowView.swift
//  LittlePhysicsTrail
//
//  Chains the Big Idea intro into the game inside one full-screen cover
//  (same pattern as ShadowMatch's PackFlowView).
//

import SwiftUI

struct LessonFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: LessonViewModel

    init(viewModel: LessonViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            if viewModel.phase == .intro {
                BigIdeaView(viewModel: viewModel, onClose: close)
                    .transition(.opacity)
            } else {
                SortGameView(viewModel: viewModel, onClose: close)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.phase == .intro)
    }

    private func close() {
        viewModel.leave()
        dismiss()
    }
}
