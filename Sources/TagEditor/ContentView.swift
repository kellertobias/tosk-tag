import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    
    var body: some View {
        NavigationSplitView {
            // LEFT PANE: Track List
            VStack(spacing: 0) {
                HStack {
                    Text("Tracks (\(viewModel.tracks.count))")
                        .font(.headline)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.fill")
                            .foregroundColor(.secondary)
                            .font(.caption2)
                        Slider(value: Binding(
                            get: { viewModel.volume },
                            set: { viewModel.updateVolume($0) }
                        ), in: 0...1)
                        .frame(width: 80)
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.secondary)
                            .font(.caption2)
                    }
                    Button("Sort") {
                        viewModel.sortTracks()
                    }
                    .disabled(viewModel.tracks.isEmpty)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)
                
                if let progress = viewModel.loadingProgress {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView("Loading...", value: progress, total: 1.0)
                            .progressViewStyle(.linear)
                            .frame(width: 150)
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else if viewModel.tracks.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Drag files to start")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    List(selection: $viewModel.selectedTrackID) {
                        ForEach(viewModel.tracks) { track in
                            HStack {
                                Text("\(track.trackNumber).")
                                    .foregroundColor(.secondary)
                                    .frame(width: 24, alignment: .trailing)
                                Text(track.filename)
                                    .lineLimit(1)
                                Spacer()
                                Button(action: {
                                    viewModel.togglePlayback(for: track)
                                }) {
                                    Image(systemName: viewModel.playingTrackID == track.id ? "stop.fill" : "play.fill")
                                        .foregroundColor(viewModel.playingTrackID == track.id ? .red : .accentColor)
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                            }
                            .tag(track.id)
                        }
                        .onMove(perform: viewModel.moveTracks)
                    }
                }
            }
            .onDrop(of: [UTType.fileURL.identifier, UTType.mp3.identifier], isTargeted: nil, perform: viewModel.handleDrop)
            .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        } detail: {
            // RIGHT PANE: Metadata Editor
            VStack {
                Picker("Mode", selection: $viewModel.mode) {
                    ForEach(AppMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        GlobalMetadataSection(viewModel: viewModel)
                        
                        Divider()
                        
                        TrackMetadataSection(viewModel: viewModel)
                    }
                    .padding()
                }
                
                Spacer()
                
                HStack {
                    Button(role: .destructive, action: viewModel.clearAll) {
                        Text("Clear All")
                    }
                    Spacer()
                    if let progress = viewModel.bakingProgress {
                        ProgressView("Baking...", value: progress, total: 1.0)
                            .progressViewStyle(.linear)
                            .frame(width: 150)
                            .padding(.trailing, 8)
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        if viewModel.mode == .audiobook {
                            Button(action: { viewModel.bake(rename: true) }) {
                                Text("Bake & Rename")
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.tracks.isEmpty)
                        }
                        
                        Button(action: { viewModel.bake(rename: false) }) {
                            Text("Bake to Files")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.tracks.isEmpty)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .alert(isPresented: .constant(viewModel.errorMessage != nil)) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.errorMessage ?? ""),
                dismissButton: .default(Text("OK")) {
                    viewModel.errorMessage = nil
                }
            )
        }
    }
}

struct GlobalMetadataSection: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Album Fields", systemImage: "square.stack")
                .font(.headline)
            Text("Applied to all tracks")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .top, spacing: 20) {
                // Cover Image
                ZStack {
                    if let data = viewModel.globalMetadata.coverImageData, let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                        VStack(spacing: 4) {
                            Image(systemName: "photo")
                                .font(.title2)
                            Text("Drop Cover")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .frame(width: 120, height: 120)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                .onDrop(of: [UTType.image.identifier, UTType.fileURL.identifier], isTargeted: nil) { providers in
                    for provider in providers {
                        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                                if let data = data {
                                    DispatchQueue.main.async {
                                        viewModel.globalMetadata.coverImageData = data
                                    }
                                }
                            }
                            return true
                        } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                                if let data = item as? Data, let urlString = String(data: data, encoding: .utf8), let url = URL(string: urlString) {
                                    if let imageData = try? Data(contentsOf: url) {
                                        DispatchQueue.main.async {
                                            viewModel.globalMetadata.coverImageData = imageData
                                        }
                                    }
                                }
                            }
                            return true
                        }
                    }
                    return false
                }
                
                VStack(spacing: 8) {
                    if viewModel.mode == .audiobook {
                        LabeledRow(label: "Book Title", idTag: "Album", text: $viewModel.globalMetadata.albumTitle)
                        LabeledRow(label: "Author", idTag: "Artist", text: $viewModel.globalMetadata.artist)
                        LabeledRow(label: "Narrator", idTag: "Album Artist", text: $viewModel.globalMetadata.albumArtist)
                        HStack {
                            Text("Genre")
                                .frame(width: 80, alignment: .trailing)
                                .foregroundColor(.primary)
                            Text("Audiobook")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("ID3: Genre")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    } else {
                        LabeledRow(label: "Album", idTag: "Album", text: $viewModel.globalMetadata.albumTitle)
                        LabeledRow(label: "Album Artist", idTag: "Album Artist", text: $viewModel.globalMetadata.albumArtist)
                    }
                    
                    Divider()
                    
                    DownsampleAllControl(viewModel: viewModel)
                }
            }
        }
    }
}

struct DownsampleAllControl: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        HStack(alignment: .top) {
            Text("Downsample")
                .frame(width: 80, alignment: .trailing)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 4) {
                Menu {
                    Button("Keep original bitrate") {
                        viewModel.targetBitrateKbps = nil
                    }
                    
                    ForEach(viewModel.availableDownsampleBitrates, id: \.self) { bitrate in
                        Button("\(bitrate) kbit/s") {
                            viewModel.targetBitrateKbps = bitrate
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedDownsampleTitle)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 210, alignment: .leading)
                }
                .menuStyle(.button)
                
                Text(viewModel.downsampleHelpText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .disabled(viewModel.tracks.isEmpty || viewModel.bakingProgress != nil)
    }
    
    private var selectedDownsampleTitle: String {
        guard let bitrate = viewModel.targetBitrateKbps else {
            return "Keep original bitrate"
        }
        return "\(bitrate) kbit/s"
    }
}

struct TrackMetadataSection: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Track Fields", systemImage: "music.note")
                .font(.headline)
            Text("Applied to selected track only")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let selectedID = viewModel.selectedTrackID,
               let index = viewModel.tracks.firstIndex(where: { $0.id == selectedID }) {
                
                let trackBinding = $viewModel.tracks[index]
                let track = viewModel.tracks[index]
                
                VStack(spacing: 10) {
                    HStack {
                        Text(track.filename)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Track #\(track.trackNumber) of \(viewModel.tracks.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    CodecDetailsView(details: track.codecDetails)
                    
                    Divider()
                    
                    if viewModel.mode == .audiobook {
                        LabeledRow(label: "Chapter", idTag: "Title", text: trackBinding.trackTitle)
                    } else {
                        LabeledRow(label: "Title", idTag: "Title", text: trackBinding.trackTitle)
                        
                        MusicFieldRow(label: "Year", idTag: "Year", text: trackBinding.year) {
                            viewModel.applyAll(field: \.year, value: track.year)
                        } setEmptyAction: {
                            viewModel.setForEmpty(field: \.year, value: track.year)
                        }
                        
                        MusicFieldRow(label: "Genre", idTag: "Genre", text: trackBinding.genre) {
                            viewModel.applyAll(field: \.genre, value: track.genre)
                        } setEmptyAction: {
                            viewModel.setForEmpty(field: \.genre, value: track.genre)
                        }
                        
                        MusicFieldRow(label: "Artist", idTag: "Artist", text: trackBinding.artist) {
                            viewModel.applyAll(field: \.artist, value: track.artist)
                        } setEmptyAction: {
                            viewModel.setForEmpty(field: \.artist, value: track.artist)
                        }
                        
                        MusicFieldRow(label: "Composer", idTag: "Composer", text: trackBinding.composer) {
                            viewModel.applyAll(field: \.composer, value: track.composer)
                        } setEmptyAction: {
                            viewModel.setForEmpty(field: \.composer, value: track.composer)
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                
            } else {
                Text(viewModel.mode == .music ? "select a track to show all tags" : "Select a track to edit its properties.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }
}

struct CodecDetailsView: View {
    let details: AudioCodecDetails
    
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            GridRow {
                Text("Channels")
                    .foregroundColor(.secondary)
                Text(details.channelDescription)
            }
            GridRow {
                Text("Bitrate")
                    .foregroundColor(.secondary)
                Text("\(details.bitrateDescription) \(details.bitrateMode == "Unknown" ? "" : "(\(details.bitrateMode))")")
            }
            GridRow {
                Text("Sample Rate")
                    .foregroundColor(.secondary)
                Text(details.sampleRateDescription)
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LabeledRow: View {
    let label: String
    let idTag: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .trailing)
                .foregroundColor(.primary)
            TextField("", text: $text)
            Text("ID3: \(idTag)")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
        }
    }
}

struct MusicFieldRow: View {
    let label: String
    let idTag: String
    @Binding var text: String
    let applyAllAction: () -> Void
    let setEmptyAction: () -> Void
    
    var body: some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .trailing)
                .foregroundColor(.primary)
            TextField("", text: $text)
            Text("ID3: \(idTag)")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
            Button("Apply All", action: applyAllAction)
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundColor(.accentColor)
            Button("Set Empty", action: setEmptyAction)
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundColor(.accentColor)
        }
    }
}
