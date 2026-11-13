// Widget + Live Activity for iPhone and CarPlay (iOS 26 shows systemSmall widgets and the
// .small Live Activity family on the CarPlay dashboard, StandBy-style, background removed).
import ActivityKit
import SwiftUI
import WidgetKit

private let soulRed = Color(red: 200 / 255, green: 16 / 255, blue: 46 / 255)
private let brightRed = Color(red: 1, green: 59 / 255, blue: 85 / 255)
private let amber = Color(red: 1, green: 167 / 255, blue: 38 / 255)
private let green = Color(red: 51 / 255, green: 209 / 255, blue: 122 / 255)

private func fmt(_ v: Double?, _ decimals: Int = 0) -> String {
  guard let v else { return "--" }
  let f = NumberFormatter()
  f.locale = Locale(identifier: "es_CO")
  f.minimumFractionDigits = decimals
  f.maximumFractionDigits = decimals
  return f.string(from: NSNumber(value: v)) ?? "--"
}

private func levelColor(_ level: String?) -> Color {
  switch level {
  case "due": return brightRed
  case "soon": return amber
  case "ok": return green
  default: return .secondary
  }
}

/// Arc gauge matching the phone app (270° sweep, rounded caps).
struct ArcGauge: View {
  var fraction: Double
  var color: Color = soulRed
  var lineWidth: CGFloat = 7

  var body: some View {
    ZStack {
      Circle()
        .trim(from: 0, to: 0.75)
        .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
      Circle()
        .trim(from: 0, to: 0.75 * max(0, min(1, fraction)))
        .stroke(
          AngularGradient(colors: [color.opacity(0.6), color], center: .center, startAngle: .degrees(0), endAngle: .degrees(270)),
          style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }
    .rotationEffect(.degrees(135))
  }
}

// MARK: - Status widget

struct StatusEntry: TimelineEntry {
  let date: Date
  let status: MzdStatus
}

struct StatusProvider: TimelineProvider {
  func placeholder(in context: Context) -> StatusEntry { StatusEntry(date: Date(), status: .placeholder) }

  func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
    completion(StatusEntry(date: Date(), status: MzdStatus.load() ?? .placeholder))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
    // The app reloads the timeline when data changes; refresh at least every 30 min.
    let entry = StatusEntry(date: Date(), status: MzdStatus.load() ?? .placeholder)
    completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60))))
  }
}

struct StatusWidgetView: View {
  let entry: StatusEntry

  var body: some View {
    let s = entry.status
    let hot = (s.coolant ?? 0) > 105
    let lowBattery = s.voltage.map { $0 < 12 } ?? false
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        Image(systemName: "car.side.fill").foregroundStyle(soulRed)
        Text(s.carName).font(.system(size: 14, weight: .bold)).lineLimit(1)
      }
      HStack(spacing: 10) {
        metric(icon: "thermometer.medium", value: "\(fmt(s.coolant))°", warn: hot)
        metric(icon: "minus.plus.batteryblock.fill", value: "\(fmt(s.voltage, 1))V", warn: lowBattery)
      }
      Spacer(minLength: 0)
      if let title = s.serviceTitle {
        HStack(spacing: 5) {
          Image(systemName: "wrench.adjustable.fill").foregroundStyle(levelColor(s.serviceLevel))
          VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
            Text(s.serviceLabel ?? "").font(.system(size: 11)).foregroundStyle(levelColor(s.serviceLevel)).lineLimit(1)
          }
        }
      }
      if let n = s.dtcCount, n > 0 {
        Label("\(n) código\(n > 1 ? "s" : "") de falla", systemImage: "exclamationmark.triangle.fill")
          .font(.system(size: 11, weight: .semibold)).foregroundStyle(amber)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .containerBackground(for: .widget) {
      LinearGradient(colors: [Color(white: 0.13), Color(red: 0.16, green: 0.03, blue: 0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
  }

  private func metric(icon: String, value: String, warn: Bool) -> some View {
    HStack(spacing: 3) {
      Image(systemName: icon).font(.system(size: 12)).foregroundStyle(warn ? amber : .secondary)
      Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(warn ? amber : .primary)
        .minimumScaleFactor(0.7).lineLimit(1)
    }
  }
}

struct MiMazdaStatusWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "MiMazdaStatus", provider: StatusProvider()) { entry in
      StatusWidgetView(entry: entry)
    }
    .configurationDisplayName("Estado de Mi Mazda")
    .description("Batería, temperatura del motor y próximo mantenimiento.")
    .supportedFamilies([.systemSmall])
  }
}

// MARK: - Drive Live Activity

struct DriveSmallView: View {
  let state: MzdDriveAttributes.ContentState

  var body: some View {
    HStack(spacing: 14) {
      ZStack {
        ArcGauge(fraction: (state.speed ?? 0) / 180, lineWidth: 8)
        VStack(spacing: -2) {
          Text(fmt(state.speed)).font(.system(size: 26, weight: .heavy, design: .rounded)).minimumScaleFactor(0.6)
          Text("km/h").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
        }
      }
      .frame(width: 74, height: 74)
      VStack(alignment: .leading, spacing: 4) {
        row(icon: "gauge.with.dots.needle.67percent", text: "\(fmt(state.rpm)) rpm", warn: (state.rpm ?? 0) > 6000)
        row(icon: "thermometer.medium", text: "\(fmt(state.coolant))°", warn: (state.coolant ?? 0) > 105)
        row(icon: "minus.plus.batteryblock.fill", text: "\(fmt(state.voltage, 1)) V", warn: state.voltage.map { $0 < 12 } ?? false)
        if let w = state.warning {
          Text(w).font(.system(size: 11, weight: .bold)).foregroundStyle(amber).lineLimit(1)
        }
      }
    }
  }

  private func row(icon: String, text: String, warn: Bool) -> some View {
    HStack(spacing: 5) {
      Image(systemName: icon).font(.system(size: 11)).foregroundStyle(warn ? amber : soulRed)
      Text(text).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(warn ? amber : .primary)
    }
  }
}

struct DriveActivityView: View {
  @Environment(\.activityFamily) private var family
  let context: ActivityViewContext<MzdDriveAttributes>

  var body: some View {
    switch family {
    case .small:
      DriveSmallView(state: context.state).padding(6)
    default:
      HStack {
        DriveSmallView(state: context.state)
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          Image(systemName: "car.side.fill").foregroundStyle(soulRed)
          Text(context.attributes.carName).font(.caption.bold())
          Text("En ruta").font(.caption2).foregroundStyle(.secondary)
        }
      }
      .padding(16)
      .activityBackgroundTint(Color(white: 0.08))
      .activitySystemActionForegroundColor(.white)
    }
  }
}

struct MiMazdaDriveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: MzdDriveAttributes.self) { context in
      DriveActivityView(context: context)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label("\(fmt(context.state.speed)) km/h", systemImage: "speedometer").font(.headline)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Label("\(fmt(context.state.coolant))°", systemImage: "thermometer.medium").font(.headline)
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack {
            Text("\(fmt(context.state.rpm)) rpm")
            Spacer()
            Text("\(fmt(context.state.voltage, 1)) V")
            if let w = context.state.warning { Spacer(); Text(w).foregroundStyle(amber) }
          }
          .font(.subheadline.weight(.semibold))
        }
      } compactLeading: {
        Text(fmt(context.state.speed)).font(.system(.body, design: .rounded).bold()).foregroundStyle(soulRed)
      } compactTrailing: {
        Text("\(fmt(context.state.coolant))°").foregroundStyle((context.state.coolant ?? 0) > 105 ? amber : .primary)
      } minimal: {
        Image(systemName: "car.side.fill").foregroundStyle(context.state.warning == nil ? soulRed : amber)
      }
    }
    .supplementalActivityFamilies([.small])
  }
}

@main
struct MiMazdaWidgets: WidgetBundle {
  var body: some Widget {
    MiMazdaStatusWidget()
    MiMazdaDriveActivity()
  }
}
