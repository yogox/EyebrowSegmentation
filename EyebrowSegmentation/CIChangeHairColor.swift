//
//  CIChangeHairColor.swift
//  EyebrowSegmentation
//
//  Created by yogox on 2020/10/07.
//  Copyright © 2020 Yogox Galaxy. All rights reserved.
//

import CoreImage.CIFilterBuiltins

extension CIImage {
    func getColorAtPoint (point: CGPoint = CGPoint(x: 0, y: 0)) -> CIColor {
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull])
        context.render(self, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: point.x, y: point.y, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        let redInteger = Int(bitmap[0].description) ?? 0
        let redc = CGFloat(redInteger)/255
        let greenInteger = Int(bitmap[1].description) ?? 0
        let greenc = CGFloat(greenInteger)/255
        let blueInteger = Int(bitmap[2].description) ?? 0
        let bluec = CGFloat(blueInteger)/255
        let alphaInteger = Int(bitmap[3].description) ?? 0
        let alphac = CGFloat(alphaInteger)/255
        
        let color = CIColor(red: redc, green: greenc, blue: bluec, alpha: alphac)
        
        return color
    }
}

class CILightnessInfo: CIFilter {
    let batchSize = 500
    var inputImage: CIImage?
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return nil }
        
        let scaleFilter = CIFilter.bicubicScaleTransform()
        let scale = CGFloat(batchSize) / max(inputImage.extent.width, inputImage.extent.height)
        scaleFilter.inputImage = inputImage
        scaleFilter.scale = Float(scale)
        scaleFilter.parameterB = 1
        scaleFilter.parameterC = 0

        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)
        let kernel = try! CIKernel(functionName: "minMaxModeLightness", fromMetalLibraryData: data)
        let outputImage = kernel.apply(extent: CGRect(x: 0, y: 0, width: 1, height: 1),
                                       roiCallback: { index, rect in
                                        return scaleFilter.outputImage!.extent
                                       },
                                       arguments: [scaleFilter.outputImage!])
        
        return outputImage
    }
}

class CIGetOnesideEyebowMatte: CIFilter {
    // hairMatte
    var inputImage: CIImage?
    // skinMatte
    var backgroundImage: CIImage?
    var eyebowPoints = Array<CGPoint>()
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage
              , let backgroundImage = backgroundImage
              , eyebowPoints.count >= 6
        else { return nil }
        
        print(eyebowPoints)
        let p1 = eyebowPoints[0]
        let p2 = eyebowPoints[1]
        let p3 = eyebowPoints[2]
        let p4 = eyebowPoints[3]
        let p5 = eyebowPoints[4]
        let p6 = eyebowPoints[5]
        
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)
        let arguments = [inputImage, backgroundImage, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y, p4.x, p4.y, p5.x, p5.y, p6.x, p6.y] as [Any]
        let kernel = try! CIKernel(functionName: "getEyebowMatte", fromMetalLibraryData: data)
        let outputImage = kernel.apply(extent: inputImage.extent,
                                       roiCallback: { index, rect in
                                        return inputImage.extent
                                       },
                                       arguments: arguments)

        return outputImage!
    }
}

class CIGetEyebowMatte: CIFilter {
    // hairMatte
    var inputImage: CIImage?
    // skinMatte
    var backgroundImage: CIImage?
    var rightEyebowPoints = Array<CGPoint>()
    var leftEyebowPoints = Array<CGPoint>()

    override var outputImage: CIImage? {
        guard let inputImage = inputImage
              , let backgroundImage = backgroundImage
              , rightEyebowPoints.count >= 6
              , leftEyebowPoints.count >= 6
        else { return nil }
        
        let addFilter = CIFilter.additionCompositing()
        
        let eyebowFilter = CIGetOnesideEyebowMatte()
        eyebowFilter.inputImage = inputImage
        eyebowFilter.backgroundImage = backgroundImage
        eyebowFilter.eyebowPoints = rightEyebowPoints
        addFilter.inputImage = eyebowFilter.outputImage!
        
        eyebowFilter.eyebowPoints = leftEyebowPoints
        addFilter.backgroundImage = eyebowFilter.outputImage!

        return addFilter.outputImage!
    }
}

class CIResizeImageWith: CIFilter {
    var inputImage: CIImage?
    var backgroundImage: CIImage?
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage
        , let backgraoundImage = backgroundImage
        else { return nil }
        
        // Matte画像に合わせて写真のスケールを縮小
        let scaleFilter = CIFilter.lanczosScaleTransform()
        let targetHeight = backgraoundImage.extent.height
        let baseHight = inputImage.extent.height
        scaleFilter.inputImage = inputImage
        scaleFilter.scale = Float(targetHeight / baseHight)
        scaleFilter.aspectRatio = 1.0
        
        return scaleFilter.outputImage!
    }
}

class CICutoutSegmentGray: CIFilter {
    var inputImage: CIImage?
    var matteImage: CIImage?
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage
            , let matteImage = matteImage
        else { return nil }
        
        // マット画像のアルファを変更
        let maskFilter = CIFilter.maskToAlpha()
        maskFilter.inputImage = matteImage

        // マット領域で写真を切り抜き
        let cutFilter = CIFilter.sourceInCompositing()
        cutFilter.inputImage = inputImage
        cutFilter.backgroundImage = maskFilter.outputImage!
        
        // 切り抜いたマット領域を輝度でグレースケール変換
        let grayFilter = CIFilter.falseColor()
        grayFilter.inputImage = cutFilter.outputImage!
        grayFilter.color0 = CIColor.black
        grayFilter.color1 = CIColor.white

        return grayFilter.outputImage!
    }
}

class CIIkaHairGradient: CIFilter {
    var minPoint = CGFloat(0.0)
    var modePoint = CGFloat(0.5)
    var maxPoint = CGFloat(1.0)
    var minColor: CIColor?
    var modeColor: CIColor?
    var maxColor: CIColor?
    
    override var outputImage: CIImage? {
        guard let minColor = minColor
            , let modeColor = modeColor
            , let maxColor = maxColor
        else { return nil }
        
        // 合成用フィルターを定義
        let compositeFilter = CIFilter.sourceOverCompositing()

        //TODO: maxLightnessを参照して明るさを落としたい

        // グラデーションマップの左側を作成
        let gradientFilter = CIFilter.smoothLinearGradient()
        gradientFilter.point0 = CGPoint(x: minPoint * 1000, y: 0)
        gradientFilter.color0 = minColor
        gradientFilter.point1 = CGPoint(x: modePoint * 1000, y: 0)
        gradientFilter.color1 = modeColor
        compositeFilter.inputImage = gradientFilter.outputImage!
            .cropped(to: CGRect(x: 0, y: 0, width: modePoint * 1000, height: 480))
        
        // グラデーションマップの右側を作成
        gradientFilter.point0 = CGPoint(x: modePoint * 1000, y: 0)
        gradientFilter.color0 = modeColor
        gradientFilter.point1 = CGPoint(x: maxPoint * 1000, y: 0)
        gradientFilter.color1 = maxColor
        compositeFilter.backgroundImage = gradientFilter.outputImage!
            .cropped(to: CGRect(x: 0, y: 0, width: 1000, height: 480))

        return compositeFilter.outputImage!
    }
}
