import SwiftUI

/// Maps open door / frunk / trunk / charge bits to a dial-filling status asset (v10 photoreal).
enum DialVehicleStatus {
    /// Asset name for the current aperture combination, or `nil` when all closed.
    static func assetName(
        doorFL: Bool,
        doorFR: Bool,
        doorRL: Bool,
        doorRR: Bool,
        frunkOpen: Bool,
        trunkOpen: Bool,
        chargePortOpen: Bool
    ) -> String? {
        let fl = doorFL, fr = doorFR, rl = doorRL, rr = doorRR
        let doors = fl || fr || rl || rr
        let all4 = fl && fr && rl && rr
        let anyOpen = doors || frunkOpen || trunkOpen || chargePortOpen
        guard anyOpen else { return nil }

        // Charge-only
        if chargePortOpen && !doors && !frunkOpen && !trunkOpen {
            return "DialStatusCharge"
        }

        // Frunk / trunk without side doors (charge ignored for graphic pick)
        if !doors {
            if frunkOpen && trunkOpen { return "DialStatusFrunkTrunk" }
            if frunkOpen { return "DialStatusFrunk" }
            if trunkOpen { return "DialStatusTrunk" }
            if chargePortOpen { return "DialStatusCharge" }
        }

        // Doors + trunk
        if all4 && trunkOpen { return "DialStatusAllTrunk" }
        if all4 { return "DialStatusAllDoors" }

        // Exact multi-door combos
        if fl && fr && !rl && !rr { return "DialStatusFrontBoth" }
        if fl && rl && !fr && !rr { return "DialStatusLeftBoth" }
        if fr && rr && !fl && !rl { return "DialStatusRightBoth" }
        if rl && rr && !fl && !fr { return "DialStatusRearBoth" }
        if fl && rl && rr && !fr { return "DialStatusFLRLRR" }
        if fl && fr && rr && !rl { return "DialStatusFLFRRR" }

        // Singles
        if fl && !fr && !rl && !rr { return "DialStatusFL" }
        if fr && !fl && !rl && !rr { return "DialStatusFR" }
        if rl && !fl && !fr && !rr { return "DialStatusRL" }
        if rr && !fl && !fr && !rl { return "DialStatusRR" }

        // Fallbacks for uncommon mixes
        if frunkOpen && trunkOpen { return "DialStatusFrunkTrunk" }
        if frunkOpen { return "DialStatusFrunk" }
        if trunkOpen && (fl || fr || rl || rr) { return "DialStatusAllTrunk" }
        if (fl || rl) && (fr || rr) { return "DialStatusAllDoors" }
        if fl || rl { return fl && rl ? "DialStatusLeftBoth" : (fl ? "DialStatusFL" : "DialStatusRL") }
        if fr || rr { return fr && rr ? "DialStatusRightBoth" : (fr ? "DialStatusFR" : "DialStatusRR") }
        if chargePortOpen { return "DialStatusCharge" }
        return "DialStatusAllDoors"
    }
}
