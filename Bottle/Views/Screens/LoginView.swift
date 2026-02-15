//
//  LoginView.swift
//  Bottle
//
//  User Login Screen
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.colorScheme) var colorScheme
    
    enum Field {
        case phone
        case code
    }
    
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var codeSent = false
    @State private var isLoading = false
    @State private var showingError = false
    @FocusState private var focusedField: Field?
    
    var body: some View {
        ZStack {
            // Full-bleed background
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color.brandBlack, Color.brandBlueDark]
                    : [Color(hex: "BFE2FF"), Color(hex: "9CCFFF"), Color(hex: "78B6F6")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Spacer(minLength: max(40, geo.safeAreaInsets.top + 20))
                        
                        // Hero
                        VStack(spacing: 16) {
                            Image("logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 140, height: 140)
                            
                            Text("bottlr")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Connect neighbors to recycle bottles")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.95))
                        }
                        .padding(.bottom, 8)

                        if let errorMessage = authService.errorMessage, showingError {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                Text(errorMessage)
                                    .font(.caption)
                                    .multilineTextAlignment(.leading)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(colorScheme == .dark ? 0.45 : 0.3))
                            .cornerRadius(10)
                        }
                        
                        // Login form (Phone + OTP)
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Phone Number")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                TextField("+1 555 123 4567", text: $phoneNumber)
                                    .textFieldStyle(CustomTextFieldStyle(colorScheme: colorScheme))
                                    .keyboardType(.phonePad)
                                    .focused($focusedField, equals: .phone)
                            }
                            
                            if codeSent {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Verification Code")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    TextField("123456", text: $verificationCode)
                                        .textFieldStyle(CustomTextFieldStyle(colorScheme: colorScheme))
                                        .keyboardType(.numberPad)
                                        .focused($focusedField, equals: .code)
                                }
                            }
                            
                            Button(action: codeSent ? handleVerifyCode : handleSendCode) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text(codeSent ? "Verify & Sign In" : "Send Verification Code")
                                            .font(.headline)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(isPrimaryActionDisabled ? 0.1 : 0.25))
                                .foregroundColor(.white)
                                .cornerRadius(15)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .disabled(isPrimaryActionDisabled)
                            .opacity(isPrimaryActionDisabled ? 0.5 : 1.0)
                            .padding(.top, 4)
                            
                            HStack {
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.white.opacity(0.3))
                                
                                Text("OR")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 8)
                                
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .padding(.vertical, 4)
                            
                            GoogleSignInButton(
                                action: {
                                    handleGoogleSignIn()
                                },
                                colorScheme: colorScheme
                            )
                            .disabled(isLoading)
                        }
                        
                        Spacer(minLength: 16)
                    }
                    .frame(minHeight: geo.size.height)
                    .padding(.horizontal, 24)
                    .padding(.bottom, max(20, geo.safeAreaInsets.bottom))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedField = nil
                    }
                }
            }
            
            if isLoading {
                Color.black.opacity(colorScheme == .dark ? 0.45 : 0.3)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
            }
        }
        .onChange(of: authService.errorMessage) { _, newValue in
            if newValue != nil {
                showingError = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation {
                        showingError = false
                    }
                }
            }
        }
    }
    
    private var isPrimaryActionDisabled: Bool {
        if codeSent {
            return isLoading || verificationCode.trimmingCharacters(in: .whitespacesAndNewlines).count < 6
        }
        return isLoading || normalizedPhoneNumber() == nil
    }
    
    private func normalizedPhoneNumber() -> String? {
        let raw = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return nil }

        let digits = raw.filter(\.isNumber)
        guard digits.count >= 10 && digits.count <= 15 else { return nil }

        if raw.hasPrefix("+") {
            return "+\(digits)"
        }

        if digits.count == 10 { return "+1\(digits)" }
        return "+\(digits)"
    }

    private func rootViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes
            .flatMap { $0.windows }
            .first(where: \.isKeyWindow)
        return keyWindow?.rootViewController
    }

    private func presentLocalError(_ message: String) {
        authService.errorMessage = message
        showingError = true
    }

    private func isCancelledSignInError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain.contains("GIDSignIn") && nsError.code == -5
    }
    
    private func handleSendCode() {
        guard let e164 = normalizedPhoneNumber() else {
            presentLocalError("Enter a valid phone number with country code (e.g. +1 555 123 4567).")
            return
        }

        isLoading = true
        focusedField = nil
        
        Task {
            do {
                try await authService.sendPhoneVerification(to: e164)
                codeSent = true
                focusedField = .code
            } catch {
                showingError = true
            }
            isLoading = false
        }
    }
    
    private func handleVerifyCode() {
        isLoading = true
        focusedField = nil
        
        Task {
            do {
                try await authService.signInWithPhoneCode(verificationCode)
            } catch {
                showingError = true
            }
            isLoading = false
        }
    }
    
    private func handleGoogleSignIn() {
        isLoading = true
        focusedField = nil
        
        Task {
            do {
                guard let rootViewController = rootViewController() else {
                    throw AppError.authentication("Unable to get view controller")
                }
                
                try await authService.signInWithGoogle(presenting: rootViewController)
            } catch {
                if !isCancelledSignInError(error) {
                    showingError = true
                }
            }
            isLoading = false
        }
    }
}

// MARK: - Sign Up View

struct SignUpView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var userType: UserType = .collector
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Create Account")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("Join the bottle revolution")
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 32)
                        
                        // Form
                        VStack(spacing: 20) {
                            // Name
                            FormField(title: "Full Name", text: $name)
                            
                            // Email
                            FormField(title: "Email", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                            
                            // Password
                            SecureFormField(title: "Password", text: $password)
                            
                            // Confirm password
                            SecureFormField(title: "Confirm Password", text: $confirmPassword)
                            
                            // User type selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("I am a...")
                                    .font(.headline)
                                
                                HStack(spacing: 12) {
                                    UserTypeButton(
                                        title: "Collector",
                                        icon: "figure.walk",
                                        description: "Pick up bottles",
                                        isSelected: userType == .collector
                                    ) {
                                        userType = .collector
                                        HapticManager.shared.selection()
                                    }
                                    
                                    UserTypeButton(
                                        title: "Host",
                                        icon: "house",
                                        description: "Post bottles",
                                        isSelected: userType == .donor
                                    ) {
                                        userType = .donor
                                        HapticManager.shared.selection()
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 24)
                        
                        // Sign up button
                        LoadingButton(
                            title: "Create Account",
                            gradient: Color.brandGradient()
                        ) {
                            handleSignUp()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        
                        // Terms
                        Text("By signing up, you agree to our Terms of Service and Privacy Policy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func handleSignUp() {
        // Validation
        guard !name.isEmpty else {
            errorMessage = "Please enter your name"
            showingError = true
            return
        }
        
        guard email.contains("@") else {
            errorMessage = "Please enter a valid email"
            showingError = true
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            showingError = true
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords don't match"
            showingError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await authService.signUp(
                    email: email,
                    password: password,
                    name: name,
                    userType: userType
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
            isLoading = false
        }
    }
}

// MARK: - Forgot Password View

struct ForgotPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    
    @State private var email = ""
    @State private var isLoading = false
    @State private var showingSuccess = false
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Reset Password")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Enter your email and we'll send you a reset link")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                FormField(title: "Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .padding(.horizontal, 24)
                
                LoadingButton(
                    title: "Send Reset Link",
                    gradient: Color.brandGradient()
                ) {
                    handleReset()
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .padding(.top, 60)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Password reset email sent! Check your inbox.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(authService.errorMessage ?? "An error occurred")
            }
        }
    }
    
    private func handleReset() {
        isLoading = true
        
        Task {
            do {
                try await authService.resetPassword(email: email)
                showingSuccess = true
            } catch {
                showingError = true
            }
            isLoading = false
        }
    }
}

// MARK: - Custom Components

struct FormField: View {
    let title: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            TextField("", text: $text)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
        }
    }
}

struct SecureFormField: View {
    let title: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            SecureField("", text: $text)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
        }
    }
}

struct UserTypeButton: View {
    let title: String
    let icon: String
    let description: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                    
                    Text(description)
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.brandGreen : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(15)
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    let colorScheme: ColorScheme

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(colorScheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.25))
            .foregroundColor(.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.5 : 0.4), lineWidth: 1)
            )
            .accentColor(.white)
    }
}

// MARK: - Google Sign In Button

struct GoogleSignInButton: View {
    let action: () -> Void
    let colorScheme: ColorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image("google-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                
                Text("Continue with Google")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(colorScheme == .dark ? Color(.secondarySystemBackground) : Color.white)
            .foregroundColor(colorScheme == .dark ? .white : .black)
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 5, y: 2)
        }
    }
}
