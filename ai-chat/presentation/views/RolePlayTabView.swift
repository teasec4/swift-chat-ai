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
    @State private var pendingNetworkLaunch: RolePlayLaunchAction?
    @State private var networkErrorMessage: String?
    @State private var isShowingCustomScenarioOverlay = false
    @State private var isPreparingNetworkAccess = false

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    Button {
                        isShowingCustomScenarioOverlay = true
                    } label: {
                        CreateRolePlayScenarioCardView()
                    }
                    .buttonStyle(.plain)
                    .disabled(isPreparingNetworkAccess)

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
                    feedbackCenter: feedbackCenter,
                    onFreshSessionCreated: { freshSessionID in
                        path = [freshSessionID]
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $isShowingCustomScenarioOverlay) {
            CustomRolePlayScenarioView(
                onCancel: {
                    isShowingCustomScenarioOverlay = false
                },
                onCreate: handleCustomScenarioCreate
            )
        }
        .confirmationDialog(
            "Allow Network Access?",
            isPresented: isShowingNetworkApprovalDialog,
            titleVisibility: .visible,
            presenting: pendingNetworkLaunch
        ) { launch in
            Button("Allow and Continue") {
                pendingNetworkLaunch = nil
                viewModel.approveNetworkAccess()
                start(launch)
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
            pendingNetworkLaunch != nil
        } set: { isPresented in
            if isPresented == false {
                pendingNetworkLaunch = nil
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
        prepare(.open(scenario))
    }

    private func handleCustomScenarioCreate(_ scenario: RolePlayScenario) {
        isShowingCustomScenarioOverlay = false
        prepare(.create(scenario))
    }

    private func prepare(_ launch: RolePlayLaunchAction) {
        guard viewModel.hasApprovedNetworkAccess else {
            pendingNetworkLaunch = launch
            return
        }

        start(launch)
    }

    private func start(_ launch: RolePlayLaunchAction) {
        guard isPreparingNetworkAccess == false else { return }

        Task {
            isPreparingNetworkAccess = true
            defer { isPreparingNetworkAccess = false }

            do {
                try await viewModel.prepareForNetworkedChat()

                if let sessionID = await sessionID(for: launch) {
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

    private func sessionID(for launch: RolePlayLaunchAction) async -> ChatSession.ID? {
        switch launch {
        case let .open(scenario):
            await viewModel.openSession(for: scenario)
        case let .create(scenario):
            await viewModel.createSession(rolePlayScenario: scenario)
        }
    }
}

private enum RolePlayLaunchAction {
    case open(RolePlayScenario)
    case create(RolePlayScenario)
}

private struct CreateRolePlayScenarioCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "plus.bubble")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text("Create Your Own Scenario")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Custom role play")
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

private struct CustomRolePlayScenarioView: View {
    let onCancel: () -> Void
    let onCreate: (RolePlayScenario) -> Void

    @State private var scenario = ""
    @State private var assistantRole = ""
    @State private var learnerRole = ""
    @State private var additionalDetail = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Scenario") {
                    TextField("Scenario", text: $scenario, axis: .vertical)
                        .lineLimit(2...4)
                        .textInputAutocapitalization(.sentences)
                }

                Section("Tutor's Role") {
                    TextField("Tutor's Role", text: $assistantRole, axis: .vertical)
                        .lineLimit(1...3)
                        .textInputAutocapitalization(.sentences)
                }

                Section("Your Role") {
                    TextField("Your Role", text: $learnerRole, axis: .vertical)
                        .lineLimit(1...3)
                        .textInputAutocapitalization(.sentences)
                }

                Section("Additional Detail (Optional)") {
                    TextField("Additional Detail", text: $additionalDetail, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Create Scenario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: createScenario)
                        .disabled(canCreate == false)
                }
            }
        }
    }

    private var canCreate: Bool {
        sanitized(scenario).isEmpty == false
            && sanitized(assistantRole).isEmpty == false
            && sanitized(learnerRole).isEmpty == false
    }

    private func createScenario() {
        guard canCreate else { return }

        onCreate(
            RolePlayScenario.custom(
                scenario: scenario,
                assistantRole: assistantRole,
                learnerRole: learnerRole,
                additionalDetail: additionalDetail
            )
        )
    }

    private func sanitized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
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
