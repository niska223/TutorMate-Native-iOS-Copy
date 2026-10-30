import SwiftUI

struct TutorAttendanceView: View {
    @EnvironmentObject private var app: AppController
    var onManageClasses: () -> Void = {}
    var onManageStudents: () -> Void = {}
    @State private var selectedClassID: UUID?
    @State private var showNFC = false

    private var presentCount: Int {
        todayRecords.filter { $0.status == .present }.count
    }

    private var todayRecords: [AttendanceRecord] {
        app.attendance.filter {
            Calendar.current.isDateInToday($0.date) &&
                (($0.classID == selectedClassID) || ($0.classID == nil && $0.className == selectedSession?.title))
        }
    }
    private var selectedSession: ClassSession? {
        guard let selectedClassID else { return nil }
        return app.sessions.first { $0.id == selectedClassID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(
                    title: "Today's attendance",
                    subtitle: "Track attendance manually or with NFC check-in."
                )

                Picker("Class", selection: $selectedClassID) {
                    Text(app.sessions.isEmpty ? "No saved classes" : "Select class")
                        .tag(UUID?.none)
                    ForEach(app.sessions.sorted { $0.date < $1.date }) { session in
                        Text("\(session.title) · \(session.subject) · \(session.date.formatted(date: .abbreviated, time: .omitted))")
                            .tag(Optional(session.id))
                    }
                }
                .pickerStyle(.menu)
                .padding(10)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Choose a saved class for attendance")
                .disabled(app.sessions.isEmpty)

                if app.sessions.isEmpty && !app.isLoadingClasses {
                    ContentUnavailableView("No saved classes", systemImage: "calendar", description: Text("Create a class in the Classes tab before taking attendance."))
                }

                if app.isLoadingAttendance {
                    ProgressView("Loading saved attendance…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    MetricTile(
                        title: "Present",
                        value: "\(presentCount)",
                        detail: "Checked in",
                        icon: "checkmark.circle.fill",
                        tint: TMStyle.green
                    )
                    MetricTile(
                        title: "Absent",
                        value: "\(todayRecords.filter { $0.status == .absent }.count)",
                        detail: "Not present",
                        icon: "xmark.circle.fill",
                        tint: TMStyle.red
                    )
                    MetricTile(
                        title: "Rate",
                        value: "\(todayRecords.isEmpty ? 0 : presentCount * 100 / todayRecords.count)%",
                        detail: "Attendance",
                        icon: "chart.pie.fill",
                        tint: TMStyle.blue
                    )
                }

                TMCard {
                    HStack {
                        Text("Student attendance").font(.headline)
                        Spacer()
                        Button { showNFC = true } label: {
                            Label("NFC scan", systemImage: "wave.3.right")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if app.students.isEmpty {
                        ContentUnavailableView(
                            "No saved students",
                            systemImage: "person.2",
                            description: Text("Add a student in the Tutor Students page first.")
                        )
                    } else {
                        ForEach(app.students) { student in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    AvatarView(name: student.name)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(student.name).font(.subheadline.weight(.semibold))
                                        Text(student.grade).font(.caption).foregroundStyle(TMStyle.muted)
                                    }
                                    Spacer()
                                    let status = todayRecords.first(where: {
                                        $0.studentID == student.id || ($0.studentID == nil && $0.studentName == student.name)
                                    })?.status
                                    StatusPill(
                                        text: status?.rawValue ?? "Not marked",
                                        color: status == .present ? TMStyle.green : (status == .absent ? TMStyle.red : TMStyle.orange)
                                    )
                                }

                                HStack(spacing: 8) {
                                    ForEach(AttendanceStatus.allCases) { status in
                                        Button(status.rawValue) {
                                            app.markAttendance(
                                                student: student,
                                                status: status,
                                                session: selectedSession
                                            )
                                        }
                                        .disabled(selectedSession == nil)
                                        .accessibilityHint(selectedSession == nil ? "Save a class before recording attendance" : "Mark this student's attendance as \(status.rawValue)")
                                        .font(.caption.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            statusColor(status).opacity(0.10),
                                            in: RoundedRectangle(cornerRadius: 9)
                                        )
                                        .foregroundStyle(statusColor(status))
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }

                TMCard {
                    Label("Live NFC attendance", systemImage: "wave.3.right")
                        .font(.headline)
                    Text("Tap NFC scan to open the NFC check-in flow. Real NFC scanning requires a supported device and NFC configuration.")
                        .font(.caption)
                        .foregroundStyle(TMStyle.muted)
                    PrimaryButton(title: "Open NFC attendance", icon: "wave.3.right") {
                        showNFC = true
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 950)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(TMStyle.canvas)
        .sheet(isPresented: $showNFC) {
            NFCScanSheet(
                isTutor: true,
                onManageClasses: onManageClasses,
                onManageStudents: onManageStudents
            )
        }
        .onChange(of: app.sessions.map(\.id)) { _, ids in
            if let selectedClassID, ids.contains(selectedClassID) {
                self.selectedClassID = selectedClassID
            } else if let first = app.sessions.sorted(by: { $0.date < $1.date }).first {
                selectedClassID = first.id
            } else {
                selectedClassID = nil
            }
        }
        .onAppear {
            if let selectedClassID, app.sessions.contains(where: { $0.id == selectedClassID }) { return }
            if let first = app.sessions.sorted(by: { $0.date < $1.date }).first {
                selectedClassID = first.id
            }
        }
    }

    private func statusColor(_ status: AttendanceStatus) -> Color {
        switch status {
        case .present: TMStyle.green
        case .absent: TMStyle.red
        case .late: TMStyle.orange
        }
    }
}

