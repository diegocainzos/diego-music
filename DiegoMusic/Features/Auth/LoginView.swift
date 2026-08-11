import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var showSignUpSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    AppleMusicLogoView(size: 40, showText: true)
                        .padding(.top, 24)

                    VStack(spacing: 8) {
                        Text("Iniciar Sesión")
                            .font(.largeTitle.bold())
                            .foregroundStyle(DiegoTheme.textPrimary)

                        Text("Conecta tu cuenta privada de DiegoMusic")
                            .font(.callout)
                            .foregroundStyle(DiegoTheme.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Correo Electrónico")
                                .font(.caption.bold())
                                .foregroundStyle(DiegoTheme.textSecondary)
                            TextField("usuario@ejemplo.com", text: $email)
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                #endif
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Contraseña")
                                .font(.caption.bold())
                                .foregroundStyle(DiegoTheme.textSecondary)
                            SecureField("••••••••", text: $password)
                                .textFieldStyle(.roundedBorder)
                        }

                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(DiegoTheme.red)
                                .padding(.vertical, 4)
                        }

                        Button {
                            performLogin()
                        } label: {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                        .padding(.trailing, 6)
                                }
                                Text("Iniciar Sesión")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty || isSubmitting)

                        HStack {
                            Text("¿No tienes cuenta?")
                                .font(.subheadline)
                                .foregroundStyle(DiegoTheme.textSecondary)
                            Button("Crear cuenta") {
                                showSignUpSheet = true
                            }
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(DiegoTheme.accent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    }
                    .minimalCard()
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 32)
            }
            .background(DiegoTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .sheet(isPresented: $showSignUpSheet) {
                SignUpView()
            }
        }
    }

    private func performLogin() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty, !password.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                try await environment.login(email: trimmedEmail, password: password)
                isSubmitting = false
                dismiss()
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
