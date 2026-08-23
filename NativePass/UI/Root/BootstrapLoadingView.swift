import SwiftUI

struct BootstrapLoadingView: View {
    let step: BootstrapStep

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("NativePass")
                .font(.title2.weight(.semibold))

            ProgressView(value: step.progress)
                .progressViewStyle(.linear)
                .frame(maxWidth: 240)

            Text(step.label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: step)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
