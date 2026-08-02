import SwiftUI

extension View {
    func mediaDetailDestination() -> some View {
        self
            .navigationDestination(for: MediaDetailRoute.self) { route in
                MediaDetailView(route: route)
            }
            .navigationDestination(for: PersonDetailRoute.self) { route in
                PersonDetailView(route: route)
            }
    }
}

struct MediaDetailLink<Label: View>: View {
    let route: MediaDetailRoute
    @ViewBuilder var label: () -> Label

    var body: some View {
        NavigationLink(value: route) {
            label()
        }
        .buttonStyle(.plain)
    }
}
struct PersonDetailLink<Label: View>: View {
    let route: PersonDetailRoute
    @ViewBuilder var label: () -> Label

    var body: some View {
        NavigationLink(value: route) {
            label()
        }
        .buttonStyle(.plain)
    }
}
