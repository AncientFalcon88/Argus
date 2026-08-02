import SwiftUI

struct LoginView: View {
    @StateObject private var auth = AuthService.shared
    @State private var identity = ""
    @State private var password = ""
    @State private var tmdbKey = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showPassword = false
    @State private var showTmdbKey = false
    @FocusState private var focusedField: Field?

    enum Field { case identity, password, tmdb }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)

                    // Logo / Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 96, height: 96)
                            Image(systemName: "eye")
                                .font(.system(size: 40, weight: .light))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.7)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        .shadow(color: .white.opacity(0.1), radius: 20)

                        VStack(spacing: 6) {
                            Text("Argus")
                                .font(.custom("Times New Roman", size: 36))
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Text("Sign in to PublicMetaDB")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding(.bottom, 48)

                    // Form Card
                    VStack(spacing: 16) {

                        // Email Field
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "person.circle")
                                Text("Email")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.6))

                            // Custom placeholder to avoid iOS blue email autofill color
                            ZStack(alignment: .leading) {
                                if identity.isEmpty {
                                    Text(verbatim: "you@example.com")
                                        .foregroundStyle(Color.gray)
                                        .padding(.horizontal, 14)
                                        .allowsHitTesting(false)
                                }
                                TextField("", text: $identity)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .foregroundStyle(.white)
                                    .tint(.white)
                                    .focused($focusedField, equals: .identity)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .password }
                                    .padding(14)
                            }
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(focusedField == .identity ? .white.opacity(0.3) : .white.opacity(0.08), lineWidth: 1)
                            )
                        }

                        // Password Field
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.circle")
                                Text("Password")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.6))

                            HStack {
                                Group {
                                    if showPassword {
                                        TextField("", text: $password, prompt: Text("••••••••").foregroundStyle(.white.opacity(0.3)))
                                    } else {
                                        SecureField("", text: $password, prompt: Text("••••••••").foregroundStyle(.white.opacity(0.3)))
                                    }
                                }
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundStyle(.white)
                                .tint(.white)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .tmdb }

                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                            .padding(14)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(focusedField == .password ? .white.opacity(0.3) : .white.opacity(0.08), lineWidth: 1)
                            )
                        }

                        // TMDB API Key Field
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "film")
                                Text("TMDB API Key")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 4)

                            // Custom placeholder avoids iOS pre-filling dots for existing keys
                            ZStack(alignment: .leading) {
                                if tmdbKey.isEmpty {
                                    Text("Paste your API Key here")
                                        .foregroundStyle(.white.opacity(0.3))
                                        .padding(.horizontal, 14)
                                        .allowsHitTesting(false)
                                }
                                HStack {
                                    if showTmdbKey {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            TextField("", text: $tmdbKey)
                                                .textInputAutocapitalization(.never)
                                                .autocorrectionDisabled()
                                                .foregroundStyle(.white)
                                                .tint(.white)
                                                .focused($focusedField, equals: .tmdb)
                                                .submitLabel(.go)
                                                .onSubmit { Task { await signIn() } }
                                                .frame(minWidth: max(250, CGFloat(tmdbKey.count * 12)), alignment: .leading)
                                        }
                                    } else {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            SecureField("", text: $tmdbKey)
                                                .textInputAutocapitalization(.never)
                                                .autocorrectionDisabled()
                                                .foregroundStyle(.white)
                                                .tint(.white)
                                                .focused($focusedField, equals: .tmdb)
                                                .submitLabel(.go)
                                                .onSubmit { Task { await signIn() } }
                                                .frame(minWidth: max(250, CGFloat(tmdbKey.count * 12)), alignment: .leading)
                                        }
                                    }

                                    Button {
                                        showTmdbKey.toggle()
                                    } label: {
                                        Image(systemName: showTmdbKey ? "eye.slash" : "eye")
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                }
                                .padding(14)
                            }
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(focusedField == .tmdb ? .white.opacity(0.3) : .white.opacity(0.08), lineWidth: 1)
                            )

                            Text("From themoviedb.org → Settings → API")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.3))
                                .padding(.horizontal, 4)
                        }

                        // Error Message
                        if let error = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red.opacity(0.8))
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red.opacity(0.8))
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Sign In Button
                        Button(action: { Task { await signIn() } }) {
                            ZStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.right.circle.fill")
                                        Text("Sign In")
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(isFormValid ? .black : .white.opacity(0.4))
                            .background(
                                isFormValid
                                    ? AnyShapeStyle(LinearGradient(colors: [.white, .white.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    : AnyShapeStyle(.white.opacity(0.1)),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                        }
                        .disabled(!isFormValid || isLoading)
                        .animation(.easeInOut(duration: 0.2), value: isFormValid)
                        .padding(.top, 4)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                    Spacer(minLength: 40)

                    // Footer
                    VStack(spacing: 8) {
                        Text("Don't have an account?")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                        Link("Create one at publicmetadb.com", destination: URL(string: "https://publicmetadb.com")!)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onTapGesture { focusedField = nil }
        .onAppear {
            // Do NOT pre-fill — avoids the truncated dots issue for long keys
            // The placeholder text already indicates if a key is saved
        }
    }

    private var isFormValid: Bool {
        !identity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        password.count >= 6 &&
        !tmdbKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func signIn() async {
        guard isFormValid else { return }
        focusedField = nil
        withAnimation { isLoading = true; errorMessage = nil }
        do {
            // Save TMDB key first
            SettingsStore.shared.saveTMDBKey(tmdbKey)
            try await AuthService.shared.login(identity: identity, password: password)
        } catch {
            withAnimation {
                errorMessage = error.localizedDescription
            }
        }
        withAnimation { isLoading = false }
    }
}
