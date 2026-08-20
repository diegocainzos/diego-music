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

    var isEmbedded: Bool = false

    var body: some View {
        if isEmbedded {
            formContent
        } else {
            NavigationStack {
                ScrollView {
                    formContent
                }
                .background(DiegoTheme.background.ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { dismiss() }
                    }
                }
            }
        }
    }

    private var formContent: some View {
        VStack(spacing: 24) {
            if !isEmbedded {
                AppleMusicLogoView(size: 40, showText: true)
                    .padding(.top, 24)
            }

            VStack(spacing: 8) {
                Text("Crear Cuenta")
                    .font(.title2.bold())
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
                    SecureField("Entre 10 y 25 caracteres", text: $password)
                        .textFieldStyle(.roundedBorder)

                    // Feedback en tiempo real de requisitos de contraseña
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: isPasswordLengthValid ? "checkmark.circle.fill" : "circle")
                                .font(.caption2)
                                .foregroundStyle(isPasswordLengthValid ? DiegoTheme.accent : DiegoTheme.textSecondary)
                            Text("Entre 10 y 25 caracteres (\(password.count)/25)")
                                .font(.caption2)
                                .foregroundStyle(isPasswordLengthValid ? DiegoTheme.textPrimary : DiegoTheme.textSecondary)
                        }

                        HStack(spacing: 6) {
                            Image(systemName: isPasswordUppercaseValid ? "checkmark.circle.fill" : "circle")
                                .font(.caption2)
                                .foregroundStyle(isPasswordUppercaseValid ? DiegoTheme.accent : DiegoTheme.textSecondary)
                            Text("Al menos una letra mayúscula")
                                .font(.caption2)
                                .foregroundStyle(isPasswordUppercaseValid ? DiegoTheme.textPrimary : DiegoTheme.textSecondary)
                        }
                    }
                    .padding(.top, 2)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Confirmar Contraseña")
                        .font(.caption.bold())
                        .foregroundStyle(DiegoTheme.textSecondary)
                    SecureField("Repite tu contraseña", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                    
                    if !confirmPassword.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: password == confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(password == confirmPassword ? DiegoTheme.accent : DiegoTheme.red)
                            Text(password == confirmPassword ? "Las contraseñas coinciden" : "Las contraseñas no coinciden")
                                .font(.caption2)
                                .foregroundStyle(password == confirmPassword ? DiegoTheme.textPrimary : DiegoTheme.red)
                        }
                        .padding(.top, 2)
                    }
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
            .padding(.horizontal, isEmbedded ? 0 : 24)
        }
        .padding(.bottom, 32)
    }

    private var isPasswordLengthValid: Bool {
        password.count >= 10 && password.count <= 25
    }

    private var isPasswordUppercaseValid: Bool {
        password.contains(where: \.isUppercase)
    }

    private var isPasswordValid: Bool {
        isPasswordLengthValid && isPasswordUppercaseValid
    }

    private var isFormValid: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        return !trimmedEmail.isEmpty && isPasswordValid && password == confirmPassword
    }

    private func performSignUp() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard isFormValid else {
            if !isPasswordLengthValid {
                errorMessage = "La contraseña debe tener entre 10 y 25 caracteres."
            } else if !isPasswordUppercaseValid {
                errorMessage = "La contraseña debe contener al menos una letra mayúscula."
            } else if password != confirmPassword {
                errorMessage = "Las contraseñas no coinciden."
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
