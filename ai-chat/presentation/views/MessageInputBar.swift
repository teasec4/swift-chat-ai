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

            Button(action: onSend) {
                ZStack {
                    Image(systemName: "paperplane.fill")
                        .opacity(isSending ? 0 : 1)

                    if isSending {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                }
                .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .disabled(canSend == false || isSending)
            .accessibilityLabel("Send")
            .accessibilityIdentifier("sendButton")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
}
