package runtime

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/miekg/dns"
	"github.com/troodi/xray-desktop/core-manager/internal/config"
	"github.com/troodi/xray-desktop/core-manager/internal/platform"
	"github.com/troodi/xray-desktop/core-manager/internal/xray"
	"golang.org/x/net/proxy"
)

const maxLogLines = 200

const (
	runetFreedomGeoSiteURL = "https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geosite.dat"
	runetFreedomGeoIPURL   = "https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geoip.dat"
	loyalSoldierGeoSiteURL = "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
	loyalSoldierGeoIPURL   = "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
	routingAssetsTTL       = 6 * time.Hour

	// Local mixed inbound; must match xray buildInbounds.
	localMixedInboundPort = config.DefaultMixedInboundPort
	localMixedInboundAddr = config.DefaultMixedInboundAddr
)

type Status struct {
	Running                      bool                       `json:"running"`
	PID                          int                        `json:"pid"`
	BinaryPath                   string                     `json:"binaryPath"`
	ConfigPath                   string                     `json:"configPath"`
	LastError                    string                     `json:"lastError,omitempty"`
	LastExit                     string                     `json:"lastExit,omitempty"`
	Mode                         string                     `json:"mode"`
	LatencyMS                    int                        `json:"latencyMs"`
	PublicIP                     string                     `json:"publicIp"`
	DownloadBps                  uint64                     `json:"downloadBps"`
	UploadBps                    uint64                     `json:"uploadBps"`
	Ready                        bool                       `json:"ready"`
	Elevated                     bool                       `json:"elevated"`
	Logs                         []string                   `json:"logs"`
	RoutingAssetsStatus          string                     `json:"routingAssetsStatus"`
	RoutingAssetsError           string                     `json:"routingAssetsError,omitempty"`
	RoutingAssetsFiles           []RoutingAssetFileProgress `json:"routingAssetsFiles"`
	RussiaRoutingAssetsUpdatedAt string                     `json:"russiaRoutingAssetsUpdatedAt,omitempty"`
}

type Manager struct {
	mu             sync.Mutex
	cmd            *exec.Cmd
	running        bool
	binaryPath     string
	configPath     string
	logs           []string
	lastError      string
	lastExit       string
	mode           string
	latencyMS      int
	publicIP       string
	downloadBps    uint64
	uploadBps      uint64
	ready          bool
	metricsCancel  context.CancelFunc
	lastReadBytes  uint64
	lastWriteBytes uint64
	lastMetricsAt  time.Time
	lastIPLookupAt time.Time
	proxyState     *platform.ProxySettings
	tunState       *platform.TUNState

	assetsMu                 sync.Mutex
	routingAssetsStatus      string
	routingAssetsErr         string
	routingAssetsDownloadRun bool
	routingAssetFiles        []RoutingAssetFileProgress
}

func NewManager(binaryPath string) *Manager {
	return &Manager{binaryPath: binaryPath, routingAssetsStatus: "idle"}
}

func DefaultBinaryPath() string {
	fileName := "xray"
	if runtime.GOOS == "windows" {
		fileName += ".exe"
	}

	if executablePath, err := os.Executable(); err == nil {
		candidate := filepath.Join(filepath.Dir(executablePath), fileName)
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}
	}

	wd, err := os.Getwd()
	if err != nil {
		return filepath.Join("..", "xray_runtime", "bin", runtime.GOOS, fileName)
	}

	current := wd
	for i := 0; i < 6; i++ {
		candidate := filepath.Join(current, "xray_runtime", "bin", runtime.GOOS, fileName)
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}

		candidate = filepath.Join(current, "..", "xray_runtime", "bin", runtime.GOOS, fileName)
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}

		parent := filepath.Dir(current)
		if parent == current {
			break
		}
		current = parent
	}

	return filepath.Join("..", "xray_runtime", "bin", runtime.GOOS, fileName)
}

func (m *Manager) Start(cfg config.AppConfig) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.isRunningLocked() {
		return nil
	}

	if err := m.startLocked(cfg); err != nil {
		m.lastError = err.Error()
		return err
	}

	return nil
}

func (m *Manager) Restart(cfg config.AppConfig) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.isRunningLocked() {
		m.stopLocked()
	}

	if err := m.startLocked(cfg); err != nil {
		m.lastError = err.Error()
		return err
	}

	return nil
}

func (m *Manager) Stop() error {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.stopLocked()
}

func (m *Manager) Status() Status {
	m.mu.Lock()
	defer m.mu.Unlock()

	raSt, raErr, raFiles, raUpdated := m.routingAssetsSnapshotForStatus()

	status := Status{
		Running:                      m.running,
		BinaryPath:                   m.binaryPath,
		ConfigPath:                   m.configPath,
		LastError:                    m.lastError,
		LastExit:                     m.lastExit,
		Mode:                         m.mode,
		LatencyMS:                    m.latencyMS,
		PublicIP:                     m.publicIP,
		DownloadBps:                  m.downloadBps,
		UploadBps:                    m.uploadBps,
		Ready:                        m.ready,
		Elevated:                     platform.IsElevated(),
		Logs:                         append([]string(nil), m.logs...),
		RoutingAssetsStatus:          raSt,
		RoutingAssetsError:           raErr,
		RoutingAssetsFiles:           raFiles,
		RussiaRoutingAssetsUpdatedAt: raUpdated,
	}

	if m.running && m.cmd != nil && m.cmd.Process != nil {
		status.PID = m.cmd.Process.Pid
	}

	return status
}

func (m *Manager) startLocked(cfg config.AppConfig) error {
	startedAt := time.Now()

	if err := m.ensureBinaryLocked(); err != nil {
		return err
	}
	assetDir, err := m.startLockedRussiaAssetPath(cfg)
	if err != nil {
		return err
	}
	if err := m.cleanupStaleProcessesLocked(m.binaryPath); err != nil {
		return err
	}
	if cfg.TUNEnabled && !platform.IsElevated() {
		return errors.New("TUN mode requires administrator rights")
	}
	buildOptions := xray.DefaultBuildOptions()
	tunOptions := platform.DefaultTUNOptions()
	if cfg.TUNEnabled {
		tunOptions.DNSServers = []string{tunOptions.IPAddress}

		m.appendLogLocked(fmt.Sprintf("[%s] TUN: validating wintun.dll", time.Now().Format(time.RFC3339)))
		if err := platform.EnsureWintunDLL(m.binaryPath); err != nil {
			return err
		}

		m.appendLogLocked(fmt.Sprintf("[%s] TUN: capturing default route", time.Now().Format(time.RFC3339)))
		defaultRoute, err := platform.CaptureDefaultRoute()
		if err != nil {
			return err
		}
		m.appendLogLocked(fmt.Sprintf("[%s] TUN: default route captured in %d ms", time.Now().Format(time.RFC3339), time.Since(startedAt).Milliseconds()))
		activeProfile := activeProfile(cfg)
		buildOptions.BindInterface = defaultRoute.InterfaceAlias
		buildOptions.BindAddress = defaultRoute.IPAddress
		tunOptions.ManageRoutes = true
		tunOptions.DefaultRoute = defaultRoute
		if tunOptions.ManageRoutes {
			bypassCIDRs, err := resolveBypassCIDRs(activeProfile)
			if err != nil {
				return err
			}
			tunOptions.BypassCIDRs = bypassCIDRs
		}
		buildOptions.TUNInterface = tunOptions.InterfaceAlias
		buildOptions.TUNAddress = tunOptions.IPAddress
		buildOptions.TUNMTU = tunOptions.MTU
	}

	configPath, err := m.writeConfigLocked(cfg, buildOptions)
	if err != nil {
		return err
	}

	var cmd *exec.Cmd
	if cfg.TUNEnabled {
		cmd, err = platform.CommandAsRoot(m.binaryPath, "run", "-c", configPath)
		if err != nil {
			return err
		}
	} else {
		cmd = exec.Command(m.binaryPath, "run", "-c", configPath)
	}
	cmd.Dir = filepath.Dir(m.binaryPath)
	cmd.Env = append(os.Environ(), "xray.location.asset="+assetDir)
	cmd.SysProcAttr = hiddenProcessAttributes()

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}

	stderr, err := cmd.StderrPipe()
	if err != nil {
		return err
	}

	if err := cmd.Start(); err != nil {
		return err
	}

	go m.captureLogs(stdout)
	go m.captureLogs(stderr)

	m.cmd = cmd
	m.running = true
	m.configPath = configPath
	m.lastError = ""
	m.lastExit = ""
	m.mode = "proxy"
	m.publicIP = ""
	m.downloadBps = 0
	m.uploadBps = 0
	m.ready = false
	m.lastReadBytes = 0
	m.lastWriteBytes = 0
	m.lastMetricsAt = time.Time{}
	m.lastIPLookupAt = time.Time{}
	if cfg.TUNEnabled {
		m.mode = "tun"
	}
	m.appendLogLocked(fmt.Sprintf("[%s] xray started (pid %d)", time.Now().Format(time.RFC3339), cmd.Process.Pid))
	if err := m.applySystemProxyLocked(cfg); err != nil {
		m.appendLogLocked("system proxy error: " + err.Error())
	}
	if cfg.TUNEnabled {
		m.appendLogLocked(fmt.Sprintf("[%s] TUN: preparing adapter and routes", time.Now().Format(time.RFC3339)))
		prepareStartedAt := time.Now()
		tunState, err := platform.PrepareTUN(tunOptions)
		if err != nil {
			_ = m.stopLocked()
			return err
		}
		m.tunState = tunState
		if tunOptions.ManageRoutes {
			if len(tunState.BypassCIDRs) > 0 {
				m.appendLogLocked(fmt.Sprintf("[%s] pinned upstream routes outside TUN: %s", time.Now().Format(time.RFC3339), strings.Join(tunState.BypassCIDRs, ", ")))
			}
			m.appendLogLocked(fmt.Sprintf("[%s] TUN adapter %s configured with system routes", time.Now().Format(time.RFC3339), tunState.InterfaceAlias))
		} else {
			m.appendLogLocked(fmt.Sprintf("[%s] TUN adapter %s configured in safe test mode (routes unchanged)", time.Now().Format(time.RFC3339), tunState.InterfaceAlias))
		}
		m.ready = true
		m.appendLogLocked(fmt.Sprintf("[%s] TUN: adapter and routes ready in %d ms", time.Now().Format(time.RFC3339), time.Since(prepareStartedAt).Milliseconds()))
	}
	m.startMetricsLoopLocked(cfg)
	go m.waitForExit(cmd)

	time.Sleep(300 * time.Millisecond)
	if !m.running {
		status := m.Status()
		if status.LastExit != "" {
			return errors.New(status.LastExit)
		}
		return errors.New("xray exited immediately after start")
	}

	if cfg.TUNEnabled {
		m.appendLogLocked(fmt.Sprintf("[%s] TUN: total startup completed in %d ms", time.Now().Format(time.RFC3339), time.Since(startedAt).Milliseconds()))
	}

	return nil
}

func (m *Manager) stopLocked() error {
	if !m.isRunningLocked() {
		return nil
	}

	proc := m.cmd.Process
	m.appendLogLocked(fmt.Sprintf("[%s] stopping xray", time.Now().Format(time.RFC3339)))
	err := proc.Kill()
	if err != nil && !errors.Is(err, os.ErrProcessDone) {
		m.lastError = err.Error()
		return err
	}
	if cleanupErr := m.cleanupStaleProcessesLocked(m.binaryPath); cleanupErr != nil {
		m.appendLogLocked("stale process cleanup error: " + cleanupErr.Error())
	}

	m.running = false
	m.cmd = nil
	m.stopMetricsLoopLocked()
	if err := platform.CleanupTUN(m.tunState); err == nil {
		m.tunState = nil
	}
	if err := platform.RestoreSystemProxy(m.proxyState); err == nil {
		m.proxyState = nil
	}
	m.lastExit = "xray stopped"
	m.latencyMS = 0
	m.publicIP = ""
	m.downloadBps = 0
	m.uploadBps = 0
	m.ready = false

	return nil
}

func (m *Manager) ensureBinaryLocked() error {
	if m.binaryPath == "" {
		m.binaryPath = DefaultBinaryPath()
	}

	abs, err := filepath.Abs(m.binaryPath)
	if err == nil {
		m.binaryPath = abs
	}

	info, err := os.Stat(m.binaryPath)
	if err != nil {
		return fmt.Errorf("xray binary not found at %s", m.binaryPath)
	}

	if info.IsDir() {
		return fmt.Errorf("xray binary path points to a directory: %s", m.binaryPath)
	}

	return nil
}

func (m *Manager) appendLog(line string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.appendLogLocked(line)
}

func defaultAssetDir() (string, error) {
	if cacheDir, err := os.UserCacheDir(); err == nil && cacheDir != "" {
		return filepath.Join(cacheDir, "troodi-vpn", "xray-assets"), nil
	}
	if configDir, err := os.UserConfigDir(); err == nil && configDir != "" {
		return filepath.Join(configDir, "troodi-vpn", "xray-assets"), nil
	}
	return filepath.Join(os.TempDir(), "troodi-vpn", "xray-assets"), nil
}

func isFreshFile(path string, ttl time.Duration) bool {
	info, err := os.Stat(path)
	if err != nil || info.IsDir() {
		return false
	}
	return time.Since(info.ModTime()) < ttl && info.Size() > 0
}

func downloadFile(url, path string) error {
	return downloadFileWithProgress(url, path, nil)
}

func downloadFileWithProgress(url, path string, onProgress func(downloaded, total int64)) error {
	client := newDownloadHTTPClient()
	response, err := client.Get(url)
	if err != nil {
		return err
	}
	defer response.Body.Close()

	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return fmt.Errorf("unexpected status %s", response.Status)
	}

	var total int64
	if response.ContentLength > 0 {
		total = response.ContentLength
	}
	if onProgress != nil {
		onProgress(0, total)
	}

	tmpPath := path + ".tmp"
	file, err := os.Create(tmpPath)
	if err != nil {
		return err
	}

	buf := make([]byte, 32*1024)
	var downloaded int64
	lastReport := int64(-1)
	const reportStep = 64 * 1024

	copyErr := func() error {
		defer file.Close()
		for {
			n, rerr := response.Body.Read(buf)
			if n > 0 {
				if _, werr := file.Write(buf[:n]); werr != nil {
					return werr
				}
				downloaded += int64(n)
				if onProgress != nil &&
					(lastReport < 0 || downloaded-lastReport >= reportStep || (total > 0 && downloaded == total)) {
					onProgress(downloaded, total)
					lastReport = downloaded
				}
			}
			if rerr == io.EOF {
				break
			}
			if rerr != nil {
				return rerr
			}
		}
		if onProgress != nil {
			onProgress(downloaded, total)
		}
		return file.Sync()
	}()
	if copyErr != nil {
		_ = os.Remove(tmpPath)
		return copyErr
	}

	if err := os.Rename(tmpPath, path); err != nil {
		_ = os.Remove(tmpPath)
		return err
	}
	return nil
}

func newDownloadHTTPClient() *http.Client {
	// Russia "warmup" needs network access; on Linux we want to respect
	// GNOME system proxy (HTTP/SOCKS) because env vars might be unset.
	transport := &http.Transport{
		Proxy: http.ProxyFromEnvironment,
	}

	// Try to use GNOME proxy only when env proxies are not set.
	// (This avoids overriding explicit per-process proxy config.)
	if os.Getenv("HTTP_PROXY") == "" &&
		os.Getenv("http_proxy") == "" &&
		os.Getenv("HTTPS_PROXY") == "" &&
		os.Getenv("https_proxy") == "" {
		if settings, err := platform.CaptureSystemProxy(); err == nil && settings != nil {
			mode := unquoteGSettingsString(settings.ModeRaw)
			if mode == "manual" {
				// Prefer HTTP proxy if enabled.
				if parseGSettingsBool(settings.HTTPEnabledRaw) {
					if host := unquoteGSettingsString(settings.HTTPHostRaw); host != "" {
						if port, err := parseGSettingsInt(settings.HTTPPortRaw); err == nil && port > 0 {
							if proxyURL, err := url.Parse(fmt.Sprintf("http://%s:%d", host, port)); err == nil {
								transport.Proxy = http.ProxyURL(proxyURL)
								// Keep default Dialer for the HTTP proxy itself.
							}
						}
					}
				} else {
					// Fallback to SOCKS5.
					if host := unquoteGSettingsString(settings.SocksHostRaw); host != "" {
						if port, err := parseGSettingsInt(settings.SocksPortRaw); err == nil && port > 0 {
							dialer, err := proxy.SOCKS5(
								"tcp",
								net.JoinHostPort(host, strconv.Itoa(port)),
								nil,
								&net.Dialer{Timeout: 30 * time.Second},
							)
							if err == nil {
								transport.Proxy = nil
								transport.DialContext = func(_ context.Context, network, addr string) (net.Conn, error) {
									return dialer.Dial(network, addr)
								}
							}
						}
					}
				}
			}
		}
	}

	return &http.Client{
		Timeout:   6 * time.Minute,
		Transport: transport,
	}
}

func unquoteGSettingsString(raw string) string {
	s := strings.TrimSpace(raw)
	s = strings.Trim(s, "\"'")
	return s
}

func parseGSettingsBool(raw string) bool {
	s := strings.ToLower(unquoteGSettingsString(raw))
	return s == "true" || s == "1" || s == "yes" || s == "on"
}

func parseGSettingsInt(raw string) (int, error) {
	s := unquoteGSettingsString(raw)
	return strconv.Atoi(s)
}

func copyRoutingAssetsToBinaryDir(assetDir, binaryDir string, assets []struct {
	name string
	url  string
}) error {
	if binaryDir == "" {
		return nil
	}

	for _, asset := range assets {
		source := filepath.Join(assetDir, asset.name)
		destination := filepath.Join(binaryDir, asset.name)
		if err := copyFileIfChanged(source, destination); err != nil {
			return fmt.Errorf("failed to sync %s next to xray.exe: %w", asset.name, err)
		}
	}

	return nil
}

func copyFileIfChanged(source, destination string) error {
	sourceInfo, err := os.Stat(source)
	if err != nil {
		return err
	}

	if destInfo, err := os.Stat(destination); err == nil {
		if destInfo.Size() == sourceInfo.Size() && !sourceInfo.ModTime().After(destInfo.ModTime()) {
			return nil
		}
	}

	input, err := os.Open(source)
	if err != nil {
		return err
	}
	defer input.Close()

	output, err := os.Create(destination)
	if err != nil {
		return err
	}

	if _, err := io.Copy(output, input); err != nil {
		output.Close()
		return err
	}
	if err := output.Close(); err != nil {
		return err
	}

	return os.Chtimes(destination, time.Now(), sourceInfo.ModTime())
}

func (m *Manager) writeConfigLocked(cfg config.AppConfig, options xray.BuildOptions) (string, error) {
	tempDir := filepath.Join(os.TempDir(), "xray-desktop")
	if err := os.MkdirAll(tempDir, 0o755); err != nil {
		return "", err
	}

	path := filepath.Join(tempDir, "generated-config.json")
	payload := xray.BuildWithOptions(cfg, options)
	data, err := json.MarshalIndent(payload, "", "  ")
	if err != nil {
		return "", err
	}

	if err := os.WriteFile(path, data, 0o644); err != nil {
		return "", err
	}

	return path, nil
}

func (m *Manager) captureLogs(reader io.Reader) {
	scanner := bufio.NewScanner(reader)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		m.mu.Lock()
		m.appendLogLocked(line)
		m.mu.Unlock()
	}

	if err := scanner.Err(); err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "file already closed") {
			return
		}
		m.mu.Lock()
		m.appendLogLocked("log reader error: " + err.Error())
		m.mu.Unlock()
	}
}

func (m *Manager) waitForExit(cmd *exec.Cmd) {
	err := cmd.Wait()

	m.mu.Lock()
	defer m.mu.Unlock()

	if m.cmd != cmd {
		return
	}

	if err != nil {
		m.lastExit = err.Error()
		m.appendLogLocked("xray exited: " + err.Error())
	} else {
		m.lastExit = "xray exited cleanly"
		m.appendLogLocked(m.lastExit)
	}
	if cleanupErr := m.cleanupStaleProcessesLocked(m.binaryPath); cleanupErr != nil {
		m.appendLogLocked("stale process cleanup error: " + cleanupErr.Error())
	}

	m.stopMetricsLoopLocked()
	if cleanupErr := platform.CleanupTUN(m.tunState); cleanupErr == nil {
		m.tunState = nil
	}
	if restoreErr := platform.RestoreSystemProxy(m.proxyState); restoreErr == nil {
		m.proxyState = nil
	}
	m.latencyMS = 0
	m.publicIP = ""
	m.downloadBps = 0
	m.uploadBps = 0
	m.ready = false
	m.running = false
	m.cmd = nil
}

func (m *Manager) appendLogLocked(line string) {
	m.logs = append(m.logs, line)
	if len(m.logs) > maxLogLines {
		m.logs = append([]string(nil), m.logs[len(m.logs)-maxLogLines:]...)
	}
	writeRuntimeDiagnosticLine(line)
}

func writeRuntimeDiagnosticLine(line string) {
	logDir := filepath.Join(os.TempDir(), "troodi-vpn")
	if err := os.MkdirAll(logDir, 0o755); err != nil {
		return
	}
	logPath := filepath.Join(logDir, "core-manager-runtime.log")
	message := fmt.Sprintf("%s %s\n", time.Now().Format(time.RFC3339Nano), line)
	file, err := os.OpenFile(logPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	defer file.Close()
	_, _ = file.WriteString(message)
}

func activeProfile(cfg config.AppConfig) config.ServerProfile {
	for _, profile := range cfg.Profiles {
		if profile.ID == cfg.ActiveProfileID {
			return profile
		}
	}
	if len(cfg.Profiles) > 0 {
		return cfg.Profiles[0]
	}
	return config.ServerProfile{}
}

func resolveBypassCIDRs(profile config.ServerProfile) ([]string, error) {
	if profile.Address == "" {
		return nil, errors.New("active profile address is required for full TUN mode")
	}

	if ip := net.ParseIP(profile.Address); ip != nil {
		if ipv4 := ip.To4(); ipv4 != nil {
			return []string{ipv4.String() + "/32"}, nil
		}
		return []string{ip.String() + "/128"}, nil
	}

	ips, err := net.LookupIP(profile.Address)
	if err != nil {
		return nil, fmt.Errorf("failed to resolve upstream host %q for full TUN mode: %w", profile.Address, err)
	}

	cidrs := make([]string, 0, len(ips))
	for _, ip := range ips {
		if ipv4 := ip.To4(); ipv4 != nil {
			cidrs = append(cidrs, ipv4.String()+"/32")
		}
	}
	if len(cidrs) == 0 {
		return nil, fmt.Errorf("no IPv4 addresses resolved for upstream host %q", profile.Address)
	}
	return cidrs, nil
}

func (m *Manager) isRunningLocked() bool {
	return m.running && m.cmd != nil && m.cmd.Process != nil
}

func (m *Manager) cleanupStaleProcessesLocked(binaryPath string) error {
	currentPID := 0
	if m.cmd != nil && m.cmd.Process != nil {
		currentPID = m.cmd.Process.Pid
	}

	normalizedBinaryPath, err := filepath.EvalSymlinks(binaryPath)
	if err != nil {
		normalizedBinaryPath = binaryPath
	}

	m.appendLogLocked(fmt.Sprintf(
		"[%s] cleanupStaleProcesses: currentPID=%d binaryPath=%q",
		time.Now().Format(time.RFC3339Nano),
		currentPID,
		binaryPath,
	))

	if runtime.GOOS == "windows" {
		pids, err := findBinaryProcessIDs(binaryPath)
		if err != nil {
			return err
		}

		for _, pid := range pids {
			if pid == 0 || pid == currentPID {
				continue
			}

			cmd := exec.Command("taskkill", "/PID", strconv.Itoa(pid), "/T", "/F")
			cmd.SysProcAttr = hiddenProcessAttributes()
			if output, err := cmd.CombinedOutput(); err != nil {
				return fmt.Errorf("failed to cleanup stale xray process %d: %w (%s)", pid, err, strings.TrimSpace(string(output)))
			}
			m.appendLogLocked(fmt.Sprintf("[%s] cleaned stale xray process (pid %d)", time.Now().Format(time.RFC3339), pid))
		}

		return nil
	}

	pids := map[int]struct{}{}
	if byBinary, err := findUnixBinaryProcessIDs(binaryPath); err == nil {
		for _, pid := range byBinary {
			pids[pid] = struct{}{}
		}
	}

	// Additionally, gather any process listening on the local mixed inbound port
	// and kill it only if it matches our exact xray binary.
	// This prevents stale instances from keeping the local mixed inbound port busy.
	if byPort, err := findListeningProcessIDs(localMixedInboundPort); err == nil {
		for _, pid := range byPort {
			if pid == 0 || pid == currentPID {
				continue
			}
			if m.pidMatchesBinary(pid, normalizedBinaryPath) {
				pids[pid] = struct{}{}
			}
		}
	} else {
		m.appendLogLocked(fmt.Sprintf(
			"[%s] cleanupStaleProcesses: findListeningProcessIDs failed: %v",
			time.Now().Format(time.RFC3339Nano),
			err,
		))
	}

	if len(pids) > 0 {
		first := make([]int, 0, len(pids))
		for pid := range pids {
			first = append(first, pid)
		}
		m.appendLogLocked(fmt.Sprintf(
			"[%s] cleanupStaleProcesses: candidatePIDs=%v",
			time.Now().Format(time.RFC3339Nano),
			first,
		))
	}

	for pid := range pids {
		if pid == 0 || pid == currentPID {
			continue
		}
		if err := m.terminateUnixProcess(pid); err != nil {
			return err
		}
		m.appendLogLocked(fmt.Sprintf("[%s] cleaned stale xray process (pid %d)", time.Now().Format(time.RFC3339), pid))
	}

	return nil
}

func (m *Manager) pidMatchesBinary(pid int, normalizedBinaryPath string) bool {
	exePath, err := os.Readlink(filepath.Join("/proc", strconv.Itoa(pid), "exe"))
	if err != nil {
		return false
	}
	normalizedExePath, err := filepath.EvalSymlinks(exePath)
	if err != nil {
		normalizedExePath = exePath
	}
	return filepath.Clean(normalizedExePath) == filepath.Clean(normalizedBinaryPath)
}

func findBinaryProcessIDs(binaryPath string) ([]int, error) {
	escapedPath := strings.ReplaceAll(binaryPath, "'", "''")
	script := fmt.Sprintf(
		"$procs = Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -eq '%s' }; $procs | ForEach-Object { $_.ProcessId }",
		escapedPath,
	)

	cmd := exec.Command("powershell", "-NoProfile", "-Command", script)
	cmd.SysProcAttr = hiddenProcessAttributes()
	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("failed to inspect existing xray processes: %w (%s)", err, strings.TrimSpace(string(output)))
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	pids := make([]int, 0, len(lines))
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		pid, err := strconv.Atoi(line)
		if err != nil {
			return nil, fmt.Errorf("failed to parse process id %q", line)
		}
		pids = append(pids, pid)
	}

	return pids, nil
}

func findListeningProcessIDs(port int) ([]int, error) {
	cmd := exec.Command("ss", "-lptn", fmt.Sprintf("sport = :%d", port))
	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil, err
	}

	matches := regexp.MustCompile(`pid=(\d+)`).FindAllStringSubmatch(string(output), -1)
	pids := make([]int, 0, len(matches))
	seen := map[int]struct{}{}
	for _, match := range matches {
		pid, err := strconv.Atoi(match[1])
		if err != nil {
			continue
		}
		if _, exists := seen[pid]; exists {
			continue
		}
		seen[pid] = struct{}{}
		pids = append(pids, pid)
	}

	return pids, nil
}

func findUnixBinaryProcessIDs(binaryPath string) ([]int, error) {
	normalizedBinaryPath, err := filepath.EvalSymlinks(binaryPath)
	if err != nil {
		normalizedBinaryPath = binaryPath
	}

	cmd := exec.Command("pgrep", "-f", binaryPath)
	output, err := cmd.CombinedOutput()
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok && exitErr.ExitCode() == 1 {
			return nil, nil
		}
		return nil, err
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	pids := make([]int, 0, len(lines))
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		pid, err := strconv.Atoi(line)
		if err != nil {
			continue
		}

		// pgrep -f may match unrelated commands that only contain the same path
		// prefix (e.g. xray_desktop_ui). Keep only processes whose executable
		// actually resolves to the target xray binary.
		exePath, err := os.Readlink(filepath.Join("/proc", strconv.Itoa(pid), "exe"))
		if err != nil {
			continue
		}
		normalizedExePath, err := filepath.EvalSymlinks(exePath)
		if err != nil {
			normalizedExePath = exePath
		}
		if filepath.Clean(normalizedExePath) != filepath.Clean(normalizedBinaryPath) {
			continue
		}

		pids = append(pids, pid)
	}
	return pids, nil
}

func processParentPID(pid int) (int, error) {
	cmd := exec.Command("ps", "-o", "ppid=", "-p", strconv.Itoa(pid))
	output, err := cmd.CombinedOutput()
	if err != nil {
		return 0, err
	}
	value := strings.TrimSpace(string(output))
	if value == "" {
		return 0, nil
	}
	return strconv.Atoi(value)
}

func processCommandLine(pid int) (string, error) {
	cmd := exec.Command("ps", "-o", "args=", "-p", strconv.Itoa(pid))
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

func (m *Manager) terminateUnixProcess(pid int) error {
	if pid <= 0 {
		return nil
	}

	// Diagnostics: try to understand what we are killing.
	exePath, _ := os.Readlink(filepath.Join("/proc", strconv.Itoa(pid), "exe"))
	var cmdline string
	if cmdlineRaw, err := os.ReadFile(filepath.Join("/proc", strconv.Itoa(pid), "cmdline")); err == nil {
		cmdline = strings.ReplaceAll(string(cmdlineRaw), "\x00", " ")
	}
	m.appendLogLocked(fmt.Sprintf(
		"[%s] terminateUnixProcess: pid=%d exe=%q cmdline=%q",
		time.Now().Format(time.RFC3339Nano),
		pid,
		exePath,
		cmdline,
	))

	kill := func(signal string, elevated bool) ([]byte, error) {
		args := []string{"-" + signal, strconv.Itoa(pid)}
		if elevated {
			cmd, err := platform.CommandAsRoot("kill", args...)
			if err != nil {
				return nil, err
			}
			return cmd.CombinedOutput()
		}
		return exec.Command("kill", args...).CombinedOutput()
	}

	if _, err := kill("TERM", false); err == nil {
		if waitForPortRelease(localMixedInboundPort, pid, 800*time.Millisecond) {
			return nil
		}
	}
	if _, err := kill("TERM", true); err == nil {
		if waitForPortRelease(localMixedInboundPort, pid, 1200*time.Millisecond) {
			return nil
		}
	}
	if output, err := kill("KILL", true); err != nil {
		return fmt.Errorf("failed to cleanup stale xray process %d: %w (%s)", pid, err, strings.TrimSpace(string(output)))
	}
	if !waitForPortRelease(localMixedInboundPort, pid, 1200*time.Millisecond) {
		return fmt.Errorf("stale xray process %d did not release port %d", pid, localMixedInboundPort)
	}
	return nil
}

func waitForPortRelease(port int, pid int, timeout time.Duration) bool {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		pids, err := findListeningProcessIDs(port)
		if err == nil {
			stillListening := false
			for _, current := range pids {
				if current == pid {
					stillListening = true
					break
				}
			}
			if !stillListening {
				return true
			}
		}
		time.Sleep(120 * time.Millisecond)
	}
	return false
}

func (m *Manager) applySystemProxyLocked(cfg config.AppConfig) error {
	if cfg.TUNEnabled || !cfg.SystemProxyEnabled {
		if m.proxyState != nil {
			if err := platform.RestoreSystemProxy(m.proxyState); err != nil {
				return err
			}
			m.proxyState = nil
		}
		return nil
	}

	if m.proxyState == nil {
		previous, err := platform.ApplySystemProxy(localMixedInboundAddr)
		if err != nil {
			return err
		}
		m.proxyState = previous
	}

	return nil
}

func (m *Manager) startMetricsLoopLocked(cfg config.AppConfig) {
	m.stopMetricsLoopLocked()

	ctx, cancel := context.WithCancel(context.Background())
	m.metricsCancel = cancel

	go func() {
		ticker := time.NewTicker(1 * time.Second)
		defer ticker.Stop()

		m.refreshRuntimeMetrics(cfg)
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				m.refreshRuntimeMetrics(cfg)
			}
		}
	}()
}

func (m *Manager) stopMetricsLoopLocked() {
	if m.metricsCancel != nil {
		m.metricsCancel()
		m.metricsCancel = nil
	}
}

func (m *Manager) refreshRuntimeMetrics(cfg config.AppConfig) {
	m.mu.Lock()
	running := m.running
	mode := m.mode
	shouldRefreshIP := m.publicIP == "" || time.Since(m.lastIPLookupAt) >= 10*time.Second
	currentIP := m.publicIP
	m.mu.Unlock()

	latency := measureLatency(cfg)
	publicIP := ""

	if shouldRefreshIP {
		if ip, err := lookupExternalIP(cfg); err == nil {
			publicIP = ip
		}
	} else {
		publicIP = currentIP
	}

	downloadBps, uploadBps := m.measureProcessIO()

	localInboundReady := false
	if running && mode == "proxy" {
		localInboundReady = mixedInboundListening()
	}

	m.mu.Lock()
	defer m.mu.Unlock()
	if !m.running {
		return
	}
	m.latencyMS = latency
	if publicIP != "" {
		m.publicIP = publicIP
		m.lastIPLookupAt = time.Now()
	}
	m.downloadBps = downloadBps
	m.uploadBps = uploadBps
	m.ready = m.running && (m.mode == "tun" || localInboundReady || m.latencyMS > 0 || m.publicIP != "")
}

func mixedInboundListening() bool {
	conn, err := net.DialTimeout("tcp", localMixedInboundAddr, 800*time.Millisecond)
	if err != nil {
		return false
	}
	_ = conn.Close()
	return true
}

func measureLatency(cfg config.AppConfig) int {
	profile := activeProfile(cfg)
	if profile.Address != "" && profile.Port > 0 {
		address := net.JoinHostPort(profile.Address, strconv.Itoa(profile.Port))
		startedAt := time.Now()
		conn, err := net.DialTimeout("tcp", address, 2*time.Second)
		if err == nil {
			_ = conn.Close()
			latency := int(time.Since(startedAt).Milliseconds())
			if latency == 0 {
				return 1
			}
			return latency
		}
	}

	startedAt := time.Now()
	conn, err := dialDiagnosticTarget(cfg, "8.8.8.8:53")
	if err != nil {
		return 0
	}
	defer conn.Close()

	if err := queryGoogleDNS(conn); err != nil {
		return 0
	}

	latency := int(time.Since(startedAt).Milliseconds())
	if latency == 0 {
		return 1
	}
	return latency
}

func dialDiagnosticTarget(cfg config.AppConfig, address string) (net.Conn, error) {
	if cfg.TUNEnabled {
		return net.DialTimeout("tcp", address, 2*time.Second)
	}

	dialer, err := proxy.SOCKS5(
		"tcp",
		localMixedInboundAddr,
		nil,
		&net.Dialer{Timeout: 2 * time.Second},
	)
	if err != nil {
		return nil, err
	}

	return dialer.Dial("tcp", address)
}

func lookupExternalIP(cfg config.AppConfig) (string, error) {
	request, err := http.NewRequest(http.MethodGet, "https://api4.ipify.org?format=json", nil)
	if err != nil {
		return "", err
	}

	client := &http.Client{Timeout: 4 * time.Second}
	if !cfg.TUNEnabled {
		dialer, err := proxy.SOCKS5(
			"tcp",
		localMixedInboundAddr,
			nil,
			&net.Dialer{Timeout: 3 * time.Second},
		)
		if err != nil {
			return "", err
		}
		client.Transport = &http.Transport{
			DialContext: func(_ context.Context, network, addr string) (net.Conn, error) {
				return dialer.Dial(network, addr)
			},
		}
	}

	response, err := client.Do(request)
	if err != nil {
		return "", err
	}
	defer response.Body.Close()

	if response.StatusCode >= http.StatusBadRequest {
		return "", fmt.Errorf("ip lookup failed: %s", response.Status)
	}

	var payload struct {
		IP string `json:"ip"`
	}
	if err := json.NewDecoder(response.Body).Decode(&payload); err != nil {
		return "", err
	}
	return strings.TrimSpace(payload.IP), nil
}

func queryGoogleDNS(conn net.Conn) error {
	message := new(dns.Msg)
	message.SetQuestion("google.com.", dns.TypeA)
	message.RecursionDesired = true

	if err := conn.SetDeadline(time.Now().Add(2 * time.Second)); err != nil {
		return err
	}

	dnsConn := &dns.Conn{Conn: conn}
	if err := dnsConn.WriteMsg(message); err != nil {
		return err
	}

	_, err := dnsConn.ReadMsg()
	return err
}
