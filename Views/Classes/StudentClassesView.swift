import SwiftUI

struct StudentClassesView: View {
    @EnvironmentObject private var app: AppController
    @State private var showScan = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(title: "Your classes", subtitle: "Your schedule and class check-in details.")
                TMCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Eyebrow(text: "NEXT CLASS")
                            Text("Grade 11 Mathematics").font(.headline)
                            Text("Monday · 10:30–11:30").font(.caption).foregroundStyle(TMStyle.muted)
                            Text("Room 02").font(.caption).foregroundStyle(TMStyle.muted)
                        }
                        Spacer()
                        Image(systemName: "calendar").font(.system(size: 32)).foregroundStyle(TMStyle.blue)
                    }
                    PrimaryButton(title: app.nfcCheckedIn ? "Attendance recorded" : "Check in with NFC", icon: "wave.3.right") { showScan = true }
                }
                ForEach(app.sessions.sorted { $0.date < $1.date }) { session in
                    TMCard {
                        HStack {
                            Image(systemName: "book.closed.fill").font(.title2).foregroundStyle(TMStyle.blue)
                                .frame(width: 48, height: 48).background(TMStyle.blueSoft, in: RoundedRectangle(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(session.title).font(.headline).foregroundStyle(TMStyle.ink)
                                Text("\(session.subject) · \(session.time)").font(.caption).foregroundStyle(TMStyle.muted)
                                Text("\(session.date.formatted(date: .abbreviated, time: .omitted)) · \(session.location)").font(.caption).foregroundStyle(TMStyle.muted)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }.padding(18).frame(maxWidth: 700).frame(maxWidth: .infinity, alignment: .topLeading)
        }.background(TMStyle.canvas).navigationTitle("Classes").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showScan) { NFCScanSheet(isTutor: false) }
    }
}
