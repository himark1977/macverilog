import SwiftUI

// --- VIZUALIZATORUL GRAFIC INTERACTIV ---
struct RealWaveformViewer: View {
    let signals: [VCDSignal]
    
    private let rowHeight: CGFloat = 60
    private let timeScale: CGFloat = 5.0 // 1ns = 5px
    
    @State private var hoverX: CGFloat? = nil
    @State private var selectedTime: Int? = nil
    
    var body: some View {
        if signals.isEmpty {
            ContentUnavailableView("No Simulation Data", systemImage: "waveform.path.badge.minus")
        } else {
            VStack(spacing: 0) {
                // Bara de status superioară pentru Timpul Selectat
                HStack {
                    Image(systemName: "clock.halo")
                        .foregroundColor(.orange)
                    if let time = selectedTime {
                        Text("Timp Cursor: \(time) ns")
                            .font(.system(.body, design: .monospaced))
                            .bold()
                    } else {
                        Text("Mișcă mouse-ul peste grafic pentru probe...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor))
                
                Divider()
                
                ScrollView([.vertical, .horizontal], showsIndicators: true) {
                    VStack(spacing: 0) {
                        ForEach(signals, id: \.id) { (sig: VCDSignal) in
                            HStack(spacing: 0) {
                                
                                // 1. Eticheta din stânga + Valoarea Sondată (Probe)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sig.name)
                                        .font(.system(.body, design: .monospaced))
                                        .bold()
                                        .foregroundColor(sig.isBus ? .orange : .cyan)
                                    
                                    // Valoarea semnalului la momentul de timp selectat
                                    Text(getValueAtSelectedTime(signal: sig, time: selectedTime))
                                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(sig.isBus ? Color.orange.opacity(0.3) : Color.green.opacity(0.3))
                                        .cornerRadius(3)
                                }
                                .frame(width: 120, height: rowHeight, alignment: .leading)
                                .padding(.leading, 15)
                                .background(Color(NSColor.windowBackgroundColor))
                                
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 1, height: rowHeight)
                                
                                // 2. Desenul grafic + Suprapunere Cursor
                                Canvas { context, size in
                                    let midY = rowHeight / 2
                                    
                                    if sig.isBus {
                                        // --- RENDER MAGISTRALĂ ---
                                        for i in 0..<sig.timeline.count {
                                            let currentPoint = sig.timeline[i]
                                            let startX = CGFloat(currentPoint.time) * timeScale
                                            let endX = (i + 1 < sig.timeline.count) ? CGFloat(sig.timeline[i+1].time) * timeScale : startX + 150
                                            
                                            if endX - startX < 4 { continue }
                                            
                                            let busTop = midY - 12
                                            let busBottom = midY + 12
                                            
                                            var busPath = Path()
                                            busPath.move(to: CGPoint(x: startX, y: midY))
                                            busPath.addLine(to: CGPoint(x: startX + 4, y: busTop))
                                            busPath.addLine(to: CGPoint(x: endX - 4, y: busTop))
                                            busPath.addLine(to: CGPoint(x: endX, y: midY))
                                            busPath.addLine(to: CGPoint(x: endX - 4, y: busBottom))
                                            busPath.addLine(to: CGPoint(x: startX + 4, y: busBottom))
                                            busPath.addLine(to: CGPoint(x: startX, y: midY))
                                            
                                            context.stroke(busPath, with: .color(.orange), style: StrokeStyle(lineWidth: 1.5))
                                            
                                            let hexVal = String(Int(currentPoint.value, radix: 2) ?? 0, radix: 16).uppercased()
                                            let text = Text(hexVal).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.white)
                                            let textRect = CGRect(x: startX + 6, y: busTop + 4, width: (endX - startX) - 12, height: 20)
                                            context.draw(text, in: textRect)
                                        }
                                    } else {
                                        // --- RENDER FIR SCALAR ---
                                        var path = Path()
                                        let highY = midY - 12
                                        let lowY = midY + 12
                                        
                                        if let firstPoint = sig.timeline.first {
                                            let firstY = firstPoint.value == "1" ? highY : lowY
                                            path.move(to: CGPoint(x: CGFloat(firstPoint.time) * timeScale, y: firstY))
                                            
                                            for point in sig.timeline {
                                                let nextX = CGFloat(point.time) * timeScale
                                                let nextY = point.value == "1" ? highY : lowY
                                                
                                                path.addLine(to: CGPoint(x: nextX, y: path.currentPoint?.y ?? nextY))
                                                path.addLine(to: CGPoint(x: nextX, y: nextY))
                                            }
                                            
                                            if let lastX = path.currentPoint?.x {
                                                path.addLine(to: CGPoint(x: lastX + 150, y: path.currentPoint?.y ?? midY))
                                            }
                                            context.stroke(path, with: .color(.green), style: StrokeStyle(lineWidth: 1.5))
                                        }
                                    }
                                    
                                    // --- CURSOR VERTICAL ---
                                    if let x = hoverX {
                                        var cursorPath = Path()
                                        cursorPath.move(to: CGPoint(x: x, y: 0))
                                        cursorPath.addLine(to: CGPoint(x: x, y: size.height))
                                        context.stroke(cursorPath, with: .color(.orange.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                    }
                                }
                                .frame(width: 1500, height: rowHeight)
                                .background(Color(NSColor.textBackgroundColor))
                                .onContinuousHover { phase in
                                    switch phase {
                                    case .active(let location):
                                        self.hoverX = location.x
                                        self.selectedTime = Int((location.x / timeScale).rounded())
                                    case .ended:
                                        self.hoverX = nil
                                        self.selectedTime = nil
                                    }
                                }
                            }
                            
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 1)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func getValueAtSelectedTime(signal: VCDSignal, time: Int?) -> String {
        guard let time = time else { return "--" }
        let pastPoints = signal.timeline.filter { $0.time <= time }
        
        if let lastPoint = pastPoints.last {
            if signal.isBus {
                let hexVal = String(Int(lastPoint.value, radix: 2) ?? 0, radix: 16).uppercased()
                return "0x\(hexVal)"
            } else {
                return lastPoint.value
            }
        }
        return signal.isBus ? "0x0" : "0"
    }
}
