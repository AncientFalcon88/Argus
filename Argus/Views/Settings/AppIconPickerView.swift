import SwiftUI

struct AppIconInfo: Identifiable {
    let id = UUID()
    let name: String
    let iconName: String? // nil for default
    let displayName: String
    let previewName: String // The name of the standard ImageSet to load
}

struct AppIconPickerView: View {
    @State private var currentIconName: String? = UIApplication.shared.alternateIconName

    let icons: [AppIconInfo] = [
        AppIconInfo(name: "Default (Classic)", iconName: nil, displayName: "Argus Classic", previewName: "Argus-flat-Preview"),
        AppIconInfo(name: "Argus 3D", iconName: "Argus-3D-Black", displayName: "Argus 3D", previewName: "Argus-3D-Black-Preview"),
        AppIconInfo(name: "Argus 100 Eyes", iconName: "Argus-100-eyes", displayName: "Argus 100 Eyes", previewName: "Argus-100-eyes-Preview"),
        AppIconInfo(name: "PMDB Classic", iconName: "pmdb-flat", displayName: "PMDB Classic", previewName: "pmdb-flat-Preview"),
        AppIconInfo(name: "PMDB 3D", iconName: "pmdb-3D", displayName: "PMDB 3D", previewName: "pmdb-3D-Preview")
    ]

    let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(icons) { icon in
                    Button {
                        setAppIcon(icon.iconName)
                    } label: {
                        VStack(spacing: 16) {
                            Image(icon.previewName)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )

                            Text(icon.displayName)
                                .font(.subheadline)
                                .fontWeight(currentIconName == icon.iconName ? .bold : .medium)
                                .foregroundStyle(currentIconName == icon.iconName ? .white : .white.opacity(0.7))
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color.white.opacity(currentIconName == icon.iconName ? 0.08 : 0.03))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(currentIconName == icon.iconName ? Color.white : Color.white.opacity(0.05), lineWidth: currentIconName == icon.iconName ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
        .background(GlassTheme.background)
        .navigationTitle("App Icons")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setAppIcon(_ iconName: String?) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        
        // Delay the change to ensure UI runloop is idle, a common cause of NSPOSIXErrorDomain 35
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            UIApplication.shared.setAlternateIconName(iconName) { error in
                if let error = error {
                    print("Failed to set app icon: \(error.localizedDescription)")
                } else {
                    currentIconName = iconName
                }
            }
        }
    }
}
