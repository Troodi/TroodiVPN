package runtime

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
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

type Status struct {
	Running    bool     `json:"running"`
	PID        int      `json:"pid"`
	BinaryPath string   `json:"binaryPath"`
	ConfigPath string   `json:"configPath"`
	LastError  string   `json:"lastError,omitempty"`
	LastExit   string   `json:"lastExit,omitempty"`
	Mode       string   `json:"mode"`
	LatencyMS  int      `json:"latencyMs"`
	Elevated   bool     `json:"elevated"`
	Logs       []string `json:"logs"`
}

type Manager struct {
	mu         sync.Mutex
	cmd        *exec.Cmd
	running    bool
	binaryPath string
	configPath string
	logs       []string
	lastError  string
	lastExit   string
	mode       string
	latencyMS  int
	pingCancel context.CancelFunc
	proxyState *platform.ProxySettings
	tunState   *platform.TUNState
}

func NewManager(binaryPath string) *Manager {
	return &Manager{binaryPath: binaryPath}
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

	status := Status{
		Running:    m.running,
		BinaryPath: m.binaryPath,
		ConfigPath: m.configPath,
		LastError:  m.lastError,
		LastExit:   m.lastExit,
		Mode:       m.mode,
		LatencyMS:  m.latencyMS,
		Elevated:   platform.IsElevated(),
		Logs:       append([]string(nil), m.logs...),
	}

	if m.running && m.cmd != nil && m.cmd.Process != nil {
		status.PID = m.cmd.Process.Pid
	}

	return status
}

func (m *Manager) startLocked(cfg config.AppConfig) error {
	if err := m.ensureBinaryLocked(); err != nil {
		return err
	}
	if cfg.TUNEnabled && !platform.IsElevated() {
		return errors.New("TUN mode requires administrator rights")
	}
	buildOptions := xray.DefaultBuildOptions()
	if cfg.TUNEnabled {
		if err := platform.EnsureWintunDLL(m.binaryPath); err != nil {
			return err
		}

		defaultRoute, err := platform.CaptureDefaultRoute()
		if err != nil {
			return err
		}
		buildOptions.BindInterface = defaultRoute.InterfaceAlias
		tunOptions := platform.DefaultTUNOptions()
		tunOptions.ManageRoutes = unsafeFullTUNRoutesEnabled()
		buildOptions.TUNInterface = tunOptions.InterfaceAlias
		buildOptions.TUNMTU = tunOptions.MTU
	}

	configPath, err := m.writeConfigLocked(cfg, buildOptions)
	if err != nil {
		return err
	}

	cmd := exec.Command(m.binaryPath, "run", "-c", configPath)
	cmd.Dir = filepath.Dir(m.binaryPath)

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

	m.cmd = cmd
	m.running = true
	m.configPath = configPath
	m.lastError = ""
	m.lastExit = ""
	m.mode = "proxy"
	if cfg.TUNEnabled {
		m.mode = "tun"
	}
	m.appendLogLocked(fmt.Sprintf("[%s] xray started (pid %d)", time.Now().Format(time.RFC3339), cmd.Process.Pid))
	if err := m.applySystemProxyLocked(cfg); err != nil {
		m.appendLogLocked("system proxy error: " + err.Error())
	}
	if cfg.TUNEnabled {
		tunOptions := platform.DefaultTUNOptions()
		tunOptions.ManageRoutes = unsafeFullTUNRoutesEnabled()
		tunState, err := platform.PrepareTUN(tunOptions)
		if err != nil {
			_ = m.stopLocked()
			return err
		}
		m.tunState = tunState
		if tunOptions.ManageRoutes {
			m.appendLogLocked(fmt.Sprintf("[%s] TUN adapter %s configured with system routes", time.Now().Format(time.RFC3339), tunState.InterfaceAlias))
		} else {
			m.appendLogLocked(fmt.Sprintf("[%s] TUN adapter %s configured in safe test mode (routes unchanged)", time.Now().Format(time.RFC3339), tunState.InterfaceAlias))
		}
	}
	m.startPingLoopLocked(cfg)

	go m.captureLogs(stdout)
	go m.captureLogs(stderr)
	go m.waitForExit(cmd)

	time.Sleep(300 * time.Millisecond)
	if !m.running {
		status := m.Status()
		if status.LastExit != "" {
			return errors.New(status.LastExit)
		}
		return errors.New("xray exited immediately after start")
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

	m.running = false
	m.cmd = nil
	m.stopPingLoopLocked()
	if err := platform.CleanupTUN(m.tunState); err == nil {
		m.tunState = nil
	}
	if err := platform.RestoreSystemProxy(m.proxyState); err == nil {
		m.proxyState = nil
	}
	m.lastExit = "xray stopped"
	m.latencyMS = 0

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

func (m *Manager) writeConfigLocked(cfg config.AppConfig, options xray.BuildOptions) (string, error) {
	tempDir := filepath.Join(os.TempDir(), "xray-desktop")
	if err := os.MkdirAll(tempDir, 0o755); err != nil {
		return "", err
	}

	path := filepath.Join(tempDir, "generated-config.json")
	data, err := json.MarshalIndent(xray.BuildWithOptions(cfg, options), "", "  ")
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

	m.stopPingLoopLocked()
	if cleanupErr := platform.CleanupTUN(m.tunState); cleanupErr == nil {
		m.tunState = nil
	}
	if restoreErr := platform.RestoreSystemProxy(m.proxyState); restoreErr == nil {
		m.proxyState = nil
	}
	m.latencyMS = 0
	m.running = false
	m.cmd = nil
}

func (m *Manager) appendLogLocked(line string) {
	m.logs = append(m.logs, line)
	if len(m.logs) > maxLogLines {
		m.logs = append([]string(nil), m.logs[len(m.logs)-maxLogLines:]...)
	}
}

func (m *Manager) isRunningLocked() bool {
	return m.running && m.cmd != nil && m.cmd.Process != nil
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
		previous, err := platform.ApplySystemProxy("127.0.0.1:10808")
		if err != nil {
			return err
		}
		m.proxyState = previous
	}

	return nil
}

func (m *Manager) startPingLoopLocked(cfg config.AppConfig) {
	m.stopPingLoopLocked()

	ctx, cancel := context.WithCancel(context.Background())
	m.pingCancel = cancel

	go func() {
		ticker := time.NewTicker(1 * time.Second)
		defer ticker.Stop()

		m.measurePing(cfg)
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				m.measurePing(cfg)
			}
		}
	}()
}

func (m *Manager) stopPingLoopLocked() {
	if m.pingCancel != nil {
		m.pingCancel()
		m.pingCancel = nil
	}
}

func (m *Manager) measurePing(cfg config.AppConfig) {
	startedAt := time.Now()

	var (
		conn net.Conn
		err  error
	)

	if cfg.TUNEnabled {
		conn, err = net.DialTimeout("tcp", "8.8.8.8:53", 2*time.Second)
	} else {
		var dialer proxy.Dialer
		dialer, err = proxy.SOCKS5(
			"tcp",
			"127.0.0.1:10808",
			nil,
			&net.Dialer{Timeout: 2 * time.Second},
		)
		if err == nil {
			conn, err = dialer.Dial("tcp", "8.8.8.8:53")
		}
	}

	latency := 0
	if err == nil {
		err = queryGoogleDNS(conn)
		if err == nil {
			latency = int(time.Since(startedAt).Milliseconds())
			if latency == 0 {
				latency = 1
			}
		}
		_ = conn.Close()
	}

	m.mu.Lock()
	defer m.mu.Unlock()
	if err != nil {
		m.latencyMS = 0
		return
	}
	m.latencyMS = latency
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

func unsafeFullTUNRoutesEnabled() bool {
	value := strings.TrimSpace(strings.ToLower(os.Getenv("XRAY_DESKTOP_UNSAFE_TUN_ROUTES")))
	return value == "1" || value == "true" || value == "yes"
}
