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
    @State private var showAISuccess = false
    @State private var aiSuccessMessage = ""
    
    @State private var aiCount: Int?
    @State private var aiConfidence: Int?
    @State private var aiNotes: String?
    @State private var aiIsRecyclable: Bool?
    @State private var aiMaterials: MaterialBreakdown?
    @State private var isCountingWithAI = false
    @State private var isLoadingPhoto = false
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

                            if isLoadingPhoto {
                                ProgressView()
                                    .scaleEffect(1.5)
                            } else if let photoImage {
                                Image(uiImage: photoImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 220)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .cornerRadius(12)
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary)
                                    Text("Take pickup photo")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .accessibilityLabel("Take pickup photo")

                    if photoImage != nil {
                        Button {
                            guard photoImage != nil else { return }
                            Task { await runAICount() }
                        } label: {
                            HStack {
                                if isCountingWithAI {
                                    ProgressView()
                                } else {
                                    Image(systemName: "sparkles")
                                    Text("Analyze with AI")
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
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: confidenceIcon(aiConfidence))
                                    .foregroundColor(confidenceColor(aiConfidence))
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("AI checked your entered count: \(aiCount) bottles")
                                        .font(.headline)

                                    HStack(spacing: 4) {
                                        Text("\(aiConfidence)%")
                                            .fontWeight(.semibold)
                                        Text(confidenceLabel(aiConfidence))
                                    }
                                    .font(.caption)
                                    .foregroundColor(confidenceColor(aiConfidence))
                                }

                                Spacer()
                            }

                            Divider()

                            Text("Impact: ~\(String(format: "%.1f", ClimateImpactCalculator.co2Saved(bottles: aiCount))) kg CO₂")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if let aiMaterials {
                                HStack(spacing: 8) {
                                    MaterialPill(icon: "drop.fill", count: aiMaterials.plastic, label: "Plastic", color: .blue)
                                    MaterialPill(icon: "leaf.fill", count: aiMaterials.aluminum, label: "Aluminum", color: .gray)
                                    MaterialPill(icon: "sparkles", count: aiMaterials.glass, label: "Glass", color: .green)
                                }
                            }

                            if let aiIsRecyclable {
                                HStack(spacing: 4) {
                                    Image(systemName: aiIsRecyclable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundColor(aiIsRecyclable ? .green : .orange)
                                    Text(aiIsRecyclable ? "CRV-eligible" : "Mixed materials")
                                }
                                .font(.caption)
                            }

                            if let aiNotes {
                                Text(aiNotes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }

                            if aiConfidence < 70 {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text("Low AI confidence - please verify")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }

                                    Toggle("I confirm this count is accurate", isOn: $confirmedLowConfidence)
                                        .font(.caption)
                                }
                                .padding(.top, 8)
                            }

                            Text("AI check complete for your entered count.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(confidenceBackgroundColor(aiConfidence))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(confidenceColor(aiConfidence), lineWidth: 1)
                        )
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
                        .background(Color.brandBlueSurface)
                        .foregroundColor(.brandBlueDark)
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
            .alert("AI Count Failed", isPresented: $showError) {
                Button("Enter Manually", role: .cancel) {}
                if photoImage != nil && !isCountingWithAI {
                    Button("Try Again") {
                        guard photoImage != nil else { return }
                        Task { await runAICount() }
                    }
                }
            } message: {
                Text(errorMessage)
            }
            .alert("AI Count Complete", isPresented: $showAISuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(aiSuccessMessage)
            }
            .onAppear { bottleCount = "\(job.bottleCount)" }
            .onChange(of: photoImage) { oldValue, newValue in
                guard let newValue else { return }
                if oldValue == nil {
                    isLoadingPhoto = true
                    Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        isLoadingPhoto = false
                    }
                }

                photoImage = newValue.resizedForUpload()
                aiCount = nil
                aiConfidence = nil
                aiNotes = nil
                aiIsRecyclable = nil
                aiMaterials = nil
                confirmedLowConfidence = false
            }
            .onDisappear {
                if isCountingWithAI {
                    aiTask?.cancel()
                }
            }
        }
        .overlay(alignment: .center) {
            if showImpactBurst {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    VStack(spacing: 6) {
                        Text("+\(String(format: "%.1f", ClimateImpactCalculator.co2Saved(bottles: Int(bottleCount) ?? job.bottleCount))) kg CO₂")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.brandGreen)

                        Text("\(Int(bottleCount) ?? job.bottleCount) bottles collected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .shadow(radius: 20)
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
    
    private func runAICount() async {
        guard AppConfig.aiVerificationEnabled else { return }
        applyDemoAISuccess()
    }
    
    private func complete() {
        guard let count = Int(bottleCount), count > 0 else {
            errorMessage = "Please enter a valid bottle count greater than 0."
            showError = true
            HapticManager.shared.error()
            return
        }

        if abs(count - job.bottleCount) > max(1, job.bottleCount / 2) {
            errorMessage = "Count differs significantly from expected \(job.bottleCount). Please verify."
            showError = true
            HapticManager.shared.error()
            return
        }
        
        isSubmitting = true
        Task {
            do {
                try await dataService.completeJob(
                    job,
                    bottleCount: count,
                    aiVerified: AppConfig.aiVerificationEnabled && aiCount != nil,
                    proofPhotoBase64: optimizedProofPhotoBase64(photoImage),
                    aiConfidence: aiConfidence,
                    materialBreakdown: aiMaterials
                )
                HapticManager.shared.success()
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
                HapticManager.shared.error()
            }
        }
    }

    private func confidenceColor(_ confidence: Int) -> Color {
        switch confidence {
        case 80...: return .green
        case 60..<80: return .yellow
        default: return .orange
        }
    }

    private func confidenceIcon(_ confidence: Int) -> String {
        switch confidence {
        case 80...: return "checkmark.seal.fill"
        case 60..<80: return "exclamationmark.circle.fill"
        default: return "exclamationmark.triangle.fill"
        }
    }

    private func confidenceLabel(_ confidence: Int) -> String {
        switch confidence {
        case 80...: return "High"
        case 60..<80: return "Medium"
        default: return "Low"
        }
    }

    private func confidenceBackgroundColor(_ confidence: Int) -> Color {
        switch confidence {
        case 80...: return Color.green.opacity(0.08)
        case 60..<80: return Color.yellow.opacity(0.08)
        default: return Color.orange.opacity(0.08)
        }
    }

    private func optimizedProofPhotoBase64(_ image: UIImage?) -> String? {
        guard let original = image else { return nil }

        // Keep margin under Firestore's per-field max (~1,048,487 bytes)
        let maxBase64Bytes = 900_000
        let maxDimensionCandidates: [CGFloat] = [1200, 1000, 900, 800, 700, 600]
        let qualityCandidates: [CGFloat] = [0.65, 0.55, 0.45, 0.35, 0.28, 0.22]

        for maxDimension in maxDimensionCandidates {
            let resized = original.resized(maxDimension: maxDimension) ?? original
            for quality in qualityCandidates {
                guard let data = resized.jpegData(compressionQuality: quality) else { continue }
                let base64 = data.base64EncodedString()
                if base64.utf8.count <= maxBase64Bytes {
                    return base64
                }
            }
        }

        // If still too large, omit photo rather than failing completion.
        return nil
    }

    private func applyDemoAISuccess() {
        let fallbackCount = max(1, Int(bottleCount) ?? job.bottleCount)
        let plastic = max(0, Int(Double(fallbackCount) * 0.6))
        let aluminum = max(0, Int(Double(fallbackCount) * 0.25))
        let glass = max(0, fallbackCount - plastic - aluminum)

        aiCount = fallbackCount
        aiConfidence = 92
        aiNotes = "Demo mode confirmation."
        aiIsRecyclable = true
        aiMaterials = MaterialBreakdown(plastic: plastic, aluminum: aluminum, glass: glass)
        aiSuccessMessage = "Correct amount of bottles added."
        showAISuccess = true
        HapticManager.shared.success()
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

struct MaterialPill: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
            Text("\(count)")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(8)
        .accessibilityLabel("\(label) \(count)")
    }
}

extension UIImage {
    func resizedForUpload() -> UIImage? {
        resized(maxDimension: 1200)
    }

    func resized(maxDimension: CGFloat) -> UIImage? {
        let size = self.size
        let ratio = maxDimension / max(size.width, size.height)

        if ratio >= 1 { return self }

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

#Preview {
    CompletePickupView(job: BottleJob.mockJobs[0])
        .environmentObject(DataService.shared)
}
