import SwiftUI

struct NFCScanSheet: View {
    @EnvironmentObject private var app: AppController
    @Environment(\.dismiss) private var dismiss
    let isTutor: Bool
    @StateObject private var nfc = NFCService()
    @State private var state = 0 // 0 ready, 1 scanning, 2 success, 3 error
    @State private var message = "Hold your iPhone near the TutorMate class NFC tag."

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Spacer()
                Image(systemName: state == 2 ? "checkmark.circle.fill" : (state == 3 ? "exclamationmark.triangle.fill" : "wave.3.right"))
                    .font(.system(size: 74)).foregroundStyle(state == 2 ? TMStyle.green : (state == 3 ? TMStyle.red : TMStyle.blue))
                    .frame(width: 140, height: 140).background(state == 2 ? TMStyle.greenSoft : TMStyle.blueSoft, in: Circle())
                Text(state == 2 ? "Attendance recorded!" : (state == 1 ? "Scanning NFC tag…" : (state == 3 ? "Could not scan tag" : "Ready to scan")))
                    .font(.title2.bold()).foregroundStyle(TMStyle.ink)
                Text(message).multilineTextAlignment(.center).font(.subheadline).foregroundStyle(TMStyle.muted).padding(.horizontal, 22)
                TMCard {
                    HStack {
                        Image(systemName: "book.closed.fill").foregroundStyle(TMStyle.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Grade 11 Mathematics").font(.headline)
                            Text("Monday, 16 June · Room 02").font(.caption).foregroundStyle(TMStyle.muted)
                        }
                        Spacer()
                    }
                }.padding(.horizontal, 20)
                if state == 0 || state == 3 {
                    PrimaryButton(title: "Scan NFC tag", icon: "wave.3.right") {
                        state = 1
                        message = "Keep the top of your iPhone close to the tag."
                        nfc.startScanning { result in
                            switch result {
                            case .success(let payload):
                                Task {
                                    if FirebaseService.shared.isConfigured {
                                        do {
                                            try await FirebaseService.shared.recordAttendance(
                                                tagPayload: payload,
                                                studentEmail: "demo-user@tutormate.app",
                                                role: isTutor ? "tutor" : "student"
                                            )
                                            message = "Tag read and attendance saved to Firebase."
                                        } catch {
                                            message = "Tag read, but Firebase save failed: \(error.localizedDescription)"
                                        }
                                    } else {
                                        message = "Tag read: \(payload). Attendance is marked locally; configure Firebase to sync it online."
                                    }
                                    state = 2
                                    app.nfcCheckedIn = true
                                    app.showToast("NFC tag scanned")
                                }
                            case .failure(let error):
                                state = 3
                                message = error.localizedDescription
                            }
                        }
                    }.padding(.horizontal, 20)
                } else if state == 2 {
                    PrimaryButton(title: "Done", icon: "checkmark") { dismiss() }.padding(.horizontal, 20)
                } else {
                    ProgressView().tint(TMStyle.blue)
                    Button("Cancel scan") { state = 0 }.foregroundStyle(TMStyle.blue)
                }
                Text("Requires a supported physical iPhone and an NDEF-formatted NFC tag. Simulator scanning is not supported.")
                    .font(.caption2).multilineTextAlignment(.center).foregroundStyle(TMStyle.muted).padding(.horizontal, 24)
                Spacer()
            }.frame(maxWidth: .infinity).background(TMStyle.canvas)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
    }
}
