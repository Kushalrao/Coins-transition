//
//  RiveInspect.swift
//  Vacations
//
//  Debug helper: enumerates a bundled .riv's artboards, animations, state
//  machines, and state-machine inputs so we know what can be driven at
//  runtime. Logs lines prefixed "RIVE_INSPECT".
//

import Foundation
import RiveRuntime

enum RiveInspector {
    static func inspect(_ resource: String) {
        print("RIVE_INSPECT ===== \(resource).riv =====")
        guard let file = try? RiveFile(resource: resource, loadCdn: false) else {
            print("RIVE_INSPECT load FAILED")
            return
        }
        let artboards = file.artboardNames()
        print("RIVE_INSPECT artboards: \(artboards)")
        for ab in artboards {
            guard let artboard = try? file.artboard(fromName: ab) else {
                print("RIVE_INSPECT [\(ab)] could not open")
                continue
            }
            print("RIVE_INSPECT [\(ab)] animations: \(artboard.animationNames())")
            let sms = artboard.stateMachineNames()
            print("RIVE_INSPECT [\(ab)] stateMachines: \(sms)")
            for sm in sms {
                guard let smi = try? artboard.stateMachine(fromName: sm) else { continue }
                var inputs: [String] = []
                for i in 0..<smi.inputCount() {
                    if let inp = try? smi.input(from: i) {
                        let type = inp.isBoolean() ? "bool" : (inp.isTrigger() ? "trigger" : "number")
                        inputs.append("\(inp.name())[\(type)]")
                    }
                }
                print("RIVE_INSPECT [\(ab)/\(sm)] inputs: \(inputs)")
            }
        }
        print("RIVE_INSPECT ===== end =====")
    }
}
