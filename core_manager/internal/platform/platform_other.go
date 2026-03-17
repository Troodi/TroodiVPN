//go:build !windows

package platform

import (
	"fmt"
	"net"
	"os/exec"
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

func IsElevated() bool {
	return true
}

func RequestElevation(executablePath, workingDirectory string) error {
	return nil
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
	return &DefaultRoute{
		InterfaceAlias: "default",
		InterfaceIndex: 1,
		NextHop:        "",
	}, nil
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
	return &TUNState{
		InterfaceAlias: opts.InterfaceAlias,
		InterfaceIndex: 1,
		IPAddress:      opts.IPAddress,
		PrefixLength:   opts.PrefixLength,
		DNSServers:     append([]string(nil), opts.DNSServers...),
		RoutePrefixes:  []string{"0.0.0.0/1", "128.0.0.0/1"},
		BypassCIDRs:    append([]string(nil), opts.BypassCIDRs...),
	}, nil
}

func CleanupTUN(state *TUNState) error {
	return nil
}

func IsTUNSupported() bool {
	return true
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
