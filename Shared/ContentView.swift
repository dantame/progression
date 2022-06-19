//
//  ContentView.swift
//  Shared
//
//  Created by Dan Tame on 05/06/2022.
//

import SwiftUI
import AudioKit
import CoreMIDI
import Foundation
import MusicTheory

struct ContentView: View {
    @StateObject var conductor: MidiConductor = MidiConductor()
    @State private var selectedPort1Uid: MIDIUniqueID?
    @State private var selectedPort2Uid: MIDIUniqueID?
    @State private var selectedScaleType: ScaleType = ScaleType.major
    @State private var selectedKey: Key = Key(type: .c) {
        didSet {
            setScale()
            setPitches()
            setChords()
        }
    }
    
    @State private var selectedOctave: Int = 4
    
    @State private var scale: Scale = Scale(type: ScaleType.major, key: Key(type: .c))
    @State private var pitches: [PitchIdentifiable] = Scale(type: ScaleType.major, key: Key(type: .c)).pitches(octaves: [1,2,3,4,5]).map({PitchIdentifiable(pitch: $0)}).reversed()
    
    @State private var chords: [ChordIdentifiable] =
    Scale.HarmonicField.all.flatMap({field in
        Scale(type: ScaleType.major, key: Key(type: .c)).harmonicField(for: field).compactMap({$0 != nil ? ChordIdentifiable(chord: $0) : nil})
    })
    
    struct ScaleTypeIdentifiable: Identifiable {
        let id = UUID()
        let scale: ScaleType
    }
    
    struct KeyIdentifiable: Identifiable {
        let id = UUID()
        let key: Key
    }
    
    struct PitchIdentifiable: Identifiable {
        let id = UUID()
        let pitch: Pitch
    }
    
    struct ChordIdentifiable: Identifiable {
        let id = UUID()
        let chord: Chord?
    }
    
    func setScale() {
        scale = Scale(type: selectedScaleType, key: selectedKey)
    }
    
    func setChords() {
        chords = Scale.HarmonicField.all.flatMap({field in
            scale.harmonicField(for: field).compactMap({$0 != nil ? ChordIdentifiable(chord: $0) : nil})
        })
    }
    
    func setPitches() {
        pitches = scale.pitches(octaves: [1,2,3,4,5]).map({ PitchIdentifiable(pitch: $0)})
    }
    
    var scales: [ScaleTypeIdentifiable] = ScaleType.all.map({ ScaleTypeIdentifiable(scale: $0) })
    var keys: [KeyIdentifiable] = Key.keysWithFlats.map({ KeyIdentifiable(key: $0) })
    
    var pitchColumns: [GridItem] =
    Array(repeating: .init(.fixed(100), spacing: 10), count: 7)
    
    var chordColumns: [GridItem] =
    Array(repeating: .init(.fixed(100), spacing: 10), count: 5)
    
    var body: some View {
        VStack {
            HStack {
                Picker(selection: $selectedPort1Uid, label:
                        Text("Destination Ports:")
                ) {
                    Text("All")
                        .tag(nil as MIDIUniqueID?)
                    ForEach(0..<conductor.destinationNames.count, id: \.self) { index in
                        
                        Text("\(conductor.destinationNames[index])")
                            .tag(conductor.destinationUIDs[index] as MIDIUniqueID?)
                    }
                }.pickerStyle(.segmented)
                Picker(selection: $selectedPort2Uid, label:
                        Text("Virtual Output Ports:")
                ) {
                    Text("All")
                        .tag(nil as MIDIUniqueID?)
                    ForEach(0..<conductor.virtualOutputUIDs.count, id: \.self) { index in
                        Text("\(conductor.virtualOutputNames[index])")
                            .tag(conductor.virtualOutputUIDs[index] as MIDIUniqueID?)
                    }
                }.pickerStyle(.segmented)
            }
            Divider()
            Text("Selected Scale: \(selectedScaleType.description)")
            Picker(selection: $selectedScaleType, label: Text("Scales:")) {
                ForEach(scales) { scale in
                    Text(scale.scale.description).tag(scale.scale)
                }
            }.onChange(of: selectedScaleType) { _ in setScale(); setPitches(); setChords() }
            
            Divider()
            Text("Selected Key: \(selectedKey.description)")
            HStack {
                ForEach(keys) { key in
                    Button(action: { selectedKey = key.key; setPitches() }) {
                        Text(key.key.description).padding().frame(width:75, height: 50).cornerRadius(10.0).foregroundColor(.white).background(Rectangle().fill(.red))
                    }
                    
                }
            }
            Divider()
            HStack {
                
                LazyVGrid(columns: pitchColumns, alignment: .leading, spacing: 10) {
                    ForEach(pitches) { pitch in
                        Button(action: {}) {
                            Text(pitch.pitch.description).multilineTextAlignment(.center).padding().frame(width: 100, height: 100).cornerRadius(10.0).foregroundColor(.white).background(
                                Rectangle().fill(.blue))
                        }
                        .onLongPressGesture(minimumDuration: 0, perform: {}, onPressingChanged: {isPressing in isPressing ? sendMidiDown(pitch: pitch.pitch) : sendMidiUp(pitch: pitch.pitch)})
                    }
                    
                    
                }
                
                LazyVGrid(columns: chordColumns, spacing: 10) {
                    ForEach(chords) { chord in
                        Button(action: { }) {
                            Text(chord.chord!.description).multilineTextAlignment(.center).frame(width: 100, height: 100).cornerRadius(10.0).foregroundColor(.white).background(
                                Rectangle().fill(.green)).font(.system(size: 14))
                        }
                        .onLongPressGesture(minimumDuration: 0, perform: {}, onPressingChanged: {isPressing in isPressing ? sendChordDown(chord: chord.chord!) : sendChordUp(chord: chord.chord!)})
                    }
                    
                }
            }
        }.padding()
        
    }
    
    func sendChordDown(chord: Chord) {
        let pitches = chord.pitches(octave: 2)
        
        for pitch in pitches {
            sendMidiDown(pitch: pitch)
        }
    }
    
    func sendChordUp(chord: Chord) {
        let pitches = chord.pitches(octave: 2)
        
        for pitch in pitches {
            sendMidiUp(pitch: pitch)
        }
    }
    
    func sendMidiDown(pitch: Pitch) {
        let eventToSend = StMIDIEvent(statusType: MIDIStatusType.noteOn.rawValue,
                                      channel: 0,
                                      data1: MIDIByte(pitch.rawValue),
                                      data2: 90)
        if selectedPort1Uid != nil {
            conductor.sendEvent(eventToSend: eventToSend, portIDs: [selectedPort1Uid!])
        } else {
            conductor.sendEvent(eventToSend: eventToSend, portIDs: nil)
        }
    }
    
    func sendMidiUp(pitch: Pitch) {
        let eventToSend = StMIDIEvent(statusType: MIDIStatusType.noteOff.rawValue,
                                      channel: 0,
                                      data1: MIDIByte(pitch.rawValue),
                                      data2: 90)
        if selectedPort1Uid != nil {
            conductor.sendEvent(eventToSend: eventToSend, portIDs: [selectedPort1Uid!])
        } else {
            conductor.sendEvent(eventToSend: eventToSend, portIDs: nil)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .previewDevice("iPad Pro (12.9-inch) (5th generation)")
                .previewInterfaceOrientation(.landscapeLeft)
        }
    }
}
