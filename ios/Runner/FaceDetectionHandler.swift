import Foundation
import UIKit
import Vision
import CoreML

class DrowsinessDetector {
    private var model: VNCoreMLModel
    private var request: VNCoreMLRequest
    
    init?() {
        // Initialize the Core ML model
        guard let mlmodel = try? DrowsinessClassifier().model,
              let vnModel = try? VNCoreMLModel(for: mlmodel) else {
            return nil
        }
        self.model = vnModel
        self.request = VNCoreMLRequest(model: model)
    }
    
    func detectFace(in uiImage: UIImage, completion: @escaping (Bool) -> Void) {
        guard let cgImage = uiImage.cgImage else {
            completion(false)
            return
        }
        
        let faceDetectionRequest = VNDetectFaceRectanglesRequest { (req, err) in
            guard err == nil else {
                completion(false)
                return
            }
            
            // Assume one face (driver) is present
            guard let results = req.results as? [VNFaceObservation],
                  let face = results.first else {
                completion(false)
                return
            }
            
            let boundingBox = face.boundingBox
            let width = uiImage.size.width
            let height = uiImage.size.height
            let faceRect = CGRect(
                x: boundingBox.origin.x * width,
                y: (1 - boundingBox.origin.y - boundingBox.height) * height,
                width: boundingBox.width * width,
                height: boundingBox.height * height
            )
            
            guard let faceImage = self.cropImage(uiImage, to: faceRect) else {
                completion(false)
                return
            }
            
            // Classify if drowsy or not
            self.classifyDrowsiness(faceImage: faceImage, completion: completion)
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([faceDetectionRequest])
    }
    
    private func classifyDrowsiness(faceImage: UIImage, completion: @escaping (Bool) -> Void) {
        guard let cgImage = faceImage.cgImage else {
            completion(false)
            return
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        request.imageCropAndScaleOption = .scaleFit
        
        do {
            try handler.perform([request])
            if let results = request.results as? [VNClassificationObservation],
               let bestResult = results.first {
                // Check label
                let isDrowsy = (bestResult.identifier == "drowsy") // adjust based on your model’s labels
                completion(isDrowsy)
            } else {
                completion(false)
            }
        } catch {
            completion(false)
        }
    }
    
    private func cropImage(_ image: UIImage, to rect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage?.cropping(to: rect) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
