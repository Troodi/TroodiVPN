package platform

// TUNPrepareDiagnostics is filled by PrepareTUN when diag != nil.
type TUNPrepareDiagnostics struct {
	// Mode is "single_ps", "split_ps" (TROODI_TUN_TIMING=1 on Windows), or "other".
	Mode string
	// WaitForAdapterMs: split_ps — time until Get-NetAdapter sees the wintun interface.
	WaitForAdapterMs int64
	// ConfigureMs: split_ps — IP/DNS/metric/routes in the second PowerShell.
	ConfigureMs int64
	// SingleScriptMs: single_ps — one combined wait+configure PowerShell run.
	SingleScriptMs int64
	// TotalMs is wall time for the entire PrepareTUN call.
	TotalMs int64
}
