import SwiftUI

struct TutorDashboardView: View {
    @EnvironmentObject private var app: AppController
    var onSelect: (TutorSection) -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageTitle(title: "Good morning, \(firstName)", subtitle: "Here’s what’s happening with your classes today.")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                    MetricTile(title: "Total students", value: "\(app.students.count)", detail: "Saved student records", icon: "person.2.fill")
                    MetricTile(title: "Today's classes", value: "\(todayClasses.count)", detail: "Across your subjects", icon: "calendar", tint: TMStyle.violet)
                    MetricTile(title: "Attendance", value: "\(todayAttendance)%", detail: "Today's attendance", icon: "checkmark.circle.fill", tint: TMStyle.green)
                    MetricTile(title: "Income collected", value: app.collectedIncome.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")), detail: "All paid records", icon: "creditcard.fill", tint: TMStyle.orange)
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
                            Text(app.collectedIncome, format: .currency(code: Locale.current.currency?.identifier ?? "USD")).font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(TMStyle.ink)
                            Text("Collected payments").font(.caption).foregroundStyle(TMStyle.muted)
                        }
                        Spacer()
                        Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 36)).foregroundStyle(TMStyle.green)
                    }
                    Button("Open finance overview") { onSelect(.finance) }.font(.subheadline.weight(.semibold))
                }
                TMCard {
                    Text("Recent activity").font(.headline).foregroundStyle(TMStyle.ink)
                    if recentActivity.isEmpty {
                        Text("No saved attendance or payment activity yet.")
                            .font(.body)
                            .foregroundStyle(TMStyle.muted)
                    } else {
                        ForEach(recentActivity) { item in
                            activityRow(item.title, detail: item.detail, icon: item.icon, tint: item.tint)
                        }
                    }
                }
            }.padding(20).frame(maxWidth: 1100).frame(maxWidth: .infinity, alignment: .topLeading)
        }.background(TMStyle.canvas)
    }
    private var firstName: String { app.displayName.split(separator: " ").first.map(String.init) ?? "Tutor" }
    private var todayClasses: [ClassSession] { app.sessions.filter { Calendar.current.isDateInToday($0.date) } }
    private var todayAttendanceRecords: [AttendanceRecord] {
        app.attendance.filter { Calendar.current.isDateInToday($0.date) }
    }
    private var todayAttendance: Int {
        guard !todayAttendanceRecords.isEmpty else { return 0 }
        let attendedCount = todayAttendanceRecords.filter { $0.status == .present || $0.status == .late }.count
        return Int(Double(attendedCount) / Double(todayAttendanceRecords.count) * 100)
    }
    private var recentActivity: [DashboardActivity] {
        let attendance = app.attendance.map { record in
            DashboardActivity(id: "attendance-\(record.id.uuidString)",
                title: "\(record.status.rawValue): \(record.studentName)",
                detail: "\(record.className) · \(record.date.formatted(date: .abbreviated, time: .shortened))",
                icon: "checkmark.circle", tint: TMStyle.green, date: record.date)
        }
        let payments = app.payments.map { payment in
            DashboardActivity(id: "payment-\(payment.id.uuidString)",
                title: "\(payment.isPaid ? "Payment received" : "Payment due") · \(payment.amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))",
                detail: "\(payment.studentName) · \(payment.date.formatted(date: .abbreviated, time: .omitted))",
                icon: "creditcard", tint: payment.isPaid ? TMStyle.blue : TMStyle.orange, date: payment.date)
        }
        return (attendance + payments).sorted { $0.date > $1.date }.prefix(4).map { $0 }
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

private struct DashboardActivity: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let tint: Color
    let date: Date
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
