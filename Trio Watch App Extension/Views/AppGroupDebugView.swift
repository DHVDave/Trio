import SwiftUI

/// Debug view to display App Group data for troubleshooting complications
struct AppGroupDebugView: View {
    @State private var debugInfo: [String: String] = [:]
    @State private var appGroupName: String = "Unknown"
    @State private var canAccessAppGroup: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("🔍 App Group Debug")
                    .font(.headline)
                    .padding(.bottom, 4)

                Divider()

                // App Group Name
                HStack {
                    Text("App Group:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                Text(appGroupName)
                    .font(.caption2)
                    .foregroundColor(canAccessAppGroup ? .green : .red)

                Divider()

                // Access Status
                HStack {
                    Text("Access:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(canAccessAppGroup ? "✅ OK" : "❌ FAIL")
                        .font(.caption2)
                        .foregroundColor(canAccessAppGroup ? .green : .red)
                }

                Divider()

                // Glucose Data
                Group {
                    debugRow(key: "Glucose", value: debugInfo["currentGlucose"] ?? "nil")
                    debugRow(key: "Trend", value: debugInfo["trend"] ?? "nil")
                    debugRow(key: "Delta", value: debugInfo["delta"] ?? "nil")
                    debugRow(key: "Color", value: debugInfo["currentGlucoseColorString"] ?? "nil")
                    debugRow(key: "IOB", value: debugInfo["iob"] ?? "nil")
                    debugRow(key: "COB", value: debugInfo["cob"] ?? "nil")
                    debugRow(key: "Units", value: debugInfo["units"] ?? "nil")
                    debugRow(key: "Last Update", value: debugInfo["date"] ?? "nil")
                }

                Divider()

                Button(action: refreshData) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
            .padding(8)
        }
        .navigationTitle("Debug")
        .onAppear {
            refreshData()
        }
    }

    private func debugRow(key: String, value: String) -> some View {
        HStack {
            Text(key + ":")
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption2)
                .foregroundColor(value == "nil" ? .red : .primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func refreshData() {
        // Get app group name
        if let suiteName = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String {
            appGroupName = suiteName

            // Try to access UserDefaults
            if let sharedDefaults = UserDefaults(suiteName: suiteName) {
                canAccessAppGroup = true

                // Read all glucose-related keys
                debugInfo = [
                    "currentGlucose": sharedDefaults.string(forKey: "currentGlucose") ?? "nil",
                    "trend": sharedDefaults.string(forKey: "trend") ?? "nil",
                    "delta": sharedDefaults.string(forKey: "delta") ?? "nil",
                    "currentGlucoseColorString": sharedDefaults.string(forKey: "currentGlucoseColorString") ?? "nil",
                    "iob": sharedDefaults.string(forKey: "iob") ?? "nil",
                    "cob": sharedDefaults.string(forKey: "cob") ?? "nil",
                    "units": sharedDefaults.string(forKey: "units") ?? "nil",
                    "date": {
                        let timestamp = sharedDefaults.double(forKey: "date")
                        if timestamp > 0 {
                            let date = Date(timeIntervalSince1970: timestamp)
                            let formatter = DateFormatter()
                            formatter.timeStyle = .short
                            return formatter.string(from: date)
                        }
                        return "nil"
                    }()
                ]
            } else {
                canAccessAppGroup = false
                debugInfo = [:]
            }
        } else {
            appGroupName = "Not configured"
            canAccessAppGroup = false
            debugInfo = [:]
        }
    }
}

#Preview {
    AppGroupDebugView()
}
