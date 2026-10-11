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
                        Button {
                            dismiss()
                        } label: {
                            Text("CANCELAR").dondaLabel()
                        }
                        .tint(DiegoTheme.textPrimary)
                    }
                }
            }
        }
    }

    private var formContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("CREAR CUENTA")
                    .dondaTitle(size: 22)
                    .foregroundStyle(DiegoTheme.textPrimary)
                    .padding(.top, isEmbedded ? 0 : 32)

                Text("Registra tu usuario en el backend privado")
                    .font(.callout)
                    .foregroundStyle(DiegoTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("NOMBRE COMPLETO (OPCIONAL)")
                        .dondaLabel()
                        .foregroundStyle(DiegoTheme.textSecondary)
                    TextField("Diego Cainzos", text: $fullName)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 40)
                        .background(DiegoTheme.background)
                        .overlay(Rectangle().stroke(DiegoTheme.outline, lineWidth: 1))
                }

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
                    SecureField("Entre 10 y 25 caracteres", text: $password)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 40)
                        .background(DiegoTheme.background)
                        .overlay(Rectangle().stroke(DiegoTheme.outline, lineWidth: 1))

                    // Feedback en tiempo real de requisitos de contraseña
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: isPasswordLengthValid ? "checkmark.circle" : "circle")
                                .font(.caption2)
                                .foregroundStyle(isPasswordLengthValid ? DiegoTheme.textPrimary : DiegoTheme.textSecondary)
                            Text("Entre 10 y 25 caracteres (\(password.count)/25)")
                                .font(.caption2)
                                .foregroundStyle(isPasswordLengthValid ? DiegoTheme.textPrimary : DiegoTheme.textSecondary)
                        }

                        HStack(spacing: 6) {
                            Image(systemName: isPasswordUppercaseValid ? "checkmark.circle" : "circle")
                                .font(.caption2)
                                .foregroundStyle(isPasswordUppercaseValid ? DiegoTheme.textPrimary : DiegoTheme.textSecondary)
                            Text("Al menos una letra mayúscula")
                                .font(.caption2)
                                .foregroundStyle(isPasswordUppercaseValid ? DiegoTheme.textPrimary : DiegoTheme.textSecondary)
                        }
                    }
                    .padding(.top, 2)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("CONFIRMAR CONTRASEÑA")
                        .dondaLabel()
                        .foregroundStyle(DiegoTheme.textSecondary)
                    SecureField("Repite tu contraseña", text: $confirmPassword)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 40)
                        .background(DiegoTheme.background)
                        .overlay(Rectangle().stroke(DiegoTheme.outline, lineWidth: 1))
                    
                    if !confirmPassword.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: password == confirmPassword ? "checkmark.circle" : "xmark.circle")
                                .font(.caption2)
                                .foregroundStyle(password == confirmPassword ? DiegoTheme.textPrimary : DiegoTheme.textSecondary)
                            Text(password == confirmPassword ? "Las contraseñas coinciden" : "Las contraseñas no coinciden")
                                .font(.caption2)
                                .foregroundStyle(password == confirmPassword ? DiegoTheme.textPrimary : DiegoTheme.textSecondary)
                        }
                        .padding(.top, 2)
                    }
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(DiegoTheme.textSecondary)
                        .padding(.vertical, 4)
                }

                Button {
                    performSignUp()
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(DiegoTheme.background)
                                .padding(.trailing, 6)
                        }
                        Text("CREAR CUENTA")
                            .dondaLabel()
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
