//
//  ProjectModel.swift
//  macVerilog
//
//  Created by Ilie-Adrian Avramescu on 11/06/2026.
//
import Foundation

enum GroupType: String, CaseIterable, Identifiable {
    case design = "Design Sources"
    case simulation = "Simulation Sources"
    
    var id: String { self.rawValue }
    var icon: String {
        self == .design ? "cpu" : "waveform.path.badge.minus"
    }
}

struct ProjectFile: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var icon: String
    var type: GroupType
}

struct ProjectGroup: Identifiable {
    let id = UUID()
    let type: GroupType
    var files: [ProjectFile]
}
