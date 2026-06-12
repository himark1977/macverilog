import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    // Injectăm managerul de proiect decuplat
    @StateObject private var projectManager = ProjectManager()
    
    @State private var isSimulating = false
    @State private var selectedTab = 0
    @State private var consoleOutput: String = "site:evokzh_lab> ready."
    @State private var parsedSignals: [VCDSignal] = []
    @State private var simulationID = UUID()
    
    private var activeCodeBinding: Binding<String> {
        Binding(
            get: {
                guard let id = projectManager.selectedFileId else { return "Selectează un fișier..." }
                return projectManager.filesContent[id] ?? ""
            },
            set: { projectManager.filesContent[projectManager.selectedFileId!] = $0 }
        )
    }

    var body: some View {
        NavigationSplitView {
            // Ierarhie stil Vivado cu foldere expandabile
            List(selection: $projectManager.selectedFileId) {
                ForEach(projectManager.groups) { group in
                    Section(header: Label(group.type.rawValue, systemImage: group.type.icon).font(.subheadline).bold()) {
                        ForEach(group.files) { file in
                            NavigationLink(value: file.id) {
                                Label(file.name, systemImage: file.icon)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Hierarchy")
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 15) {
                    Menu {
                        Button("Design Source") { projectManager.createNewFile(in: .design) }
                        Button("Simulation Source") { projectManager.createNewFile(in: .simulation) }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 25)
                    
                    Button(action: {
                        if let log = projectManager.deleteCurrentFile() { consoleOutput += log }
                    }) {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.plain)
                    .disabled(projectManager.groups.flatMap({ $0.files }).count <= 1)
                    
                    Spacer()
                }
                .padding(10)
                .background(Color(NSColor.windowBackgroundColor))
            }
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
            #endif
        } detail: {
            VStack(spacing: 0) {
                // top toolbar
                HStack {
                    HStack(spacing: 12) {
                        Menu {
                            Button("In Design Sources") { if let log = projectManager.openFileFromDisk(into: .design) { consoleOutput += log } }
                            Button("In Simulation Sources") { if let log = projectManager.openFileFromDisk(into: .simulation) { consoleOutput += log } }
                        } label: {
                            Label("Open", systemImage: "doc.badge.plus")
                        }
                        .menuStyle(.borderedButton)
                        
                        Button(action: {
                            if let log = projectManager.saveCurrentFile() { consoleOutput += log }
                        }) {
                            Label("Save As", systemImage: "arrow.down.doc")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    Picker("", selection: $selectedTab) {
                        Text("Text Editor").tag(0)
                        Text("Behavioral Simulation").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                    
                    Spacer()
                    
                    Button(action: runVivadoStyleSimulation) {
                        Label("Run Simulation", systemImage: "play.fill").foregroundColor(.green)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSimulating)
                }
                .padding(8)
                .background(Color(NSColor.windowBackgroundColor))
                
                Divider()
                
                if selectedTab == 0 {
                    MacVerilogEditor(text: activeCodeBinding)
                        .padding(1)
                } else {
                    RealWaveformViewer(signals: parsedSignals)
                        .id(simulationID)
                }
                
                Divider()
                
                // Tcl console
                VStack(alignment: .leading, spacing: 0) {
                    Text("Tcl Console").font(.caption).bold().padding(.horizontal, 10).padding(.vertical, 5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                    
                    ScrollView {
                        Text(consoleOutput).font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                    }
                    .frame(height: 140)
                    .background(Color(NSColor.textBackgroundColor))
                }
            }
        }
    }
    
    func runVivadoStyleSimulation() {
        isSimulating = true
        consoleOutput = "launch_simulation...\n"
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let core = VerilogCore()
        
        // we take all the code for iverilog
        let fullCode = projectManager.filesContent.values.joined(separator: "\n\n")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let log = core.runSimulation(sourceCode: fullCode, directory: tempDirectory)
            let vcdURL = tempDirectory.appendingPathComponent("wave.vcd")
            let signals = core.parseVCD(vcdURL: vcdURL)
            
            DispatchQueue.main.async {
                self.consoleOutput += log
                self.parsedSignals = signals
                self.simulationID = UUID()
                self.isSimulating = false
                self.selectedTab = 1
            }
        }
    }
}
