import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct TrioWatchComplicationEntry: TimelineEntry {
    let date: Date
    let glucoseValue: String
    let trend: String
    let delta: String
    let glucoseColor: Color
    let iob: String?
    let cob: String?
    let lastUpdateTime: Date?
    let units: String

    var isStale: Bool {
        guard let lastUpdate = lastUpdateTime else { return true }
        return Date().timeIntervalSince(lastUpdate) > 900 // 15 minutes
    }
}

// MARK: - Provider

struct TrioWatchComplicationProvider: TimelineProvider {
    func placeholder(in _: Context) -> TrioWatchComplicationEntry {
        TrioWatchComplicationEntry(
            date: Date(),
            glucoseValue: "120",
            trend: "→",
            delta: "+2",
            glucoseColor: .green,
            iob: "2.5U",
            cob: "30g",
            lastUpdateTime: Date(),
            units: "mg/dL"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TrioWatchComplicationEntry) -> Void) {
        print("📸 Complication: getSnapshot called, isPreview = \(context.isPreview)")
        let entry = loadLatestGlucoseFromAppGroup() ?? placeholder(in: context)
        print("📸 Complication: Returning snapshot with glucose = \(entry.glucoseValue)")
        completion(entry)
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<TrioWatchComplicationEntry>) -> Void) {
        print("⏰ Complication: getTimeline called at \(Date())")
        let currentEntry = loadLatestGlucoseFromAppGroup() ?? createPlaceholderEntry()

        // Create timeline with single entry
        let entries = [currentEntry]

        // Update policy: Reload every 5 minutes (CGM readings come ~5 min)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))

        print("⏰ Complication: Timeline created with glucose = \(currentEntry.glucoseValue), nextUpdate = \(nextUpdate)")
        completion(timeline)
    }

    // MARK: - Data Loading

    private func loadLatestGlucoseFromAppGroup() -> TrioWatchComplicationEntry? {
        // Debug: Print the app group suite name
        let suiteName = Bundle.main.appGroupSuiteName
        print("🔍 Complication: App Group Suite Name = \(suiteName ?? "nil")")

        guard let suiteName = suiteName,
              let sharedDefaults = UserDefaults(suiteName: suiteName) else {
            print("❌ Complication: Could not access App Group UserDefaults")
            return nil
        }

        // Debug: Print all keys in shared defaults
        print("🔍 Complication: Checking App Group for glucose data...")
        let glucoseValue = sharedDefaults.string(forKey: "currentGlucose")
        let trend = sharedDefaults.string(forKey: "trend")
        let delta = sharedDefaults.string(forKey: "delta")
        let colorString = sharedDefaults.string(forKey: "currentGlucoseColorString")

        print("🔍 Complication: glucoseValue = \(glucoseValue ?? "nil")")
        print("🔍 Complication: trend = \(trend ?? "nil")")
        print("🔍 Complication: delta = \(delta ?? "nil")")
        print("🔍 Complication: colorString = \(colorString ?? "nil")")

        // Read WatchState data persisted by iPhone app
        guard let glucoseValue = glucoseValue,
              glucoseValue != "",
              let trend = trend,
              let delta = delta,
              let colorString = colorString else {
            print("⚠️ Complication: Missing glucose data, returning placeholder")
            return createPlaceholderEntry()
        }

        let glucoseColor = Color(hex: colorString) ?? .white
        let lastUpdateTimestamp = sharedDefaults.double(forKey: "date")
        let lastUpdate = lastUpdateTimestamp > 0 ? Date(timeIntervalSince1970: lastUpdateTimestamp) : nil

        print("✅ Complication: Loaded glucose data successfully: \(glucoseValue)")

        return TrioWatchComplicationEntry(
            date: Date(),
            glucoseValue: glucoseValue,
            trend: trend,
            delta: delta,
            glucoseColor: glucoseColor,
            iob: sharedDefaults.string(forKey: "iob"),
            cob: sharedDefaults.string(forKey: "cob"),
            lastUpdateTime: lastUpdate,
            units: sharedDefaults.string(forKey: "units") ?? "mg/dL"
        )
    }

    private func createPlaceholderEntry() -> TrioWatchComplicationEntry {
        TrioWatchComplicationEntry(
            date: Date(),
            glucoseValue: "---",
            trend: "⋯",
            delta: "...",
            glucoseColor: .gray,
            iob: nil,
            cob: nil,
            lastUpdateTime: nil,
            units: "mg/dL"
        )
    }
}

// MARK: - Views

/// Displayed View Wrapper
struct TrioWatchComplicationEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    var entry: TrioWatchComplicationEntry

    var body: some View {
        print("🎨 Complication: Rendering widgetFamily = \(widgetFamily)")

        switch widgetFamily {
        case .accessoryCircular:
            TrioAccessoryCircularView(entry: entry)
        case .accessoryCorner:
            TrioAccessoryCornerView(entry: entry)
        case .accessoryRectangular:
            TrioAccessoryRectangularView(entry: entry)
        case .accessoryInline:
            TrioAccessoryInlineView(entry: entry)
        case .graphicCircular:
            TrioGraphicCircularView(entry: entry)
        case .graphicCorner:
            TrioGraphicCornerView(entry: entry)
        case .graphicRectangular:
            TrioGraphicRectangularView(entry: entry)
        default:
            // Fallback for unsupported families - show glucose text
            VStack {
                Text(entry.glucoseValue)
                    .font(.system(.body, design: .rounded))
                    .bold()
                Text(entry.trend)
                    .font(.caption)
            }
            .widgetBackground(backgroundView: Color.clear)
        }
    }
}

/// Circular Complication - Main glucose display
struct TrioAccessoryCircularView: View {
    var entry: TrioWatchComplicationEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            VStack(spacing: 1) {
                // Main glucose value
                Text(entry.isStale ? "--" : entry.glucoseValue)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(entry.isStale ? .gray : entry.glucoseColor)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                // Trend + Delta
                HStack(spacing: 2) {
                    Text(entry.trend)
                        .font(.system(size: 12))
                        .foregroundStyle(entry.isStale ? .gray : .primary)
                    Text(entry.delta)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(4)
        }
    }
}

/// Corner Complication - Compact glucose display
struct TrioAccessoryCornerView: View {
    var entry: TrioWatchComplicationEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            HStack(spacing: 3) {
                // Glucose value
                Text(entry.isStale ? "--" : entry.glucoseValue)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(entry.isStale ? .gray : entry.glucoseColor)
                    .minimumScaleFactor(0.7)

                // Trend arrow
                Text(entry.trend)
                    .font(.system(size: 12))
                    .foregroundStyle(entry.isStale ? .gray : .primary)
            }
        }
        .widgetLabel {
            Text(entry.delta)
                .font(.system(size: 10))
        }
    }
}

/// Rectangular Complication - Full info display with IOB/COB
struct TrioAccessoryRectangularView: View {
    var entry: TrioWatchComplicationEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Top row: Glucose + Trend + Delta
            HStack(spacing: 4) {
                Text(entry.isStale ? "--" : entry.glucoseValue)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(entry.isStale ? .gray : entry.glucoseColor)

                Text(entry.trend)
                    .font(.system(size: 16))
                    .foregroundStyle(entry.isStale ? .gray : .primary)

                Text(entry.delta)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Spacer()
            }

            // Bottom row: IOB + COB
            HStack(spacing: 12) {
                if let iob = entry.iob, !entry.isStale {
                    Text("IOB: \(iob)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                if let cob = entry.cob, !entry.isStale {
                    Text("COB: \(cob)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }
}

/// Inline Complication - Minimal glucose display
struct TrioAccessoryInlineView: View {
    var entry: TrioWatchComplicationEntry

    var body: some View {
        HStack(spacing: 3) {
            Text(entry.isStale ? "--" : entry.glucoseValue)
                .foregroundStyle(entry.isStale ? .gray : entry.glucoseColor)
            Text(entry.trend)
                .foregroundStyle(entry.isStale ? .gray : .primary)
            Text(entry.delta)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 14, weight: .semibold, design: .rounded))
    }
}

// MARK: - Graphic Complications (watchOS 7-8)

/// Graphic Circular Complication - For older watch faces
struct TrioGraphicCircularView: View {
    var entry: TrioWatchComplicationEntry

    var body: some View {
        Gauge(value: Double(entry.glucoseValue) ?? 100, in: 40...400) {
            VStack(spacing: 2) {
                Text(entry.isStale ? "--" : entry.glucoseValue)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(entry.isStale ? .gray : entry.glucoseColor)
                HStack(spacing: 1) {
                    Text(entry.trend)
                        .font(.system(size: 10))
                    Text(entry.delta)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        } currentValueLabel: {
            EmptyView()
        }
        .gaugeStyle(.accessoryCircular)
    }
}

/// Graphic Corner Complication - For corner positions on older faces
struct TrioGraphicCornerView: View {
    var entry: TrioWatchComplicationEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.isStale ? "--" : entry.glucoseValue)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(entry.isStale ? .gray : entry.glucoseColor)
            HStack(spacing: 2) {
                Text(entry.trend)
                    .font(.system(size: 14))
                Text(entry.delta)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .widgetLabel {
            Gauge(value: Double(entry.glucoseValue) ?? 100, in: 40...400) {
                EmptyView()
            }
            .gaugeStyle(.accessoryCircular)
        }
    }
}

/// Graphic Rectangular Complication - For larger info display
struct TrioGraphicRectangularView: View {
    var entry: TrioWatchComplicationEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.isStale ? "--" : entry.glucoseValue)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(entry.isStale ? .gray : entry.glucoseColor)
                    Text(entry.trend)
                        .font(.system(size: 18))
                    Text(entry.delta)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                if !entry.isStale {
                    HStack(spacing: 8) {
                        if let iob = entry.iob {
                            Text("IOB: \(iob)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        if let cob = entry.cob {
                            Text("COB: \(cob)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(4)
    }
}

// MARK: - Widget Configuration

@main struct TrioWatchComplication: Widget {
    let kind: String = "TrioWatchComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrioWatchComplicationProvider()) { entry in
            TrioWatchComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Trio Glucose")
        .description("Real-time blood glucose monitoring with trend and delta")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular,
            .accessoryInline,
            .graphicCircular,
            .graphicCorner,
            .graphicRectangular
        ])
    }
}

// MARK: - Extensions

extension View {
    func widgetBackground(backgroundView: some View) -> some View {
        if #available(watchOS 10.0, iOSApplicationExtension 17.0, iOS 17.0, *) {
            return containerBackground(for: .widget) {
                backgroundView
            }
        } else {
            return background(backgroundView)
        }
    }
}

extension Color {
    /// Initialize Color from hex string (supports #RRGGBB and #AARRGGBB formats)
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (no alpha)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension Bundle {
    var appGroupSuiteName: String? {
        object(forInfoDictionaryKey: "AppGroupID") as? String
    }
}
