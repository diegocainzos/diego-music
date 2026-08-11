import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    AppleMusicLogoView(size: 40, showText: true)
                        .padding(.top, 24)

                    VStack(spacing: 8) {
                        Text("Crear Cuenta")
                            .font(.largeTitle.bold())
                            .foregroundStyle(DiegoTheme.textPrimary)

                        Text("Registra tu usuario en el backend privado")
                            .font(.callout)
                            .foregroundStyle(DiegoTheme.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nombre Completo (Opcional)")
                                .font(.caption.bold())
                                .foregroundStyle(DiegoTheme.textSecondary)
                            TextField("Diego Cainzos", text: $fullName)
                                .textFieldStyle(.roundedBorder)
                        }

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
                            SecureField("Mínimo 6 caracteres", text: $password)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Confirmar Contraseña")
                                .font(.caption.bold())
                                .foregroundStyle(DiegoTheme.textSecondary)
                            SecureField("Repite tu contraseña", text: $confirmPassword)
                                .textFieldStyle(.roundedBorder)
                        }

                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(DiegoTheme.red)
                                .padding(.vertical, 4)
                        }

                        Button {
                            performSignUp()
                        } label: {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                        .padding(.trailing, 6)
                                }
                                Text("Crear Cuenta")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!isFormValid || isSubmitting)
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
        }
    }

    private var isFormValid: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        return !trimmedEmail.isEmpty && password.count >= 6 && password == confirmPassword
    }

    private func performSignUp() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard isFormValid else {
            if password != confirmPassword {
                errorMessage = "Las contraseñas no coinciden."
            } else if password.count < 6 {
                errorMessage = "La contraseña debe tener al menos 6 caracteres."
            }
            return
        }

        isSubmitting = true
        errorMessage = nil

        let trimmedName = fullName.trimmingCharacters(in: .whitespaces)
        let nameOrNil = trimmedName.isEmpty ? nil : trimmedName

        Task {
            do {
                try await environment.register(email: trimmedEmail, password: password, fullName: nameOrNil)
                isSubmitting = false
                dismiss()
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
