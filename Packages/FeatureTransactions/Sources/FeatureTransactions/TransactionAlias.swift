import PortoKit

/// `PortoKit` (the module) also declares a top-level `public enum PortoKit`, which shadows the
/// module name for qualified lookups (`PortoKit.Transaction` resolves to a member of that enum,
/// not the module) — a known Swift ambiguity when a module and one of its own types share a name.
/// Combined with `SwiftUI.Transaction` (animation transactions), the bare name `Transaction` is
/// ambiguous in any file that imports both SwiftUI and PortoKit. This file has no SwiftUI import,
/// so the bare name below resolves unambiguously to `PortoKit`'s model; screens then reference it
/// as `TxModel` instead of needing to spell out (or qualify) `Transaction` themselves.
public typealias TxModel = Transaction
