#if os(iOS)
import SwiftUI
import VisionKit

/// The system document scanner (edge detection + perspective correction), which gives OCR
/// a much cleaner image of a flyer than a plain camera photo. Returns the first page as JPEG.
struct DocumentCameraView: UIViewControllerRepresentable {
    let onScan: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isSupported: Bool { VNDocumentCameraViewController.isSupported }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentCameraView

        init(parent: DocumentCameraView) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            if scan.pageCount > 0, let data = scan.imageOfPage(at: 0).jpegData(compressionQuality: 0.9) {
                parent.onScan(data)
            }
            parent.dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            parent.dismiss()
        }
    }
}
#endif
