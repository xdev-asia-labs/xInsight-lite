import SwiftUI
import Charts

/// BenchmarkTab - Performance benchmarking UI
struct BenchmarkTab: View {
    @StateObject private var benchmarks = PerformanceBenchmarks.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Run Button
                if benchmarks.isRunning {
                    runningSection
                } else {
                    runButton
                }
                
                // Latest Results
                if !benchmarks.results.isEmpty {
                    resultsSection
                }
                
                // History
                if !benchmarks.history.isEmpty {
                    historySection
                }
                
                // Comparison
                if !benchmarks.history.isEmpty {
                    comparisonSection
                }
            }
            .padding(24)
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Performance Benchmarks")
                    .font(.title.bold())
                Text("Test your Mac's performance with standardized benchmarks")
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            if !benchmarks.history.isEmpty {
                Text("Last run: \(benchmarks.history.first!.date.formatted())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Run Button
    
    private var runButton: some View {
        Button {
            Task {
                await benchmarks.runAllBenchmarks()
            }
        } label: {
            Label("Run All Benchmarks", systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
    }
    
    // MARK: - Running
    
    private var runningSection: some View {
        VStack(spacing: 16) {
            if let current = benchmarks.currentBenchmark {
                HStack {
                    Image(systemName: current.icon)
                        .font(.title2)
                    Text("Running \(current.rawValue)...")
                        .font(.headline)
                }
            }
            
            ProgressView(value: benchmarks.progress)
                .progressViewStyle(.linear)
            
            Text("\(Int(benchmarks.progress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Results
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Results")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(benchmarks.results) { result in
                    resultCard(result)
                }
            }
            
            // Total Score
            HStack {
                Text("Total Score")
                    .font(.headline)
                Spacer()
                Text(String(format: "%.0f", benchmarks.results.reduce(0) { $0 + $1.score }))
                    .font(.title.bold())
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private func resultCard(_ result: BenchmarkResult) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: result.type.icon)
                    .foregroundColor(.blue)
                Text(result.type.rawValue)
                    .font(.caption.bold())
            }
            
            Text(result.formattedScore)
                .font(.title.bold())
            
            Text(String(format: "%.2fs", result.duration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - History
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("History")
                .font(.headline)
            
            Chart {
                ForEach(benchmarks.history.reversed()) { session in
                    BarMark(
                        x: .value("Date", session.date, unit: .day),
                        y: .value("Score", session.totalScore)
                    )
                    .foregroundStyle(.blue.gradient)
                }
            }
            .frame(height: 150)
            
            // History List
            ForEach(benchmarks.history.prefix(5)) { session in
                HStack {
                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    Spacer()
                    Text(String(format: "%.0f", session.totalScore))
                        .font(.headline)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Comparison
    
    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Comparison with M3 Max Baseline")
                .font(.headline)
            
            ForEach(benchmarks.compareWithBaseline(), id: \.self) { comparison in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(comparison)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}
