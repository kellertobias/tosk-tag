import Foundation
import SwiftUI
import ID3TagEditor
import UniformTypeIdentifiers
import AVFoundation

@MainActor
class AppViewModel: ObservableObject {
    @Published var mode: AppMode = .audiobook {
        didSet {
            if mode == .audiobook {
                globalMetadata.genre = "Audiobook"
            }
        }
    }
    
    @Published var tracks: [AudioTrack] = []
    @Published var globalMetadata: GlobalMetadata = GlobalMetadata(genre: "Audiobook")
    @Published var selectedTrackID: UUID?
    @Published var loadingProgress: Double? = nil
    @Published var bakingProgress: Double? = nil
    @Published var targetBitrateKbps: Int? = nil {
        didSet {
            validateTargetBitrate()
        }
    }
    @Published var errorMessage: String? = nil
    private var completedLoads: Int = 0
    private let supportedDownsampleBitrates = [320, 256, 192, 160, 128, 96]
    
    // Audio playback
    @Published var playingTrackID: UUID? = nil
    @Published var volume: Float = 0.5
    private var audioPlayer: AVAudioPlayer? = nil
    
    private let tagEditor = ID3TagEditor()
    
    var availableDownsampleBitrates: [Int] {
        guard let lowestBitrate = lowestLoadedBitrateKbps else { return [] }
        return supportedDownsampleBitrates.filter { $0 < lowestBitrate }
    }
    
    var downsampleHelpText: String {
        guard !tracks.isEmpty else {
            return "Applies to all loaded MP3 files."
        }
        
        guard let lowestBitrate = lowestLoadedBitrateKbps else {
            return "Bitrate is unknown for at least one loaded MP3."
        }
        
        let count = tracks.count == 1 ? "1 loaded MP3" : "\(tracks.count) loaded MP3s"
        if availableDownsampleBitrates.isEmpty {
            return "\(count). No lower preset is available below \(lowestBitrate) kbit/s."
        }
        return "\(count). Downsample applies to every loaded MP3."
    }
    
    private var lowestLoadedBitrateKbps: Int? {
        let bitrates = tracks.compactMap(\.codecDetails.bitrateKbps)
        guard bitrates.count == tracks.count else { return nil }
        return bitrates.min()
    }
    
    func clearAll() {
        stopPlayback()
        tracks.removeAll()
        globalMetadata = GlobalMetadata(genre: mode == .audiobook ? "Audiobook" : "")
        selectedTrackID = nil
        targetBitrateKbps = nil
    }
    
    // MARK: - Audio Playback
    
    func togglePlayback(for track: AudioTrack) {
        if playingTrackID == track.id {
            stopPlayback()
        } else {
            playTrack(track)
        }
    }
    
    private func playTrack(_ track: AudioTrack) {
        stopPlayback()
        do {
            let player = try AVAudioPlayer(contentsOf: track.fileURL)
            player.volume = volume
            player.play()
            audioPlayer = player
            playingTrackID = track.id
        } catch {
            errorMessage = "Failed to play: \(error.localizedDescription)"
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        playingTrackID = nil
    }
    
    func updateVolume(_ newVolume: Float) {
        volume = newVolume
        audioPlayer?.volume = newVolume
    }
    
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        let totalItems = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.mp3.identifier) }.count
        guard totalItems > 0 else { return false }
        
        loadingProgress = 0.0
        self.completedLoads = 0
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.mp3.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.mp3.identifier, options: nil) { item, error in
                    let parsedUrl: URL?
                    if let url = item as? URL {
                        parsedUrl = url
                    } else if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
                        parsedUrl = URL(string: string)
                    } else {
                        parsedUrl = nil
                    }
                    
                    guard let url = parsedUrl else {
                        Task { @MainActor in
                            self.completedLoads += 1
                            self.checkLoadingFinished(total: totalItems)
                        }
                        return
                    }
                    
                    // Parse file data on background thread.
                    let tagEditor = ID3TagEditor()
                    let tag = try? tagEditor.read(from: url.path)
                    let codecDetails = MP3Analyzer.analyze(url: url)
                    
                    Task { @MainActor in
                        self.addTrackWithParsedTag(from: url, tag: tag, codecDetails: codecDetails)
                        self.completedLoads += 1
                        self.loadingProgress = Double(self.completedLoads) / Double(totalItems)
                        self.checkLoadingFinished(total: totalItems)
                    }
                }
            }
        }
        return true
    }
    
    private func checkLoadingFinished(total: Int) {
        if self.completedLoads == total {
            self.loadingProgress = nil
            self.sortByExistingTrackNumbers()
            self.validateTargetBitrate()
        }
    }
    
    func addTrackWithParsedTag(from url: URL, tag: ID3Tag?, codecDetails: AudioCodecDetails = .unknown) {
        guard !tracks.contains(where: { $0.fileURL == url }) else { return }
        
        var track = AudioTrack(fileURL: url)
        track.codecDetails = codecDetails
        track.trackTitle = url.deletingPathExtension().lastPathComponent
        track.trackNumber = tracks.count + 1
        
        if let tag = tag {
            if let title = (tag.frames[.title] as? ID3FrameWithStringContent)?.content {
                track.trackTitle = title
            }
            if let trackPos = (tag.frames[.trackPosition] as? ID3FramePartOfTotal)?.part {
                track.trackNumber = trackPos
                track.originalTrackNumber = trackPos
            }
            if let artist = (tag.frames[.artist] as? ID3FrameWithStringContent)?.content {
                track.artist = artist
            }
            if let composer = (tag.frames[.composer] as? ID3FrameWithStringContent)?.content {
                track.composer = composer
            }
            if let year = (tag.frames[.recordingYear] as? ID3FrameWithIntegerContent)?.value {
                track.year = String(year)
            }
            if let genre = (tag.frames[.genre] as? ID3FrameGenre)?.description {
                track.genre = genre
            }
            
            if tracks.isEmpty {
                if let album = (tag.frames[.album] as? ID3FrameWithStringContent)?.content {
                    globalMetadata.albumTitle = album
                }
                if let albumArtist = (tag.frames[.albumArtist] as? ID3FrameWithStringContent)?.content {
                    globalMetadata.albumArtist = albumArtist
                }
                if mode == .audiobook {
                    if let artist = (tag.frames[.artist] as? ID3FrameWithStringContent)?.content {
                        globalMetadata.artist = artist
                    }
                }
                if let cover = tag.frames[.attachedPicture(.frontCover)] as? ID3FrameAttachedPicture {
                    globalMetadata.coverImageData = cover.picture
                } else if let cover = tag.frames[.attachedPicture(.other)] as? ID3FrameAttachedPicture {
                    globalMetadata.coverImageData = cover.picture
                }
            }
        }
        
        tracks.append(track)
        validateTargetBitrate()
    }
    

    
    /// Sort tracks by their original ID3 track numbers (if present),
    /// then reassign sequential track numbers.
    private func sortByExistingTrackNumbers() {
        let hasExistingNumbers = tracks.contains { $0.originalTrackNumber != nil }
        if hasExistingNumbers {
            tracks.sort {
                ($0.originalTrackNumber ?? Int.max) < ($1.originalTrackNumber ?? Int.max)
            }
        }
        updateTrackNumbers()
    }
    
    func updateTrackNumbers() {
        for i in 0..<tracks.count {
            tracks[i].trackNumber = i + 1
        }
    }
    
    func sortTracks() {
        tracks.sort { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
        updateTrackNumbers()
    }
    
    func moveTracks(from source: IndexSet, to destination: Int) {
        tracks.move(fromOffsets: source, toOffset: destination)
        updateTrackNumbers()
    }
    

    
    func applyAll(field: WritableKeyPath<AudioTrack, String>, value: String) {
        for i in 0..<tracks.count {
            tracks[i][keyPath: field] = value
        }
    }
    
    func setForEmpty(field: WritableKeyPath<AudioTrack, String>, value: String) {
        for i in 0..<tracks.count {
            let current = tracks[i][keyPath: field].trimmingCharacters(in: .whitespacesAndNewlines)
            if current.isEmpty {
                tracks[i][keyPath: field] = value
            }
        }
    }
    
    func bake(rename: Bool = false) {
        validateTargetBitrate()
        
        if let targetBitrateKbps, !canDownsampleAllTracks(to: targetBitrateKbps) {
            errorMessage = "Choose a bitrate lower than every loaded MP3 before baking."
            return
        }
        
        bakingProgress = 0.0
        let currentTracks = tracks
        let currentMode = mode
        let currentGlobal = globalMetadata
        let targetBitrateKbps = targetBitrateKbps
        
        let maxNumber = currentTracks.map { $0.trackNumber }.max() ?? 0
        let padding = maxNumber >= 100 ? 3 : 2
        let formatStr = "%0\(padding)d %@.mp3"
        
        Task.detached {
            do {
                let tagEditor = ID3TagEditor()
                for (index, track) in currentTracks.enumerated() {
                    let builder = ID32v3TagBuilder()
                    
                    if currentMode == .audiobook {
                        _ = builder.title(frame: ID3FrameWithStringContent(content: track.trackTitle))
                        _ = builder.album(frame: ID3FrameWithStringContent(content: currentGlobal.albumTitle))
                        _ = builder.artist(frame: ID3FrameWithStringContent(content: currentGlobal.artist))
                        _ = builder.albumArtist(frame: ID3FrameWithStringContent(content: currentGlobal.albumArtist))
                        _ = builder.genre(frame: ID3FrameGenre(genre: nil, description: "Audiobook"))
                    } else {
                        _ = builder.title(frame: ID3FrameWithStringContent(content: track.trackTitle))
                        _ = builder.album(frame: ID3FrameWithStringContent(content: currentGlobal.albumTitle))
                        _ = builder.artist(frame: ID3FrameWithStringContent(content: track.artist))
                        _ = builder.albumArtist(frame: ID3FrameWithStringContent(content: currentGlobal.albumArtist))
                        _ = builder.composer(frame: ID3FrameWithStringContent(content: track.composer))
                        _ = builder.genre(frame: ID3FrameGenre(genre: nil, description: track.genre))
                        if let yearInt = Int(track.year) {
                            _ = builder.recordingYear(frame: ID3FrameWithIntegerContent(value: yearInt))
                        }
                    }
                    
                    _ = builder.trackPosition(frame: ID3FramePartOfTotal(part: track.trackNumber, total: currentTracks.count))
                    
                    if let coverData = currentGlobal.coverImageData {
                        let isPNG = coverData.prefix(8) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
                        _ = builder.attachedPicture(pictureType: .frontCover, frame: ID3FrameAttachedPicture(picture: coverData, type: .frontCover, format: isPNG ? .png : .jpeg))
                    }
                    
                    let tag = builder.build()
                    let originalURL = track.fileURL
                    var workingURL = originalURL
                    var temporaryURL: URL?
                    
                    if let targetBitrateKbps {
                        guard originalURL.pathExtension.lowercased() == "mp3",
                              let sourceBitrate = track.codecDetails.bitrateKbps,
                              targetBitrateKbps < sourceBitrate else {
                            throw AudioProcessingError.invalidDownsampleTarget(originalURL.lastPathComponent)
                        }
                        
                        let tempName = ".\(originalURL.deletingPathExtension().lastPathComponent)-\(UUID().uuidString).mp3"
                        let tempURL = originalURL.deletingLastPathComponent().appendingPathComponent(tempName)
                        try AudioTranscoder.downsampleMP3(inputURL: originalURL, outputURL: tempURL, bitrateKbps: targetBitrateKbps)
                        workingURL = tempURL
                        temporaryURL = tempURL
                    }
                    
                    try tagEditor.write(tag: tag, to: workingURL.path)
                    
                    var finalURL = originalURL
                    
                    if rename {
                        var cleanName = track.fileURL.deletingPathExtension().lastPathComponent
                        if let range = cleanName.range(of: "^\\d+[\\s\\.-]*", options: .regularExpression) {
                            cleanName.removeSubrange(range)
                        }
                        if cleanName.isEmpty { cleanName = "Track" }
                        
                        let newFilename = String(format: formatStr, track.trackNumber, cleanName)
                        let newURL = track.fileURL.deletingLastPathComponent().appendingPathComponent(newFilename)
                        
                        finalURL = newURL
                    }
                    
                    if let temporaryURL {
                        if finalURL == originalURL {
                            _ = try FileManager.default.replaceItemAt(originalURL, withItemAt: temporaryURL)
                        } else {
                            if FileManager.default.fileExists(atPath: finalURL.path) {
                                throw AudioProcessingError.outputAlreadyExists(finalURL.lastPathComponent)
                            }
                            try FileManager.default.moveItem(at: temporaryURL, to: finalURL)
                            try FileManager.default.removeItem(at: originalURL)
                        }
                    } else if finalURL != originalURL {
                        try FileManager.default.moveItem(at: originalURL, to: finalURL)
                    }
                    
                    let updatedCodecDetails = targetBitrateKbps == nil ? track.codecDetails : MP3Analyzer.analyze(url: finalURL)
                    
                    await MainActor.run {
                        if finalURL != track.fileURL, let realIndex = self.tracks.firstIndex(where: { $0.id == track.id }) {
                            self.tracks[realIndex].fileURL = finalURL
                        }
                        if targetBitrateKbps != nil, let realIndex = self.tracks.firstIndex(where: { $0.id == track.id }) {
                            self.tracks[realIndex].codecDetails = updatedCodecDetails
                        }
                        self.bakingProgress = Double(index + 1) / Double(currentTracks.count)
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to bake/rename: \(error.localizedDescription)"
                }
            }
            
            await MainActor.run {
                self.bakingProgress = nil
            }
        }
    }
    
    private func validateTargetBitrate() {
        guard let targetBitrateKbps else { return }
        if !availableDownsampleBitrates.contains(targetBitrateKbps) {
            self.targetBitrateKbps = nil
        }
    }
    
    private func canDownsampleAllTracks(to bitrateKbps: Int) -> Bool {
        !tracks.isEmpty && tracks.allSatisfy { track in
            track.fileURL.pathExtension.lowercased() == "mp3"
                && track.codecDetails.bitrateKbps.map { bitrateKbps < $0 } == true
        }
    }
}
