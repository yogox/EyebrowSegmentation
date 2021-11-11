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

extension Array where Element == CGPoint {
    func getEyebrowCenter() -> CGPoint {
        //        let pointsSum = reduce(CGPoint.zero) {
        //            return $0 + $1
        //        }
        //        let centerPoint = pointsSum / count
                //                let pointsSum = self[1] + self[4]
        //                        let centerPoint = pointsSum / 2
        //        let centerPoint = (self[1] + self[4]) / 2
        // とりあえず中央の2点からこれくらいの比率で決め打ちがよさげ
        let centerPoint = (self[1] * 0.15) + (self[4] * 0.85)

        return centerPoint
    }
    
    func expandEyebrow(_ rate: CGFloat, aspect: CGFloat = 1.0, angle: CGFloat = 0.0) -> [CGPoint] {
        guard count == 6 else { return [CGPoint.zero] }
        let centerPoint = getEyebrowCenter()
        let newPoints = rotateAndExpantFrom(centerPoint, rate: rate, aspect: aspect, angle: angle)
        
        return newPoints
    }
    
    func getConnectedEyebrowCenter() -> CGPoint {
        var horizontalElemetns: [CGPoint] = []
        horizontalElemetns.append(contentsOf: self[2...3])
        horizontalElemetns.append(contentsOf: self[8...9])
        let horizontalCenter = horizontalElemetns.average()
        
        var verticalElements: [CGPoint] = []
        verticalElements.append(self[1])
        verticalElements.append(self[4])
        verticalElements.append(self[7])
        verticalElements.append(self[10])
        let verticalCenter = verticalElements.average()

        let centerPoint = CGPoint(x: horizontalCenter.x, y: verticalCenter.y)
        return centerPoint
    }
}

class FacePartColorist {
    var matte: CIImage?
    var partImage: CIImage?
    var coloredPart: CIImage?
    var minLightness: CGFloat?
    var modeLightness: CGFloat?
    var maxLightness: CGFloat?
    var minColor: CIColor?
    var modeColor: CIColor?
    var maxColor: CIColor?
    var gradientImage: CIImage?

    func setupPhoto(_ photo: CIImage, _ matte: CIImage) {
        self.matte = matte
        
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
        
        self.coloredPart = mapFIlter.outputImage!
    }
    
    func printRange(_ y: CGFloat) {
        guard let coloredPart = self.coloredPart,
              let minLightness = self.minLightness,
              let modeLightness = self.modeLightness,
              let maxLightness = self.maxLightness
        else { return }
        
        let compositeFilter = CIFilter.sourceOverCompositing()

        // 識別用文字列
        var text = String()
        text += String(format: "min(%.4f) - ", minLightness)
        text += String(format: "mode(%.4f) - ", modeLightness)
        text += String(format: "max(%.4f)", maxLightness)
        // 識別用テキストを画像化
        let textFilter = CIFilter.textImageGenerator()
        textFilter.fontSize = 30
        textFilter.text = text
        let clumpFilter = CIFilter.colorClamp()
        clumpFilter.inputImage = textFilter.outputImage!
        clumpFilter.minComponents = CIVector(x: 1, y: 1, z: 1, w: 0)
        
        let trans = CGAffineTransform(CGPoint(x: 0, y: y))
        // 合成写真を回転して識別用テキストを合成
        compositeFilter.inputImage = clumpFilter.outputImage!.transformed(by: trans)
        compositeFilter.backgroundImage = coloredPart
        
        self.coloredPart = compositeFilter.outputImage!
    }

    func clear() {
        matte = nil
        partImage = nil
        coloredPart = nil
        minLightness = nil
        modeLightness = nil
        maxLightness = nil
        minColor = nil
        modeColor = nil
        maxColor = nil
        gradientImage = nil
    }
}

class ColorChanger: ObservableObject {
    enum FacePart: Int, CaseIterable {
        // 髪の毛
        case hair = 0
        // 眉毛
        case eyebrows
        // 厚い眉毛（とりあえずは別々に管理しておく）
        case thickEyebrows
    }
    
    private let linearContext = CIContext(options: [.workingColorSpace: kCFNull])
    private let sRGBContext = CIContext(options: nil)
    private let detector: CIDetector?
    private let facePartColorists: [FacePart: FacePartColorist] = [
        .hair: FacePartColorist(),
        .eyebrows: FacePartColorist(),
        .thickEyebrows: FacePartColorist()
    ]

    @Published var image: UIImage?
    var photoImage: CIImage?
    var originalPhoto: CIImage?
    var hairMatte: CIImage?
    var skinMatte: CIImage?
    var portraitMatte: CIImage?
    var eyebrowMatte: CIImage?
    var rightEyebrowPoints: [CGPoint]?
    var leftEyebrowPoints: [CGPoint]?
    var faceRoll: Float = 0
    var expantionRate: CGFloat = 0.5
    let eyebrowAspect: CGFloat = 2.0
    var printRange = true
    var thickenEyebrow = true
    let blurRadius:Float = 6
    let shiftRadius:CGFloat = 5
    let times = 4
    var checkSegmentation = false
    var checkEyebrowPart = false

    private var error = MyError()

    init() {
        detector = CIDetector(ofType: CIDetectorTypeFace, context: linearContext, options: nil)
        if thickenEyebrow == true {
            print("thickenEyebrow")
        }
    }

    func setupPhoto(_ photo: CIImage, _ hairMatte: CIImage, _ skinMatte: CIImage, _ portraitMatte: CIImage) {
        self.originalPhoto = photo

        // Matte画像に合わせて写真のスケールを縮小
        let resizeFilter = CIResizeImageWith()
        resizeFilter.inputImage = photo
        resizeFilter.backgroundImage = hairMatte
        self.photoImage = resizeFilter.outputImage!
        
        self.hairMatte = hairMatte
        self.skinMatte = skinMatte
        self.portraitMatte = portraitMatte
        // photoとmatteから眉のmatteを作る
        self.eyebrowMatte = getEyebrowMatte()
        
        setupAndCompute(part: .hair, photo: self.photoImage!, matte: self.hairMatte!)
        
        if let photoImage = self.photoImage, let eyebrowMatte = self.eyebrowMatte {
            setupAndCompute(part: .eyebrows, photo: photoImage, matte: eyebrowMatte)
            if self.thickenEyebrow == true,
                let partImage = facePartColorists[.eyebrows]?.partImage,
                let portraitMatte = self.portraitMatte {
                // 眉画像を元に厚い眉を作る
                let filter = CIShiftAndStack()
                filter.inputImage = partImage
                filter.matte = eyebrowMatte
                filter.startAngle = CGFloat(faceRoll)
                filter.times = times
                filter.radius = shiftRadius
                // 眉matteも厚くする
                let matteFilter = CIThickenMatte()
                matteFilter.inputImage = eyebrowMatte
                matteFilter.portraitMatte = portraitMatte

                setupAndCompute(part: .thickEyebrows, photo: filter.outputImage!, matte: matteFilter.outputImage!)
            }
        }
    }
    
    func setupAndCompute(part: FacePart, photo: CIImage, matte: CIImage) {
        if let colorist = facePartColorists[part] {
            colorist.setupPhoto(photo, matte)
            if let partImage = colorist.partImage {
                let lightness = computeLightness(partImage)
                colorist.setupLightness(lightness)
            }
        }
    }
    
    func computeLightness(_ inputImage: CIImage) -> (minLightness: CGFloat, modeLightness: CGFloat, maxLightness: CGFloat) {
        let lightnessInfoFilter = CILightnessInfo()
        lightnessInfoFilter.inputImage = inputImage
        let colorInfo = lightnessInfoFilter.outputImage!
        
        let color = colorInfo.getColorAtPoint(context: linearContext)
        print(color)
        
        return (minLightness: color.red, modeLightness: color.green, maxLightness: color.blue)
    }
    
    func setupColor( _ colorChart: (minColor: CIColor, modeColor: CIColor, maxColor: CIColor) ) {
        for part in FacePart.allCases {
            facePartColorists[part]?.setupColor(colorChart)
        }
    }
    
    func makeImage() {
        guard checkSegmentation == false else { return }
        guard checkEyebrowPart == false
        else {
//            if let matte = self.eyebrowColorist.matte, let image = self.eyebrowColorist.partImage {
            if let matte = facePartColorists[.eyebrows]?.matte, let image = facePartColorists[.eyebrows]?.coloredPart {
                // 背景用フィルター
                let gradientFilter = CIFilter.linearGradient()
                gradientFilter.point0 = CGPoint(x: 0, y: 0)
                gradientFilter.color0 = CIColor.magenta
                gradientFilter.point1 = CGPoint(x: image.extent.width, y: image.extent.height)
                gradientFilter.color1 = CIColor.green

                // 合成用フィルターを定義
                let compositeFilter = CIFilter.sourceOverCompositing()
                let maskFIlter = CIFilter.maskToAlpha()
                maskFIlter.inputImage = matte
                let bgImage = gradientFilter.outputImage!.cropped(to: image.extent)
                compositeFilter.backgroundImage = bgImage
                compositeFilter.inputImage = maskFIlter.outputImage!
                
                let lowerTrans = CGAffineTransform(CGPoint(x: 0, y: -150))
                compositeFilter.backgroundImage = compositeFilter.outputImage!
                compositeFilter.inputImage = image.transformed(by: lowerTrans)
                
                if thickenEyebrow  == true,
                   let thickMatte = facePartColorists[.thickEyebrows]?.matte,
//                   let thickeImage = self.eyebrowColorist2.partImage {
                    let thickeImage = facePartColorists[.thickEyebrows]?.coloredPart {
                    maskFIlter.inputImage = thickMatte
                    var lowerTrans = CGAffineTransform(CGPoint(x: 0, y: -300))
                    compositeFilter.backgroundImage = compositeFilter.outputImage!
                    compositeFilter.inputImage = maskFIlter.outputImage!.transformed(by: lowerTrans)
                    
                    lowerTrans = CGAffineTransform(CGPoint(x: 0, y: -450))
                    compositeFilter.backgroundImage = compositeFilter.outputImage!
                    compositeFilter.inputImage = thickeImage.transformed(by: lowerTrans)
                }
                let ciImage = compositeFilter.outputImage!
                let cgImage = sRGBContext.createCGImage(ciImage, from: ciImage.extent)
                self.image = UIImage(cgImage: cgImage!)
            }
            return
        }
        
        for part in FacePart.allCases {
            facePartColorists[part]?.printRange(CGFloat(part.rawValue * 50))
        }
        
        guard let photoImage = self.photoImage
        else {
            self.image = nil
            error.setError(.photoImageError)
            return
        }
        
        let eyebrowImage:CIImage?
        if thickenEyebrow  == true {
            eyebrowImage = facePartColorists[.thickEyebrows]?.coloredPart
        } else {
            eyebrowImage = facePartColorists[.eyebrows]?.coloredPart
        }
        
        guard let eyebrowImage = eyebrowImage
        else {
//            let cgImage = linearContext.createCGImage(photoImage, from: photoImage.extent)
//            self.image = UIImage(cgImage: cgImage!)
            self.image = nil
            error.setError(.eyebrowImageError)
            return
        }
        
        // 合成用フィルターを定義
        let compositeFilter = CIFilter.sourceOverCompositing()
        guard let hairImage = facePartColorists[.hair]?.coloredPart
        else {
            let cgImage = linearContext.createCGImage(photoImage, from: photoImage.extent)
            self.image = UIImage(cgImage: cgImage!)
            error.setError(.hairImageError)
            return
        }
        compositeFilter.inputImage = hairImage
        compositeFilter.backgroundImage = photoImage
        compositeFilter.backgroundImage = compositeFilter.outputImage!
        // 色変更した眉を元写真と合成
        compositeFilter.inputImage = eyebrowImage
        
        let newImage = compositeFilter.outputImage!
        // Imageクラスで描画されるようにCGImage経由でUIImageに変換する必要がある
        let cgImage = sRGBContext.createCGImage(newImage, from: newImage.extent)
        self.image = UIImage(cgImage: cgImage!)
    }
    
    func getEyebrowMatte() -> CIImage? {
        guard let photoImage = self.photoImage
              , let hairMatte = self.hairMatte
              , let skinMatte = self.skinMatte
              , let originalPhoto = self.originalPhoto
        else {
            return nil
        }

        getFaceData()

        guard let baseRightEyebrowPoints = rightEyebrowPoints, let baseLeftEyebrowPoints = leftEyebrowPoints
        else {
            return nil
        }
        
        let roll = CGFloat(-faceRoll)
        let expandedRightEyebrowPoints
            = baseRightEyebrowPoints.expandEyebrow(expantionRate, aspect: eyebrowAspect, angle: roll)
        let expandedLeftEyebrowPoints
            = baseLeftEyebrowPoints.expandEyebrow(expantionRate, aspect: eyebrowAspect, angle: roll)
//        print("new rightEyebrowPoints")
//        print(expandedRightEyebrowPoints)
//        print("new leftEyebrowPoints")
//        print(expandedLeftEyebrowPoints)
        
        var connectedEybrowPoints
            = connectEyebrow(rightEyebrow: baseRightEyebrowPoints, leftEyebrow: baseLeftEyebrowPoints)
        
        var connectedExtended
            = connectEyebrow(rightEyebrow: expandedRightEyebrowPoints, leftEyebrow: expandedLeftEyebrowPoints)
        
        // 左眉と右眉の領域の交差をチェックし、交差している場合は2点を交点にまとめる
        let lowerIntersection = calculateIntersection(
            (connectedExtended[7], connectedExtended[8]),
            (connectedExtended[9], connectedExtended[10]))
        if let intersection = lowerIntersection {
            connectedExtended.remove(at: 9)
            connectedExtended[8] = intersection
        }
        let upperIntersection = calculateIntersection(
            (connectedExtended[1], connectedExtended[2]),
            (connectedExtended[3], connectedExtended[4]))
        if let intersection = upperIntersection {
            connectedExtended.remove(at: 3)
            connectedExtended[2] = intersection
        }

        let eyebrowFIlter = CIGetEyebrowMatte()
        eyebrowFIlter.inputImage = hairMatte
        eyebrowFIlter.backgroundImage = skinMatte
        eyebrowFIlter.eyebrowPoints = connectedExtended
        
        // 眉のランドマークを拡大したことで顔の外を取ってしまうケースがあるのでportraitMatteを減算する
        let infIlter = CIFilter.sourceInCompositing()
        let maskFilter = CIFilter.maskToAlpha()
        maskFilter.inputImage = self.portraitMatte
        infIlter.inputImage = eyebrowFIlter.outputImage!
        infIlter.backgroundImage = maskFilter.outputImage!

        // MARK: 目も取ってしまうケースがあるので、本来なら目のランドマーク分を除去する必要がある
        // 自分が最終的に作りたいものには不要となる処理なので追加しない

        // 最終出力はsRGB色空間でないと色がおかしくなるが、色計算はリニア色空間でないとおかしくなる。
        // CIImage単位で色空間を制御する方法がよくわからないので、
        // とりあえずmatteをCGImageに変換して色空間をリニアで確定させてからCIImageに戻す
        let eyebrowMatte = infIlter.outputImage!
        let cgImage = linearContext.createCGImage(eyebrowMatte, from: eyebrowMatte.extent)
        let linearEyebrowMatte = CIImage(cgImage: cgImage!)
        
        // 領域チェック用 START
        if checkSegmentation == true {
            let pointRadius: CGFloat = 10
            
            let invertFilter = CIFilter.colorInvert()
            invertFilter.inputImage = hairMatte
            let invertHair = invertFilter.outputImage!
            let cgHair = linearContext.createCGImage(invertHair, from: invertHair.extent)
            invertFilter.inputImage = skinMatte
            let invertSkin = invertFilter.outputImage!
            let cgSkin = linearContext.createCGImage(invertSkin, from: invertSkin.extent)

            let clampFilter = CIFilter.colorClamp()
            clampFilter.maxComponents = CIVector(x: 1, y: 0, z: 0, w: 1)
            clampFilter.inputImage = invertSkin
            let redSkin = clampFilter.outputImage!
            clampFilter.maxComponents = CIVector(x: 0, y: 1, z: 1, w: 1)
            clampFilter.inputImage = linearEyebrowMatte
            let greenEyebrow = clampFilter.outputImage!
            
            let addFilter = CIFilter.additionCompositing()
            addFilter.inputImage = redSkin
            addFilter.backgroundImage = greenEyebrow
            let compareImage = addFilter.outputImage!
            let cgImage2 = linearContext.createCGImage(compareImage, from: compareImage.extent)
            let linearCompare = CIImage(cgImage: cgImage2!)
            
            let photoRect = CGRect(x: 0, y: 0, width: cgImage2!.width, height: cgImage2!.height)
            let cgContext = CGContext(
                data: nil,
                width: cgImage2!.width,
                height: cgImage2!.height,
                bitsPerComponent: cgImage2!.bitsPerComponent,
                bytesPerRow: cgImage2!.bytesPerRow,
                space: cgImage2!.colorSpace!,
                bitmapInfo: cgImage2!.bitmapInfo.rawValue
            )
            cgContext?.draw(cgImage2!, in: photoRect)
            cgContext?.setLineWidth(4.0)
            cgContext?.setStrokeColor(UIColor.green.cgColor)
            cgContext?.addLines(between: baseRightEyebrowPoints)
            cgContext?.addLines(between: baseLeftEyebrowPoints)
            cgContext?.strokePath()
            
            cgContext?.setStrokeColor(UIColor.cyan.cgColor)
            cgContext?.addLines(between: expandedRightEyebrowPoints)
            cgContext?.addLines(between: expandedLeftEyebrowPoints)
            cgContext?.strokePath()
            cgContext?.setStrokeColor(UIColor.magenta.cgColor)
            cgContext?.addLines(between: connectedExtended)
            cgContext?.strokePath()
            
            let rightCenter = baseRightEyebrowPoints.getEyebrowCenter()
            let leftCenter = baseLeftEyebrowPoints.getEyebrowCenter()
            cgContext?.setFillColor(UIColor.yellow.cgColor)
            let rightRect = CGRect(origin: rightCenter, radius: pointRadius)
            let leftRect = CGRect(origin: leftCenter, radius: pointRadius)
            cgContext?.fillEllipse(in: rightRect)
            cgContext?.fillEllipse(in: leftRect)
            
            cgContext?.setStrokeColor(UIColor.magenta.cgColor)
            cgContext?.addLines(between: connectedEybrowPoints)
            cgContext?.strokePath()

            let newImage = cgContext?.makeImage()
            self.image = UIImage(cgImage: newImage!)
        }
        // 領域チェック用 END

//        saveCIImage(linearEyebrowMatte)
//        saveCIImage(invertSkin)
//        saveCIImage(invertHair)

        return linearEyebrowMatte
    }
    
    func getFaceData() {
        guard let photoImage = self.photoImage
              , let originalPhoto = self.originalPhoto
        else {
            return
        }
        
        // CIDetectorで顔の角度(roll)を取得する(Visionは45°単位でしか取得できない)
        let features = detector!.features(in: originalPhoto, options: [CIDetectorEyeBlink : true])
        print("CIFaceFeature count: ", terminator: "")
        print(features.count)

        if features.count > 0 {
            (features as? [CIFaceFeature])?.forEach {
                print("bounds:")
                print($0.bounds) // yの位置が上下判定しているので注意!!
                print("hasFaceAngle: ", terminator: "")
                print($0.hasFaceAngle)
                print("faceAngle: ", terminator: "")
                self.faceRoll = $0.faceAngle * .pi / 180
                print(faceRoll)
                print("leftEyeClosed: ", terminator: "")
                print($0.leftEyeClosed)
                print("rightEyeClosed: ", terminator: "")
                print($0.rightEyeClosed)
            }
        } else {
            self.error.setError(.ciDetectorNoHuman)
        }
        
        // 眉のランドマークを取得する
        let visionRequest = VNDetectFaceLandmarksRequest { (request, error) in
            guard let results = request.results as? [VNFaceObservation] else {
                self.error.setError(.visionFailure)
                return
            }
            
            let matteSize = photoImage.extent.size
            print(matteSize)
            
            if results.count == 0 {
                self.error.setError(.visionFailureNoHuman)
            }
            
            for observation in results {
                self.rightEyebrowPoints = observation.landmarks?.rightEyebrow?.pointsInImage(imageSize: matteSize)
                self.leftEyebrowPoints = observation.landmarks?.leftEyebrow?.pointsInImage(imageSize: matteSize)
                
//                print("rightEyebrow:")
//                print(self.rightEyebrowPoints)
//                print("leftEyebrow:")
//                print(self.leftEyebrowPoints)
                
//                print("VNFaceObservation angle")
//                print(observation.roll)
//                print(observation.yaw)
//                print(observation.pitch)
            }
            
        }
            
        let handler = VNImageRequestHandler(ciImage: originalPhoto, options: [:])
        try? handler.perform([visionRequest])
    }
    
    func connectEyebrow(rightEyebrow: [CGPoint], leftEyebrow: [CGPoint]) -> [CGPoint] {
        guard rightEyebrow.count == 6, leftEyebrow.count == 6 else {return []}
        var connectedEyebrowPoints: [CGPoint] = []
        connectedEyebrowPoints.append(contentsOf: rightEyebrow[0...2])
        connectedEyebrowPoints.append(contentsOf: leftEyebrow[0...2].reversed())
        connectedEyebrowPoints.append(contentsOf: leftEyebrow[3...5].reversed())
        connectedEyebrowPoints.append(contentsOf: rightEyebrow[3...5])
        
        return connectedEyebrowPoints
    }

    func calculateIntersection(_ lineA: (start: CGPoint, end: CGPoint), _ lineB: (start: CGPoint, end: CGPoint)) -> CGPoint? {
        let pA = lineA.start
        let pB = lineA.end
        let pC = lineB.start
        let pD = lineB.end
        
        let sMolecule =     (pC.x - pA.x) * (pD.y - pC.y) - (pC.y - pA.y) * (pD.x - pC.x)
        let sDenominator =  (pB.x - pA.x) * (pD.y - pC.y) - (pB.y - pA.y) * (pD.x - pC.x)
        let tMolecule =     (pA.x - pC.x) * (pB.y - pA.y) - (pA.y - pC.y) * (pB.x - pA.x)
        let tDenominator =  (pD.x - pC.x) * (pB.y - pA.y) - (pD.y - pC.y) * (pB.x - pA.x)
        
        let s = sMolecule / sDenominator
        let t = tMolecule / tDenominator
        
        if 0...1 ~= s && 0...1 ~= t {
            let intersection = pA + (s * (pB - pA))
            return intersection
        } else {
            return nil
        }
    }
    
    func saveCIImage(_ image: CIImage) {
        let cgImage = linearContext.createCGImage(image, from: image.extent)
        let uiImage = UIImage(cgImage: cgImage!)
        UIImageWriteToSavedPhotosAlbum(uiImage, self, nil, nil)
    }
    
    func clear() {
        for part in FacePart.allCases {
            facePartColorists[part]?.clear()
        }
        image = nil
        originalPhoto = nil
        photoImage = nil
        hairMatte = nil
        skinMatte = nil
        portraitMatte = nil
        eyebrowMatte = nil
        rightEyebrowPoints = nil
        leftEyebrowPoints = nil
        faceRoll = 0
    }
    
    func removeError() -> String {
        return error.removeError()
    }
}
