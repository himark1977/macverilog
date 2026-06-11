//
//  ProjectManager.swift
//  macVerilog
//
//  Created by Ilie-Adrian Avramescu on 11/06/2026.
//
import SwiftUI
import UniformTypeIdentifiers
import Combine

class ProjectManager: NSObject, ObservableObject {
    @Published var groups: [ProjectGroup] = []
    @Published var filesContent: [UUID: String] = [:]
    @Published var selectedFileId: UUID?
    
    override init() {
        super.init()
        setupDefaultProject()
    }
    
    private func setupDefaultProject() {
        let designFile = ProjectFile(name: "counter.v", icon: "doc.text.fill", type: .design)
        let tbFile = ProjectFile(name: "counter_tb.v", icon: "doc.text", type: .simulation)
        
        self.groups = [
            ProjectGroup(type: .design, files: [designFile]),
            ProjectGroup(type: .simulation, files: [tbFile])
        ]
        
        self.selectedFileId = designFile.id
        self.filesContent = [
            designFile.id: """
            // ==========================================
            // DESIGN SOURCE (counter.v)
            // ==========================================
            module counter(input clk, input rst, output reg [3:0] out);
                always @(posedge clk or posedge rst) begin
                    if (rst) out <= 4'b0000;
                    else out <= out + 1;
                end
            endmodule
            """,
            tbFile.id: """
            // ==========================================
            // SIMULATION SOURCE (counter_tb.v)
            // ==========================================
            module sim_top;
                reg clk;
                reg rst;
                wire [3:0] out;
                
                counter uut (.clk(clk), .rst(rst), .out(out));
                
                initial begin
                    $dumpfile("wave.vcd");
                    $dumpvars(0, sim_top);
                    clk = 0; rst = 1;
                    #15 rst = 0;
                    #120 $finish;
                end
                always #5 clk = ~clk;
            endmodule
            """
        ]
    }
    
    func createNewFile(in type: GroupType) {
        let name = type == .design ? "untitled_design.v" : "untitled_tb.v"
        let newFile = ProjectFile(name: name, icon: "doc.text", type: type)
        
        if let idx = groups.firstIndex(where: { $0.type == type }) {
            groups[idx].files.append(newFile)
            filesContent[newFile.id] = """
            module \(name.replacingOccurrences(of: ".v", with: ""));
                // Cod hardware aici
            endmodule
            """
            selectedFileId = newFile.id
        }
    }
    
    func openFileFromDisk(into type: GroupType) -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.text, .data]
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                let openedFile = ProjectFile(name: url.lastPathComponent, icon: "doc.text.fill", type: type)
                if let idx = groups.firstIndex(where: { $0.type == type }) {
                    groups[idx].files.append(openedFile)
                    filesContent[openedFile.id] = content
                    selectedFileId = openedFile.id
                    return "✅ Deschis: \(url.lastPathComponent)\n"
                }
            }
        }
        return nil
    }
    
    func saveCurrentFile() -> String? {
        guard let currentId = selectedFileId,
              let allFiles = groups.flatMap({ $0.files }).first(where: { $0.id == currentId }),
              let content = filesContent[currentId] else { return nil }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.text]
        panel.nameFieldStringValue = allFiles.name
        
        if panel.runModal() == .OK, let url = panel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
            
            for gIdx in 0..<groups.count {
                if let fIdx = groups[gIdx].files.firstIndex(where: { $0.id == currentId }) {
                    groups[gIdx].files[fIdx].name = url.lastPathComponent
                }
            }
            return "✅ Salvat: \(url.lastPathComponent)\n"
        }
        return nil
    }
    
    func deleteCurrentFile() -> String? {
        guard let currentId = selectedFileId else { return nil }
        let totalFiles = groups.flatMap { $0.files }.count
        guard totalFiles > 1 else { return "⚠️ Nu poți șterge ultimul fișier.\n" }
        
        for idx in 0..<groups.count {
            if let fIdx = groups[idx].files.firstIndex(where: { $0.id == currentId }) {
                groups[idx].files.remove(at: fIdx)
                filesContent.removeValue(forKey: currentId)
                selectedFileId = groups.flatMap({ $0.files }).first?.id
                return "🗑️ Fișier eliminat.\n"
            }
        }
        return nil
    }
}
