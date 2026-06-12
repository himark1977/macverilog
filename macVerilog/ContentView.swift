import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var projectManager = ProjectManager()
    
    @State private var isSimulating = false
    @State private var selectedTab = 0
    @State private var consoleOutput: String = "site:evokzh_lab> ready."
    @State private var parsedSignals: [VCDSignal] = []
    @State private var simulationID = UUID()
    
    private var activeCodeBinding: Binding<String> {
        Binding(
            get: {
                guard let id = projectManager.selectedFileId else { return "Select a file..." }
                return projectManager.filesContent[id] ?? ""
            },
            set: { newValue in
                if let id = projectManager.selectedFileId {
                    projectManager.filesContent[id] = newValue
                    // Dynamic auto-rename the file node in the sidebar based on module declaration
                    projectManager.updateFileNameFromModule(for: id)
                }
            }
        )
    }
    
    var body: some View {
        NavigationSplitView {
            // Vivado-style design hierarchy with expandable folders
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
                        if let log = projectManager.deleteCurrentFile() {
                            consoleOutput += log
                        }
                    }) {
                        Image(systemName: "trash")
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
                // Top toolbar
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
        // Ne asigurăm că utilizatorul are selectat un fișier în sidebar
        guard let selectedId = projectManager.selectedFileId else {
            consoleOutput += "⚠️ Error: Select a tb before begin\n"
            return
        }
        
        isSimulating = true
        consoleOutput = "launch_simulation...\n"
        
        // Reset vizual instantaneu al graficului vechi
        self.parsedSignals = []
        self.simulationID = UUID()
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let core = VerilogCore()
        
        let allFiles = projectManager.groups.flatMap { $0.files }
        let filesMap = projectManager.filesContent
        
        // Găsim fișierul selectat curent în interfață
        guard let currentFile = allFiles.first(where: { $0.id == selectedId }) else { return }
        
        // --- 1. CLEANUP WORKSPACE ---
        if let enumerator = FileManager.default.enumerator(at: tempDirectory, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                let ext = fileURL.pathExtension.lowercased()
                if ext == "v" || ext == "vvp" || ext == "vcd" {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        }
        
        var filesToCompile: [ProjectFile] = []
        
        let designFiles = allFiles.filter { $0.type == .design }
        filesToCompile.append(contentsOf: designFiles)
        
        if currentFile.type == .simulation {
            filesToCompile.append(currentFile)
        } else {
            if let fallbackTB = allFiles.first(where: { $0.type == .simulation }) {
                filesToCompile.append(fallbackTB)
            }
        }
        
        var expectedVCDName = "wave.vcd"
        let codeToScan = filesToCompile.compactMap { filesMap[$0.id] }.joined(separator: "\n\n")
        
        let vcdPattern = #"\$dumpfile\s*\(\s*"([^"]+)"\s*\)"#
        if let regex = try? NSRegularExpression(pattern: vcdPattern, options: []),
           let match = regex.firstMatch(in: codeToScan, options: [], range: NSRange(codeToScan.startIndex..., in: codeToScan)) {
            if let outputRange = Range(match.range(at: 1), in: codeToScan) {
                expectedVCDName = String(codeToScan[outputRange])
                print("🎯 Detected VCD for this run: \(expectedVCDName)")
            }
        }
        
        let dynamicVCDURL = tempDirectory.appendingPathComponent(expectedVCDName)
        
        DispatchQueue.global(qos: .userInitiated).async {
            let log = core.runMultiFileSimulation(projectFiles: filesToCompile, contentMap: filesMap, directory: tempDirectory)
            
            var signals = core.parseVCD(vcdURL: dynamicVCDURL)
            
            if signals.isEmpty {
                if let enumerator = FileManager.default.enumerator(at: tempDirectory, includingPropertiesForKeys: nil) {
                    for case let fileURL as URL in enumerator {
                        if fileURL.pathExtension.lowercased() == "vcd" {
                            signals = core.parseVCD(vcdURL: fileURL)
                            break
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.consoleOutput += log
                self.parsedSignals = signals
                
                if signals.isEmpty {
                    self.consoleOutput += "⚠️ Warning: No simulation signals captured for \(currentFile.name).\n"
                } else {
                    self.consoleOutput += "📈 Successfully loaded \(signals.count) signals for \(currentFile.name).\n"
                }
                
                self.simulationID = UUID()
                self.isSimulating = false
                self.selectedTab = 1
            }
        }
    }
}
