import Foundation

struct VCDSignal: Identifiable {
    let id = UUID()
    let name: String
    let symbol: String
    let isBus: Bool
    var timeline: [TimePoint]
}

struct TimePoint {
    let time: Int
    let value: String // Modificat în String pentru a suporta și magistrale (ex: "b0001" sau "1")
}

class VerilogCore {
    private let iverilogPath = "/opt/homebrew/bin/iverilog"
    private let vvpPath = "/opt/homebrew/bin/vvp"
    
    func runSimulation(sourceCode: String, directory: URL) -> String {
        let designURL = directory.appendingPathComponent("design.v")
        let outputVVPURL = directory.appendingPathComponent("sim.vvp")
        let outputVCDURL = directory.appendingPathComponent("wave.vcd")
        
        try? FileManager.default.removeItem(at: outputVCDURL)
        
        do {
            try sourceCode.write(to: designURL, atomically: true, encoding: .utf8)
        } catch {
            return "❌ Eroare la scrierea fișierului pe disk.\n"
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.currentDirectoryURL = directory
        
        let shellCommand = """
        export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
        iverilog -o "\(outputVVPURL.path)" "\(designURL.path)" && vvp "\(outputVVPURL.path)"
        """
        process.arguments = ["-c", shellCommand]
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                return "❌ Eroare Sintaxă:\n" + (String(data: errorData, encoding: .utf8) ?? "")
            }
            return FileManager.default.fileExists(atPath: outputVCDURL.path) ? "✅ Compilat și simulat cu succes!\n" : "⚠️ wave.vcd lipsă.\n"
        } catch {
            return "❌ Eroare subproces: \(error.localizedDescription)\n"
        }
    }
    
    func parseVCD(vcdURL: URL) -> [VCDSignal] {
        guard let content = try? String(contentsOf: vcdURL, encoding: .utf8) else { return [] }
        
        var signals: [VCDSignal] = []
        var currentTime = 0
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            // $var reg 4 ! count [3:0] $end sau $var wire 1 # clk $end
            if trimmed.hasPrefix("$var") {
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 5 {
                    let size = parts[2]
                    let symbol = parts[3]
                    let name = parts[4]
                    
                    // Prevenim duplicarea biților individuali generați de iverilog pentru instanțieri
                    if !signals.contains(where: { $0.name == name }) {
                        signals.append(VCDSignal(name: name, symbol: symbol, isBus: size != "1", timeline: []))
                    }
                }
            } else if trimmed.hasPrefix("#") {
                if let timeInt = Int(trimmed.dropFirst()) {
                    currentTime = timeInt
                }
            }
            // Schimbare magistrală: b0001 !
            else if trimmed.hasPrefix("b") {
                let parts = trimmed.dropFirst().components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count == 2 {
                    let val = parts[0]
                    let symbol = parts[1]
                    if let idx = signals.firstIndex(where: { $0.symbol == symbol }) {
                        signals[idx].timeline.append(TimePoint(time: currentTime, value: val))
                    }
                }
            }
            // Schimbare fir scalar: 1# sau 0#
            else if trimmed.count >= 2 && (trimmed.hasPrefix("0") || trimmed.hasPrefix("1")) {
                let val = String(trimmed.prefix(1))
                let symbol = String(trimmed.dropFirst())
                if let idx = signals.firstIndex(where: { $0.symbol == symbol }) {
                    signals[idx].timeline.append(TimePoint(time: currentTime, value: val))
                }
            }
        }
        return signals
    }
}
