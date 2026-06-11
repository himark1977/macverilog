import SwiftUI

// Reprezintă un fișier din proiectul tău de Verilog
struct ProjectFile: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
}

struct ContentView: View {
    // 1. Lista de fișiere din ierarhie
    @State private var files = [
        ProjectFile(name: "design.v", icon: "doc.text"),
        ProjectFile(name: "counter_tb.v", icon: "doc.text.magnifyingglass")
    ]
    
    // Fișierul selectat curent (pornește cu design.v selectat implicit)
    @State private var selectedFileId: UUID?
    
    // 2. Aici ținem codul pentru fiecare fișier, salvat într-un dicționar [FileID: CodText]
    @State private var filesContent: [UUID: String] = [:]
    
    // Stări pentru simulator și consolă
    @State private var isSimulating = false
    @State private var selectedTab = 0
    @State private var consoleOutput: String = "site:evokzh_lab> ready."
    @State private var parsedSignals: [VCDSignal] = []
    
    init() {
        // Inițializăm codul default pentru cele două fișiere când pornește aplicația
        let designId = files[0].id
        let tbId = files[1].id
        
        _selectedFileId = State(initialValue: designId)
        _filesContent = State(initialValue: [
            designId: """
            // ==========================================
            // DESIGN-UL TĂU (counter.v)
            // ==========================================
            module counter(input clk, input rst, output reg [3:0] out);
                always @(posedge clk or posedge rst) begin
                    if (rst) out <= 4'b0000;
                    else out <= out + 1;
                end
            endmodule
            """,
            tbId: """
            // ==========================================
            // TESTBENCH-UL TĂU (counter_tb.v)
            // ==========================================
            module sim_top;
                reg clk;
                reg rst;
                wire [3:0] out;
                
                // Instanțiem modulul proiectat
                counter uut (.clk(clk), .rst(rst), .out(out));
                
                initial begin
                    $dumpfile("wave.vcd");
                    $dumpvars(0, sim_top);
                    
                    clk = 0; 
                    rst = 1;
                    #15 rst = 0;
                    #120 $finish;
                end
                
                always #5 clk = ~clk;
            endmodule
            """
        ])
    }

    // Un "computed binding" care îi dă TextEditor-ului acces direct la textul fișierului selectat
    private var activeCodeBinding: Binding<String> {
        Binding(
            get: {
                guard let id = selectedFileId else { return "Selectează un fișier din stânga..." }
                return filesContent[id] ?? ""
            },
            set: { newValue in
                if let id = selectedFileId {
                    filesContent[id] = newValue
                }
            }
        )
    }

    var body: some View {
        NavigationSplitView {
            // --- SIDEBAR: Schimbă fișierul când dai click ---
            List(files, selection: $selectedFileId) { file in
                NavigationLink(value: file.id) {
                    Label(file.name, systemImage: file.icon)
                }
            }
            .navigationTitle("Hierarchy")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 150, ideal: 180, max: 250)
            #endif
        } detail: {
            VStack(spacing: 0) {
                // Bara de unelte superioară
                HStack {
                    Picker("", selection: $selectedTab) {
                        Text("Text Editor").tag(0)
                        Text("Behavioral Simulation").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)
                    
                    Spacer()
                    
                    Button(action: runVivadoStyleSimulation) {
                        Label("Run Simulation", systemImage: "play.fill")
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSimulating)
                }
                .padding(8)
                .background(Color(NSColor.windowBackgroundColor))
                
                Divider()
                
                // Schimbare tab-uri (Editor vs Waveform)
                if selectedTab == 0 {
                    // Editorul folosește binding-ul nostru dinamic
                    TextEditor(text: activeCodeBinding)
                        .font(.system(.body, design: .monospaced))
                        .padding(4)
                } else {
                    RealWaveformViewer(signals: parsedSignals)
                }
                
                Divider()
                
                // Tcl Console (Panoul de jos)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Tcl Console")
                        .font(.caption)
                        .bold()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                    
                    ScrollView {
                        Text(consoleOutput)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(height: 140)
                    .background(Color(NSColor.textBackgroundColor))
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    func runVivadoStyleSimulation() {
        isSimulating = true
        consoleOutput = "launch_simulation...\n"
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let core = VerilogCore()
        
        // Unim conținutul ambelor fișiere ca iverilog să le poată compila împreună!
        let fullCode = filesContent.values.joined(separator: "\n\n")
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Executare iverilog + vvp pe codul combinat
            let log = core.runSimulation(sourceCode: fullCode, directory: tempDirectory)
            
            // Parsare fișier VCD generat
            let vcdURL = tempDirectory.appendingPathComponent("wave.vcd")
            let signals = core.parseVCD(vcdURL: vcdURL)
            
            DispatchQueue.main.async {
                self.consoleOutput += log
                self.parsedSignals = signals
                self.isSimulating = false
                self.selectedTab = 1 // Sare direct la grafic ca în Vivado
            }
        }
    }
}

// --- COMPONENTA CARE DESENEAZĂ UNDE GRAFICE (Rămâne neschimbată) ---
struct RealWaveformViewer: View {
    let signals: [VCDSignal]
    
    var body: some View {
        if signals.isEmpty {
            ContentUnavailableView("No Simulation Data",
                                   systemImage: "waveform.path.badge.minus",
                                   description: Text("Asigură-te că ai rulat simularea și că ai blocul $dumpfile în testbench."))
        } else {
            HSplitView {
                VStack(alignment: .leading, spacing: 40) {
                    ForEach(signals) { sig in
                        Text(sig.name)
                            .font(.system(.body, design: .monospaced))
                            .bold()
                            .foregroundColor(.cyan)
                            .frame(height: 20)
                    }
                    Spacer()
                }
                .padding()
                .frame(width: 120, height: 100, alignment: .topLeading)
                .background(Color(NSColor.windowBackgroundColor))
                
                ScrollView([.horizontal, .vertical]) {
                    Canvas { context, size in
                        var currentYOffset: CGFloat = 20
                        let timeScale: CGFloat = 4.0
                        
                        for sig in signals {
                            var path = Path()
                            guard !sig.timeline.isEmpty else { continue }
                            
                            let firstY = sig.timeline[0].value == 1 ? currentYOffset : currentYOffset + 25
                            path.move(to: CGPoint(x: CGFloat(sig.timeline[0].time) * timeScale, y: firstY))
                            
                            for point in sig.timeline {
                                let nextX = CGFloat(point.time) * timeScale
                                let nextY = point.value == 1 ? currentYOffset : currentYOffset + 25
                                
                                path.addLine(to: CGPoint(x: nextX, y: path.currentPoint?.y ?? nextY))
                                path.addLine(to: CGPoint(x: nextX, y: nextY))
                            }
                            
                            if let lastX = path.currentPoint?.x {
                                path.addLine(to: CGPoint(x: lastX + 100, y: path.currentPoint?.y ?? currentYOffset))
                            }
                            
                            context.stroke(path, with: .color(.green), style: StrokeStyle(lineWidth: 2))
                            currentYOffset += 60
                        }
                    }
                    .frame(width: 1000, height: CGFloat(signals.count * 60) + 40)
                    .padding(.top, 15)
                }
                .background(Color(NSColor.textBackgroundColor))
            }
        }
    }
}
