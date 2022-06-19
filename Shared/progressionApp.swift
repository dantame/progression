//
//  progressionApp.swift
//  Shared
//
//  Created by Dan Tame on 05/06/2022.
//

import SwiftUI
import AudioKit
import Foundation
import CoreMIDI

@main
struct progressionApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct StMIDIEvent: Decodable, Encodable {
    var statusType: Int
    var channel: MIDIChannel
    var data1: MIDIByte
    var data2: MIDIByte?
    var portUniqueID: MIDIUniqueID?
}

class MidiConductor: ObservableObject {
    let inputUIDDevelop: Int32 = 1_200_000
    let outputUIDDevelop: Int32 = 1_500_000
    let inputUIDMain: Int32 = 2_200_000
    let outputUIDMain: Int32 = 2_500_000
    let midi = MIDI()
    
    @Published var outputIsOpen: Bool = false {
        didSet {
            print("outputIsOpen: \(outputIsOpen)")
            if outputIsOpen {
                openOutputs()
            } else {
                midi.closeOutput()
            }
        }
    }
    @Published var outputPortIsSwapped: Bool = false
    
    var destinationNames: [String] {
        midi.destinationNames
    }
    var destinationUIDs: [MIDIUniqueID] {
        midi.destinationUIDs
    }
    var destinationInfos: [EndpointInfo] {
        midi.destinationInfos
    }
    var virtualOutputNames: [String] {
        midi.virtualOutputNames
    }
    var virtualOutputUIDs: [MIDIUniqueID] {
        midi.virtualOutputUIDs
    }
    var virtualOutputInfos: [EndpointInfo] {
        midi.virtualOutputInfos
    }
    
    init() {
        //        midi.createVirtualOutputPorts(count: 1, uniqueIDs: [outputUIDDevelop])
        midi.createVirtualOutputPorts(count: 1, uniqueIDs: [outputUIDMain], names: ["Virtual Output Port"])
        openOutputs()
    }
    
    func swapVirtualOutputPorts (withUID uid: [MIDIUniqueID]?) -> [MIDIUniqueID]? {
        if uid != nil {
            if outputPortIsSwapped {
                switch uid {
                case [outputUIDMain]: return [inputUIDMain]
                case [outputUIDDevelop]: return [inputUIDDevelop]
                    
                default:
                    return uid
                }
            }
        }
        return uid
    }
    
    
    func sendEvent(eventToSend event: StMIDIEvent, portIDs: [MIDIUniqueID]?) {
        let portIDs2: [MIDIUniqueID]? = swapVirtualOutputPorts(withUID: portIDs)
        if portIDs2 != nil {
            print("sendEvent, port: \(portIDs2![0].description)")
        }
        switch event.statusType {
        case MIDIStatusType.controllerChange.rawValue:
            //                print("sendEvent controllerChange, port: \(portIDs2![0].description)")
            midi.sendControllerMessage(event.data1,
                                       value: event.data2 ?? 0,
                                       channel: event.channel,
                                       endpointsUIDs: portIDs2)
        case MIDIStatusType.programChange.rawValue:
            //                print("sendEvent programChange, port: \(portIDs2![0].description)")
            midi.sendEvent(MIDIEvent(programChange: event.data1,
                                     channel: event.channel),
                           endpointsUIDs: portIDs2)
        case MIDIStatusType.noteOn.rawValue:
            //                print("sendEvent noteOn, port: \(portIDs2![0].description)")
            midi.sendNoteOnMessage(noteNumber: event.data1,
                                   velocity: event.data2 ?? 0,
                                   channel: event.channel,
                                   endpointsUIDs: portIDs2)
        case MIDIStatusType.noteOff.rawValue:
            //                print("sendEvent noteOn, port: \(portIDs2![0].description)")
            midi.sendNoteOffMessage(noteNumber: event.data1,
                                    channel: event.channel,
                                    endpointsUIDs: portIDs2)
        default:
            // Do Nothing
            ()
        }
    }
    
    func openOutputs () {
        for uid in midi.destinationUIDs {
            midi.openOutput(uid: uid)
        }
        for uid in midi.virtualOutputUIDs {
            midi.openOutput(uid: uid)
        }
    }
}
