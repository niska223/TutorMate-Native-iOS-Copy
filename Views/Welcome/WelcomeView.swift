import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var app: AppController
    var body: some View {
        ZStack {
            LinearGradient(colors: [TMStyle.canvas, .white, TMStyle.blueSoft.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 10) {
                        Image(systemName: "graduationcap.fill").font(.title2).foregroundStyle(.white)
                            .frame(width: 46, height: 46).background(TMStyle.blue, in: RoundedRectangle(cornerRadius: 15))
                        Text("TutorMate").font(.title2.bold()).foregroundStyle(TMStyle.ink)
                    }
                    .padding(.top, 24)
                    Eyebrow(text: "A SMARTER WAY TO TEACH & LEARN")
                    VStack(alignment: .leading, spacing: 3) {
                        Text("One learning space.").foregroundStyle(TMStyle.ink)
                        Text("Two experiences.").foregroundStyle(TMStyle.blue)
                    }.font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("TutorMate connects tutors and students with classes, attendance, payments and progress—beautifully in sync.")
                        .font(.body).foregroundStyle(TMStyle.muted).lineSpacing(4)
                    ZStack {
                        RoundedRectangle(cornerRadius: 28).fill(LinearGradient(colors: [TMStyle.blueSoft, TMStyle.violetSoft], startPoint: .topLeading, endPoint: .bottomTrailing))
                        HStack(spacing: 24) {
                            VStack(spacing: 8) {
                                Image(systemName: "ipad.landscape").font(.system(size: 72)).foregroundStyle(TMStyle.blue)
                                Text("Tutor").font(.caption.weight(.semibold)).foregroundStyle(TMStyle.ink)
                            }
                            VStack(spacing: 8) {
                                Image(systemName: "iphone").font(.system(size: 66)).foregroundStyle(TMStyle.violet)
                                Text("Student").font(.caption.weight(.semibold)).foregroundStyle(TMStyle.ink)
                            }
                        }.padding(.vertical, 22)
                    }.frame(height: 150)
                    VStack(spacing: 12) {
                        roleCard(title: "I'm a Tutor", subtitle: "Manage your teaching on iPad", icon: "ipad.landscape", tint: TMStyle.blue) {
                            app.route = .tutorAuth
                        }
                        roleCard(title: "I'm a Student", subtitle: "Learn and check in on iPhone", icon: "iphone", tint: TMStyle.violet) {
                            app.route = .studentAuth
                        }
                    }
                    HStack(spacing: 7) {
                        Image(systemName: "lock.shield.fill")
                        Text("Securely synced across devices")
                    }.font(.caption).foregroundStyle(TMStyle.muted).frame(maxWidth: .infinity).padding(.top, 4)
                }.padding(22).frame(maxWidth: 650).frame(maxWidth: .infinity)
            }
        }
    }
    private func roleCard(title: String, subtitle: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title2).foregroundStyle(tint).frame(width: 54, height: 54)
                    .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(TMStyle.ink)
                    Text(subtitle).font(.caption).foregroundStyle(TMStyle.muted)
                }
                Spacer()
                Image(systemName: "arrow.right").foregroundStyle(tint)
            }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 19))
                .overlay(RoundedRectangle(cornerRadius: 19).stroke(TMStyle.line, lineWidth: 1))
        }.buttonStyle(.plain)
    }
}
