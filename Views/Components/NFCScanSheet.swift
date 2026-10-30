import SwiftUI

struct NFCScanSheet: View {
    @EnvironmentObject private var app: AppController
    @Environment(\.dismiss) private var dismiss
    let isTutor: Bool
    var onManageClasses: () -> Void = {}
    var onManageStudents: () -> Void = {}
    @StateObject private var nfc = NFCService()
    @State private var state = 0 // 0 ready, 1 scanning, 2 success, 3 error
    @State private var message = "Hold your iPhone near the TutorMate class NFC tag."
    @State private var selectedStudentID: UUID?
    @State private var selectedClassID: UUID?
    @State private var isRefreshing = false

    private var savedClasses: [ClassSession] {
        app.sessions.sorted { $0.date < $1.date }
    }
    private var savedStudents: [Student] {
        app.students.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    private var canScan: Bool {
        isTutor && !isRefreshing && selectedStudentID != nil && selectedClassID != nil
            && savedStudents.contains { $0.id == selectedStudentID }
            && savedClasses.contains { $0.id == selectedClassID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: state == 2 ? "checkmark.circle.fill" : (state == 3 ? "exclamationmark.triangle.fill" : "wave.3.right"))
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(state == 2 ? TMStyle.green : (state == 3 ? TMStyle.red : TMStyle.blue))
                        .frame(width: 88, height: 88)
                        .background(state == 2 ? TMStyle.greenSoft : TMStyle.blueSoft, in: Circle())
                        .accessibilityHidden(true)

                    Text(state == 2 ? "Attendance recorded" : (state == 1 ? "Scanning NFC tag…" : (state == 3 ? "Could not scan tag" : "Ready to scan")))
                        .font(.title2.bold())
                        .foregroundStyle(TMStyle.ink)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.body)
                        .foregroundStyle(state == 3 ? TMStyle.red : TMStyle.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    if isTutor {
                        selectionControls
                    } else {
                        Text("Only a tutor can record attendance.")
                            .font(.body)
                            .foregroundStyle(TMStyle.muted)
                    }

                    if state == 0 || state == 3 {
                        PrimaryButton(title: "Scan NFC tag", icon: "wave.3.right") {
                            beginScan()
                        }
                        .disabled(!canScan)
                        .opacity(canScan ? 1 : 0.55)
                    } else if state == 2 {
                        PrimaryButton(title: "Done", icon: "checkmark") { dismiss() }
                    } else {
                        ProgressView().tint(TMStyle.blue)
                        Button("Cancel scan") {
                            nfc.cancelScanning()
                            state = 0
                            message = "Scan cancelled. You can try again when ready."
                        }
                        .accessibilityHint("Stops the current NFC reading session")
                    }

                    Text("NFC requires a supported physical iPhone and an NDEF text tag. Simulator scanning is not supported.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(TMStyle.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(22)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(TMStyle.canvas)
            .navigationTitle("NFC attendance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        nfc.cancelScanning()
                        dismiss()
                    }
                }
            }
            .task { await refreshSavedRecords() }
            .onChange(of: selectedClassID) { _, _ in clearSelectionError() }
            .onChange(of: selectedStudentID) { _, _ in clearSelectionError() }
            .onDisappear { nfc.cancelScanning() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var selectionControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isRefreshing {
                ProgressView("Loading your saved classes and students…")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Picker("Class", selection: $selectedClassID) {
                Text(savedClasses.isEmpty ? "No saved classes" : "Select class")
                    .tag(UUID?.none)
                ForEach(savedClasses) { session in
                    Text("\(session.title) · \(session.subject) · \(session.date.formatted(date: .abbreviated, time: .omitted))")
                        .tag(Optional(session.id))
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Select a saved class for attendance")
            .disabled(isRefreshing || savedClasses.isEmpty)
            .frame(maxWidth: .infinity, alignment: .leading)

            if savedClasses.count == 1 {
                Text("Only one class is currently saved. Add more from the Classes tab; this list uses your saved classes.")
                    .font(.footnote)
                    .foregroundStyle(TMStyle.muted)
            } else if savedClasses.count > 1 {
                Text("Showing all \(savedClasses.count) saved classes. Each option includes its subject and date.")
                    .font(.footnote)
                    .foregroundStyle(TMStyle.muted)
            }

            if !savedClasses.isEmpty {
                Button("Manage saved classes", systemImage: "calendar.badge.plus") {
                    dismiss()
                    onManageClasses()
                }
                .buttonStyle(.bordered)
            } else if savedClasses.isEmpty && !isRefreshing {
                Text("Create and save a class from the Classes tab before scanning attendance.")
                    .font(.footnote)
                    .foregroundStyle(TMStyle.muted)
                Button("Add a class", systemImage: "plus") {
                    dismiss()
                    onManageClasses()
                }
                .buttonStyle(.borderedProminent)
            }

            Picker("Student", selection: $selectedStudentID) {
                Text(savedStudents.isEmpty ? "No saved students" : "Select student")
                    .tag(UUID?.none)
                ForEach(savedStudents) { student in
                    Text(student.name).tag(Optional(student.id))
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Select a saved student for attendance")
            .disabled(isRefreshing || savedStudents.isEmpty)

            if savedStudents.isEmpty && !isRefreshing {
                Text("Create and save a student from the Students tab before scanning attendance.")
                    .font(.footnote)
                    .foregroundStyle(TMStyle.muted)
                Button("Add a student", systemImage: "plus") {
                    dismiss()
                    onManageStudents()
                }
                .buttonStyle(.bordered)
            }

            if !canScan && !isRefreshing {
                Label("Select one saved class and one saved student to continue.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(TMStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(TMStyle.line))
    }

    @MainActor
    private func refreshSavedRecords() async {
        guard isTutor, app.route == .tutor, FirebaseService.shared.isConfigured else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        async let loadClasses: Void = app.loadTutorClasses()
        async let loadStudents: Void = app.loadTutorStudents()
        _ = await (loadClasses, loadStudents)
        if let selectedClassID, !app.sessions.contains(where: { $0.id == selectedClassID }) {
            self.selectedClassID = nil
        }
        if let selectedStudentID, !app.students.contains(where: { $0.id == selectedStudentID }) {
            self.selectedStudentID = nil
        }
    }

    private func clearSelectionError() {
        guard state == 3, !nfc.isScanning else { return }
        state = 0
        message = "Hold your iPhone near the TutorMate class NFC tag."
    }

    private func beginScan() {
        guard canScan,
              let studentID = selectedStudentID,
              let classID = selectedClassID,
              let student = app.students.first(where: { $0.id == studentID }),
              let session = app.sessions.first(where: { $0.id == classID }) else {
            state = 3
            message = "Select a saved class and student before scanning."
            return
        }

        state = 1
        message = "Keep the top of your iPhone close to the tag."
        nfc.startScanning { result in
            switch result {
            case .success(let payload):
                Task { @MainActor in
                    let expected = "tutormate:v1:\(classID.uuidString):\(studentID.uuidString)"
                    guard payload.trimmingCharacters(in: .whitespacesAndNewlines) == expected else {
                        state = 3
                        message = "This tag does not match the selected class and student."
                        return
                    }
                    do {
                        try await app.recordNFCAttendance(student: student, session: session)
                        state = 2
                        app.nfcCheckedIn = true
                        message = "Attendance was saved to your tutor account."
                    } catch {
                        state = 3
                        message = "Attendance could not be saved: \(error.localizedDescription)"
                    }
                }
            case .failure(let error):
                state = 3
                message = error.localizedDescription
            }
        }
    }
}
