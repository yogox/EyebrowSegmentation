//
//  Error.swift
//  EyebrowSegmentation
//
//  Created by yogox on 2021/09/27.
//  Copyright © 2021 Yogox Galaxy. All rights reserved.
//

import Foundation

class MyError {
    private var message: String = ""
    enum ErrorMessage: String {
        case portraitFailure = "No object with portrait."
        case segmentaionFailure = "No object with segmentation."
        case ciDetectorFailure = "Cound not get face angle."
        case ciDetectorNoHuman = "There is no human.(CIDetector)"
        case visionFailure = "Cound not get eyebow data."
        case visionFailureNoHuman = "There is no human.(Vision)"
    }
    
    func setError(_ errorMessage: ErrorMessage) {
        if message.isEmpty {
            message = errorMessage.rawValue
        } else {
            message.append("\n")
            message.append(errorMessage.rawValue)
        }
    }
    
    func getError() -> String {
        return message
    }
    
    func clear() {
        message.removeAll()
    }
    
    func removeError() -> String {
        let message = getError()
        clear()
        return message
    }
}
