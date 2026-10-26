import SwiftUI

struct TutorDashboardView: View {
    @EnvironmentObject private var app: AppController
    var onSelect: (TutorSection) -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageTitle(title: "Good morning, \(firstName)", subtitle: "Here’s what’s happening with your classes today.")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                    MetricTile(title: "Total students", value: "\(app.students.count)", detail: "+2 this month", icon: "person.2.fill")
                    MetricTile(title: "Today's classes", value: "\(todayClasses.count)", detail: "Across your subjects", icon: "calendar", tint: TMStyle.violet)
                    MetricTile(title: "Attendance", value: "\(todayAttendance)%", detail: "Today's attendance", icon: "checkmark.circle.fill", tint: TMStyle.green)
                    MetricTile(title: "Income collected", value: "$\(Int(app.collectedIncome))", detail: "This month", icon: "creditcard.fill", tint: TMStyle.orange)
                }
                TMCard {
                    HStack {
                        Text("Today's classes").font(.headline).foregroundStyle(TMStyle.ink)
                        Spacer()
                        Button("View all") { onSelect(.classes) }.font(.caption.weight(.semibold))
                    }
                    if todayClasses.isEmpty {
                        Text("No classes today.").foregroundStyle(TMStyle.muted)
                    } else {
                        ForEach(todayClasses) { session in
                            ClassSummaryRow(session: session)
                        }
                    }
                }
                HStack {
                    Text("Quick actions").font(.headline).foregroundStyle(TMStyle.ink)
                    Spacer()
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    quickAction("Add a class", icon: "plus.circle.fill", tint: TMStyle.blue) { onSelect(.classes) }
                    quickAction("Take attendance", icon: "checkmark.circle.fill", tint: TMStyle.green) { onSelect(.attendance) }
                    quickAction("Manage students", icon: "person.2.fill", tint: TMStyle.violet) { onSelect(.students) }
                    quickAction("View finances", icon: "chart.bar.fill", tint: TMStyle.orange) { onSelect(.finance) }
                }
                TMCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Eyebrow(text: "INCOME OVERVIEW")
                            Text("$\(Int(app.collectedIncome))").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(TMStyle.ink)
                            Text("Collected payments").font(.caption).foregroundStyle(TMStyle.muted)
                        }
                        Spacer()
                        Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 36)).foregroundStyle(TMStyle.green)
                    }
                    Button("Open finance overview") { onSelect(.finance) }.font(.subheadline.weight(.semibold))
                }
                TMCard {
                    Text("Recent activity").font(.headline).foregroundStyle(TMStyle.ink)
                    activityRow("Maya checked in via NFC", detail: "Attendance · just now", icon: "wave.3.right", tint: TMStyle.green)
                    activityRow("Payment received · $120", detail: "Maya Silva · today", icon: "creditcard", tint: TMStyle.blue)
                    activityRow("Assessment marks published", detail: "Grade 11 Mathematics", icon: "doc.text", tint: TMStyle.violet)
                }
            }.padding(20).frame(maxWidth: 1100).frame(maxWidth: .infinity, alignment: .topLeading)
        }.background(TMStyle.canvas)
    }
    private var firstName: String { app.displayName.split(separator: " ").first.map(String.init) ?? "Tutor" }
    private var todayClasses: [ClassSession] { app.sessions.filter { Calendar.current.isDateInToday($0.date) } }
    private var todayAttendance: Int {
        guard !app.attendance.isEmpty else { return 0 }
        return Int(Double(app.attendance.filter { $0.status == .present }.count) / Double(app.attendance.count) * 100)
    }
    private func quickAction(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.title3).foregroundStyle(tint)
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(TMStyle.ink)
                Spacer(minLength: 0)
            }.padding(15).background(.white, in: RoundedRectangle(cornerRadius: 17))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(TMStyle.line))
        }.buttonStyle(.plain)
    }
    private func activityRow(_ title: String, detail: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 40, height: 40).background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(TMStyle.ink)
                Text(detail).font(.caption).foregroundStyle(TMStyle.muted)
            }
            Spacer()
        }
    }
}
struct ClassSummaryRow: View {
    let session: ClassSession
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4).fill(TMStyle.blue).frame(width: 4, height: 54)
            VStack(alignment: .leading, spacing: 5) {
                Text(session.title).font(.subheadline.weight(.semibold)).foregroundStyle(TMStyle.ink)
                Text("\(session.subject) · \(session.location)").font(.caption).foregroundStyle(TMStyle.muted)
            }
            Spacer()
            Text(session.time).font(.caption.weight(.semibold)).foregroundStyle(TMStyle.blue)
        }.padding(.vertical, 5)
    }
}
