//
//  ColorChanger.swift
//  EyebrowSegmentation
//
//  Created by yogox on 2021/02/26.
//  Copyright © 2021 Yogox Galaxy. All rights reserved.
//

import SwiftUI
import CoreImage
import Vision


class FacePartColorist {
    // CIContextをインスタンス毎に持つと重くなるのでColorChanger側で持つ
//    private let linearContext = CIContext(options: [.workingColorSpace: kCFNull])

    var partImage: CIImage?
    var coloredPart: CIImage?
    var minLightness: CGFloat?
    var modeLightness: CGFloat?
    var maxLightness: CGFloat?
    var minColor: CIColor?
    var modeColor: CIColor?
    var maxColor: CIColor?
    var gradientImage: CIImage?
    var printRange = true

    func setupPhoto(_ photo: CIImage, _ matte: CIImage) {
        // マット画像で写真を切り抜いて、グレースケール変換
        let cutoutFilter = CICutoutSegmentGray()
        cutoutFilter.inputImage = photo
        cutoutFilter.matteImage = matte
        self.partImage = cutoutFilter.outputImage!
        
        makeImage()
    }
    
    func setupLightness(_ lightness: (minLightness: CGFloat, modeLightness: CGFloat, maxLightness: CGFloat) ) {
        self.minLightness = lightness.minLightness
        self.modeLightness = lightness.modeLightness
        self.maxLightness = lightness.maxLightness

        makeImage()
    }
    
    func setupColor( _ colorChart: (minColor: CIColor, modeColor: CIColor, maxColor: CIColor) ) {
        self.minColor = colorChart.minColor
        self.modeColor = colorChart.modeColor
        self.maxColor = colorChart.maxColor

        makeImage()
    }
    
    func makeImage() {
        guard let partImage = self.partImage
              , let minColor = self.minColor
              , let modeColor = self.modeColor
              , let maxColor = self.maxColor
              , let minLightness = self.minLightness
              , let modeLightness = self.modeLightness
              , let maxLightness = self.maxLightness
        else {
            self.coloredPart = nil
            return
        }
        
        // グラデーションマップを作成
        let gradientFilter = CIIkaHairGradient()
        gradientFilter.minPoint = minLightness
        gradientFilter.modePoint = modeLightness
        gradientFilter.maxPoint = maxLightness
        gradientFilter.minColor = minColor
        gradientFilter.modeColor = modeColor
        gradientFilter.maxColor = maxColor

        // グラデーションマップで毛の色を変更
        let mapFIlter = CIFilter.colorMap()
        mapFIlter.inputImage = partImage
        mapFIlter.gradientImage = gradientFilter.outputImage!
        
        if self.printRange {
            let compositeFilter = CIFilter.sourceOverCompositing()
            let newPhoto = mapFIlter.outputImage!
            // 識別用文字列
            var text = String()
            text += String(format: "min(%.4f) - ", minLightness)
            text += String(format: "max(%.4f)", maxLightness)
            // 識別用テキストを画像化
            let textFilter = CIFilter.textImageGenerator()
            textFilter.fontSize = 30
            textFilter.text = text
            let clumpFilter = CIFilter.colorClamp()
            clumpFilter.inputImage = textFilter.outputImage!
            clumpFilter.minComponents = CIVector(x: 1, y: 1, z: 1, w: 0)
            // 合成写真を回転して識別用テキストを合成
            compositeFilter.inputImage = clumpFilter.outputImage!
            compositeFilter.backgroundImage = newPhoto
            
            self.coloredPart = compositeFilter.outputImage!
            return
        }
        
        self.coloredPart = mapFIlter.outputImage!
    }

}

class ColorChanger: ObservableObject {
    private let linearContext = CIContext(options: [.workingColorSpace: kCFNull])
    private let sRGBContext = CIContext(options: nil)
    private let eyebowColorist = FacePartColorist()

    @Published var image: UIImage?
    var photoImage: CIImage?
    var originalPhoto: CIImage?
    var hairMatte: CIImage?
    var skinMatte: CIImage?
    var eyebowMatte: CIImage?
    var rightEyebowPoints: [CGPoint]?
    var leftEyebowPoints: [CGPoint]?
    var printRange = true

    func setupPhoto(_ photo: CIImage, _ hairMatte: CIImage, _ skinMatte: CIImage) {
        self.originalPhoto = photo

        // Matte画像に合わせて写真のスケールを縮小
        let resizeFilter = CIResizeImageWith()
        resizeFilter.inputImage = photo
        resizeFilter.backgroundImage = hairMatte
        self.photoImage = resizeFilter.outputImage!
        
        self.hairMatte = hairMatte
        self.skinMatte = skinMatte
        // photoとmatteから眉のmatteを作る
        self.eyebowMatte = getEyebowMatte()
        
        if let photoImage = self.photoImage, let eyebowMatte = self.eyebowMatte {
            self.eyebowColorist.setupPhoto(photoImage, eyebowMatte)
        }
        
        if let partImage = self.eyebowColorist.partImage {
            // CGContextを複数持ちたくないのでこちらで明度を計算
            let lightness = computeLightness(partImage)
            eyebowColorist.setupLightness(lightness)
        }
    }
    
    func computeLightness(_ inputImage: CIImage) -> (minLightness: CGFloat, modeLightness: CGFloat, maxLightness: CGFloat) {
        let lightnessInfoFilter = CILightnessInfo()
        lightnessInfoFilter.inputImage = inputImage
        let colorInfo = lightnessInfoFilter.outputImage!

        let point = CGPoint(x: 0, y: 0)
        var bitmap = [UInt8](repeating: 0, count: 4)
        self.linearContext.render(colorInfo, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: point.x, y: point.y, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        let redInteger = Int(bitmap[0].description) ?? 0
        let redc = CGFloat(redInteger)/255
        let greenInteger = Int(bitmap[1].description) ?? 0
        let greenc = CGFloat(greenInteger)/255
        let blueInteger = Int(bitmap[2].description) ?? 0
        let bluec = CGFloat(blueInteger)/255

        print( (redc, greenc, bluec) )
        return (minLightness: redc, modeLightness: greenc, maxLightness: bluec)
    }
    
    func setupColor( _ colorChart: (minColor: CIColor, modeColor: CIColor, maxColor: CIColor) ) {
        self.eyebowColorist.setupColor(colorChart)
    }
    
    func makeImage() {
        guard let photoImage = self.photoImage
        else {
            self.image = nil
            return
        }
        guard let eyebowImage = self.eyebowColorist.coloredPart
        else {
            let cgImage = linearContext.createCGImage(photoImage, from: photoImage.extent)
            self.image = UIImage(cgImage: cgImage!)
            return
        }
        
        // 合成用フィルターを定義
        let compositeFilter = CIFilter.sourceOverCompositing()
        // 色変更した眉を元写真と合成
        compositeFilter.inputImage = eyebowImage
        compositeFilter.backgroundImage = photoImage
        
        let newImage = compositeFilter.outputImage!
        // Imageクラスで描画されるようにCGImage経由でUIImageに変換する必要がある
//        let cgImage = linearContext.createCGImage(newImage, from: newImage.extent)
        let cgImage = sRGBContext.createCGImage(newImage, from: newImage.extent)
        self.image = UIImage(cgImage: cgImage!)
    }
    
    func getEyebowMatte() -> CIImage? {
        guard let photoImage = self.photoImage
              , let hairImage = self.hairMatte
              , let skinImage = self.skinMatte
              , let originalPhoto = self.originalPhoto
        else {
            return nil
        }
        
        let visionRequest = VNDetectFaceLandmarksRequest { (request, error) in
            guard let results = request.results as? [VNFaceObservation] else {
                return
            }
            
            // デバッグで眉のランドマークを描画するための処理
//            let photoCg = self.context.createCGImage(photoImage, from: photoImage.extent)!
//            let photoRect = CGRect(x: 0, y: 0, width: photoCg.width, height: photoCg.height)
//            let cgContext = CGContext(
//                data: nil,
//                width: photoCg.width,
//                height: photoCg.height,
//                bitsPerComponent: photoCg.bitsPerComponent,
//                bytesPerRow: photoCg.bytesPerRow,
//                space: photoCg.colorSpace!,
//                bitmapInfo: photoCg.bitmapInfo.rawValue
//            )
//            cgContext?.draw(photoCg, in: photoRect)
                
            let cgSize = photoImage.extent.size
            print(cgSize)
            
            for observation in results {
                self.rightEyebowPoints = observation.landmarks?.rightEyebrow?.pointsInImage(imageSize: cgSize)
                self.leftEyebowPoints = observation.landmarks?.leftEyebrow?.pointsInImage(imageSize: cgSize)
                
                print("rightEyebrow:")
                print(self.rightEyebowPoints)
                print("leftEyebrow:")
                print(self.leftEyebowPoints)
                
                // デバッグで眉のランドマークを描画するための処理
//                cgContext?.setStrokeColor(UIColor.green.cgColor)
//                cgContext?.addLines(between: self.rightEyebowPoints!)
//                cgContext?.addLines(between: self.leftEyebowPoints!)
//                cgContext?.strokePath()
//
//                let newImage = cgContext?.makeImage()
//                self.image = UIImage(cgImage: newImage!)
            }
            
        }
            
        let handler = VNImageRequestHandler(ciImage: originalPhoto, options: [:])
        try? handler.perform([visionRequest])
        
        guard let rightEyebowPoints = self.rightEyebowPoints, let leftEyebowPoints = self.leftEyebowPoints
        else {
            return nil
        }
        
        let eyebowFIlter = CIGetEyebowMatte()
        eyebowFIlter.inputImage = hairImage
        eyebowFIlter.backgroundImage = skinImage
        eyebowFIlter.rightEyebowPoints = rightEyebowPoints
        eyebowFIlter.leftEyebowPoints = leftEyebowPoints
        //        return eyebowFIlter.outputImage!

        // 最終出力はsRGB色空間でないと色がおかしくなるが、色計算はリニア色空間でないとおかしくなる。
        // CIImage単位で色空間を制御する方法がよくわからないので、
        // とりあえずmatteをCGImageに変換して色空間をリニアで確定させてからCIImageに戻す
        let eyebowMatte = eyebowFIlter.outputImage!
        let cgImage = linearContext.createCGImage(eyebowMatte, from: eyebowMatte.extent)
        let linearEyebowMatte = CIImage(cgImage: cgImage!)

        return linearEyebowMatte
    }
    
    func clear() {
        image = nil
        originalPhoto = nil
        photoImage = nil
        hairMatte = nil
        skinMatte = nil
        eyebowMatte = nil
        rightEyebowPoints = nil
        leftEyebowPoints = nil
    }
}
