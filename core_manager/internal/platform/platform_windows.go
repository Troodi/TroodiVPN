//go:build windows

package platform

import (
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"golang.org/x/sys/windows"
	"golang.org/x/sys/windows/registry"
)

type ProxySettings struct {
	Enabled  bool
	Server   string
	Override string

	// Keep parity with non-Windows proxy capture fields so shared runtime
	// code can compile on all platforms.
	ModeRaw             string
	AutoconfigURLRaw    string
	IgnoreHostsRaw      string
	UseSameProxyRaw     string
	FTPHostRaw          string
	FTPPortRaw          string
	HTTPEnabledRaw      string
	HTTPHostRaw         string
	HTTPPortRaw         string
	HTTPUseAuthRaw      string
	HTTPAuthUserRaw     string
	HTTPAuthPasswordRaw string
	HTTPSHostRaw        string
	HTTPSPortRaw        string
	SocksHostRaw        string
	SocksPortRaw        string
}

type DefaultRoute struct {
	InterfaceAlias string `json:"InterfaceAlias"`
	InterfaceIndex int    `json:"ifIndex"`
	NextHop        string `json:"NextHop"`
	IPAddress      string `json:"IPAddress"`
}

type TUNOptions struct {
	InterfaceAlias string
	IPAddress      string
	PrefixLength   int
	MTU            int
	DNSServers     []string
	ManageRoutes   bool
	DefaultRoute   *DefaultRoute
	BypassCIDRs    []string
}

type TUNState struct {
	InterfaceAlias string
	InterfaceIndex int
	IPAddress      string
	PrefixLength   int
	DNSServers     []string
	RoutePrefixes  []string
	BypassCIDRs    []string
}

func DefaultTUNOptions() TUNOptions {
	return TUNOptions{
		InterfaceAlias: "xray0",
		IPAddress:      "198.18.0.1",
		PrefixLength:   15,
		MTU:            1500,
		DNSServers:     []string{"1.1.1.1", "8.8.8.8"},
		ManageRoutes:   false,
	}
}

func IsElevated() bool {
	adminSID, err := windows.CreateWellKnownSid(windows.WinBuiltinAdministratorsSid)
	if err != nil {
		return false
	}

	token := windows.Token(0)
	member, err := token.IsMember(adminSID)
	return err == nil && member
}

func RequestElevation(executablePath, workingDirectory string) error {
	command := fmt.Sprintf(
		"Start-Process -FilePath '%s' -WorkingDirectory '%s' -Verb RunAs",
		escapeSingleQuotes(executablePath),
		escapeSingleQuotes(workingDirectory),
	)

	cmd := exec.Command(
		"powershell",
		"-NoProfile",
		"-Command",
		command,
	)
	cmd.SysProcAttr = hiddenPowerShellAttributes()
	return cmd.Start()
}

func SetElevationSecret(secret string) error {
	return nil
}

func CommandAsRoot(name string, args ...string) (*exec.Cmd, error) {
	return exec.Command(name, args...), nil
}

func CaptureSystemProxy() (*ProxySettings, error) {
	key, err := registry.OpenKey(
		registry.CURRENT_USER,
		`Software\Microsoft\Windows\CurrentVersion\Internet Settings`,
		registry.QUERY_VALUE,
	)
	if err != nil {
		return nil, err
	}
	defer key.Close()

	enable, _, err := key.GetIntegerValue("ProxyEnable")
	if err != nil {
		enable = 0
	}

	server, _, err := key.GetStringValue("ProxyServer")
	if err != nil {
		server = ""
	}

	override, _, err := key.GetStringValue("ProxyOverride")
	if err != nil {
		override = ""
	}

	httpHost, httpPort := extractWindowsProxyEndpoint(server, []string{"http"})
	if httpHost == "" || httpPort == "" {
		httpHost, httpPort = extractWindowsProxyEndpoint(server, nil)
	}
	socksHost, socksPort := extractWindowsProxyEndpoint(server, []string{"socks", "socks5"})

	modeRaw := "none"
	httpEnabledRaw := "false"
	if enable != 0 {
		modeRaw = "manual"
		httpEnabledRaw = "true"
	}

	return &ProxySettings{
		Enabled:  enable != 0,
		Server:   server,
		Override: override,
		ModeRaw:  modeRaw,

		HTTPEnabledRaw: httpEnabledRaw,
		HTTPHostRaw:    httpHost,
		HTTPPortRaw:    httpPort,
		HTTPSHostRaw:   httpHost,
		HTTPSPortRaw:   httpPort,
		SocksHostRaw:   socksHost,
		SocksPortRaw:   socksPort,
	}, nil
}

func extractWindowsProxyEndpoint(proxyServer string, schemes []string) (string, string) {
	s := strings.TrimSpace(proxyServer)
	if s == "" {
		return "", ""
	}

	// Single endpoint format: "host:port"
	if !strings.Contains(s, "=") && !strings.Contains(s, ";") {
		host, port := splitHostPort(s)
		return host, port
	}

	allowed := map[string]struct{}{}
	for _, scheme := range schemes {
		allowed[strings.ToLower(strings.TrimSpace(scheme))] = struct{}{}
	}

	parts := strings.Split(s, ";")
	for _, part := range parts {
		item := strings.TrimSpace(part)
		if item == "" {
			continue
		}
		name, value, found := strings.Cut(item, "=")
		if !found {
			continue
		}
		name = strings.ToLower(strings.TrimSpace(name))
		value = strings.TrimSpace(value)
		if len(allowed) > 0 {
			if _, ok := allowed[name]; !ok {
				continue
			}
		}
		host, port := splitHostPort(value)
		if host != "" && port != "" {
			return host, port
		}
	}

	return "", ""
}

func splitHostPort(endpoint string) (string, string) {
	value := strings.TrimSpace(endpoint)
	if value == "" {
		return "", ""
	}
	value = strings.TrimPrefix(value, "http://")
	value = strings.TrimPrefix(value, "https://")
	value = strings.TrimPrefix(value, "socks://")
	value = strings.TrimPrefix(value, "socks5://")
	host, port, err := net.SplitHostPort(value)
	if err == nil {
		return host, port
	}

	lastColon := strings.LastIndex(value, ":")
	if lastColon <= 0 || lastColon >= len(value)-1 {
		return "", ""
	}
	host = strings.TrimSpace(value[:lastColon])
	port = strings.TrimSpace(value[lastColon+1:])
	if host == "" || port == "" {
		return "", ""
	}
	return host, port
}

func ApplySystemProxy(address string) (*ProxySettings, error) {
	previous, err := CaptureSystemProxy()
	if err != nil {
		return nil, err
	}

	key, err := registry.OpenKey(
		registry.CURRENT_USER,
		`Software\Microsoft\Windows\CurrentVersion\Internet Settings`,
		registry.SET_VALUE,
	)
	if err != nil {
		return nil, err
	}
	defer key.Close()

	if err := key.SetDWordValue("ProxyEnable", 1); err != nil {
		return nil, err
	}
	if err := key.SetStringValue("ProxyServer", address); err != nil {
		return nil, err
	}
	if err := key.SetStringValue("ProxyOverride", "<local>"); err != nil {
		return nil, err
	}

	refreshInternetSettings()
	return previous, nil
}

func RestoreSystemProxy(previous *ProxySettings) error {
	key, err := registry.OpenKey(
		registry.CURRENT_USER,
		`Software\Microsoft\Windows\CurrentVersion\Internet Settings`,
		registry.SET_VALUE,
	)
	if err != nil {
		return err
	}
	defer key.Close()

	if previous == nil {
		if err := key.SetDWordValue("ProxyEnable", 0); err != nil {
			return err
		}
		if err := key.SetStringValue("ProxyServer", ""); err != nil {
			return err
		}
		if err := key.SetStringValue("ProxyOverride", ""); err != nil {
			return err
		}
		refreshInternetSettings()
		return nil
	}

	enable := uint32(0)
	if previous.Enabled {
		enable = 1
	}

	if err := key.SetDWordValue("ProxyEnable", enable); err != nil {
		return err
	}
	if err := key.SetStringValue("ProxyServer", previous.Server); err != nil {
		return err
	}
	if err := key.SetStringValue("ProxyOverride", previous.Override); err != nil {
		return err
	}

	refreshInternetSettings()
	return nil
}

func EnsureWintunDLL(xrayBinaryPath string) error {
	dllPath := filepath.Join(filepath.Dir(xrayBinaryPath), "wintun.dll")
	info, err := os.Stat(dllPath)
	if err == nil && !info.IsDir() {
		return nil
	}

	if errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("wintun.dll not found рядом с xray.exe: %s", dllPath)
	}

	return err
}

func CaptureDefaultRoute() (*DefaultRoute, error) {
	script := `
$route = Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' |
  Where-Object { $_.NextHop -ne '0.0.0.0' } |
  Sort-Object RouteMetric, InterfaceMetric |
  Select-Object -First 1 InterfaceAlias, ifIndex, NextHop
if ($null -eq $route) { exit 2 }
$ip = Get-NetIPAddress -InterfaceIndex $route.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.IPAddress -notlike '169.254.*' } |
  Select-Object -First 1 -ExpandProperty IPAddress
if ($null -ne $ip) { $route | Add-Member -NotePropertyName IPAddress -NotePropertyValue $ip }
$route | ConvertTo-Json -Compress
`

	output, err := runPowerShellJSON(script)
	if err != nil {
		return nil, err
	}

	var route DefaultRoute
	if err := json.Unmarshal(output, &route); err != nil {
		return nil, err
	}
	if route.InterfaceAlias == "" || route.InterfaceIndex == 0 {
		return nil, errors.New("failed to determine the current default interface")
	}

	return &route, nil
}

func prefixToMask(prefix int) string {
	if prefix <= 0 || prefix > 32 {
		return "255.255.255.0"
	}
	mask := uint32(^uint32(0) << (32 - prefix))
	return fmt.Sprintf("%d.%d.%d.%d", (mask>>24)&0xff, (mask>>16)&0xff, (mask>>8)&0xff, mask&0xff)
}

// waitForTUNInterfaceIndex polls the OS until the TUN adapter appears. This avoids a long-running
// PowerShell loop (Get-NetAdapter each iteration is very slow on some systems).
func waitForTUNInterfaceIndex(alias string, deadline time.Duration) (int, error) {
	alias = strings.TrimSpace(alias)
	if alias == "" {
		return 0, errors.New("empty interface alias")
	}
	deadlineAt := time.Now().Add(deadline)
	for time.Now().Before(deadlineAt) {
		if ifi, err := net.InterfaceByName(alias); err == nil && ifi.Index > 0 {
			return ifi.Index, nil
		}
		if ifaces, err := net.Interfaces(); err == nil {
			for _, ifi := range ifaces {
				if strings.EqualFold(strings.TrimSpace(ifi.Name), alias) && ifi.Index > 0 {
					return ifi.Index, nil
				}
			}
		}
		time.Sleep(10 * time.Millisecond)
	}
	return 0, fmt.Errorf("timeout waiting for network interface %q", alias)
}

func waitForTUNAdapterPowerShell(alias string, diag *TUNPrepareDiagnostics) (int, error) {
	tw := time.Now()
	out, err := runPowerShellOutput(buildWaitForTUNAdapterScript(alias, 12, true))
	if diag != nil {
		diag.WaitForAdapterMs = time.Since(tw).Milliseconds()
	}
	if err != nil {
		return 0, fmt.Errorf("prepare TUN (wait for adapter): %w", err)
	}
	return parseTUNIfIndexOutput(out)
}

func buildWaitForTUNAdapterScript(alias string, deadlineSec int, emitOutput bool) string {
	esc := escapeSingleQuotes(alias)
	var b strings.Builder
	fmt.Fprintf(&b, `
$AdapterName = '%s'
$deadline = (Get-Date).AddSeconds(%d)
$adapter = $null
while ((Get-Date) -lt $deadline) {
  $adapter = Get-NetAdapter -IncludeHidden -Name $AdapterName -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($null -ne $adapter -and $adapter.ifIndex -gt 0) { break }
  Start-Sleep -Milliseconds 20
}
if ($null -eq $adapter -or $adapter.ifIndex -le 0) { exit 2 }
`, esc, deadlineSec)
	if emitOutput {
		b.WriteString("Write-Output $adapter.ifIndex\n")
	}
	return b.String()
}

// configureTUNNative uses netsh and route.exe instead of PowerShell for much faster setup.
func configureTUNNative(opts TUNOptions, ifIndex int) error {
	alias := opts.InterfaceAlias
	ip := opts.IPAddress
	mask := prefixToMask(opts.PrefixLength)

	// IP address: netsh interface ip set address "name" static ip mask [gateway]
	if out, err := runCmdHidden("netsh", "interface", "ip", "set", "address",
		"name="+alias, "static", ip, mask, "0.0.0.0"); err != nil {
		return fmt.Errorf("netsh set address: %w: %s", err, strings.TrimSpace(string(out)))
	}

	// DNS - first server
	if len(opts.DNSServers) > 0 {
		if out, err := runCmdHidden("netsh", "interface", "ip", "set", "dns",
			"name="+alias, "static", opts.DNSServers[0]); err != nil {
			return fmt.Errorf("netsh set dns: %w: %s", err, strings.TrimSpace(string(out)))
		}
		for i := 1; i < len(opts.DNSServers); i++ {
			if out, err := runCmdHidden("netsh", "interface", "ip", "add", "dns",
				"name="+alias, opts.DNSServers[i], "index="+strconv.Itoa(i+1)); err != nil {
				return fmt.Errorf("netsh add dns: %w: %s", err, strings.TrimSpace(string(out)))
			}
		}
	}

	// Interface metric
	if out, err := runCmdHidden("netsh", "interface", "ip", "set", "interface",
		"name="+alias, "metric=1"); err != nil {
		return fmt.Errorf("netsh set interface metric: %w: %s", err, strings.TrimSpace(string(out)))
	}

	if opts.ManageRoutes {
		// Bypass routes on default interface
		if opts.DefaultRoute != nil && opts.DefaultRoute.InterfaceIndex != 0 && opts.DefaultRoute.NextHop != "" {
			for _, cidrStr := range opts.BypassCIDRs {
				_, ipnet, err := net.ParseCIDR(cidrStr)
				if err != nil {
					continue
				}
				dest := ipnet.IP.String()
				mask := prefixToMask(cidrPrefix(ipnet))
				if out, err := runCmdHidden("route", "add", dest, "mask", mask, opts.DefaultRoute.NextHop,
					"if", strconv.Itoa(opts.DefaultRoute.InterfaceIndex), "metric", "1"); err != nil {
					if !strings.Contains(string(out), "already exists") {
						return fmt.Errorf("route add bypass %s: %w: %s", cidrStr, err, strings.TrimSpace(string(out)))
					}
				}
			}
		}

		// Split routes on TUN interface (0.0.0.0/1 and 128.0.0.0/1)
		for _, r := range []struct{ dest, mask string }{
			{"0.0.0.0", "128.0.0.0"},
			{"128.0.0.0", "128.0.0.0"},
		} {
			if out, err := runCmdHidden("route", "add", r.dest, "mask", r.mask, "0.0.0.0",
				"if", strconv.Itoa(ifIndex), "metric", "1"); err != nil {
				if !strings.Contains(string(out), "already exists") {
					return fmt.Errorf("route add split %s/%s: %w: %s", r.dest, r.mask, err, strings.TrimSpace(string(out)))
				}
			}
		}
	}

	return nil
}

func cidrPrefix(cidr *net.IPNet) int {
	ones, _ := cidr.Mask.Size()
	return ones
}

func runCmdHidden(name string, args ...string) ([]byte, error) {
	cmd := exec.Command(name, args...)
	cmd.SysProcAttr = hiddenPowerShellAttributes()
	return cmd.CombinedOutput()
}

func buildConfigureTUNScript(opts TUNOptions) string {
	alias := escapeSingleQuotes(opts.InterfaceAlias)
	var b strings.Builder
	fmt.Fprintf(&b, "$AdapterName = '%s'\n", alias)

	fmt.Fprintf(&b, `
$existing = Get-NetIPAddress -InterfaceAlias $AdapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.IPAddress -eq '%s' }
if ($null -eq $existing) {
  New-NetIPAddress -InterfaceAlias $AdapterName -IPAddress '%s' -PrefixLength %d -Type Unicast -PolicyStore ActiveStore | Out-Null
}
`, opts.IPAddress, opts.IPAddress, opts.PrefixLength)

	quotedServers := make([]string, 0, len(opts.DNSServers))
	for _, server := range opts.DNSServers {
		quotedServers = append(quotedServers, fmt.Sprintf("'%s'", escapeSingleQuotes(server)))
	}
	fmt.Fprintf(&b,
		"Set-DnsClientServerAddress -InterfaceAlias $AdapterName -ServerAddresses @(%s)\n",
		strings.Join(quotedServers, ", "),
	)

	fmt.Fprintf(&b,
		"Set-NetIPInterface -InterfaceAlias $AdapterName -AutomaticMetric Disabled -InterfaceMetric 1\n",
	)

	if opts.ManageRoutes && opts.DefaultRoute != nil && len(opts.BypassCIDRs) > 0 &&
		opts.DefaultRoute.InterfaceIndex != 0 && opts.DefaultRoute.NextHop != "" {
		fmt.Fprintf(&b, "$ifIndex = %d\n", opts.DefaultRoute.InterfaceIndex)
		fmt.Fprintf(&b, "$nextHop = '%s'\n", escapeSingleQuotes(opts.DefaultRoute.NextHop))
		b.WriteString("$bypassPrefixes = @(")
		for i, prefix := range opts.BypassCIDRs {
			if i > 0 {
				b.WriteString(", ")
			}
			b.WriteString("'")
			b.WriteString(escapeSingleQuotes(prefix))
			b.WriteString("'")
		}
		b.WriteString(")\n")
		b.WriteString(`
foreach ($prefix in $bypassPrefixes) {
  $existing = Get-NetRoute -DestinationPrefix $prefix -ErrorAction SilentlyContinue | Where-Object { $_.ifIndex -eq $ifIndex -and $_.NextHop -eq $nextHop }
  if ($null -eq $existing) {
    New-NetRoute -DestinationPrefix $prefix -InterfaceIndex $ifIndex -NextHop $nextHop -RouteMetric 1 -PolicyStore ActiveStore | Out-Null
  }
}
`)
	}

	if opts.ManageRoutes {
		b.WriteString(`
$splitPrefixes = @('0.0.0.0/1', '128.0.0.0/1')
foreach ($prefix in $splitPrefixes) {
  $existing = Get-NetRoute -InterfaceAlias $AdapterName -DestinationPrefix $prefix -ErrorAction SilentlyContinue
  if ($null -eq $existing) {
    New-NetRoute -InterfaceAlias $AdapterName -DestinationPrefix $prefix -NextHop '0.0.0.0' -RouteMetric 1 -PolicyStore ActiveStore | Out-Null
  }
}
`)
	}

	return b.String()
}

// buildPrepareTUNScript waits for the wintun adapter (Get-NetAdapter) and applies IP/DNS/metric/routes
// in one PowerShell process so we pay powershell.exe startup once.
func buildPrepareTUNScript(opts TUNOptions) string {
	return buildWaitForTUNAdapterScript(opts.InterfaceAlias, 12, false) +
		buildConfigureTUNScript(opts) +
		"\nWrite-Output $adapter.ifIndex\n"
}

func parseTUNIfIndexOutput(out []byte) (int, error) {
	rawOut := strings.TrimSpace(strings.ReplaceAll(string(out), "\r\n", "\n"))
	if rawOut == "" {
		return 0, errors.New("prepare TUN: empty output")
	}
	var idx int
	lines := strings.Split(rawOut, "\n")
	for i := len(lines) - 1; i >= 0; i-- {
		line := strings.TrimSpace(strings.TrimRight(lines[i], "\r"))
		if line == "" {
			continue
		}
		if v, err := strconv.Atoi(line); err == nil && v > 0 {
			idx = v
			break
		}
	}
	if idx <= 0 {
		return 0, fmt.Errorf("prepare TUN: invalid ifIndex in output %q", rawOut)
	}
	return idx, nil
}

func tunStateFromOpts(opts TUNOptions, idx int) *TUNState {
	routePrefixes := []string{}
	bypassCIDRs := []string{}
	if opts.ManageRoutes {
		bypassCIDRs = append(bypassCIDRs, opts.BypassCIDRs...)
		routePrefixes = []string{"0.0.0.0/1", "128.0.0.0/1"}
	}
	return &TUNState{
		InterfaceAlias: opts.InterfaceAlias,
		InterfaceIndex: idx,
		IPAddress:      opts.IPAddress,
		PrefixLength:   opts.PrefixLength,
		DNSServers:     append([]string(nil), opts.DNSServers...),
		RoutePrefixes:  routePrefixes,
		BypassCIDRs:    bypassCIDRs,
	}
}

func runPowerShellOutput(script string) ([]byte, error) {
	command := exec.Command("powershell", "-NoProfile", "-Command", script)
	command.SysProcAttr = hiddenPowerShellAttributes()
	return command.Output()
}

func PrepareTUN(opts TUNOptions, diag *TUNPrepareDiagnostics) (*TUNState, error) {
	if opts.InterfaceAlias == "" {
		return nil, errors.New("tun interface alias is required")
	}

	tAll := time.Now()
	defer func() {
		if diag != nil {
			diag.TotalMs = time.Since(tAll).Milliseconds()
		}
	}()

	usePS := os.Getenv("TROODI_TUN_USE_PS") == "1"
	timingSplit := os.Getenv("TROODI_TUN_TIMING") == "1"

	if usePS {
		// Legacy PowerShell path (slower, use for debugging or if native fails)
		if timingSplit {
			if diag != nil {
				diag.Mode = "split_ps"
			}
			tw := time.Now()
			out, err := runPowerShellOutput(buildWaitForTUNAdapterScript(opts.InterfaceAlias, 12, true))
			if diag != nil {
				diag.WaitForAdapterMs = time.Since(tw).Milliseconds()
			}
			if err != nil {
				return nil, fmt.Errorf("prepare TUN (wait for adapter): %w", err)
			}
			idx, err := parseTUNIfIndexOutput(out)
			if err != nil {
				return nil, err
			}
			tc := time.Now()
			err = runPowerShell(buildConfigureTUNScript(opts))
			if diag != nil {
				diag.ConfigureMs = time.Since(tc).Milliseconds()
			}
			if err != nil {
				return nil, fmt.Errorf("prepare TUN (configure): %w", err)
			}
			return tunStateFromOpts(opts, idx), nil
		}
		if diag != nil {
			diag.Mode = "single_ps"
		}
		tps := time.Now()
		out, err := runPowerShellOutput(buildPrepareTUNScript(opts))
		if diag != nil {
			diag.SingleScriptMs = time.Since(tps).Milliseconds()
		}
		if err != nil {
			return nil, fmt.Errorf("prepare TUN (wait + configure): %w", err)
		}
		idx, err := parseTUNIfIndexOutput(out)
		if err != nil {
			return nil, err
		}
		return tunStateFromOpts(opts, idx), nil
	}

	// Fast path: wait for adapter in-process (no PowerShell loop) + configure via netsh/route
	tw := time.Now()
	var idx int
	var err error
	if os.Getenv("TROODI_TUN_WAIT_PS") == "1" {
		if diag != nil {
			diag.Mode = "native_wait_ps"
		}
		idx, err = waitForTUNAdapterPowerShell(opts.InterfaceAlias, diag)
	} else {
		if diag != nil {
			diag.Mode = "native"
		}
		idx, err = waitForTUNInterfaceIndex(opts.InterfaceAlias, 12*time.Second)
		if diag != nil {
			diag.WaitForAdapterMs = time.Since(tw).Milliseconds()
		}
		if err != nil {
			idx, err = waitForTUNAdapterPowerShell(opts.InterfaceAlias, diag)
			if diag != nil && err == nil {
				diag.Mode = "native_ps_fallback"
			}
		}
	}
	if err != nil {
		return nil, err
	}
	tc := time.Now()
	if err := configureTUNNative(opts, idx); err != nil {
		return nil, fmt.Errorf("prepare TUN (configure): %w", err)
	}
	if diag != nil {
		diag.ConfigureMs = time.Since(tc).Milliseconds()
	}
	return tunStateFromOpts(opts, idx), nil
}

func CleanupTUN(state *TUNState) error {
	if state == nil {
		return nil
	}

	var errs []string
	for _, prefix := range state.RoutePrefixes {
		if err := removeNetRoute(state.InterfaceAlias, prefix); err != nil {
			errs = append(errs, err.Error())
		}
	}
	for _, prefix := range state.BypassCIDRs {
		if err := removeNetRouteByPrefix(prefix); err != nil {
			errs = append(errs, err.Error())
		}
	}

	if err := resetTUNDNS(state.InterfaceAlias); err != nil {
		errs = append(errs, err.Error())
	}
	if err := resetTUNMetric(state.InterfaceAlias); err != nil {
		errs = append(errs, err.Error())
	}
	if err := removeTUNAddress(state.InterfaceAlias, state.IPAddress); err != nil {
		errs = append(errs, err.Error())
	}

	if len(errs) > 0 {
		return errors.New(strings.Join(errs, "; "))
	}

	return nil
}

func IsTUNSupported() bool {
	return true
}

func refreshInternetSettings() {
	wininet := syscall.NewLazyDLL("wininet.dll")
	internetSetOption := wininet.NewProc("InternetSetOptionW")
	const (
		internetOptionSettingsChanged = 39
		internetOptionRefresh         = 37
	)
	_, _, _ = internetSetOption.Call(0, uintptr(internetOptionSettingsChanged), 0, 0)
	_, _, _ = internetSetOption.Call(0, uintptr(internetOptionRefresh), 0, 0)
}

func escapeSingleQuotes(value string) string {
	return strings.ReplaceAll(value, "'", "''")
}

func runPowerShellJSON(script string) ([]byte, error) {
	command := exec.Command("powershell", "-NoProfile", "-Command", script)
	command.SysProcAttr = hiddenPowerShellAttributes()
	output, err := command.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("%w: %s", err, strings.TrimSpace(string(output)))
	}

	return output, nil
}

func runPowerShell(script string) error {
	command := exec.Command("powershell", "-NoProfile", "-Command", script)
	command.SysProcAttr = hiddenPowerShellAttributes()
	output, err := command.CombinedOutput()
	if err != nil {
		return fmt.Errorf("%w: %s", err, strings.TrimSpace(string(output)))
	}

	return nil
}

func removeTUNAddress(alias, ipAddress string) error {
	script := fmt.Sprintf(`
$existing = Get-NetIPAddress -InterfaceAlias '%s' -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.IPAddress -eq '%s' }
if ($null -ne $existing) {
  $existing | Remove-NetIPAddress -Confirm:$false
}
`, escapeSingleQuotes(alias), ipAddress)

	return runPowerShell(script)
}

func resetTUNDNS(alias string) error {
	script := fmt.Sprintf(
		"Set-DnsClientServerAddress -InterfaceAlias '%s' -ResetServerAddresses",
		escapeSingleQuotes(alias),
	)

	return runPowerShell(script)
}

func resetTUNMetric(alias string) error {
	script := fmt.Sprintf(
		"Set-NetIPInterface -InterfaceAlias '%s' -AutomaticMetric Enabled",
		escapeSingleQuotes(alias),
	)

	return runPowerShell(script)
}

func removeNetRoute(alias, prefix string) error {
	script := fmt.Sprintf(`
$existing = Get-NetRoute -InterfaceAlias '%s' -DestinationPrefix '%s' -ErrorAction SilentlyContinue
if ($null -ne $existing) {
  $existing | Remove-NetRoute -Confirm:$false
}
`, escapeSingleQuotes(alias), prefix)

	return runPowerShell(script)
}

func removeNetRouteByPrefix(prefix string) error {
	script := fmt.Sprintf(`
$existing = Get-NetRoute -DestinationPrefix '%s' -ErrorAction SilentlyContinue
if ($null -ne $existing) {
  $existing | Remove-NetRoute -Confirm:$false
}
`, prefix)

	return runPowerShell(script)
}

func hiddenPowerShellAttributes() *syscall.SysProcAttr {
	return &syscall.SysProcAttr{
		HideWindow:    true,
		CreationFlags: windows.CREATE_NO_WINDOW,
	}
}
