import Foundation
import SwiftUI

enum AppMode: String, CaseIterable {
    case audiobook = "Audiobook"
    case music = "Music"
}

struct AudioTrack: Identifiable, Hashable {
    let id = UUID()
    var fileURL: URL
    
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

struct GlobalMetadata {
    var coverImageData: Data?
    var albumTitle: String = ""
    var albumArtist: String = ""
    var artist: String = ""
    var genre: String = ""
}
