//
//  ContentView.swift
//  SoundClassifierApp
//
//  Created by Bill Skrzypczak on 6/12/24.
//

import SwiftUI
import AVFoundation
import SoundAnalysis
import CoreML

struct ContentView: View {
    @State private var resultLabel = "Result"
    @State private var confidenceLabel = "Confidence"
    @StateObject private var audioAnalyzer = AudioAnalyzer()
    
    var body: some View {
        VStack {
            Text(resultLabel)
                .font(.largeTitle)
                .padding()
            Text(confidenceLabel)
                .font(.title)
                .padding()
        }
        .onAppear {
            // Ensure audio analysis starts when the view appears
            audioAnalyzer.startAnalysis()
        }
        .onReceive(audioAnalyzer.$resultLabel) { resultLabel = $0 }
        .onReceive(audioAnalyzer.$confidenceLabel) { confidenceLabel = $0 }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

class AudioAnalyzer: NSObject, ObservableObject {
    private let engine = AVAudioEngine()
    private var analyzer: SNAudioStreamAnalyzer!
    private var inputFormat: AVAudioFormat!
    private var soundClassifierModel: MLModel
    
    @Published var resultLabel = "Result"
    @Published var confidenceLabel = "Confidence"
    
    override init() {
        do {
            // Load the Core ML model
            let soundClassifier = try Bills_SoundClassifier()
            soundClassifierModel = soundClassifier.model
            super.init()
            setupAudioEngine()
        } catch {
            fatalError("Failed to load sound classifier model: \(error.localizedDescription)")
        }
    }
    
    func startAnalysis() {
        do {
            try engine.start()
            print("Audio engine started") // Debug logging
        } catch {
            print("Failed to start audio engine: \(error.localizedDescription)")
        }
    }
    
    private func setupAudioEngine() {
        inputFormat = engine.inputNode.inputFormat(forBus: 0)
        analyzer = SNAudioStreamAnalyzer(format: inputFormat)
        
        do {
            let request = try SNClassifySoundRequest(mlModel: soundClassifierModel)
            try analyzer.add(request, withObserver: self)
        } catch {
            fatalError("Failed to create or add the SNClassifySoundRequest: \(error.localizedDescription)")
        }
        
        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { buffer, when in
            self.analyzer.analyze(buffer, atAudioFramePosition: when.sampleTime)
            print("Audio buffer received") // Debug logging
        }
    }
}

extension AudioAnalyzer: SNResultsObserving {
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult,
              let classification = result.classifications.first else { return }
        
        let confidence = round(classification.confidence * 1000) / 10
        DispatchQueue.main.async {
            self.resultLabel = classification.identifier
            self.confidenceLabel = "\(confidence)%"
        }
    }
}
