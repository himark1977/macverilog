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
    
    /// Parses the text content of a file and renames it based on the first declared module name
    func updateFileNameFromModule(for fileId: UUID) {
        guard let content = filesContent[fileId] else { return }
        
        // Regex pattern to capture the first module name declaration
        let pattern = #"module\s+([a-zA-Z_][a-zA-Z0-9_]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)) else {
            return // No module declaration found, leave the filename as is
        }
        
        if let moduleRange = Range(match.range(at: 1), in: content) {
            let moduleName = String(content[moduleRange])
            let targetName = "\(moduleName).v"
            
            // Search inside our groups array to update the exact file object
            for gIdx in 0..<groups.count {
                if let fIdx = groups[gIdx].files.firstIndex(where: { $0.id == fileId }) {
                    // Only update state if the name actually changed to prevent endless UI redraw loops
                    if groups[gIdx].files[fIdx].name != targetName {
                        DispatchQueue.main.async {
                            self.groups[gIdx].files[fIdx].name = targetName
                            print("💡 ProjectManager auto-renamed file to: \(targetName)")
                        }
                    }
                    break
                }
            }
        }
    }
    
    func createNewFile(in type: GroupType) {
        let name = type == .design ? "untitled_design.v" : "untitled_tb.v"
        let newFile = ProjectFile(name: name, icon: "doc.text", type: type)
        
        if let idx = groups.firstIndex(where: { $0.type == type }) {
            groups[idx].files.append(newFile)
            filesContent[newFile.id] = """
            module \(name.replacingOccurrences(of: ".v", with: ""));
                // Hardware code here
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
                    
                    // Run the auto-rename check right after opening in case the module name differs from file name
                    updateFileNameFromModule(for: openedFile.id)
                    
                    return "✅ Open: \(url.lastPathComponent)\n"
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
            return "✅ Saved: \(url.lastPathComponent)\n"
        }
        return nil
    }
    
    func deleteCurrentFile() -> String? {
        guard let idToDelete = self.selectedFileId else {
            return "⚠️ Tcl: No file selected for deletion.\n"
        }
        
        let allFiles = self.groups.flatMap { $0.files }
        guard allFiles.count > 1 else {
            return "⚠️ Tcl: Cannot delete the last remaining file.\n"
        }
        
        let fallbackFile = allFiles.first(where: { $0.id != idToDelete })
        
        self.selectedFileId = nil
        
        var deletedFileName = "file"
        
        let updatedGroups = self.groups.map { group -> ProjectGroup in
            var modifiedGroup = group
            if let index = modifiedGroup.files.firstIndex(where: { $0.id == idToDelete }) {
                deletedFileName = modifiedGroup.files[index].name
                modifiedGroup.files.remove(at: index)
            }
            return modifiedGroup
        }
        
        self.groups = updatedGroups
        self.filesContent.removeValue(forKey: idToDelete)
        
        DispatchQueue.main.async {
            self.selectedFileId = fallbackFile?.id
        }
        
        return "✅ Tcl: Successfully removed \(deletedFileName) from project.\n"
    }
}
