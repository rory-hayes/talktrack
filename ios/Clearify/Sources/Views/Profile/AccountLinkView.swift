import AuthenticationServices
import SwiftUI

struct AccountLinkView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var currentNonce = ""
    @State private var isBusy = false
    @State private var message: String?

    let dependencies: Dependencies

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Save your progress permanently")
                    .font(.largeTitle.bold())

                Text("Connect an account so your coaching profile and plan stay linked to you. Saved answers and starred prompts stay on this device for now.")
                    .foregroundStyle(.secondary)

                SignInWithAppleButton(.continue) { request in
                    let nonce = AppleSignInNonce.random()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = AppleSignInNonce.sha256(nonce)
                } onCompletion: { result in
                    Task { await handleApple(result) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Text("or create an email account")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding(14)
                    .background(Color(red: 0.97, green: 0.96, blue: 0.93), in: RoundedRectangle(cornerRadius: 14))

                SecureField("Password", text: $password)
                    .padding(14)
                    .background(Color(red: 0.97, green: 0.96, blue: 0.93), in: RoundedRectangle(cornerRadius: 14))

                Button {
                    Task { await createAccount() }
                } label: {
                    if isBusy {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Create Account")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)

                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Connect Account")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func createAccount() async {
        isBusy = true
        defer { isBusy = false }

        do {
            try await dependencies.authService.linkAnonymousWithEmail(email: email, password: password)
            try await dependencies.userProfileService.refreshIdentityFields()
            message = "Account connected. Your coaching profile is now linked to this account."
        } catch {
            message = error.localizedDescription
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) async {
        isBusy = true
        defer { isBusy = false }

        switch result {
        case let .success(authResult):
            guard
                let credential = authResult.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let tokenString = String(data: tokenData, encoding: .utf8)
            else {
                message = "Unable to read Apple identity token."
                return
            }

            do {
                try await dependencies.authService.linkAnonymousWithApple(idToken: tokenString, nonce: currentNonce)
                try await dependencies.userProfileService.refreshIdentityFields()
                message = "Account connected. Your coaching profile is now linked to this account."
            } catch {
                message = error.localizedDescription
            }

        case let .failure(error):
            message = error.localizedDescription
        }
    }
}
