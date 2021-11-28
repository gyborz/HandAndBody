//
//  Body.swift
//  HandAndBody
//
//  Created by Gyorgy Borz on 2021. 11. 27..
//

import UIKit
import Vision

struct Body {
    let face: [CGPoint]
    let rightArm: [CGPoint]
    let leftArm: [CGPoint]
    let torso: [VNHumanBodyPoseObservation.JointName: CGPoint]
    let rightLeg: [CGPoint]
    let leftLeg: [CGPoint]

    init(face: [CGPoint], rightArm: [CGPoint], leftArm: [CGPoint], torso: [VNHumanBodyPoseObservation.JointName: CGPoint], rightLeg: [CGPoint], leftLeg: [CGPoint]) {
        self.face = face
        self.rightArm = rightArm
        self.leftArm = leftArm
        self.torso = torso
        self.rightLeg = rightLeg
        self.leftLeg = leftLeg
    }
}
