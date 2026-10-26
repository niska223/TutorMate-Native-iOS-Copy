import SwiftUI

struct WidgetPreviewSheet: View {
    @EnvironmentObject private var app: AppController
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageTitle(title: "WidgetKit Preview", subtitle: "Stay ready from your Home Screen.")
                    TMCard {
                        HStack {
                            Image(systemName: "graduationcap.fill").foregroundStyle(.white).frame(width: 34, height: 34).background(TMStyle.blue, in: RoundedRectangle(cornerRadius: 10))
                            Text("TutorMate").font(.headline)
                            Spacer()
                            Text("9:41").font(.caption).foregroundStyle(TMStyle.muted)
                        }
                        Divider()
                        Eyebrow(text: "NEXT CLASS")
                        Text("Grade 11 Mathematics").font(.headline)
                        Label("10:30 AM · Room 02", systemImage: "clock").font(.caption).foregroundStyle(TMStyle.muted)
                        HStack {
                            Label("\(app.studentPoints) pts", systemImage: "star.fill").foregroundStyle(TMStyle.orange)
                            Spacer()
                            StatusPill(text: "Ready")
                        }.font(.caption.weight(.semibold))
                    }
                    Text("This is a static in-app preview. A real home-screen widget needs a separate Widget Extension target.")
                        .font(.caption).foregroundStyle(TMStyle.muted)
                }.padding(20)
            }.background(TMStyle.canvas).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
