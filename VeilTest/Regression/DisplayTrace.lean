import Veil.Core.UI.Trace.TraceDisplay

-- The public command accepts a raw trace object, including empty traces.
#displayTrace (Lean.Json.mkObj [("theory", Lean.Json.mkObj []), ("states", Lean.Json.arr #[])])
