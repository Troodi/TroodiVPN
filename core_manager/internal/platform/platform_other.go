//go:build !windows

package platform

type ProxySettings struct {
	Enabled  bool
	Server   string
	Override string
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
}

type TUNState struct {
	InterfaceAlias string
	InterfaceIndex int
	IPAddress      string
	PrefixLength   int
	DNSServers     []string
	RoutePrefixes  []string
}

func IsElevated() bool {
	return true
}

func RequestElevation(executablePath, workingDirectory string) error {
	return nil
}

func CaptureSystemProxy() (*ProxySettings, error) {
	return &ProxySettings{}, nil
}

func ApplySystemProxy(address string) (*ProxySettings, error) {
	return &ProxySettings{}, nil
}

func RestoreSystemProxy(previous *ProxySettings) error {
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
	}, nil
}

func CleanupTUN(state *TUNState) error {
	return nil
}

func IsTUNSupported() bool {
	return true
}
