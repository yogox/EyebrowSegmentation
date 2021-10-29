//
//  CIChangeHairColor.swift
//  EyebrowSegmentation
//
//  Created by yogox on 2020/10/07.
//  Copyright © 2020 Yogox Galaxy. All rights reserved.
//

import CoreImage.CIFilterBuiltins
import CoreImage

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

class CIGetEyebowMatte: CIFilter {
    // hairMatte
    var inputImage: CIImage?
    // skinMatte
    var backgroundImage: CIImage?
    var eyebowPoints = Array<CGPoint>()
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage
              , let backgroundImage = backgroundImage
              , eyebowPoints.count >= 10
        else { return nil }

        switch eyebowPoints.count {
        case 12:
            let filter = CIGetEyebowMatteWith12p()
            filter.inputImage = inputImage
            filter.backgroundImage = backgroundImage
            filter.eyebowPoints = eyebowPoints
            return filter.outputImage!
        case 11:
            let filter = CIGetEyebowMatteWith11p()
            filter.inputImage = inputImage
            filter.backgroundImage = backgroundImage
            filter.eyebowPoints = eyebowPoints
            return filter.outputImage!
        case 10:
            let filter = CIGetEyebowMatteWith10p()
            filter.inputImage = inputImage
            filter.backgroundImage = backgroundImage
            filter.eyebowPoints = eyebowPoints
            return filter.outputImage!
        default:
            return nil
        }
    }
}

class CIGetEyebowMatteWith12p: CIFilter {
    // hairMatte
    var inputImage: CIImage?
    // skinMatte
    var backgroundImage: CIImage?
    var eyebowPoints = Array<CGPoint>()
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage
              , let backgroundImage = backgroundImage
              , eyebowPoints.count >= 12
        else { return nil }
        
        let p1 = eyebowPoints[0]
        let p2 = eyebowPoints[1]
        let p3 = eyebowPoints[2]
        let p4 = eyebowPoints[3]
        let p5 = eyebowPoints[4]
        let p6 = eyebowPoints[5]
        let p7 = eyebowPoints[6]
        let p8 = eyebowPoints[7]
        let p9 = eyebowPoints[8]
        let p10 = eyebowPoints[9]
        let p11 = eyebowPoints[10]
        let p12 = eyebowPoints[11]

        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)
        let arguments = [inputImage, backgroundImage,
                         p1.x, p1.y,
                         p2.x, p2.y,
                         p3.x, p3.y,
                         p4.x, p4.y,
                         p5.x, p5.y,
                         p6.x, p6.y,
                         p7.x, p7.y,
                         p8.x, p8.y,
                         p9.x, p9.y,
                         p10.x, p10.y,
                         p11.x, p11.y,
                         p12.x, p12.y
        ] as [Any]
        let kernel = try! CIKernel(functionName: "getEyebowMatte", fromMetalLibraryData: data)
        let outputImage = kernel.apply(extent: inputImage.extent,
                                       roiCallback: { index, rect in
                                                        return inputImage.extent
                                       },
                                       arguments: arguments)

        return outputImage!
    }
}
    
class CIGetEyebowMatteWith11p: CIFilter {
    // hairMatte
    var inputImage: CIImage?
    // skinMatte
    var backgroundImage: CIImage?
    var eyebowPoints = Array<CGPoint>()
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage
                , let backgroundImage = backgroundImage
                , eyebowPoints.count >= 11
        else { return nil }
        
        let p1 = eyebowPoints[0]
        let p2 = eyebowPoints[1]
        let p3 = eyebowPoints[2]
        let p4 = eyebowPoints[3]
        let p5 = eyebowPoints[4]
        let p6 = eyebowPoints[5]
        let p7 = eyebowPoints[6]
        let p8 = eyebowPoints[7]
        let p9 = eyebowPoints[8]
        let p10 = eyebowPoints[9]
        let p11 = eyebowPoints[10]
        
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)
        let arguments = [inputImage, backgroundImage,
                         p1.x, p1.y,
                         p2.x, p2.y,
                         p3.x, p3.y,
                         p4.x, p4.y,
                         p5.x, p5.y,
                         p6.x, p6.y,
                         p7.x, p7.y,
                         p8.x, p8.y,
                         p9.x, p9.y,
                         p10.x, p10.y,
                         p11.x, p11.y
        ] as [Any]
        let kernel = try! CIKernel(functionName: "getEyebowMatte11P", fromMetalLibraryData: data)
        let outputImage = kernel.apply(extent: inputImage.extent,
                                       roiCallback: { index, rect in
                                                        return inputImage.extent
                                                    },
                                       arguments: arguments)
        
        return outputImage!
    }
}

class CIGetEyebowMatteWith10p: CIFilter {
    // hairMatte
    var inputImage: CIImage?
    // skinMatte
    var backgroundImage: CIImage?
    var eyebowPoints = Array<CGPoint>()
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage
                , let backgroundImage = backgroundImage
                , eyebowPoints.count >= 10
        else { return nil }
        
        let p1 = eyebowPoints[0]
        let p2 = eyebowPoints[1]
        let p3 = eyebowPoints[2]
        let p4 = eyebowPoints[3]
        let p5 = eyebowPoints[4]
        let p6 = eyebowPoints[5]
        let p7 = eyebowPoints[6]
        let p8 = eyebowPoints[7]
        let p9 = eyebowPoints[8]
        let p10 = eyebowPoints[9]
        
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)
        let arguments = [inputImage, backgroundImage,
                         p1.x, p1.y,
                         p2.x, p2.y,
                         p3.x, p3.y,
                         p4.x, p4.y,
                         p5.x, p5.y,
                         p6.x, p6.y,
                         p7.x, p7.y,
                         p8.x, p8.y,
                         p9.x, p9.y,
                         p10.x, p10.y
        ] as [Any]
        let kernel = try! CIKernel(functionName: "getEyebowMatte10P", fromMetalLibraryData: data)
        let outputImage = kernel.apply(extent: inputImage.extent,
                                       roiCallback: { index, rect in
                                                        return inputImage.extent
                                                    },
                                       arguments: arguments)
        
        return outputImage!
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

class CIShiftAndStack: CIFilter {
    var inputImage: CIImage?
    var matte: CIImage?
    var startAngle: CGFloat = 0
    var radius: CGFloat = 0
    var times: Int?

    override var outputImage: CIImage? {
        guard let inputImage = inputImage, let matte = matte, let times = times else { return nil }
        
        let shiftBase = CGPoint(x: radius, y: 0).rotate(startAngle)
        var shift = CGAffineTransform(shiftBase)
        var stackedImage = inputImage
        var shiftImage: CIImage?
        let compositeFilter = CIFilter.sourceOverCompositing()
        
        for i in 0..<times {
            let angle:Double = .pi * Double(360 / times) / Double(180) * Double(i)
            print(angle)
            shift = CGAffineTransform( shiftBase.rotate(angle + startAngle) )
            shiftImage = inputImage.transformed(by: shift)
            compositeFilter.backgroundImage = stackedImage
            compositeFilter.inputImage = shiftImage
            stackedImage = compositeFilter.outputImage!
        }
        
        return stackedImage
    }
}

class CIThickenMatte: CIFilter {
    var inputImage: CIImage?

    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return nil }
        
        let polyFilter = CIFilter.colorPolynomial()
        let colorVector = CIVector(x: 0, y: 3, z: 0, w: 0)
        polyFilter.inputImage = inputImage
        polyFilter.redCoefficients = colorVector
        polyFilter.greenCoefficients = colorVector
        polyFilter.blueCoefficients = colorVector

        let bloomFilter = CIFilter.bloom()
        bloomFilter.inputImage = polyFilter.outputImage!
        bloomFilter.radius = 5
        bloomFilter.intensity = 0.75

        // clampでコンポーネントの範囲を0〜1に絞らないとオーバーフローしたピクセルの処理がおかしくなる
        let clampFilter = CIFilter.colorClamp()
        clampFilter.inputImage = bloomFilter.outputImage!
        
        return clampFilter.outputImage!
    }
}


class CISimpleSubtraction: CIFilter {
    var inputImage: CIImage?
    var backgroundImage: CIImage?

    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return nil }
        guard let backgroundImage = backgroundImage else { return inputImage }
        
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!

        let data = try! Data(contentsOf: url)
        let arguments = [inputImage, backgroundImage] as [Any]
        let kernel = try! CIColorKernel(functionName: "simpleSubtraction", fromMetalLibraryData: data)
        let outputImage = kernel.apply(extent: inputImage.extent, arguments: arguments)

        return outputImage!
    }
}
