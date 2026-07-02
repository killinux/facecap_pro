import Foundation

/// One Euro Filter（Casiez et al. 2012）
/// 面捕去抖的标准方案：静止时强平滑消抖动，快速运动时自动降低平滑避免延迟。
final class OneEuroFilter {
    var minCutoff: Float = 1.0
    var beta: Float = 0.3
    var dCutoff: Float = 1.0

    private var xPrev: Float?
    private var dxPrev: Float = 0
    private var tPrev: TimeInterval?

    func reset() {
        xPrev = nil
        dxPrev = 0
        tPrev = nil
    }

    func filter(_ x: Float, at t: TimeInterval) -> Float {
        guard let xp = xPrev, let tp = tPrev, t > tp else {
            xPrev = x
            tPrev = t
            return x
        }
        let dt = Float(t - tp)
        let dx = (x - xp) / dt
        let dxHat = Self.lowpass(dx, prev: dxPrev, alpha: Self.alpha(dt: dt, cutoff: dCutoff))
        let cutoff = minCutoff + beta * abs(dxHat)
        let xHat = Self.lowpass(x, prev: xp, alpha: Self.alpha(dt: dt, cutoff: cutoff))
        xPrev = xHat
        dxPrev = dxHat
        tPrev = t
        return xHat
    }

    private static func alpha(dt: Float, cutoff: Float) -> Float {
        let r = 2 * Float.pi * cutoff * dt
        return r / (r + 1)
    }

    private static func lowpass(_ x: Float, prev: Float, alpha: Float) -> Float {
        alpha * x + (1 - alpha) * prev
    }
}
