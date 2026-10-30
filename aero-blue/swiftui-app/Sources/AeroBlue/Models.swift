import Foundation

struct WeatherSettings: Codable {
    var city = ""
    var latitude: Double? = nil
    var longitude: Double? = nil
    var units = "celsius"

    enum CodingKeys: String, CodingKey { case city, latitude, longitude, units }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(city, forKey: .city)
        try values.encode(units, forKey: .units)
        if let latitude { try values.encode(latitude, forKey: .latitude) } else { try values.encodeNil(forKey: .latitude) }
        if let longitude { try values.encode(longitude, forKey: .longitude) } else { try values.encodeNil(forKey: .longitude) }
    }
}

struct WeatherCity: Decodable, Identifiable {
    var city: String
    var country: String
    var region: String
    var latitude: Double
    var longitude: Double
    var id: String { "\(latitude),\(longitude)" }
    var label: String { [city, region, country].filter { !$0.isEmpty }.joined(separator: ", ") }
}

struct DockSettings: Codable {
    var tilesize = 48
    var magnification = false
    var autohide = false
}

struct WidgetSettings: Codable {
    var enabled = false
    var x: Int = 32
    var y: Int = 32
    var width: Int = 280
}

struct Permissions: Codable {
    var music = false
    var calendar = false
}

struct ThemeSettings: Codable {
    var enabled = false
    var preset = "pure-aero"
    var wallpaper = "aero-sky-light"
    var animations = true
    var menuBar = false
    var clock24h = true
    var weather = WeatherSettings()
    var dock = DockSettings()
    var permissions = Permissions()
    var widgets = Dictionary(uniqueKeysWithValues: WidgetKind.allCases.map { ($0.rawValue, WidgetSettings()) })

    enum CodingKeys: String, CodingKey {
        case enabled, preset, wallpaper, animations, menuBar, clock24h, weather, dock, permissions, widgets
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        preset = try values.decodeIfPresent(String.self, forKey: .preset) ?? "pure-aero"
        wallpaper = try values.decodeIfPresent(String.self, forKey: .wallpaper) ?? "aero-sky-light"
        animations = try values.decodeIfPresent(Bool.self, forKey: .animations) ?? true
        menuBar = try values.decodeIfPresent(Bool.self, forKey: .menuBar) ?? false
        clock24h = try values.decodeIfPresent(Bool.self, forKey: .clock24h) ?? true
        weather = try values.decodeIfPresent(WeatherSettings.self, forKey: .weather) ?? WeatherSettings()
        dock = try values.decodeIfPresent(DockSettings.self, forKey: .dock) ?? DockSettings()
        permissions = try values.decodeIfPresent(Permissions.self, forKey: .permissions) ?? Permissions()
        widgets = try values.decodeIfPresent([String: WidgetSettings].self, forKey: .widgets) ?? widgets
    }
}

enum WidgetKind: String, CaseIterable, Identifiable {
    case clock, weather, system, music, calendar, productivity
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .clock: return "clock"
        case .weather: return "cloud.sun"
        case .system: return "gauge.medium"
        case .music: return "music.note"
        case .calendar: return "calendar"
        case .productivity: return "checklist"
        }
    }
}

struct AssetManifest: Decodable {
    var wallpapers: [WallpaperAsset]
    var icons: [IconAsset]
    var cursors: [CursorAsset]
    static let empty = AssetManifest(wallpapers: [], icons: [], cursors: [])
}

struct WallpaperAsset: Decodable, Identifiable {
    let id: String
    let title: String
    let variant: String
    let file: String
    let thumbnail: String
    let width: Int
    let height: Int
}

struct IconAsset: Decodable, Identifiable {
    let id: String
    let title: String
    let file: String
    let icns: String?
}

struct CursorAsset: Decodable, Identifiable {
    let id: String
    let title: String
    let file: String
    let retina: String
    let hotspot: [Double]
}

enum ThemePreset: String, CaseIterable, Identifiable {
    case pureAero = "pure-aero"
    case aquaMinimal = "aqua-minimal"
    case crystalOcean = "crystal-ocean"
    case skyBlueElegance = "sky-blue-elegance"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .pureAero: return "Pure Aero"
        case .aquaMinimal: return "Aqua Minimal"
        case .crystalOcean: return "Crystal Ocean"
        case .skyBlueElegance: return "Sky Blue Elegance"
        }
    }
    var detail: String {
        switch self {
        case .pureAero: return "Bright sky, crystal surfaces, a classic Aqua mood."
        case .aquaMinimal: return "A quiet desktop with restrained motion and a compact Dock."
        case .crystalOcean: return "Clear water, deep blues and soft reflected light."
        case .skyBlueElegance: return "An airy sky and generous space for your work."
        }
    }
}

enum ControlSection: String, CaseIterable, Identifiable {
    case overview = "Overview", wallpapers = "Wallpapers", icons = "Crystal Icons", cursors = "Crystal Cursor"
    case widgets = "Desktop Widgets", dock = "Dock & Menu Bar", preferences = "Preferences"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: return "drop.fill"
        case .wallpapers: return "photo.on.rectangle.angled"
        case .icons: return "square.grid.2x2"
        case .cursors: return "cursorarrow"
        case .widgets: return "rectangle.3.group"
        case .dock: return "dock.rectangle"
        case .preferences: return "slider.horizontal.3"
        }
    }
}
