//
//  CompletePickupView.swift
//  Bottle
//
//  Complete a claimed pickup with optional Gemini AI count
//

import SwiftUI
import PhotosUI
import UIKit

struct CompletePickupView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var dataService = DataService.shared
    
    let job: BottleJob
    
    @State private var bottleCount: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoImage: UIImage?
    
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @State private var aiCount: Int?
    @State private var aiConfidence: Int?
    @State private var aiNotes: String?
    @State private var aiIsRecyclable: Bool?
    @State private var aiMaterials: MaterialBreakdown?
    @State private var isCountingWithAI = false
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
                        Text("Impact potential: \(String(format: "%.1f", ClimateImpactCalculator.co2Saved(bottles: job.bottleCount))) kg CO₂ saved")
                            .font(.subheadline)
                            .foregroundColor(.brandBlueLight)
                        Text("Every verified pickup improves neighborhood recycling outcomes.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
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
                                Label("Upload pickup photo", systemImage: "camera.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onChange(of: selectedPhoto) { _, newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                photoImage = image
                                await runAICount(image)
                            }
                        }
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
                                Toggle("AI confidence is low - I confirm this count manually", isOn: $confirmedLowConfidence)
                                    .font(.caption2)
                            }
                            Button("Use AI Count") { bottleCount = String(aiCount) }
                                .font(.caption)
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
                                Text("Verify Impact")
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
            .navigationTitle("Verify Pickup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .onAppear { bottleCount = "\(job.bottleCount)" }
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
        } catch {
            // AI optional in demo flow
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

#Preview {
    CompletePickupView(job: BottleJob.mockJobs[0])
}
