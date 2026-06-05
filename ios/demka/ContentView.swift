import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: DeckViewModel

    var body: some View {
        ZStack {
            if vm.isClickerMode {
                ClickerRemoteView()
                    .environmentObject(vm)
                    .transition(.opacity)
            } else if vm.showEditor {
                EditorView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .leading)
                    ))
            } else {
                DeckView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            }

            if vm.isLoadingShare {
                Color.black.opacity(0.45).ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.4)
            }

        }
        .animation(.easeInOut(duration: 0.3), value: vm.showEditor)
        .animation(.easeInOut(duration: 0.3), value: vm.isClickerMode)
        .alert("Could not load share", isPresented: Binding(
            get: { vm.shareError != nil },
            set: { if !$0 { vm.shareError = nil } }
        )) {
            Button("OK", role: .cancel) { vm.shareError = nil }
        } message: {
            Text(vm.shareError ?? "")
        }
    }
}
