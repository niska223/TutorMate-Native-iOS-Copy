import SwiftUI

struct TutorStudentsView: View {
    @EnvironmentObject private var app: AppController
    @State private var query = ""
    @State private var showAdd = false
    @State private var selectedStudent: Student?
    @State private var editingStudent: Student?
    private var filtered: [Student] { app.students.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.grade.localizedCaseInsensitiveContains(query) } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(title: "Students", subtitle: "Keep student profiles and learning progress in one place.")
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(TMStyle.muted)
                    TextField("Search students", text: $query)
                }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(TMStyle.line))
                HStack {
                    Text("\(filtered.count) students").font(.headline)
                    Spacer()
                    Button { showAdd = true } label: { Label("Add student", systemImage: "plus") }.buttonStyle(.borderedProminent)
                }
                if app.isLoadingStudents { ProgressView("Loading saved students…").frame(maxWidth: .infinity).padding() }
                else if filtered.isEmpty { ContentUnavailableView("No saved students", systemImage: "person.2", description: Text("Add a student to your tutor account.")) }
                ForEach(filtered) { student in
                    Button { selectedStudent = student } label: {
                        TMCard {
                            HStack(spacing: 12) {
                                AvatarView(name: student.name, color: TMStyle.blue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(student.name).font(.headline).foregroundStyle(TMStyle.ink)
                                    Text("\(student.grade) · \(student.email)").font(.caption).foregroundStyle(TMStyle.muted)
                                    Text("Attendance \(student.attendanceRate)% · Score \(student.score)%").font(.caption.weight(.medium)).foregroundStyle(TMStyle.blue)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(TMStyle.muted)
                            }
                        }
                    }.buttonStyle(.plain).accessibilityHint("Opens student details and management actions")
                }
            }.padding(20).frame(maxWidth: 850).frame(maxWidth: .infinity, alignment: .topLeading)
        }.background(TMStyle.canvas)
        .sheet(isPresented: $showAdd) { AddStudentSheet() }
        .sheet(item: $selectedStudent) { StudentDetailSheet(student: $0) }
        .sheet(item: $editingStudent) { EditStudentSheet(student: $0) }
    }
}
struct AvatarView: View {
    let name: String
    var color: Color = TMStyle.violet
    var body: some View {
        Text(name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined())
            .font(.headline.weight(.bold)).foregroundStyle(color)
            .frame(width: 48, height: 48).background(color.opacity(0.12), in: Circle())
    }
}
private struct AddStudentSheet: View {
    @EnvironmentObject private var app: AppController
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var grade = "Grade 11"
    var body: some View {
        NavigationStack {
            Form {
                TextField("Full name", text: $name)
                TextField("Email address", text: $email).keyboardType(.emailAddress)
                Picker("Grade", selection: $grade) { ForEach(["Grade 9", "Grade 10", "Grade 11", "Grade 12"], id: \.self) { Text($0) } }
            }.navigationTitle("Add student")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") {
                        guard !name.isEmpty else { return }
                        app.addStudent(name: name, email: email, grade: grade); dismiss()
                    } }
                }
        }
    }
}
private struct StudentDetailSheet: View {
    @EnvironmentObject private var app: AppController
    @Environment(\.dismiss) private var dismiss
    let student: Student
    @State private var confirmDelete = false
    @State private var showEdit = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        AvatarView(name: student.name)
                        VStack(alignment: .leading) {
                            Text(student.name).font(.headline)
                            Text(student.grade).foregroundStyle(TMStyle.muted)
                        }
                    }.padding(.vertical, 8)
                }
                Section("Performance") {
                    LabeledContent("Attendance", value: "\(student.attendanceRate)%")
                    LabeledContent("Latest score", value: "\(student.score)%")
                    LabeledContent("Payment", value: student.paid ? "Paid" : "Outstanding")
                }
                Section("Contact") {
                    LabeledContent("Email", value: student.email)
                    LabeledContent("Phone", value: student.phone)
                }
            }.navigationTitle("Student profile").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Menu {
                Button("Edit student", systemImage: "pencil") { showEdit = true }
                Button("Delete student", systemImage: "trash", role: .destructive) { confirmDelete = true }
            } label: { Image(systemName: "ellipsis.circle").accessibilityLabel("Student actions") } } }
            .sheet(isPresented: $showEdit) { EditStudentSheet(student: student) }
            .confirmationDialog("Delete this student?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) { Task { if await app.deleteStudent(student) { dismiss() } } }
            } message: { Text("This permanently removes the student record from your tutor account.") }
        }
    }
}

private struct EditStudentSheet: View {
    @EnvironmentObject private var app: AppController
    @Environment(\.dismiss) private var dismiss
    @State var student: Student
    @State private var saving = false
    @State private var error = ""
    var body: some View {
        NavigationStack { Form {
            TextField("Full name", text: $student.name).textContentType(.name)
            TextField("Email address", text: $student.email).keyboardType(.emailAddress).textInputAutocapitalization(.never)
            TextField("Grade", text: $student.grade)
            TextField("Phone", text: $student.phone).keyboardType(.phonePad)
            if !error.isEmpty { Text(error).foregroundStyle(.red).accessibilityLabel("Error: \(error)") }
        }.navigationTitle("Edit student").toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button(saving ? "Saving…" : "Save") { Task {
                saving = true; let ok = await app.updateStudent(student); saving = false
                if ok { dismiss() } else { error = app.toastMessage ?? "Update failed." }
            }}.disabled(saving) }
        }}
    }
}
