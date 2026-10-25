// Dynamic wallpapers (HEIC files with several pictures, such as Catalina or Mojave) change picture as the day goes on.
// The file says which picture belongs to which sun position, time of day or appearance. This picks the one for now,
// so the cloth shows the same scene as the desktop underneath.
import AppKit
import ImageIO

struct DynamicWallpaper {
    private enum Schedule {
        case solar([(altitude: Double, azimuth: Double, index: Int)]) // apple_desktop:solar
        case timeOfDay([(fraction: Double, index: Int)])               // apple_desktop:h24
        case appearance(light: Int, dark: Int)                          // apple_desktop:apr
    }

    private let schedule: Schedule

    // Nil for an ordinary, single picture.
    init?(source: CGImageSource) {
        guard CGImageSourceGetCount(source) > 1,
              let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil),
              let tags = CGImageMetadataCopyTags(metadata) as? [CGImageMetadataTag] else { return nil }
        for tag in tags where CGImageMetadataTagCopyPrefix(tag) as String? == "apple_desktop" {
            guard let name = CGImageMetadataTagCopyName(tag) as String?,
                  let base64 = CGImageMetadataTagCopyValue(tag) as? String,
                  let data = Data(base64Encoded: base64),
                  let plist = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
            else { continue }
            switch name {
            case "solar":
                let samples = (plist["si"] as? [[String: Any]] ?? []).compactMap { sample -> (Double, Double, Int)? in
                    guard let a = number(sample["a"]), let z = number(sample["z"]), let i = number(sample["i"]) else { return nil }
                    return (a, z, Int(i))
                }
                if !samples.isEmpty { schedule = .solar(samples); return }
            case "h24":
                let samples = (plist["ti"] as? [[String: Any]] ?? []).compactMap { sample -> (Double, Int)? in
                    guard let t = number(sample["t"]), let i = number(sample["i"]) else { return nil }
                    return (t, Int(i))
                }
                if !samples.isEmpty { schedule = .timeOfDay(samples.sorted { $0.0 < $1.0 }); return }
            case "apr":
                if let light = number(plist["l"]), let dark = number(plist["d"]) {
                    schedule = .appearance(light: Int(light), dark: Int(dark))
                    return
                }
            default:
                continue
            }
        }
        return nil
    }

    // The picture to show at this moment.
    func index(at date: Date = Date(), dark: Bool) -> Int {
        switch schedule {
        case .appearance(let light, let darkIndex):
            return dark ? darkIndex : light
        case .timeOfDay(let samples):
            // The latest entry at or before now; before the first one, the last entry of the day before.
            let fraction = date.timeIntervalSince(Calendar.current.startOfDay(for: date)) / 86400
            return (samples.last { $0.fraction <= fraction } ?? samples.last!).index
        case .solar(let samples):
            // The picture whose sun position is nearest the sun's position now.
            let sun = Sun.position(at: date)
            return samples.min { Sun.angle(sun, ($0.altitude, $0.azimuth)) < Sun.angle(sun, ($1.altitude, $1.azimuth)) }!.index
        }
    }
}

// The values are numbers, or strings for negative ones.
private func number(_ value: Any?) -> Double? {
    (value as? NSNumber)?.doubleValue ?? (value as? String).flatMap(Double.init)
}

// Where the sun is in the sky, in degrees: altitude above the horizon, azimuth clockwise from north.
enum Sun {
    typealias Position = (altitude: Double, azimuth: Double)

    // desktopcloth doesn't ask for your location: the reference city of your time zone stands in for it,
    // from macOS's time zone list (for Asia/Tokyo, Tokyo). Unknown zones use the zone's offset for longitude.
    static let home: (latitude: Double, longitude: Double) = {
        let zone = TimeZone.current.identifier
        let table = (try? String(contentsOfFile: "/usr/share/zoneinfo/zone.tab", encoding: .utf8)) ?? ""
        for line in table.split(separator: "\n") where !line.hasPrefix("#") {
            let fields = line.split(separator: "\t")
            if fields.count >= 3, fields[2] == zone, let coordinate = parse(String(fields[1])) { return coordinate }
        }
        return (35, Double(TimeZone.current.secondsFromGMT()) / 3600 * 15)
    }()

    // "+353916+1394441" (±DDMM[SS]±DDDMM[SS]) to decimal degrees.
    private static func parse(_ text: String) -> (latitude: Double, longitude: Double)? {
        guard let split = text.dropFirst().firstIndex(where: { $0 == "+" || $0 == "-" }) else { return nil }
        func degrees(_ part: Substring, degreeDigits: Int) -> Double? {
            let sign: Double = part.first == "-" ? -1 : 1
            let digits = part.dropFirst()
            guard digits.count >= degreeDigits + 2, let d = Double(digits.prefix(degreeDigits)),
                  let m = Double(digits.dropFirst(degreeDigits).prefix(2)) else { return nil }
            let s = Double(digits.dropFirst(degreeDigits + 2).prefix(2)) ?? 0
            return sign * (d + m / 60 + s / 3600)
        }
        guard let latitude = degrees(text[..<split], degreeDigits: 2),
              let longitude = degrees(text[split...], degreeDigits: 3) else { return nil }
        return (latitude, longitude)
    }

    // A low-precision solar position (good to about a degree), which is plenty to pick a wallpaper.
    static func position(at date: Date, latitude: Double = home.latitude, longitude: Double = home.longitude) -> Position {
        let rad = Double.pi / 180
        let days = date.timeIntervalSince1970 / 86400 + 2440587.5 - 2451545.0 // since J2000
        let meanLongitude = 280.460 + 0.9856474 * days
        let anomaly = (357.528 + 0.9856003 * days) * rad
        let eclipticLongitude = (meanLongitude + 1.915 * sin(anomaly) + 0.020 * sin(2 * anomaly)) * rad
        let obliquity = (23.439 - 0.0000004 * days) * rad
        let rightAscension = atan2(cos(obliquity) * sin(eclipticLongitude), cos(eclipticLongitude))
        let declination = asin(sin(obliquity) * sin(eclipticLongitude))
        let siderealTime = (280.46061837 + 360.98564736629 * days) * rad
        let hourAngle = siderealTime + longitude * rad - rightAscension
        let lat = latitude * rad
        let altitude = asin(sin(lat) * sin(declination) + cos(lat) * cos(declination) * cos(hourAngle))
        let azimuth = atan2(-sin(hourAngle), tan(declination) * cos(lat) - sin(lat) * cos(hourAngle))
        return (altitude / rad, (azimuth / rad + 360).truncatingRemainder(dividingBy: 360))
    }

    // The angle between two sky positions, in degrees.
    static func angle(_ a: Position, _ b: Position) -> Double {
        let rad = Double.pi / 180
        let cosine = sin(a.altitude * rad) * sin(b.altitude * rad)
            + cos(a.altitude * rad) * cos(b.altitude * rad) * cos((a.azimuth - b.azimuth) * rad)
        return acos(min(1, max(-1, cosine))) / rad
    }
}
