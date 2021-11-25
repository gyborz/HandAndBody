//
//  Hand.swift
//  HandAndBody
//
//  Created by Gyorgy Borz on 2021. 11. 25..
//

import UIKit

struct Hand {
    let thumbFinger: [CGPoint]
    let indexFinger: [CGPoint]
    let middleFinger: [CGPoint]
    let ringFinger: [CGPoint]
    let littleFinger: [CGPoint]
    let wrist: CGPoint?

    init(thumbFinger: [CGPoint], indexFinger: [CGPoint], middleFinger: [CGPoint], ringFinger: [CGPoint], littleFinger: [CGPoint], wrist: CGPoint?) {
        self.thumbFinger = thumbFinger
        self.indexFinger = indexFinger
        self.middleFinger = middleFinger
        self.ringFinger = ringFinger
        self.littleFinger = littleFinger
        self.wrist = wrist
    }
}
