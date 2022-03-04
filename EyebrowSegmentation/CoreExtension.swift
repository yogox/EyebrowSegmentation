//
//  CoreExtension.swift
//  EyebrowSegmentation
//
//  Created by yogox on 2021/09/28.
//  Copyright © 2021 Yogox Galaxy. All rights reserved.
//

import CoreImage

func + (right: CGPoint, left: CGPoint) -> CGPoint {
    return CGPoint(x: right.x + left.x, y: right.y + left.y)
}

func - (right: CGPoint, left: CGPoint) -> CGPoint {
    return CGPoint(x: right.x - left.x, y: right.y - left.y)
}

func * (right: CGPoint, left: CGFloat) -> CGPoint {
    return CGPoint(x: right.x * left, y: right.y * left)
}

func * (right: CGFloat, left: CGPoint) -> CGPoint {
    return left * right
}

func / (right: CGPoint, left: CGFloat) -> CGPoint {
    return CGPoint(x: right.x / left, y: right.y / left)
}

func * (right: CGPoint, left: Double) -> CGPoint {
    let floatLeft = CGFloat(left)
    return right * floatLeft
}

func / (right: CGPoint, left: Int) -> CGPoint {
    let floatLeft = CGFloat(left)
    return right / floatLeft
}

extension CGRect {
    init(origin: CGPoint, diameter: CGFloat) {
        let center = origin - CGPoint(x: diameter/2, y: diameter/2)
        let size = CGSize(width: diameter, height: diameter)
        self.init(origin: center, size: size)
    }
}

extension CIImage {
    func getColorAtPoint (context: CIContext, point: CGPoint = CGPoint(x: 0, y: 0)) -> CIColor {
        var bitmap = [UInt8](repeating: 0, count: 4)
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
    
    func getColorAtPoint (point: CGPoint = CGPoint(x: 0, y: 0)) -> CIColor {
        let context = CIContext(options: [.workingColorSpace: kCFNull])
        return self.getColorAtPoint(context: context, point: point)
    }
}

extension CGPoint {
    func rotate(_ angle: CGFloat) -> CGPoint {
        let cosRad = round(cos(angle) * 1000) / 1000
        let sinRad = round(sin(angle) * 1000) / 1000
        
        let xComponent = (cosRad * x) - (sinRad * y)
        let yComponent = (cosRad * y) + (sinRad * x)
        
        return CGPoint(x: xComponent, y: yComponent)
    }
    
    func rotate(_ angle: CGFloat, center: CGPoint) -> CGPoint {
        let distance = self - center
        return distance.rotate(angle) + center
    }
}

extension CGAffineTransform {
    init(_ point: CGPoint) {
        self.init(translationX: point.x, y: point.y)
    }
}

extension Array where Element == CGPoint {
    func average() -> CGPoint {
        let sum = reduce(CGPoint.zero) {
            return $0 + $1
        }
        let average = sum / count
        return average
    }
    
    func rotate(_ angle: CGFloat) -> [CGPoint] {
        let cosRad = round(cos(angle) * 1000) / 1000
        let sinRad = round(sin(angle) * 1000) / 1000
        
        let newPoints: [CGPoint] = map{
            let xComponent = (cosRad * $0.x) - (sinRad * $0.y)
            let yComponent = (cosRad * $0.y) + (sinRad * $0.x)
            return CGPoint(x: xComponent, y: yComponent)
        }
        
        return newPoints
    }
    
    func rotate(_ angle: CGFloat, center: CGPoint) -> [CGPoint] {
        let distance: [CGPoint] = map{
            $0 - center
        }
        
        let newPoints: [CGPoint] = distance.map{
            return $0.rotate(angle) + center
        }
        
        return newPoints
    }
    
    func expandFrom(_ center: CGPoint, rate: CGFloat = 0.0, aspect: CGFloat = 1.0)  -> [CGPoint] {
        let distances = map{
            return $0 - center
        }
        
        let newDistances = distances.map{
            CGPoint(x: $0.x, y: ($0.y * aspect)) * (rate + 1.0)
        }
        
        let newPoints = newDistances.map{
            $0 + center
        }
        
        return newPoints
    }
    
    func rotateAndExpantFrom(_ center: CGPoint, rate: CGFloat = 0.0, aspect: CGFloat = 1.0, angle: CGFloat = 0.0)  -> [CGPoint] {
        let points = self.rotate(-angle, center: center)
        let pointsExpanded = points.expandFrom(center, rate: rate, aspect: aspect)
        let newPpints = pointsExpanded.rotate(angle, center: center)
        return newPpints
    }
}
