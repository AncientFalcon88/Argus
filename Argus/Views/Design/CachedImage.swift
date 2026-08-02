import SwiftUI
import CoreImage

// MARK: - Dominant Color Extraction
extension UIImage {
    /// Extracts the average color of the image using CIAreaAverage (fast, Apple-native).
    func dominantColor() -> UIColor? {
        let targetSize = CGSize(width: 40, height: 60)
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        draw(in: CGRect(origin: .zero, size: targetSize))
        let thumb = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let cgImage = (thumb ?? self).cgImage,
              let ciInput = CIImage(cgImage: cgImage) else { return nil }
        let filter = CIFilter(name: "CIAreaAverage",
                              parameters: [kCIInputImageKey: ciInput,
                                           kCIInputExtentKey: CIVector(cgRect: ciInput.extent)])
        guard let output = filter?.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        let ctx = CIContext(options: [.workingColorSpace: NSNull()])
        ctx.render(output, toBitmap: &bitmap, rowBytes: 4,
                   bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                   format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return UIColor(red: CGFloat(bitmap[0]) / 255,
                       green: CGFloat(bitmap[1]) / 255,
                       blue: CGFloat(bitmap[2]) / 255,
                       alpha: 1.0)
    }

    /// Boosted saturation/brightness version — makes the color pop on badge backgrounds.
    func vibrantDominantColor() -> UIColor? {
        guard let base = dominantColor() else { return nil }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        base.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let boostedS = min(s * 1.5 + 0.2, 1.0)
        let boostedB = max(min(b * 1.1, 0.75), 0.35)
        return UIColor(hue: h, saturation: boostedS, brightness: boostedB, alpha: a)
    }
}

class ImageCache {
    static let shared = NSCache<NSURL, UIImage>()

    // Configure cache size limits
    static func configure() {
        shared.countLimit = 100 // maximum 100 images
        shared.totalCostLimit = 1024 * 1024 * 100 // 100 MB max
    }
}

@MainActor
class ImageLoader: ObservableObject {
    @Published var image: Image?
    @Published var isLoading = false
    
    private var url: URL?
    private var task: Task<Void, Never>?
    
    init(url: URL?) {
        self.url = url
    }
    
    func update(url: URL?) {
        guard self.url != url else { return }
        self.url = url
        self.cancel()
        self.image = nil
        self.isLoading = false
        self.load()
    }
    
    func load() {
        guard let url = url else { return }
        
        if let cached = ImageCache.shared.object(forKey: url as NSURL) {
            self.image = Image(uiImage: cached)
            return
        }
        
        guard !isLoading && image == nil else { return }
        isLoading = true
        
        task = Task {
            do {
                let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
                let (data, _) = try await URLSession.shared.data(for: request)
                
                if let uiImage = UIImage(data: data) {
                    ImageCache.shared.setObject(uiImage, forKey: url as NSURL, cost: data.count)
                    if !Task.isCancelled {
                        self.image = Image(uiImage: uiImage)
                    }
                }
            } catch {
                // Ignore errors like cancellation
            }
            if !Task.isCancelled {
                self.isLoading = false
            }
        }
    }
    
    func cancel() {
        task?.cancel()
    }
}

struct CachedImage<Placeholder: View>: View {
    @StateObject private var loader: ImageLoader
    private let contentMode: ContentMode
    private let placeholder: () -> Placeholder
    private let url: URL?
    
    init(url: URL?, contentMode: ContentMode = .fill, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        _loader = StateObject(wrappedValue: ImageLoader(url: url))
        self.contentMode = contentMode
        self.placeholder = placeholder
        self.url = url
    }
    
    var body: some View {
        Group {
            if let image = loader.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .clipped()
            } else {
                placeholder()
            }
        }
        .onAppear {
            loader.load()
        }
        .onChange(of: url) { _, newURL in
            loader.update(url: newURL)
        }
        .onDisappear {
            // We do not cancel the task aggressively here.
            // If they scroll quickly, we still want the image to fetch and enter the NSCache
            // so that when they scroll back, it's instantly ready.
        }
    }
}
