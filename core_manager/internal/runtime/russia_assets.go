package runtime

import (
	"errors"
	"fmt"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/troodi/xray-desktop/core-manager/internal/config"
	"github.com/troodi/xray-desktop/core-manager/internal/platform"
)

// ErrRoutingAssetsPending means Russia geodata files are not on disk yet; connect must not block on download.
var ErrRoutingAssetsPending = errors.New("routing rules data is still downloading")

// RoutingAssetFileProgress is per-file status for UI (4 Russia rule databases).
type RoutingAssetFileProgress struct {
	Name       string `json:"name"`
	Status     string `json:"status"` // pending | downloading | done | error
	Error      string `json:"error,omitempty"`
	Downloaded int64  `json:"downloaded,omitempty"`
	Total      int64  `json:"total,omitempty"` // 0 if Content-Length unknown
}

func russiaRoutingAssetSpecs() []struct {
	name string
	url  string
} {
	return []struct {
		name string
		url  string
	}{
		{name: "geosite.dat", url: runetFreedomGeoSiteURL},
		{name: "geoip.dat", url: runetFreedomGeoIPURL},
		{name: "geosite-ls.dat", url: loyalSoldierGeoSiteURL},
		{name: "geoip-ls.dat", url: loyalSoldierGeoIPURL},
	}
}

func russiaRoutingAssetNames() []string {
	specs := russiaRoutingAssetSpecs()
	names := make([]string, len(specs))
	for i, s := range specs {
		names[i] = s.name
	}
	return names
}

const russiaAssetMinBytes = 4096

func isRussiaAssetFileValid(path string) bool {
	info, err := os.Stat(path)
	if err != nil || info.IsDir() {
		return false
	}
	return info.Size() >= russiaAssetMinBytes
}

func russiaAssetsPresent(dir string) bool {
	for _, name := range russiaRoutingAssetNames() {
		if !isRussiaAssetFileValid(filepath.Join(dir, name)) {
			return false
		}
	}
	return true
}

func russiaAssetsUpdatedAtRFC3339(dir string) string {
	var latest time.Time
	for _, name := range russiaRoutingAssetNames() {
		p := filepath.Join(dir, name)
		if !isRussiaAssetFileValid(p) {
			return ""
		}
		info, err := os.Stat(p)
		if err != nil {
			return ""
		}
		if info.ModTime().After(latest) {
			latest = info.ModTime()
		}
	}
	if latest.IsZero() {
		return ""
	}
	return latest.UTC().Format(time.RFC3339)
}

func (m *Manager) resetRussiaFileProgressLocked() {
	specs := russiaRoutingAssetSpecs()
	m.routingAssetFiles = make([]RoutingAssetFileProgress, len(specs))
	for i, s := range specs {
		m.routingAssetFiles[i] = RoutingAssetFileProgress{Name: s.name, Status: "pending"}
	}
}

func (m *Manager) setRussiaFileStatus(name, status, errStr string) {
	m.assetsMu.Lock()
	defer m.assetsMu.Unlock()
	for i := range m.routingAssetFiles {
		if m.routingAssetFiles[i].Name == name {
			m.routingAssetFiles[i].Status = status
			m.routingAssetFiles[i].Error = errStr
			if status == "downloading" {
				m.routingAssetFiles[i].Downloaded = 0
				m.routingAssetFiles[i].Total = 0
			}
			break
		}
	}
}

func (m *Manager) setRussiaFileProgress(name string, downloaded, total int64) {
	m.assetsMu.Lock()
	defer m.assetsMu.Unlock()
	for i := range m.routingAssetFiles {
		if m.routingAssetFiles[i].Name == name {
			m.routingAssetFiles[i].Downloaded = downloaded
			m.routingAssetFiles[i].Total = total
			break
		}
	}
}

func (m *Manager) snapshotRussiaFileProgress() []RoutingAssetFileProgress {
	m.assetsMu.Lock()
	defer m.assetsMu.Unlock()
	out := make([]RoutingAssetFileProgress, len(m.routingAssetFiles))
	copy(out, m.routingAssetFiles)
	return out
}

// BeginRussiaRoutingAssetsWarmup downloads missing Russia rule files or refreshes stale ones in the background.
func (m *Manager) BeginRussiaRoutingAssetsWarmup() {
	dir, err := defaultAssetDir()
	if err != nil {
		m.assetsMu.Lock()
		m.routingAssetsStatus = "error"
		m.routingAssetsErr = err.Error()
		m.assetsMu.Unlock()
		return
	}
	_ = os.MkdirAll(dir, 0o755)

	m.appendLog(fmt.Sprintf("[%s] BeginRussiaRoutingAssetsWarmup: assetDir=%s", time.Now().Format(time.RFC3339), dir))

	m.assetsMu.Lock()
	if m.routingAssetsDownloadRun {
		m.assetsMu.Unlock()
		m.appendLog(fmt.Sprintf("[%s] BeginRussiaRoutingAssetsWarmup: already running", time.Now().Format(time.RFC3339)))
		return
	}
	if russiaAssetsPresent(dir) {
		m.routingAssetsStatus = "ready"
		m.routingAssetsErr = ""
		m.assetsMu.Unlock()
		m.appendLog(fmt.Sprintf("[%s] BeginRussiaRoutingAssetsWarmup: assets already present, refresh if stale", time.Now().Format(time.RFC3339)))
		go m.refreshRussiaAssetsIfStale()
		return
	}
	m.routingAssetsDownloadRun = true
	m.routingAssetsStatus = "downloading"
	m.routingAssetsErr = ""
	m.resetRussiaFileProgressLocked()
	m.assetsMu.Unlock()

	m.appendLog(fmt.Sprintf("[%s] BeginRussiaRoutingAssetsWarmup: assets missing, starting download", time.Now().Format(time.RFC3339)))

	go m.runRussiaAssetsDownload()
}

func (m *Manager) runRussiaAssetsDownload() {
	defer func() {
		m.assetsMu.Lock()
		m.routingAssetsDownloadRun = false
		m.assetsMu.Unlock()
	}()
	m.appendLog(fmt.Sprintf("[%s] runRussiaAssetsDownload: start", time.Now().Format(time.RFC3339)))
	_, err := m.ensureRoutingAssetsInternal(true, false)
	m.assetsMu.Lock()
	defer m.assetsMu.Unlock()
	if err != nil {
		m.routingAssetsStatus = "error"
		m.routingAssetsErr = err.Error()
		m.appendLog(fmt.Sprintf("[%s] runRussiaAssetsDownload: failed: %v", time.Now().Format(time.RFC3339), err))
		return
	}
	m.routingAssetsStatus = "ready"
	m.routingAssetsErr = ""
	m.appendLog(fmt.Sprintf("[%s] runRussiaAssetsDownload: success", time.Now().Format(time.RFC3339)))
}

func (m *Manager) refreshRussiaAssetsIfStale() {
	_, err := m.ensureRoutingAssetsInternal(true, false)
	if err != nil {
		m.appendLog(fmt.Sprintf("[%s] background routing asset refresh: %v", time.Now().Format(time.RFC3339), err))
	}
}

// ensureRoutingAssetsInternal downloads Russia geodata when enabled; uses parallel workers and per-file progress.
func (m *Manager) ensureRoutingAssetsInternal(enabled bool, force bool) (string, error) {
	assetDir, err := defaultAssetDir()
	if err != nil {
		return "", err
	}
	if err := os.MkdirAll(assetDir, 0o755); err != nil {
		return "", err
	}

	m.appendLog(fmt.Sprintf("[%s] ensureRoutingAssetsInternal: enabled=%v force=%v assetDir=%s", time.Now().Format(time.RFC3339), enabled, force, assetDir))

	if !enabled {
		return assetDir, nil
	}

	// When Xray is running in TUN mode, system routes redirect most outbound
	// traffic through Xray. Our downloader would then also go through TUN
	// (and may be reset), even though the host is reachable directly in a browser.
	//
	// To stabilize downloads, we temporarily add /32 bypass routes for the
	// GitHub raw endpoints' resolved IPv4s via the original default route.
	var undoBypass func()
	if m.isTunRunning() {
		undoBypass, _ = m.setupTunBypassForHosts(russiaRoutingAssetSpecs())
	}
	if undoBypass != nil {
		defer undoBypass()
	}

	m.assetsMu.Lock()
	if len(m.routingAssetFiles) != len(russiaRoutingAssetSpecs()) {
		m.resetRussiaFileProgressLocked()
	}
	m.assetsMu.Unlock()

	specs := russiaRoutingAssetSpecs()
	var wg sync.WaitGroup
	var errMu sync.Mutex
	var firstErr error

	for _, spec := range specs {
		path := filepath.Join(assetDir, spec.name)
		if !force && isFreshFile(path, routingAssetsTTL) && isRussiaAssetFileValid(path) {
			m.setRussiaFileStatus(spec.name, "done", "")
			continue
		}

		m.appendLog(fmt.Sprintf("[%s] routing asset scheduled: name=%s dest=%s", time.Now().Format(time.RFC3339), spec.name, path))
		wg.Add(1)
		go func(name, url, dest string) {
			defer wg.Done()
			m.appendLog(fmt.Sprintf("[%s] routing asset download started: name=%s dest=%s", time.Now().Format(time.RFC3339), name, dest))
			m.setRussiaFileStatus(name, "downloading", "")
			if err := downloadFileWithProgress(url, dest, func(d, t int64) {
				m.setRussiaFileProgress(name, d, t)
			}); err != nil {
				if _, statErr := os.Stat(dest); statErr == nil {
					m.appendLog(fmt.Sprintf("[%s] failed to refresh %s, using cached copy: %v", time.Now().Format(time.RFC3339), name, err))
					m.setRussiaFileStatus(name, "done", "")
					return
				}
				m.appendLog(fmt.Sprintf("[%s] routing asset download failed: name=%s err=%v (no cached dest)", time.Now().Format(time.RFC3339), name, err))
				m.setRussiaFileStatus(name, "error", err.Error())
				errMu.Lock()
				if firstErr == nil {
					firstErr = fmt.Errorf("failed to download %s: %w", name, err)
				}
				errMu.Unlock()
				return
			}
			if info, statErr := os.Stat(dest); statErr == nil {
				m.appendLog(fmt.Sprintf("[%s] updated routing asset %s (size=%d)", time.Now().Format(time.RFC3339), name, info.Size()))
			} else {
				m.appendLog(fmt.Sprintf("[%s] updated routing asset %s", time.Now().Format(time.RFC3339), name))
			}
			m.setRussiaFileStatus(name, "done", "")
		}(spec.name, spec.url, path)
	}
	wg.Wait()

	if firstErr != nil {
		return "", firstErr
	}
	return assetDir, nil
}

func (m *Manager) isTunRunning() bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.running && m.mode == "tun"
}

func (m *Manager) setupTunBypassForHosts(specs []struct {
	name string
	url  string
}) (func(), error) {
	defaultRoute, err := platform.CaptureDefaultRoute()
	if err != nil || defaultRoute == nil {
		return nil, err
	}

	hosts := make([]string, 0, len(specs))
	for _, s := range specs {
		u, err := url.Parse(s.url)
		if err != nil || u.Host == "" {
			continue
		}
		hosts = append(hosts, u.Hostname())
	}

	ips := make([]net.IP, 0, 16)
	seen := map[string]struct{}{}
	for _, host := range hosts {
		resolved, err := net.LookupIP(host)
		if err != nil {
			continue
		}
		for _, ip := range resolved {
			ip4 := ip.To4()
			if ip4 == nil {
				continue
			}
			key := ip4.String()
			if _, ok := seen[key]; ok {
				continue
			}
			seen[key] = struct{}{}
			ips = append(ips, ip4)
		}
	}

	if len(ips) == 0 {
		return nil, nil
	}

	m.appendLog(fmt.Sprintf(
		"[%s] setupTunBypassForHosts: default=%s ips=%d",
		time.Now().Format(time.RFC3339),
		defaultRoute.InterfaceAlias,
		len(ips),
	))

	applied := make([]string, 0, len(ips))
	for _, ip4 := range ips {
		ipCidr := ip4.String() + "/32"
		args := []string{"route", "replace", ipCidr}
		if defaultRoute.NextHop != "" {
			args = append(args, "via", defaultRoute.NextHop)
		}
		if defaultRoute.InterfaceAlias != "" {
			args = append(args, "dev", defaultRoute.InterfaceAlias)
		}

		cmd, cmdErr := platform.CommandAsRoot("ip", args...)
		if cmdErr == nil {
			// Best-effort; ignore output but fail on execution error.
			if _, execErr := cmd.CombinedOutput(); execErr != nil {
				m.appendLog(fmt.Sprintf("[%s] tun bypass route failed: %v", time.Now().Format(time.RFC3339), execErr))
				continue
			}
			applied = append(applied, ipCidr)
			continue
		}
	}

	if len(applied) == 0 {
		return nil, nil
	}

	undo := func() {
		for _, ipCidr := range applied {
			// Best-effort cleanup.
			cmd, cmdErr := platform.CommandAsRoot("ip", "route", "del", ipCidr)
			if cmdErr != nil {
				continue
			}
			_, _ = cmd.CombinedOutput()
		}
	}

	return undo, nil
}

func (m *Manager) routingAssetsSnapshotForStatus() (status, errStr string, files []RoutingAssetFileProgress, updatedAt string) {
	m.assetsMu.Lock()
	defer m.assetsMu.Unlock()
	st := m.routingAssetsStatus
	e := m.routingAssetsErr
	files = make([]RoutingAssetFileProgress, len(m.routingAssetFiles))
	copy(files, m.routingAssetFiles)
	dir, derr := defaultAssetDir()
	if derr == nil {
		if russiaAssetsPresent(dir) {
			updatedAt = russiaAssetsUpdatedAtRFC3339(dir)
		} else if st == "ready" {
			// Cached status from before files were removed from disk.
			st = "idle"
		}
	}
	return st, e, files, updatedAt
}

func (m *Manager) startLockedRussiaAssetPath(cfg config.AppConfig) (assetDir string, err error) {
	assetDir, err = defaultAssetDir()
	if err != nil {
		return "", err
	}
	if err := os.MkdirAll(assetDir, 0o755); err != nil {
		return "", err
	}
	if cfg.RulesProfile != config.RulesProfileRussia {
		return assetDir, nil
	}
	if !russiaAssetsPresent(assetDir) {
		m.BeginRussiaRoutingAssetsWarmup()
		return "", ErrRoutingAssetsPending
	}
	return assetDir, nil
}
