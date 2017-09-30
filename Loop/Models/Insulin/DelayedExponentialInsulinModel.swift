//
//  DelayedExponentialInsulinModel.swift
//  InsulinKit
//
//  Created by Pete Schwamb on 7/30/17.
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Foundation
import InsulinKit

public struct DelayedExponentialInsulinModel {
    public let actionDuration: TimeInterval
    public let peakActivityTime: TimeInterval
	public let delay: TimeInterval
    
    // Precomputed terms
    fileprivate let τ: Double
    fileprivate let a: Double
    fileprivate let S: Double

    /// Configures a new exponential insulin model
    ///
    /// - Parameters:
    ///   - actionDuration: The total duration on insulin activity
    ///   - peakActivityTime: The time of the peak of insulin activity from dose.
    public init(actionDuration: TimeInterval, peakActivityTime: TimeInterval, delay: TimeInterval) {
        self.actionDuration = actionDuration
        self.peakActivityTime = peakActivityTime
		self.delay = delay
        
        self.τ = peakActivityTime * (1 - peakActivityTime / actionDuration) / (1 - 2 * peakActivityTime / actionDuration)
        self.a = 2 * τ / actionDuration
        self.S = 1 / (1 - a + (1 + a) * exp(-actionDuration / τ))
    }
}

extension DelayedExponentialInsulinModel: InsulinModel {
    public var effectDuration: TimeInterval {
        return self.delay + self.actionDuration
    }
    
    /// Returns the percentage of total insulin effect remaining at a specified interval after delivery;
    /// also known as Insulin On Board (IOB).
    ///
    /// This is a configurable exponential model as described here: https://github.com/LoopKit/Loop/issues/388#issuecomment-317938473
    /// Allows us to specify time of peak activity, as well as duration, and provides activity and IOB decay functions
    /// Many thanks to Dragan Maksimovic (@dm61) for creating such a flexible way of adjusting an insulin curve 
    /// for use in closed loop systems.
    ///
    /// - Parameter time: The interval after insulin delivery
    /// - Returns: The percentage of total insulin effect remaining

    public func percentEffectRemaining(at time: TimeInterval) -> Double {
        switch time {
        case let t where t <= delay:
            return 1
        case let t where t >= delay + actionDuration:
            return 0
        default:
			let x = time - delay
            return 1 - S * (1 - a) *
                ((pow(x, 2) / (τ * actionDuration * (1 - a)) - x / τ - 1) * exp(-x / τ) + 1)
        }
    }
}

extension DelayedExponentialInsulinModel: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "DelayedExponentialInsulinModel(actionDuration: \(actionDuration), peakActivityTime: \(peakActivityTime), delay: \(delay))"
    }
}

#if swift(>=4)
extension DelayedExponentialInsulinModel: Decodable {
    enum CodingKeys: String, CodingKey {
        case actionDuration = "actionDuration"
        case peakActivityTime = "peakActivityTime"
		case delay = "delay"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let actionDuration: Double = try container.decode(Double.self, forKey: .actionDuration)
        let peakActivityTime: Double = try container.decode(Double.self, forKey: .peakActivityTime)
		let delay: Double = try container.decode(Double.self, forKey: .delay)

        self.init(actionDuration: actionDuration, peakActivityTime: peakActivityTime, delay: delay)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(actionDuration, forKey: .actionDuration)
        try container.encode(peakActivityTime, forKey: .peakActivityTime)
		try container.encode(delay, forKey: .delay)
    }
}
#endif
