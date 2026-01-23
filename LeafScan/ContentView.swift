//
//  ContentView.swift
//  LeafScan
//
//  Created by Aucky Riman Halim on 19/01/2026
//  FINAL VERSION - Vision Framework with Model 2 - Loading Indicator
//

import SwiftUI
import CoreML
import Vision

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var predictionResult: String = ""
    @State private var confidenceLevel: Double = 0.0
    @State private var isAnalyzing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                Text("LeafScan")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                Text("AI Plant Disease Detection")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                // Image Display
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(15)
                        .shadow(radius: 5)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 300)
                        
                        VStack {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green.opacity(0.5))
                            Text("Select an image to analyze")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                // Loading Indicator or Results Display
                if isAnalyzing {
                    VStack(spacing: 15) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .green))
                        
                        Text("Analyzing plant...")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                } else if !predictionResult.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Detection Result:")
                            .font(.headline)
                        
                        Text(formatDiseaseName(predictionResult))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Confidence: \(Int(confidenceLevel * 100))%")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Confidence bar
                        ProgressView(value: confidenceLevel)
                            .progressViewStyle(LinearProgressViewStyle(tint: confidenceColor))
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 15) {
                    Button(action: {
                        showingCamera = true
                    }) {
                        Label("Camera", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isAnalyzing ? Color.gray : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(isAnalyzing)
                    
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        Label("Gallery", systemImage: "photo.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isAnalyzing ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(isAnalyzing)
                }
                .padding(.horizontal)
            }
            .padding()
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(selectedImage: $selectedImage, sourceType: .camera)
            }
            .onChange(of: selectedImage) { oldValue, newValue in
                if newValue != nil {
                    classifyImage()
                }
            }
        }
    }
    
    // Format disease name for display
    func formatDiseaseName(_ name: String) -> String {
        return name.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "(", with: "\n(")
    }
    
    // Confidence color based on level
    var confidenceColor: Color {
        if confidenceLevel > 0.8 {
            return .green
        } else if confidenceLevel > 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    // Classification function with Vision Framework
    func classifyImage() {
        guard let image = selectedImage else {
            predictionResult = "No image selected"
            return
        }
        
        // Convert to CIImage for Vision
        guard let ciImage = CIImage(image: image) else {
            predictionResult = "Failed to process image"
            return
        }
        
        isAnalyzing = true
        predictionResult = "" // Clear previous results
        
        // Perform classification on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Load the Core ML model
                let config = MLModelConfiguration()
                let model = try LeafScan_Model_2(configuration: config)
                
                // Create Vision model
                let visionModel = try VNCoreMLModel(for: model.model)
                
                // Create classification request
                let request = VNCoreMLRequest(model: visionModel) { request, error in
                    if let error = error {
                        DispatchQueue.main.async {
                            self.predictionResult = "Error: \(error.localizedDescription)"
                            self.confidenceLevel = 0
                            self.isAnalyzing = false
                        }
                        print("❌ Classification error: \(error)")
                        return
                    }
                    
                    // Get results
                    guard let results = request.results as? [VNClassificationObservation],
                          let topResult = results.first else {
                        DispatchQueue.main.async {
                            self.predictionResult = "No results"
                            self.confidenceLevel = 0
                            self.isAnalyzing = false
                        }
                        return
                    }
                    
                    // Update UI with results
                    DispatchQueue.main.async {
                        self.predictionResult = topResult.identifier
                        self.confidenceLevel = Double(topResult.confidence)
                        self.isAnalyzing = false
                        
                        // Debug output
                        print("\n🔍 Classification Results:")
                        print("📸 Image size: \(image.size)")
                        print("\nTop 5 predictions:")
                        for (index, result) in results.prefix(5).enumerated() {
                            print("\(index + 1). \(result.identifier): \(Int(result.confidence * 100))%")
                        }
                        print("---\n")
                    }
                }
                
                // CRITICAL: Set the image crop and scale option
                request.imageCropAndScaleOption = .centerCrop
                
                // Create request handler
                let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
                
                // Perform the request
                try handler.perform([request])
                
            } catch {
                DispatchQueue.main.async {
                    self.predictionResult = "Error: \(error.localizedDescription)"
                    self.confidenceLevel = 0
                    self.isAnalyzing = false
                }
                print("❌ Error: \(error)")
            }
        }
    }
}

#Preview {
    ContentView()
}
