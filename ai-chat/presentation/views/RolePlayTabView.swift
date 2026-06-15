//
//  RolePlayTabView.swift
//  ai-chat
//
//  Created by Codex on 6/15/26.
//

import SwiftUI

struct RolePlayTabView: View {
    let viewModel: ChatViewModel
    let feedbackCenter: FeedbackCenter

    @State private var path: [ChatSession.ID] = []
    @State private var pendingNetworkScenario: RolePlayScenario?
    @State private var networkErrorMessage: String?
    @State private var isPreparingNetworkAccess = false

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.rolePlayScenarios) { scenario in
                        Button {
                            handleScenarioTap(scenario)
                        } label: {
                            RolePlayScenarioCardView(scenario: scenario)
                        }
                        .buttonStyle(.plain)
                        .disabled(isPreparingNetworkAccess)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Role Play")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isPreparingNetworkAccess {
                    PreparingRolePlayNetworkAccessView()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
            .navigationDestination(for: ChatSession.ID.self) { sessionID in
                ChatSessionDestinationView(
                    viewModel: viewModel,
                    sessionID: sessionID,
                    feedbackCenter: feedbackCenter
                )
            }
        }
        .confirmationDialog(
            "Allow Network Access?",
            isPresented: isShowingNetworkApprovalDialog,
            titleVisibility: .visible,
            presenting: pendingNetworkScenario
        ) { scenario in
            Button("Allow and Continue") {
                viewModel.approveNetworkAccess()
                openSession(with: scenario)
            }

            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Role-play conversations use the network to contact the language model.")
        }
        .alert(
            "Network Unavailable",
            isPresented: isShowingNetworkErrorAlert
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(networkErrorMessage ?? "Network access is unavailable.")
        }
    }

    private var isShowingNetworkApprovalDialog: Binding<Bool> {
        Binding {
            pendingNetworkScenario != nil
        } set: { isPresented in
            if isPresented == false {
                pendingNetworkScenario = nil
            }
        }
    }

    private var isShowingNetworkErrorAlert: Binding<Bool> {
        Binding {
            networkErrorMessage != nil
        } set: { isPresented in
            if isPresented == false {
                networkErrorMessage = nil
            }
        }
    }

    private func handleScenarioTap(_ scenario: RolePlayScenario) {
        guard viewModel.hasApprovedNetworkAccess else {
            pendingNetworkScenario = scenario
            return
        }

        openSession(with: scenario)
    }

    private func openSession(with scenario: RolePlayScenario) {
        guard isPreparingNetworkAccess == false else { return }

        Task {
            isPreparingNetworkAccess = true
            defer { isPreparingNetworkAccess = false }

            do {
                try await viewModel.prepareForNetworkedChat()

                if let sessionID = await viewModel.openSession(for: scenario) {
                    path = [sessionID]
                    await viewModel.startConversation(in: sessionID)
                }
            } catch {
                networkErrorMessage = errorMessage(for: error)
            }
        }
    }

    private func errorMessage(for error: Error) -> String {
        switch error {
        case let localizedError as LocalizedError:
            localizedError.errorDescription ?? "Network access is unavailable."
        default:
            "Network access is unavailable."
        }
    }
}

private struct RolePlayScenarioCardView: View {
    let scenario: RolePlayScenario

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: scenario.iconName)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(scenario.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(scenario.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PreparingRolePlayNetworkAccessView: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)

            Text("Preparing role play...")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
    }
}
