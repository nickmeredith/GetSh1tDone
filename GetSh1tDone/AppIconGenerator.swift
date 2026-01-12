import SwiftUI

// This view can be used to generate app icons
// Run this in a preview or simulator and take screenshots at the required sizes
struct AppIconView: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Background with gradient (matches app header logo)
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.2, green: 0.4, blue: 1.0),  // Blue
                    Color(red: 0.6, green: 0.2, blue: 0.8)   // Purple
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Main icon content (matches app header design)
            HStack(spacing: size * 0.12) {
                // Checkmark circle with gradient background
                ZStack {
                    // Outer circle with gradient
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.2, green: 0.4, blue: 1.0),
                                    Color(red: 0.6, green: 0.2, blue: 0.8)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size * 0.55, height: size * 0.55)
                        .shadow(color: Color.black.opacity(0.2), radius: size * 0.03, x: 0, y: size * 0.02)
                    
                    // White checkmark
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: size * 0.35, weight: .medium))
                        .foregroundColor(.white)
                }
                
                // Lightning bolt (orange)
                Image(systemName: "bolt.fill")
                    .font(.system(size: size * 0.32, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.0)) // Orange
                    .offset(x: -size * 0.12, y: 0)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2)) // Rounded corners for app icon
    }
}

// Preview for generating icons
struct AppIconView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Standard iOS app icon sizes
            AppIconView(size: 1024)
                .previewLayout(.fixed(width: 1024, height: 1024))
                .previewDisplayName("1024x1024 (App Store)")
            
            AppIconView(size: 180)
                .previewLayout(.fixed(width: 180, height: 180))
                .previewDisplayName("180x180 (iPhone)")
            
            AppIconView(size: 167)
                .previewLayout(.fixed(width: 167, height: 167))
                .previewDisplayName("167x167 (iPad Pro)")
        }
    }
}
