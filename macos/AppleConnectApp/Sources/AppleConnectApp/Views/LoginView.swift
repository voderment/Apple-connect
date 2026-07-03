import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @Bindable var model: AppModel

    var body: some View {
        ZStack {
            LoginBackgroundView()

            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    Text(AppConstants.productName)
                        .font(.system(size: 46, weight: .semibold))
                    Text("Manage App Store releases from a focused native workspace.")
                        .font(.title3)
                        .foregroundStyle(OrbiterColor.textMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 460)
                }

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleAuthorization(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(width: 240, height: 42)

                Button {
                    Task { await model.startDemoSession() }
                } label: {
                    Label("Continue in Demo", systemImage: "play.circle")
                        .frame(width: 216)
                }
                .buttonStyle(.orbiter(.secondary))
            }
            .padding(40)
        }
    }

    private func handleAuthorization(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case let .success(authorization):
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential
            let name = credential?.fullName.map { PersonNameComponentsFormatter().string(from: $0) }
            model.switchDataSourceMode(.live)
            model.completeAppleSignIn(displayName: name, email: credential?.email)
        case let .failure(error):
            model.errorMessage = error.localizedDescription
        }
    }
}

struct LoginBackgroundView: View {
    var body: some View {
        if let image = NSImage(named: "LoginBackground") {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        } else {
            Rectangle()
                .fill(OrbiterColor.canvas)
                .ignoresSafeArea()
        }
    }
}
