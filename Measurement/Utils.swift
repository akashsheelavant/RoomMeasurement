//
//  Untitled.swift
//  Measurement
//
//  Created by Akash Sheelavant on 12/13/24.
//
import SceneKit

extension UIViewController {
    
    /**
     Distance string
     */
    func distanceInMeters(pos1: SCNVector3?,
                                 pos2: SCNVector3?) -> String {
        
        if pos1 == nil || pos2 == nil {
            return "0"
        }
        let d = self.distanceBetween(A: pos1!, B: pos2!)
        
        var result = ""
        
        let meter = convertTostringValue(v: Float(d), unit: "m")
        result.append(meter)
        
        return result
    }
    
    /**
     Distance between 2 points
     */
    func distanceBetween(A: SCNVector3, B: SCNVector3) -> CGFloat {
        let l = sqrt(
            (A.x - B.x) * (A.x - B.x)
                +   (A.y - B.y) * (A.y - B.y)
                +   (A.z - B.z) * (A.z - B.z)
        )
        return CGFloat(l)
    }
    
    /**
     String with float value and unit
     */
    func convertTostringValue(v: Float, unit: String) -> String {
        let s = String(format: "%.1f %@", v, unit)
        return s
    }
}
