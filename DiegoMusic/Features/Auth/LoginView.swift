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
                    VStack(spacing: 8) {
                        Text("INICIAR SESIÓN")
                            .dondaTitle(size: 22)
                            .foregroundStyle(DiegoTheme.textPrimary)
                            .padding(.top, 32)

                        Text("Conecta tu cuenta privada de DiegoMusic")
                            .font(.callout)
                            .foregroundStyle(DiegoTheme.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CORREO ELECTRÓNICO")
                                .dondaLabel()
                                .foregroundStyle(DiegoTheme.textSecondary)
                            TextField("usuario@ejemplo.com", text: $email)
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                #endif
                                .padding(.horizontal, 10)
                                .frame(minHeight: 40)
                                .background(DiegoTheme.background)
                                .overlay(Rectangle().stroke(DiegoTheme.outline, lineWidth: 1))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("CONTRASEÑA")
                                .dondaLabel()
                                .foregroundStyle(DiegoTheme.textSecondary)
                            SecureField("••••••••", text: $password)
                                .padding(.horizontal, 10)
                                .frame(minHeight: 40)
                                .background(DiegoTheme.background)
                                .overlay(Rectangle().stroke(DiegoTheme.outline, lineWidth: 1))
                        }

                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(DiegoTheme.textSecondary)
                                .padding(.vertical, 4)
                        }

                        Button {
                            performLogin()
                        } label: {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(DiegoTheme.background)
                                        .padding(.trailing, 6)
                                }
                                Text("INICIAR SESIÓN")
                                    .dondaLabel()
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty || isSubmitting)

                        HStack {
                            Text("¿No tienes cuenta?")
                                .font(.callout)
                                .foregroundStyle(DiegoTheme.textSecondary)
                            Button {
                                showSignUpSheet = true
                            } label: {
                                Text("CREAR CUENTA")
                                    .dondaLabel()
                                    .foregroundStyle(DiegoTheme.textPrimary)
                            }
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
                    Button {
                        dismiss()
                    } label: {
                        Text("CANCELAR").dondaLabel()
                    }
                    .tint(DiegoTheme.textPrimary)
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
