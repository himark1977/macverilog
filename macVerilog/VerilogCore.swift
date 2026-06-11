import Foundation

// Structuri de date necesare pentru citirea semnalelor
struct VCDSignal: Identifiable {
    let id = UUID()
    let name: String
    let symbol: String
    var timeline: [TimePoint]
}

struct TimePoint {
    let time: Int
    let value: CGFloat
}

class VerilogCore {
    // Căile standard de Homebrew pe Apple Silicon
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
        
        // Rulăm totul printr-un singur script de ZSH pentru a moșteni mediul tău din Terminal
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.currentDirectoryURL = directory
        
        // Îi dăm comanda exact ca în Terminal: încarcă profilul ZSH, compilează și rulează vvp
        let shellCommand = """
        source ~/.zshrc 2>/dev/null
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
                return "❌ Eroare Execuție/Sintaxă:\n" + (String(data: errorData, encoding: .utf8) ?? "Eroare necunoscută")
            }
            
            if FileManager.default.fileExists(atPath: outputVCDURL.path) {
                return "✅ Compilat și simulat cu succes!\n"
            } else {
                return "⚠️ wave.vcd nu a fost generat. Verifică testbench-ul.\n"
            }
            
        } catch {
            return "❌ Eroare critică la lansarea shell-ului: \(error.localizedDescription)\n"
        }
    }
    
    // --- PARSERUL NATIV DE FIȘIERE VCD ---
    func parseVCD(vcdURL: URL) -> [VCDSignal] {
        guard let content = try? String(contentsOf: vcdURL, encoding: .utf8) else {
            return []
        }
        
        var signals: [VCDSignal] = []
        var currentTime = 0
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            // Căutăm definirea variabilelor: $var wire 1 # clk $end
            if trimmed.hasPrefix("$var") {
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 5 {
                    let symbol = parts[3]
                    let name = parts[4]
                    signals.append(VCDSignal(name: name, symbol: symbol, timeline: []))
                }
            }
            // Căutăm marcajele de timp: #0, #10, #15
            else if trimmed.hasPrefix("#") {
                let timeStr = trimmed.dropFirst()
                if let timeInt = Int(timeStr) {
                    currentTime = timeInt
                }
            }
            // Căutăm valorile scalare: 1# sau 0$ sau b0101 ! (Momentan citim doar bit cu bit: 0 și 1)
            else if trimmed.count >= 2 && (trimmed.hasPrefix("0") || trimmed.hasPrefix("1")) {
                let firstChar = trimmed.first!
                let symbolStr = String(trimmed.dropFirst())

                // Convert '0'/'1' to numeric value safely
                let bitValue: Int
                if firstChar == "0" { bitValue = 0 }
                else if firstChar == "1" { bitValue = 1 }
                else { bitValue = 0 }

                if let index = signals.firstIndex(where: { $0.symbol == symbolStr }) {
                    let cgValue = CGFloat(bitValue)
                    signals[index].timeline.append(TimePoint(time: currentTime, value: cgValue))
                }
            }
        }
        return signals
    }
}

