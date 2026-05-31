import Foundation

enum AudioProcessingError: LocalizedError {
    case downsampleEncoderUnavailable
    case downsampleFailed(String)
    case invalidDownsampleTarget(String)
    case outputAlreadyExists(String)
    
    var errorDescription: String? {
        switch self {
        case .downsampleEncoderUnavailable:
            return """
            Downsampling requires an external MP3 encoder, but neither lame nor ffmpeg was found.

            Install one with Homebrew, then try again:
            brew install lame
            """
        case .downsampleFailed(let message):
            return message.isEmpty ? "MP3 downsampling failed." : message
        case .invalidDownsampleTarget(let filename):
            return "\(filename) cannot be downsampled to the selected bitrate."
        case .outputAlreadyExists(let filename):
            return "A file named \(filename) already exists."
        }
    }
}

struct MP3Analyzer {
    private struct Frame {
        let bitrateKbps: Int
        let sampleRateHz: Int
        let channelMode: Int
        let version: Int
        let frameStart: Int
        let frameLength: Int
    }
    
    static func analyze(url: URL) -> AudioCodecDetails {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            return .unknown
        }
        
        var offset = id3v2Size(in: data)
        var frames: [Frame] = []
        frames.reserveCapacity(128)
        
        while offset + 4 <= data.count, frames.count < 600 {
            if let frame = frame(at: offset, in: data) {
                frames.append(frame)
                offset += max(frame.frameLength, 1)
            } else {
                offset += 1
            }
        }
        
        guard let firstFrame = frames.first else { return .unknown }
        
        let bitrates = Set(frames.map(\.bitrateKbps))
        let hasVBRHeader = hasVariableBitrateHeader(firstFrame: firstFrame, data: data)
        let bitrateMode: String
        if hasVBRHeader || bitrates.count > 1 {
            bitrateMode = "VBR"
        } else {
            bitrateMode = "CBR"
        }
        
        let bitrate: Int?
        if bitrateMode == "CBR" {
            bitrate = firstFrame.bitrateKbps
        } else if !frames.isEmpty {
            bitrate = Int((Double(frames.map(\.bitrateKbps).reduce(0, +)) / Double(frames.count)).rounded())
        } else {
            bitrate = nil
        }
        
        return AudioCodecDetails(
            channelDescription: channelDescription(for: firstFrame.channelMode),
            bitrateMode: bitrateMode,
            bitrateKbps: bitrate,
            sampleRateHz: firstFrame.sampleRateHz
        )
    }
    
    private static func id3v2Size(in data: Data) -> Int {
        guard data.count >= 10,
              data[0] == 0x49, data[1] == 0x44, data[2] == 0x33 else {
            return 0
        }
        
        let size = (Int(data[6] & 0x7F) << 21)
            | (Int(data[7] & 0x7F) << 14)
            | (Int(data[8] & 0x7F) << 7)
            | Int(data[9] & 0x7F)
        return 10 + size
    }
    
    private static func frame(at offset: Int, in data: Data) -> Frame? {
        guard offset + 4 <= data.count else { return nil }
        
        let b0 = data[offset]
        let b1 = data[offset + 1]
        let b2 = data[offset + 2]
        let b3 = data[offset + 3]
        
        guard b0 == 0xFF, (b1 & 0xE0) == 0xE0 else { return nil }
        
        let version = Int((b1 >> 3) & 0x03)
        let layer = Int((b1 >> 1) & 0x03)
        let bitrateIndex = Int((b2 >> 4) & 0x0F)
        let sampleRateIndex = Int((b2 >> 2) & 0x03)
        let padding = Int((b2 >> 1) & 0x01)
        let channelMode = Int((b3 >> 6) & 0x03)
        
        guard version != 1, layer == 1, bitrateIndex > 0, bitrateIndex < 15, sampleRateIndex < 3 else {
            return nil
        }
        
        let bitrateKbps = bitrate(version: version, index: bitrateIndex)
        let sampleRateHz = sampleRate(version: version, index: sampleRateIndex)
        guard bitrateKbps > 0, sampleRateHz > 0 else { return nil }
        
        let coefficient = version == 3 ? 144_000 : 72_000
        let frameLength = coefficient * bitrateKbps / sampleRateHz + padding
        guard frameLength > 4, offset + frameLength <= data.count else { return nil }
        
        return Frame(
            bitrateKbps: bitrateKbps,
            sampleRateHz: sampleRateHz,
            channelMode: channelMode,
            version: version,
            frameStart: offset,
            frameLength: frameLength
        )
    }
    
    private static func bitrate(version: Int, index: Int) -> Int {
        let mpeg1Layer3 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0]
        let mpeg2Layer3 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0]
        return version == 3 ? mpeg1Layer3[index] : mpeg2Layer3[index]
    }
    
    private static func sampleRate(version: Int, index: Int) -> Int {
        switch version {
        case 3:
            return [44_100, 48_000, 32_000][index]
        case 2:
            return [22_050, 24_000, 16_000][index]
        default:
            return [11_025, 12_000, 8_000][index]
        }
    }
    
    private static func channelDescription(for channelMode: Int) -> String {
        switch channelMode {
        case 3:
            return "Mono"
        case 1:
            return "Joint stereo"
        case 2:
            return "Dual channel"
        default:
            return "Stereo"
        }
    }
    
    private static func hasVariableBitrateHeader(firstFrame: Frame, data: Data) -> Bool {
        let sideInfoSize: Int
        if firstFrame.version == 3 {
            sideInfoSize = firstFrame.channelMode == 3 ? 17 : 32
        } else {
            sideInfoSize = firstFrame.channelMode == 3 ? 9 : 17
        }
        
        let xingOffset = firstFrame.frameStart + 4 + sideInfoSize
        if data.matchesASCII("Xing", at: xingOffset) {
            return true
        }
        if data.matchesASCII("Info", at: xingOffset) {
            return false
        }
        
        let vbriOffset = firstFrame.frameStart + 36
        return data.matchesASCII("VBRI", at: vbriOffset)
    }
}

struct AudioTranscoder {
    private enum Encoder {
        case lame(URL)
        case ffmpeg(URL)
        
        var name: String {
            switch self {
            case .lame: return "lame"
            case .ffmpeg: return "ffmpeg"
            }
        }
        
        var executableURL: URL {
            switch self {
            case .lame(let url), .ffmpeg(let url):
                return url
            }
        }
        
        func arguments(inputURL: URL, outputURL: URL, bitrateKbps: Int) -> [String] {
            switch self {
            case .lame:
                return [
                    "--silent",
                    "--cbr",
                    "-b", "\(bitrateKbps)",
                    inputURL.path,
                    outputURL.path
                ]
            case .ffmpeg:
                return [
                    "-y",
                    "-hide_banner",
                    "-loglevel", "error",
                    "-i", inputURL.path,
                    "-vn",
                    "-codec:a", "libmp3lame",
                    "-b:a", "\(bitrateKbps)k",
                    "-map_metadata", "-1",
                    outputURL.path
                ]
            }
        }
    }
    
    static func downsampleMP3(inputURL: URL, outputURL: URL, bitrateKbps: Int) throws {
        let encoders = availableEncoders()
        guard !encoders.isEmpty else {
            throw AudioProcessingError.downsampleEncoderUnavailable
        }
        
        var failureMessages: [String] = []
        for encoder in encoders {
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }
            
            do {
                try run(encoder: encoder, inputURL: inputURL, outputURL: outputURL, bitrateKbps: bitrateKbps)
                return
            } catch {
                failureMessages.append("\(encoder.name): \(error.localizedDescription)")
            }
        }
        
        throw AudioProcessingError.downsampleFailed(failureMessages.joined(separator: "\n"))
    }
    
    private static func run(encoder: Encoder, inputURL: URL, outputURL: URL, bitrateKbps: Int) throws {
        let process = Process()
        process.executableURL = encoder.executableURL
        process.arguments = encoder.arguments(inputURL: inputURL, outputURL: outputURL, bitrateKbps: bitrateKbps)
        
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? ""
            throw AudioProcessingError.downsampleFailed(message)
        }
    }
    
    private static func availableEncoders() -> [Encoder] {
        var encoders: [Encoder] = []
        if let lameURL = findExecutable(named: "lame") {
            encoders.append(.lame(lameURL))
        }
        if let ffmpegURL = findExecutable(named: "ffmpeg") {
            encoders.append(.ffmpeg(ffmpegURL))
        }
        return encoders
    }
    
    private static func findExecutable(named name: String) -> URL? {
        let searchPaths = executableSearchPaths()
        for directory in searchPaths {
            let path = URL(fileURLWithPath: directory).appendingPathComponent(name).path
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }
    
    private static func executableSearchPaths() -> [String] {
        let environmentPaths = ProcessInfo.processInfo.environment["PATH"]?
            .split(separator: ":")
            .map(String.init) ?? []
        let commonPaths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/opt/local/bin",
            "/usr/bin",
            "/bin"
        ]
        
        var seen = Set<String>()
        return (environmentPaths + commonPaths).filter { path in
            guard !seen.contains(path) else { return false }
            seen.insert(path)
            return true
        }
    }
}

private extension Data {
    func matchesASCII(_ string: String, at offset: Int) -> Bool {
        guard offset >= 0 else { return false }
        let bytes = Array(string.utf8)
        guard offset + bytes.count <= count else { return false }
        return bytes.enumerated().allSatisfy { index, byte in
            self[offset + index] == byte
        }
    }
}
