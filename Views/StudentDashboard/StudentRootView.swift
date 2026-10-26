import SwiftUI

struct StudentRootView: View {
    @EnvironmentObject private var app: AppController
    @State private var section: StudentSection = .home
    var body: some View {
        TabView(selection: $section) {
            NavigationStack { StudentHomeView(onOpenClasses: { section = .classes }, onOpenProgress: { section = .progress }) }
                .tabItem { Label("Home", systemImage: "house.fill") }.tag(StudentSection.home)
            NavigationStack { StudentClassesView() }
                .tabItem { Label("Classes", systemImage: "calendar") }.tag(StudentSection.classes)
            NavigationStack { StudentProgressView() }
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }.tag(StudentSection.progress)
            NavigationStack { StudentProfileView() }
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }.tag(StudentSection.profile)
        }
        .tint(TMStyle.blue)
        .overlay(alignment: .top) {
            if let message = app.toastMessage {
                Text(message).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 11).background(TMStyle.ink, in: Capsule()).padding(.top, 8)
                    .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { if app.toastMessage == message { app.toastMessage = nil } } }
            }
        }
    }
}
