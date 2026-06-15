//
//  MessageInputBar.swift
//  ai-chat
//
//  Created by Максим Ковалев on 6/13/26.
//

import SwiftUI

struct MessageInputBar: View {
    @Binding var text: String

    let isSending: Bool
    let canSend: Bool
    let focus: FocusState<Bool>.Binding
    let onSend: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Message", text: $text, axis: .vertical)
                .focused(focus)
                .lineLimit(1...5)
                .submitLabel(.send)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 1)
                }
                .onSubmit {
                    guard canSend else { return }
                    onSend()
                }
                .accessibilityIdentifier("messageInput")

            Button(action: buttonAction) {
                Image(systemName: isSending ? "stop.fill" : "paperplane.fill")
                    .frame(width: 20, height: 20)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .disabled(isSending == false && canSend == false)
            .accessibilityLabel(isSending ? "Stop response" : "Send")
            .accessibilityIdentifier("sendButton")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private func buttonAction() {
        if isSending {
            onCancel()
        } else {
            onSend()
        }
    }
}
