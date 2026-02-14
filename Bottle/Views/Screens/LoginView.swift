//
//  LoginView.swift
//  Bottle
//
//  User Login Screen
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showingError = false
    @State private var showingSignUp = false
    @State private var showingForgotPassword = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.brandGreen, Color.brandGreenLight],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Logo and welcome
                        VStack(spacing: 16) {
                            Image(systemName: "waterbottle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                            
                            Text("BOTTLE")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Turn bottles into cash")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.top, 60)
                        
                        // Login form
                        VStack(spacing: 20) {
                            // Email field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                TextField("", text: $email)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                            }
                            
                            // Password field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                SecureField("", text: $password)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                            
                            // Forgot password
                            Button("Forgot Password?") {
                                showingForgotPassword = true
                            }
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            
                            // Login button
                            Button(action: handleLogin) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Sign In")
                                            .font(.headline)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .foregroundColor(.white)
                                .cornerRadius(15)
                            }
                            .disabled(isLoading || email.isEmpty || password.isEmpty)
                            .padding(.top, 8)
                            
                            // OR divider
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
                            .padding(.vertical, 8)
                            
                            // Google Sign In button
                            GoogleSignInButton {
                                handleGoogleSignIn()
                            }
                            .disabled(isLoading)
                        }
                        .padding(.horizontal, 32)
                        
                        // Sign up prompt
                        VStack(spacing: 12) {
                            Text("Don't have an account?")
                                .foregroundColor(.white.opacity(0.8))
                            
                            Button("Create Account") {
                                showingSignUp = true
                            }
                            .font(.headline)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .foregroundColor(.brandGreen)
                            .cornerRadius(25)
                        }
                        .padding(.top, 16)
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(authService.errorMessage ?? "An error occurred")
            }
            .sheet(isPresented: $showingSignUp) {
                SignUpView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showingForgotPassword) {
                ForgotPasswordView()
                    .environmentObject(authService)
            }
        }
    }
    
    private func handleLogin() {
        isLoading = true
        
        Task {
            do {
                try await authService.signIn(email: email, password: password)
            } catch {
                showingError = true
            }
            isLoading = false
        }
    }
    
    private func handleGoogleSignIn() {
        isLoading = true
        
        Task {
            do {
                // Get the root view controller
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootViewController = windowScene.windows.first?.rootViewController else {
                    throw AppError.authentication("Unable to get view controller")
                }
                
                try await authService.signInWithGoogle(presenting: rootViewController)
            } catch {
                showingError = true
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
                                        title: "Donor",
                                        icon: "house",
                                        description: "Donate bottles",
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
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white.opacity(0.2))
            .foregroundColor(.white)
            .cornerRadius(10)
            .accentColor(.white)
    }
}

// MARK: - Google Sign In Button

struct GoogleSignInButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "g.circle.fill")
                    .font(.system(size: 24))
                
                Text("Continue with Google")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .foregroundColor(.black)
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.1), radius: 5, y: 2)
        }
    }
}
