//go:build !windows

package platform

import (
	"errors"
	"fmt"
	"net"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"
	"time"
)

type ProxySettings struct {
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
	InterfaceAlias string
	InterfaceIndex int
	NextHop        string
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

var linuxElevationState struct {
	mu       sync.RWMutex
	password string
}

func IsElevated() bool {
	if os.Geteuid() == 0 {
		return true
	}
	linuxElevationState.mu.RLock()
	defer linuxElevationState.mu.RUnlock()
	return linuxElevationState.password != ""
}

func RequestElevation(executablePath, workingDirectory string) error {
	return errors.New("sudo password is required on Linux")
}

func SetElevationSecret(secret string) error {
	if secret == "" {
		return errors.New("sudo password is required")
	}

	if os.Geteuid() == 0 {
		return nil
	}

	if err := validateSudoPassword(secret); err != nil {
		return err
	}

	linuxElevationState.mu.Lock()
	linuxElevationState.password = secret
	linuxElevationState.mu.Unlock()
	return nil
}

func CommandAsRoot(name string, args ...string) (*exec.Cmd, error) {
	if os.Geteuid() == 0 {
		return exec.Command(name, args...), nil
	}

	linuxElevationState.mu.RLock()
	password := linuxElevationState.password
	linuxElevationState.mu.RUnlock()
	if password == "" {
		return nil, errors.New("sudo password is not available")
	}

	sudoArgs := []string{"-S", "-p", "", "--preserve-env=xray.location.asset", "--", name}
	sudoArgs = append(sudoArgs, args...)
	cmd := exec.Command("sudo", sudoArgs...)
	cmd.Stdin = strings.NewReader(password + "\n")
	return cmd, nil
}

func CaptureSystemProxy() (*ProxySettings, error) {
	if _, err := exec.LookPath("gsettings"); err != nil {
		return &ProxySettings{}, nil
	}

	settings := &ProxySettings{}
	var err error

	if settings.ModeRaw, err = getGSetting("org.gnome.system.proxy", "mode"); err != nil {
		return nil, err
	}
	if settings.AutoconfigURLRaw, err = getGSetting("org.gnome.system.proxy", "autoconfig-url"); err != nil {
		return nil, err
	}
	if settings.IgnoreHostsRaw, err = getGSetting("org.gnome.system.proxy", "ignore-hosts"); err != nil {
		return nil, err
	}
	if settings.UseSameProxyRaw, err = getGSetting("org.gnome.system.proxy", "use-same-proxy"); err != nil {
		return nil, err
	}
	if settings.FTPHostRaw, err = getGSetting("org.gnome.system.proxy.ftp", "host"); err != nil {
		return nil, err
	}
	if settings.FTPPortRaw, err = getGSetting("org.gnome.system.proxy.ftp", "port"); err != nil {
		return nil, err
	}
	if settings.HTTPEnabledRaw, err = getGSetting("org.gnome.system.proxy.http", "enabled"); err != nil {
		return nil, err
	}
	if settings.HTTPHostRaw, err = getGSetting("org.gnome.system.proxy.http", "host"); err != nil {
		return nil, err
	}
	if settings.HTTPPortRaw, err = getGSetting("org.gnome.system.proxy.http", "port"); err != nil {
		return nil, err
	}
	if settings.HTTPUseAuthRaw, err = getGSetting("org.gnome.system.proxy.http", "use-authentication"); err != nil {
		return nil, err
	}
	if settings.HTTPAuthUserRaw, err = getGSetting("org.gnome.system.proxy.http", "authentication-user"); err != nil {
		return nil, err
	}
	if settings.HTTPAuthPasswordRaw, err = getGSetting("org.gnome.system.proxy.http", "authentication-password"); err != nil {
		return nil, err
	}
	if settings.HTTPSHostRaw, err = getGSetting("org.gnome.system.proxy.https", "host"); err != nil {
		return nil, err
	}
	if settings.HTTPSPortRaw, err = getGSetting("org.gnome.system.proxy.https", "port"); err != nil {
		return nil, err
	}
	if settings.SocksHostRaw, err = getGSetting("org.gnome.system.proxy.socks", "host"); err != nil {
		return nil, err
	}
	if settings.SocksPortRaw, err = getGSetting("org.gnome.system.proxy.socks", "port"); err != nil {
		return nil, err
	}

	return settings, nil
}

func ApplySystemProxy(address string) (*ProxySettings, error) {
	previous, err := CaptureSystemProxy()
	if err != nil {
		return nil, err
	}
	if _, err := exec.LookPath("gsettings"); err != nil {
		return previous, nil
	}

	host, port, err := net.SplitHostPort(address)
	if err != nil {
		return nil, err
	}

	updates := [][3]string{
		{"org.gnome.system.proxy", "mode", "'manual'"},
		{"org.gnome.system.proxy", "autoconfig-url", "''"},
		{"org.gnome.system.proxy", "use-same-proxy", "true"},
		{"org.gnome.system.proxy", "ignore-hosts", "['localhost', '127.0.0.0/8', '::1']"},
		{"org.gnome.system.proxy.ftp", "host", quoteGSettingsString(host)},
		{"org.gnome.system.proxy.ftp", "port", port},
		{"org.gnome.system.proxy.http", "enabled", "true"},
		{"org.gnome.system.proxy.http", "host", quoteGSettingsString(host)},
		{"org.gnome.system.proxy.http", "port", port},
		{"org.gnome.system.proxy.http", "use-authentication", "false"},
		{"org.gnome.system.proxy.http", "authentication-user", "''"},
		{"org.gnome.system.proxy.http", "authentication-password", "''"},
		{"org.gnome.system.proxy.https", "host", quoteGSettingsString(host)},
		{"org.gnome.system.proxy.https", "port", port},
		{"org.gnome.system.proxy.socks", "host", quoteGSettingsString(host)},
		{"org.gnome.system.proxy.socks", "port", port},
	}

	for _, item := range updates {
		if err := setGSetting(item[0], item[1], item[2]); err != nil {
			return nil, err
		}
	}

	return previous, nil
}

func RestoreSystemProxy(previous *ProxySettings) error {
	if _, err := exec.LookPath("gsettings"); err != nil {
		return nil
	}

	if previous == nil {
		return setGSetting("org.gnome.system.proxy", "mode", "'none'")
	}

	updates := [][3]string{
		{"org.gnome.system.proxy", "mode", previous.ModeRaw},
		{"org.gnome.system.proxy", "autoconfig-url", previous.AutoconfigURLRaw},
		{"org.gnome.system.proxy", "ignore-hosts", previous.IgnoreHostsRaw},
		{"org.gnome.system.proxy", "use-same-proxy", previous.UseSameProxyRaw},
		{"org.gnome.system.proxy.ftp", "host", previous.FTPHostRaw},
		{"org.gnome.system.proxy.ftp", "port", previous.FTPPortRaw},
		{"org.gnome.system.proxy.http", "enabled", previous.HTTPEnabledRaw},
		{"org.gnome.system.proxy.http", "host", previous.HTTPHostRaw},
		{"org.gnome.system.proxy.http", "port", previous.HTTPPortRaw},
		{"org.gnome.system.proxy.http", "use-authentication", previous.HTTPUseAuthRaw},
		{"org.gnome.system.proxy.http", "authentication-user", previous.HTTPAuthUserRaw},
		{"org.gnome.system.proxy.http", "authentication-password", previous.HTTPAuthPasswordRaw},
		{"org.gnome.system.proxy.https", "host", previous.HTTPSHostRaw},
		{"org.gnome.system.proxy.https", "port", previous.HTTPSPortRaw},
		{"org.gnome.system.proxy.socks", "host", previous.SocksHostRaw},
		{"org.gnome.system.proxy.socks", "port", previous.SocksPortRaw},
	}

	for _, item := range updates {
		if item[2] == "" {
			continue
		}
		if err := setGSetting(item[0], item[1], item[2]); err != nil {
			return err
		}
	}

	return nil
}

func EnsureWintunDLL(xrayBinaryPath string) error {
	return nil
}

func CaptureDefaultRoute() (*DefaultRoute, error) {
	output, err := exec.Command("ip", "route", "show", "default").CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("failed to inspect default route: %w (%s)", err, trimTrailingNewline(output))
	}

	line := strings.TrimSpace(string(output))
	if idx := strings.IndexByte(line, '\n'); idx >= 0 {
		line = strings.TrimSpace(line[:idx])
	}
	if line == "" {
		return nil, errors.New("default route is not available")
	}

	fields := strings.Fields(line)
	result := &DefaultRoute{}
	for i := 0; i < len(fields); i++ {
		switch fields[i] {
		case "via":
			if i+1 < len(fields) {
				result.NextHop = fields[i+1]
				i++
			}
		case "dev":
			if i+1 < len(fields) {
				result.InterfaceAlias = fields[i+1]
				i++
			}
		}
	}

	if result.InterfaceAlias == "" {
		return nil, fmt.Errorf("failed to parse default route: %s", line)
	}
	return result, nil
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

func PrepareTUN(opts TUNOptions) (*TUNState, error) {
	state := &TUNState{
		InterfaceAlias: opts.InterfaceAlias,
		InterfaceIndex: 1,
		IPAddress:      opts.IPAddress,
		PrefixLength:   opts.PrefixLength,
		DNSServers:     append([]string(nil), opts.DNSServers...),
		RoutePrefixes:  []string{"0.0.0.0/1", "128.0.0.0/1"},
		BypassCIDRs:    append([]string(nil), opts.BypassCIDRs...),
	}

	if err := waitForInterface(opts.InterfaceAlias, 12*time.Second); err != nil {
		return nil, err
	}
	if err := runRoot("ip", "link", "set", "dev", opts.InterfaceAlias, "up"); err != nil {
		return nil, err
	}
	if opts.MTU > 0 {
		if err := runRoot("ip", "link", "set", "dev", opts.InterfaceAlias, "mtu", strconv.Itoa(opts.MTU)); err != nil {
			return nil, err
		}
	}
	if opts.IPAddress != "" && opts.PrefixLength > 0 {
		if err := runRoot("ip", "addr", "replace", fmt.Sprintf("%s/%d", opts.IPAddress, opts.PrefixLength), "dev", opts.InterfaceAlias); err != nil {
			return nil, err
		}
	}

	if opts.ManageRoutes {
		for _, prefix := range state.RoutePrefixes {
			if err := runRoot("ip", "route", "replace", prefix, "dev", opts.InterfaceAlias); err != nil {
				return nil, err
			}
		}

		for _, cidr := range state.BypassCIDRs {
			args := []string{"route", "replace", cidr}
			if opts.DefaultRoute != nil && opts.DefaultRoute.NextHop != "" {
				args = append(args, "via", opts.DefaultRoute.NextHop)
			}
			if opts.DefaultRoute != nil && opts.DefaultRoute.InterfaceAlias != "" {
				args = append(args, "dev", opts.DefaultRoute.InterfaceAlias)
			}
			if err := runRoot("ip", args...); err != nil {
				return nil, err
			}
		}
	}

	return state, nil
}

func CleanupTUN(state *TUNState) error {
	if state == nil {
		return nil
	}

	for _, prefix := range state.RoutePrefixes {
		_ = runRoot("ip", "route", "del", prefix, "dev", state.InterfaceAlias)
	}
	for _, cidr := range state.BypassCIDRs {
		_ = runRoot("ip", "route", "del", cidr)
	}
	if state.IPAddress != "" && state.PrefixLength > 0 {
		_ = runRoot("ip", "addr", "del", fmt.Sprintf("%s/%d", state.IPAddress, state.PrefixLength), "dev", state.InterfaceAlias)
	}
	return nil
}

func IsTUNSupported() bool {
	return true
}

func validateSudoPassword(password string) error {
	cmd := exec.Command("sudo", "-S", "-k", "-p", "", "true")
	cmd.Stdin = strings.NewReader(password + "\n")
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("sudo authentication failed: %s", trimTrailingNewline(output))
	}
	return nil
}

func getGSetting(schema, key string) (string, error) {
	output, err := exec.Command("gsettings", "get", schema, key).CombinedOutput()
	if err != nil {
		return "", err
	}
	return string(trimTrailingNewline(output)), nil
}

func setGSetting(schema, key, value string) error {
	cmd := exec.Command("gsettings", "set", schema, key, value)
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("gsettings set %s %s failed: %w (%s)", schema, key, err, trimTrailingNewline(output))
	}
	return nil
}

func quoteGSettingsString(value string) string {
	return "'" + value + "'"
}

func trimTrailingNewline(value []byte) []byte {
	for len(value) > 0 && (value[len(value)-1] == '\n' || value[len(value)-1] == '\r') {
		value = value[:len(value)-1]
	}
	return value
}

func runRoot(name string, args ...string) error {
	cmd, err := CommandAsRoot(name, args...)
	if err != nil {
		return err
	}
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("%s %s failed: %w (%s)", name, strings.Join(args, " "), err, trimTrailingNewline(output))
	}
	return nil
}

func waitForInterface(name string, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if _, err := exec.Command("ip", "link", "show", "dev", name).CombinedOutput(); err == nil {
			return nil
		}
		time.Sleep(150 * time.Millisecond)
	}
	return fmt.Errorf("tun interface %s did not appear", name)
}
