import SwiftUI

struct ImportRecipeSheetView: View {
    @Binding var isPresented: Bool
    @Binding var importJsonString: String
    var onImport: () -> Void
    
    @FocusState private var isInputActive: Bool
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Deep dark background matching the app's aesthetic
                Color(red: 0.11, green: 0.11, blue: 0.12).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Icon
                        ZStack {
                            LinearGradient(
                                colors: [Color.blue.opacity(0.8), Color.blue],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 32, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Color.blue.opacity(0.5), radius: 12, x: 0, y: 6)
                        .padding(.top, 32)
                        
                        // Title & Subtitle
                        VStack(spacing: 8) {
                            Text("Import Recipe")
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Paste a recipe JSON from Discord, GitHub, or a friend to instantly create a new pick.")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        
                        // Action: Paste from Clipboard
                        Button(action: {
                            if let string = UIPasteboard.general.string {
                                importJsonString = string
                            }
                        }) {
                            HStack {
                                Image(systemName: "doc.on.clipboard")
                                Text("Paste from Clipboard")
                            }
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                        }
                        .padding(.horizontal, 24)
                        
                        // Text Editor
                        VStack(alignment: .leading, spacing: 8) {
                            Text("JSON DATA")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.gray)
                                .padding(.leading, 4)
                            
                            TextEditor(text: $importJsonString)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(minHeight: 200, maxHeight: 300)
                                .padding(16)
                                .scrollContentBackground(.hidden)
                                .background(Color.black.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                                .focused($isInputActive)
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 40)
                }
                .onTapGesture {
                    isInputActive = false
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        importJsonString = ""
                        isPresented = false
                    }
                    .tint(.blue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        isPresented = false
                        onImport()
                    }
                    .tint(.blue)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .disabled(importJsonString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isInputActive = false
                    }
                }
            }
        }
    }
}
