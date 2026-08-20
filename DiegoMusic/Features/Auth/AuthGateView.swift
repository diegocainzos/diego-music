import SwiftUI

/// Vista de entrada mandatoria de autenticación (Login y Registro).
/// No permite cancelar, cerrar ni omitir el inicio de sesión.
struct AuthGateView: View {
    @EnvironmentObject private var environment: AppEnvironment
    
    enum AuthTab: String, CaseIterable, Identifiable {
        case login = "Iniciar Sesión"
        case register = "Crear Cuenta"

        var id: String { rawValue }
    }

    @State private var selectedTab: AuthTab = .login

    // Login state
    @State private var loginEmail = ""
    @State private var loginPassword = ""
    @State private var loginError: String?
    @State private var isLoggingIn = false

    // Sign up state
    @State private var regFullName = ""
    @State private var regEmail = ""
    @State private var regPassword = ""
    @State private var regConfirmPassword = ""
    @State private var regError: String?
    @State private var isRegistering = false

    var body: some View {
        ZStack {
            DiegoTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 12) {
                        AppleMusicLogoView(size: 48, showText: true)
                            .padding(.top, 40)

                        Text("DiegoMusic")
                            .font(.title.bold())
                            .foregroundStyle(DiegoTheme.textPrimary)

                        Text("Inicia sesión para sincronizar tus playlists, favoritos y música.")
                            .font(.subheadline)
                            .foregroundStyle(DiegoTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    // Selector de Pestaña (Login / Registro)
                    Picker("Autenticación", selection: $selectedTab) {
                        ForEach(AuthTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 32)

                    // Contenido del Formulario
                    VStack(alignment: .leading, spacing: 16) {
                        if selectedTab == .login {
                            loginForm
                        } else {
                            registerForm
                        }
                    }
                    .minimalCard()
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 48)
            }
        }
    }

    // MARK: - Login Form

    private var loginForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Correo Electrónico")
                    .font(.caption.bold())
                    .foregroundStyle(DiegoTheme.textSecondary)
                TextField("usuario@ejemplo.com", text: $loginEmail)
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
                SecureField("••••••••", text: $loginPassword)
                    .textFieldStyle(.roundedBorder)
            }

            if let loginError {
                Label(loginError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(DiegoTheme.red)
                    .padding(.vertical, 2)
            }

            Button {
                performLogin()
            } label: {
                HStack {
                    if isLoggingIn {
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
            .disabled(loginEmail.trimmingCharacters(in: .whitespaces).isEmpty || loginPassword.isEmpty || isLoggingIn)
        }
    }

    // MARK: - Register Form

    private var registerForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Nombre Completo (Opcional)")
                    .font(.caption.bold())
                    .foregroundStyle(DiegoTheme.textSecondary)
                TextField("Diego Cainzos", text: $regFullName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Correo Electrónico")
                    .font(.caption.bold())
                    .foregroundStyle(DiegoTheme.textSecondary)
                TextField("usuario@ejemplo.com", text: $regEmail)
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
                SecureField("Entre 10 y 25 caracteres", text: $regPassword)
                    .textFieldStyle(.roundedBorder)

                // Feedback en tiempo real
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: isRegPasswordLengthValid ? "checkmark.circle.fill" : "circle")
                            .font(.caption2)
                            .foregroundStyle(isRegPasswordLengthValid ? DiegoTheme.accent : DiegoTheme.textSecondary)
                        Text("Entre 10 y 25 caracteres (\(regPassword.count)/25)")
                            .font(.caption2)
                            .foregroundStyle(isRegPasswordLengthValid ? DiegoTheme.textPrimary : DiegoTheme.textSecondary)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: isRegPasswordUppercaseValid ? "checkmark.circle.fill" : "circle")
                            .font(.caption2)
                            .foregroundStyle(isRegPasswordUppercaseValid ? DiegoTheme.accent : DiegoTheme.textSecondary)
                        Text("Al menos una letra mayúscula")
                            .font(.caption2)
                            .foregroundStyle(isRegPasswordUppercaseValid ? DiegoTheme.textPrimary : DiegoTheme.textSecondary)
                    }
                }
                .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Confirmar Contraseña")
                    .font(.caption.bold())
                    .foregroundStyle(DiegoTheme.textSecondary)
                SecureField("Repite tu contraseña", text: $regConfirmPassword)
                    .textFieldStyle(.roundedBorder)

                if !regConfirmPassword.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: regPassword == regConfirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(regPassword == regConfirmPassword ? DiegoTheme.accent : DiegoTheme.red)
                        Text(regPassword == regConfirmPassword ? "Las contraseñas coinciden" : "Las contraseñas no coinciden")
                            .font(.caption2)
                            .foregroundStyle(regPassword == regConfirmPassword ? DiegoTheme.textPrimary : DiegoTheme.red)
                    }
                    .padding(.top, 2)
                }
            }

            if let regError {
                Label(regError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(DiegoTheme.red)
                    .padding(.vertical, 2)
            }

            Button {
                performRegister()
            } label: {
                HStack {
                    if isRegistering {
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
            .disabled(!isRegFormValid || isRegistering)
        }
    }

    private var isRegPasswordLengthValid: Bool {
        regPassword.count >= 10 && regPassword.count <= 25
    }

    private var isRegPasswordUppercaseValid: Bool {
        regPassword.contains(where: \.isUppercase)
    }

    private var isRegPasswordValid: Bool {
        isRegPasswordLengthValid && isRegPasswordUppercaseValid
    }

    private var isRegFormValid: Bool {
        let trimmedEmail = regEmail.trimmingCharacters(in: .whitespaces)
        return !trimmedEmail.isEmpty && isRegPasswordValid && regPassword == regConfirmPassword
    }

    private func performLogin() {
        let trimmedEmail = loginEmail.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty, !loginPassword.isEmpty else { return }

        isLoggingIn = true
        loginError = nil

        Task {
            do {
                try await environment.login(email: trimmedEmail, password: loginPassword)
                isLoggingIn = false
            } catch {
                isLoggingIn = false
                loginError = error.localizedDescription
            }
        }
    }

    private func performRegister() {
        let trimmedEmail = regEmail.trimmingCharacters(in: .whitespaces)
        guard isRegFormValid else {
            if !isRegPasswordLengthValid {
                regError = "La contraseña debe tener entre 10 y 25 caracteres."
            } else if !isRegPasswordUppercaseValid {
                regError = "La contraseña debe contener al menos una letra mayúscula."
            } else if regPassword != regConfirmPassword {
                regError = "Las contraseñas no coinciden."
            }
            return
        }

        isRegistering = true
        regError = nil

        let trimmedName = regFullName.trimmingCharacters(in: .whitespaces)
        let nameOrNil = trimmedName.isEmpty ? nil : trimmedName

        Task {
            do {
                try await environment.register(email: trimmedEmail, password: regPassword, fullName: nameOrNil)
                isRegistering = false
            } catch {
                isRegistering = false
                regError = error.localizedDescription
            }
        }
    }
}
