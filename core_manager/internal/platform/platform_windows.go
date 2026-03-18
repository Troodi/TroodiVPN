//go:build windows

package platform

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
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

	return &ProxySettings{
		Enabled:  enable != 0,
		Server:   server,
		Override: override,
	}, nil
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

func PrepareTUN(opts TUNOptions) (*TUNState, error) {
	if opts.InterfaceAlias == "" {
		return nil, errors.New("tun interface alias is required")
	}

	index, err := waitForAdapterIndex(opts.InterfaceAlias, 12*time.Second)
	if err != nil {
		return nil, fmt.Errorf("waitForAdapterIndex: %w", err)
	}

	if err := ensureTUNAddress(opts); err != nil {
		return nil, fmt.Errorf("ensureTUNAddress: %w", err)
	}
	if err := setTUNDNS(opts); err != nil {
		return nil, fmt.Errorf("setTUNDNS: %w", err)
	}
	if err := setTUNMetric(opts.InterfaceAlias); err != nil {
		return nil, fmt.Errorf("setTUNMetric: %w", err)
	}
	routePrefixes := []string{}
	bypassCIDRs := []string{}
	if opts.ManageRoutes {
		if err := ensureBypassRoutes(opts); err != nil {
			return nil, fmt.Errorf("ensureBypassRoutes: %w", err)
		}
		bypassCIDRs = append(bypassCIDRs, opts.BypassCIDRs...)
		if err := ensureSplitDefaultRoutes(opts.InterfaceAlias); err != nil {
			return nil, fmt.Errorf("ensureSplitDefaultRoutes: %w", err)
		}
		routePrefixes = []string{"0.0.0.0/1", "128.0.0.0/1"}
	}

	return &TUNState{
		InterfaceAlias: opts.InterfaceAlias,
		InterfaceIndex: index,
		IPAddress:      opts.IPAddress,
		PrefixLength:   opts.PrefixLength,
		DNSServers:     append([]string(nil), opts.DNSServers...),
		RoutePrefixes:  routePrefixes,
		BypassCIDRs:    bypassCIDRs,
	}, nil
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

func waitForAdapterIndex(alias string, timeout time.Duration) (int, error) {
	timeoutSeconds := int(timeout / time.Second)
	if timeoutSeconds <= 0 {
		timeoutSeconds = 1
	}

	script := fmt.Sprintf(`
$deadline = (Get-Date).AddSeconds(%d)
while ((Get-Date) -lt $deadline) {
  $adapter = Get-NetAdapter -IncludeHidden -Name '%s' -ErrorAction SilentlyContinue | Select-Object -First 1 ifIndex
  if ($null -ne $adapter -and $adapter.ifIndex -gt 0) {
    $adapter | ConvertTo-Json -Compress
    exit 0
  }
  Start-Sleep -Milliseconds 150
}
exit 2
`, timeoutSeconds, escapeSingleQuotes(alias))

	output, err := runPowerShellJSON(script)
	if err != nil {
		return 0, fmt.Errorf("timed out waiting for TUN adapter %q", alias)
	}

	var payload struct {
		InterfaceIndex int `json:"ifIndex"`
	}
	if err := json.Unmarshal(output, &payload); err != nil {
		return 0, err
	}
	if payload.InterfaceIndex <= 0 {
		return 0, fmt.Errorf("timed out waiting for TUN adapter %q", alias)
	}

	return payload.InterfaceIndex, nil
}

func getAdapterIndex(alias string) (int, error) {
	script := fmt.Sprintf(`
$adapter = Get-NetAdapter -IncludeHidden -Name '%s' -ErrorAction SilentlyContinue | Select-Object -First 1 ifIndex
if ($null -eq $adapter) { exit 2 }
$adapter | ConvertTo-Json -Compress
`, escapeSingleQuotes(alias))

	output, err := runPowerShellJSON(script)
	if err != nil {
		return 0, err
	}

	var payload struct {
		InterfaceIndex int `json:"ifIndex"`
	}
	if err := json.Unmarshal(output, &payload); err != nil {
		return 0, err
	}

	return payload.InterfaceIndex, nil
}

func ensureTUNAddress(opts TUNOptions) error {
	script := fmt.Sprintf(`
$existing = Get-NetIPAddress -InterfaceAlias '%s' -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.IPAddress -eq '%s' }
if ($null -eq $existing) {
  New-NetIPAddress -InterfaceAlias '%s' -IPAddress '%s' -PrefixLength %d -Type Unicast -PolicyStore ActiveStore | Out-Null
}
`, escapeSingleQuotes(opts.InterfaceAlias), opts.IPAddress, escapeSingleQuotes(opts.InterfaceAlias), opts.IPAddress, opts.PrefixLength)

	return runPowerShell(script)
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

func setTUNDNS(opts TUNOptions) error {
	quotedServers := make([]string, 0, len(opts.DNSServers))
	for _, server := range opts.DNSServers {
		quotedServers = append(quotedServers, fmt.Sprintf("'%s'", escapeSingleQuotes(server)))
	}

	script := fmt.Sprintf(
		"Set-DnsClientServerAddress -InterfaceAlias '%s' -ServerAddresses @(%s)",
		escapeSingleQuotes(opts.InterfaceAlias),
		strings.Join(quotedServers, ", "),
	)

	return runPowerShell(script)
}

func resetTUNDNS(alias string) error {
	script := fmt.Sprintf(
		"Set-DnsClientServerAddress -InterfaceAlias '%s' -ResetServerAddresses",
		escapeSingleQuotes(alias),
	)

	return runPowerShell(script)
}

func setTUNMetric(alias string) error {
	script := fmt.Sprintf(
		"Set-NetIPInterface -InterfaceAlias '%s' -AutomaticMetric Disabled -InterfaceMetric 1",
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

func ensureSplitDefaultRoutes(alias string) error {
	for _, prefix := range []string{"0.0.0.0/1", "128.0.0.0/1"} {
		if err := ensureNetRoute(alias, prefix); err != nil {
			return err
		}
	}
	return nil
}

func ensureBypassRoutes(opts TUNOptions) error {
	if opts.DefaultRoute == nil {
		return errors.New("default route is required for managed TUN routes")
	}
	if opts.DefaultRoute.InterfaceIndex == 0 || opts.DefaultRoute.NextHop == "" {
		return errors.New("default route is missing interface index or next hop")
	}

	for _, prefix := range opts.BypassCIDRs {
		if err := ensureGatewayRoute(prefix, opts.DefaultRoute); err != nil {
			return err
		}
	}
	return nil
}

func ensureNetRoute(alias, prefix string) error {
	script := fmt.Sprintf(`
$existing = Get-NetRoute -InterfaceAlias '%s' -DestinationPrefix '%s' -ErrorAction SilentlyContinue
if ($null -eq $existing) {
  New-NetRoute -InterfaceAlias '%s' -DestinationPrefix '%s' -NextHop '0.0.0.0' -RouteMetric 1 -PolicyStore ActiveStore | Out-Null
}
`, escapeSingleQuotes(alias), prefix, escapeSingleQuotes(alias), prefix)

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

func ensureGatewayRoute(prefix string, route *DefaultRoute) error {
	script := fmt.Sprintf(`
$existing = Get-NetRoute -DestinationPrefix '%s' -ErrorAction SilentlyContinue |
  Where-Object { $_.ifIndex -eq %d -and $_.NextHop -eq '%s' }
if ($null -eq $existing) {
  New-NetRoute -DestinationPrefix '%s' -InterfaceIndex %d -NextHop '%s' -RouteMetric 1 -PolicyStore ActiveStore | Out-Null
}
`, prefix, route.InterfaceIndex, escapeSingleQuotes(route.NextHop), prefix, route.InterfaceIndex, escapeSingleQuotes(route.NextHop))

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
