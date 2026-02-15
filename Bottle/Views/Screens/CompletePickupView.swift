//
//  CompletePickupView.swift
//  Bottle
//
//  Complete a claimed pickup with optional Gemini AI count
//

import SwiftUI
import UIKit

struct CompletePickupView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataService: DataService
    
    let job: BottleJob
    
    @State private var bottleCount: String = ""
    @State private var photoImage: UIImage?
    @State private var showProofCamera = false
    
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @State private var aiCount: Int?
    @State private var aiConfidence: Int?
    @State private var aiNotes: String?
    @State private var aiIsRecyclable: Bool?
    @State private var aiMaterials: MaterialBreakdown?
    @State private var isCountingWithAI = false
    @State private var aiTask: Task<Void, Never>?
    @State private var showImpactBurst = false
    @State private var confirmedLowConfidence = false
    
    private let geminiService = GeminiService()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(job.title).font(.headline)
                        Text(job.address).font(.caption).foregroundColor(.secondary)
                        ImpactContextRow(
                            co2Saved: ClimateImpactCalculator.co2Saved(bottles: job.bottleCount),
                            bottles: job.bottleCount
                        )
                        Text("Every verified pickup improves neighborhood recycling outcomes.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    Button {
                        showProofCamera = true
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                                .frame(height: 220)
                            if let photoImage {
                                Image(uiImage: photoImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 220)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .cornerRadius(12)
                            } else {
                                Label("Take pickup photo", systemImage: "camera.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .accessibilityLabel("Take pickup photo")

                    if photoImage != nil {
                        Button {
                            guard let photoImage else { return }
                            Task { await runAICount(photoImage) }
                        } label: {
                            HStack {
                                if isCountingWithAI {
                                    ProgressView()
                                } else {
                                    Image(systemName: "sparkles")
                                    Text("Count with AI")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.brandBlueLight.opacity(0.15))
                            .foregroundColor(Color.brandBlueDark)
                            .cornerRadius(10)
                        }
                        .disabled(isCountingWithAI)
                        .accessibilityLabel("Run AI bottle count")
                    }
                    
                    if let aiCount, let aiConfidence {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("AI Detected: \(aiCount) bottles (\(aiConfidence)% confidence)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("AI impact estimate aligns with ~\(String(format: "%.1f", ClimateImpactCalculator.co2Saved(bottles: aiCount))) kg CO₂")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let aiIsRecyclable {
                                Text(aiIsRecyclable ? "Likely CRV-eligible recyclables" : "Mixed/non-CRV materials detected")
                                    .font(.caption)
                                    .foregroundColor(aiIsRecyclable ? .green : .orange)
                            }
                            if let aiNotes {
                                Text(aiNotes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let aiMaterials {
                                HStack(spacing: 10) {
                                    Text("Plastic: \(aiMaterials.plastic)")
                                    Text("Aluminum: \(aiMaterials.aluminum)")
                                    Text("Glass: \(aiMaterials.glass)")
                                }
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            }
                            if aiConfidence < 70 {
                                Text("Low confidence. Please review and adjust count before verifying.")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                Toggle("AI confidence is low - I confirm this count manually", isOn: $confirmedLowConfidence)
                                    .font(.caption2)
                            }
                            Text("Count is auto-filled from AI. You can edit it below any time.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bottle Count")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        TextField("Enter collected bottles", text: $bottleCount)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                    }
                    
                    Button(action: complete) {
                        HStack {
                            if isSubmitting || isCountingWithAI {
                                ProgressView().progressViewStyle(.circular)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    Text("Complete Collection")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSubmit ? Color.brandGreen : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canSubmit)

                    Button(action: {
                        dataService.openNearbyRecyclingCenters()
                    }) {
                        HStack {
                            Image(systemName: "map.fill")
                            Text("Find Nearby Recycling Centers")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Complete Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showProofCamera) {
                CameraImagePicker(image: $photoImage)
                    .ignoresSafeArea()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .onAppear { bottleCount = "\(job.bottleCount)" }
            .onChange(of: photoImage) { _, newValue in
                guard newValue != nil else { return }
                aiCount = nil
                aiConfidence = nil
                aiNotes = nil
                aiIsRecyclable = nil
                aiMaterials = nil
                confirmedLowConfidence = false
                if AppConfig.aiVerificationEnabled, let image = newValue {
                    aiTask?.cancel()
                    aiTask = Task {
                        await runAICount(image)
                    }
                }
            }
            .onDisappear {
                aiTask?.cancel()
            }
        }
        .overlay(alignment: .center) {
            if showImpactBurst {
                VStack(spacing: 10) {
                    Text("+\(String(format: "%.1f", ClimateImpactCalculator.co2Saved(bottles: Int(bottleCount) ?? job.bottleCount))) kg CO₂")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.brandBlueLight)
                    Text("+\(Int(bottleCount) ?? job.bottleCount) bottles")
                        .font(.headline)
                        .foregroundColor(.brandGreen)
                }
                .padding(18)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    private var canSubmit: Bool {
        let lowConfidenceNeedsOverride = (aiConfidence ?? 100) < 70 && !confirmedLowConfidence
        return !isSubmitting &&
            photoImage != nil &&
            (Int(bottleCount) ?? 0) > 0 &&
            !lowConfidenceNeedsOverride
    }
    
    private func runAICount(_ image: UIImage) async {
        guard AppConfig.aiVerificationEnabled else { return }
        isCountingWithAI = true
        defer { isCountingWithAI = false }
        do {
            async let countTask = geminiService.countBottles(from: image)
            async let classifyTask = geminiService.classifyRecyclability(from: image)
            let countResult = try await countTask
            let classifyResult = try await classifyTask

            aiCount = countResult.count
            aiConfidence = countResult.confidence
            aiNotes = classifyResult.summary
            aiIsRecyclable = classifyResult.isRecyclable
            aiMaterials = countResult.materials

            // AI-first flow: auto-fill from Gemini unless confidence is too low.
            if countResult.confidence >= 60 {
                bottleCount = "\(countResult.count)"
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = "AI couldn't analyze this photo right now. You can still enter the count manually."
            showError = true
        }
    }
    
    private func complete() {
        guard let count = Int(bottleCount), count > 0 else {
            errorMessage = "Enter a valid bottle count."
            showError = true
            return
        }
        
        isSubmitting = true
        Task {
            do {
                try await dataService.completeJob(
                    job,
                    bottleCount: count,
                    aiVerified: AppConfig.aiVerificationEnabled && aiCount != nil,
                    proofPhotoBase64: photoImage?.jpegData(compressionQuality: 0.6)?.base64EncodedString(),
                    aiConfidence: aiConfidence,
                    materialBreakdown: aiMaterials
                )
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                    showImpactBurst = true
                }
                isSubmitting = false
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                withAnimation {
                    showImpactBurst = false
                }
                dismiss()
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

private struct ImpactContextRow: View {
    let co2Saved: Double
    let bottles: Int

    private var contextText: String {
        switch co2Saved {
        case 0..<5:
            return "About \(Int(co2Saved * 12)) phone charges worth of carbon avoided."
        case 5..<25:
            return "Roughly \(Int(co2Saved / 0.4)) miles of car emissions avoided."
        default:
            return "Equivalent to around \(max(1, Int(co2Saved / 20))) tree(s) of annual absorption."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Impact potential: \(String(format: "%.1f", co2Saved)) kg CO₂ from \(bottles) bottles")
                .font(.subheadline)
                .foregroundColor(.brandBlueLight)
            Text(contextText)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    CompletePickupView(job: BottleJob.mockJobs[0])
        .environmentObject(DataService.shared)
}
