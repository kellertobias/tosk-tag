import Foundation
import SwiftUI

enum AppMode: String, CaseIterable, Sendable {
    case audiobook = "Audiobook"
    case music = "Music"
}

struct AudioTrack: Identifiable, Hashable, Sendable {
    let id = UUID()
    var fileURL: URL
    var codecDetails: AudioCodecDetails = .unknown
    
    var filename: String {
        fileURL.lastPathComponent
    }
    
    // Core fields
    var trackTitle: String = ""
    var trackNumber: Int = 0
    var originalTrackNumber: Int? = nil
    
    // Music fields
    var artist: String = ""
    var composer: String = ""
    var year: String = ""
    var genre: String = ""
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AudioTrack, rhs: AudioTrack) -> Bool {
        lhs.id == rhs.id
    }
}

struct AudioCodecDetails: Hashable, Sendable {
    var channelDescription: String = "Unknown"
    var bitrateMode: String = "Unknown"
    var bitrateKbps: Int?
    var sampleRateHz: Int?
    
    static let unknown = AudioCodecDetails()
    
    var bitrateDescription: String {
        guard let bitrateKbps else { return "Unknown" }
        return "\(bitrateKbps) kbit/s"
    }
    
    var sampleRateDescription: String {
        guard let sampleRateHz else { return "Unknown" }
        let khz = Double(sampleRateHz) / 1000
        return String(format: "%.1f kHz", khz)
    }
}

struct GlobalMetadata: Sendable {
    var coverImageData: Data?
    var albumTitle: String = ""
    var albumArtist: String = ""
    var artist: String = ""
    var genre: String = ""
}
