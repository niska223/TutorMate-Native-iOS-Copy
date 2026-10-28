import SwiftUI

struct TutorClassesView: View {
    @EnvironmentObject private var app: AppController

    @State private var showAdd = false
    @State private var search = ""
    @State private var listMode = false

    private var filtered: [ClassSession] {
        app.sessions
            .filter {
                search.isEmpty
                || $0.title.localizedCaseInsensitiveContains(search)
                || $0.subject.localizedCaseInsensitiveContains(search)
            }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(
                    title: "Classes",
                    subtitle: "Plan and manage your teaching schedule."
                )

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(TMStyle.muted)

                    TextField("Search classes", text: $search)
                }
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 13))
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(TMStyle.line)
                )

                HStack {
                    Text("Your schedule")
                        .font(.headline)
                        .foregroundStyle(TMStyle.ink)

                    Spacer()

                    Button {
                        listMode.toggle()
                    } label: {
                        Image(systemName: listMode ? "calendar" : "list.bullet")
                    }
                    .accessibilityLabel(listMode ? "Show calendar view" : "Show list view")

                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.bold)
                            .padding(10)
                            .foregroundStyle(.white)
                            .background(TMStyle.blue, in: RoundedRectangle(cornerRadius: 11))
                    }
                    .accessibilityLabel("Add class")
                }

                if app.isLoadingClasses {
                    ProgressView("Loading saved classes...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                } else if filtered.isEmpty {
                    ContentUnavailableView(
                        search.isEmpty ? "No saved classes yet" : "No classes found",
                        systemImage: "calendar",
                        description: Text(
                            search.isEmpty
                                ? "Add a class to save it to your TutorMate account."
                                : "Try a different class title or subject."
                        )
                    )
                } else {
                    ForEach(filtered) { session in
                        TMCard {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(spacing: 4) {
                                    Text(
                                        session.date.formatted(
                                            .dateTime.month(.abbreviated)
                                        )
                                    )
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(TMStyle.blue)

                                    Text(session.date.formatted(.dateTime.day()))
                                        .font(.title2.bold())
                                        .foregroundStyle(TMStyle.ink)
                                }
                                .frame(width: 54, height: 64)
                                .background(
                                    TMStyle.blueSoft,
                                    in: RoundedRectangle(cornerRadius: 14)
                                )

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(session.title)
                                        .font(.headline)
                                        .foregroundStyle(TMStyle.ink)

                                    Text(session.subject)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(TMStyle.blue)

                                    Label(
                                        "\(session.time) · \(session.duration)",
                                        systemImage: "clock"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(TMStyle.muted)

                                    Label(
                                        session.location,
                                        systemImage: "mappin.and.ellipse"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(TMStyle.muted)

                                    Text("\(session.students) registered students")
                                        .font(.caption)
                                        .foregroundStyle(TMStyle.muted)
                                }

                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(TMStyle.canvas)
        .sheet(isPresented: $showAdd) {
            AddClassSheet()
        }
    }
}

private struct AddClassSheet: View {
    @EnvironmentObject private var app: AppController
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var subject = "Mathematics"
    @State private var date = Date()
    @State private var time = "4:00 PM"
    @State private var location = "Room 02"
    @State private var isSaving = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Class title", text: $title)

                Picker("Subject", selection: $subject) {
                    ForEach(
                        ["Mathematics", "ICT", "Physics", "Science", "Algebra"],
                        id: \.self
                    ) { item in
                        Text(item)
                    }
                }

                DatePicker(
                    "Date",
                    selection: $date,
                    displayedComponents: .date
                )

                TextField("Time (e.g. 4:00 PM)", text: $time)
                TextField("Location", text: $location)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("New class")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        saveClass()
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func saveClass() {
        errorMessage = ""

        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a class title."
            return
        }

        guard !time.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter the class time."
            return
        }

        guard !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter the class location."
            return
        }

        isSaving = true

        Task { @MainActor in
            let saved = await app.addClass(
                title: title,
                subject: subject,
                date: date,
                time: time,
                location: location
            )

            isSaving = false

            if saved {
                dismiss()
            } else {
                errorMessage = app.toastMessage ?? "The class could not be saved. Please try again."
            }
        }
    }
}

