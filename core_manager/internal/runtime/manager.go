package runtime

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"

	"github.com/troodi/xray-desktop/core-manager/internal/config"
	"github.com/troodi/xray-desktop/core-manager/internal/xray"
)

const maxLogLines = 200

type Status struct {
	Running    bool     `json:"running"`
	PID        int      `json:"pid"`
	BinaryPath string   `json:"binaryPath"`
	ConfigPath string   `json:"configPath"`
	LastError  string   `json:"lastError,omitempty"`
	LastExit   string   `json:"lastExit,omitempty"`
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
}

func NewManager(binaryPath string) *Manager {
	return &Manager{binaryPath: binaryPath}
}

func DefaultBinaryPath() string {
	fileName := "xray"
	if runtime.GOOS == "windows" {
		fileName += ".exe"
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

	configPath, err := m.writeConfigLocked(cfg)
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
	m.appendLogLocked(fmt.Sprintf("[%s] xray started (pid %d)", time.Now().Format(time.RFC3339), cmd.Process.Pid))

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
	m.lastExit = "xray stopped"

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

func (m *Manager) writeConfigLocked(cfg config.AppConfig) (string, error) {
	tempDir := filepath.Join(os.TempDir(), "xray-desktop")
	if err := os.MkdirAll(tempDir, 0o755); err != nil {
		return "", err
	}

	path := filepath.Join(tempDir, "generated-config.json")
	data, err := json.MarshalIndent(xray.Build(cfg), "", "  ")
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
