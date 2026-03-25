package config

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sync"
)

type ConnectionState string

const (
	ConnectionConnected    ConnectionState = "connected"
	ConnectionDisconnected ConnectionState = "disconnected"
)

type RoutingMode string

const (
	RoutingGlobal    RoutingMode = "global"
	RoutingWhitelist RoutingMode = "whitelist"
	RoutingBlacklist RoutingMode = "blacklist"
)

type DNSMode string

const (
	DNSAuto   DNSMode = "auto"
	DNSProxy  DNSMode = "proxy"
	DNSDirect DNSMode = "direct"
)

type RulesProfile string

const (
	RulesProfileGlobal RulesProfile = "global"
	RulesProfileRussia RulesProfile = "russia"
)

// Local mixed inbound address used by the desktop client for system proxy and
// diagnostics. It must be consistent between:
// - xray config generator (inbound port),
// - system proxy address,
// - backend's cleanup/port probing logic.
const (
	DefaultMixedInboundPort = 10809
	DefaultMixedInboundAddr = "127.0.0.1:10809"
)

type ProfileHealth string

const (
	ProfileHealthy ProfileHealth = "healthy"
	ProfileTesting ProfileHealth = "testing"
	ProfileOffline ProfileHealth = "offline"
)

type ServerProfile struct {
	ID               string        `json:"id"`
	Name             string        `json:"name"`
	LatencyMS        int           `json:"latencyMs"`
	Health           ProfileHealth `json:"health"`
	Protocol         string        `json:"protocol"`
	Address          string        `json:"address"`
	Port             int           `json:"port"`
	SNI              string        `json:"sni"`
	Security         string        `json:"security"`
	Transport        string        `json:"transport"`
	ALPN             string        `json:"alpn"`
	Fingerprint      string        `json:"fingerprint"`
	Flow             string        `json:"flow"`
	Host             string        `json:"host"`
	Path             string        `json:"path"`
	RealityPublicKey string        `json:"realityPublicKey"`
	RealityShortID   string        `json:"realityShortId"`
	SpiderX          string        `json:"spiderX"`
	UserID           string        `json:"userId"`
	Password         string        `json:"password"`
	RawLink          string        `json:"rawLink"`
}

type AppConfig struct {
	ActiveProfileID        string          `json:"activeProfileId"`
	ConnectionState        ConnectionState `json:"connectionState"`
	RoutingMode            RoutingMode     `json:"routingMode"`
	RulesProfile           RulesProfile    `json:"rulesProfile"`
	DNSMode                DNSMode         `json:"dnsMode"`
	SystemProxyEnabled     bool            `json:"systemProxyEnabled"`
	TUNEnabled             bool            `json:"tunEnabled"`
	LaunchAtStartup        bool            `json:"launchAtStartup"`
	ProxyDomains           []string        `json:"proxyDomains"`
	DirectDomains          []string        `json:"directDomains"`
	BlockedDomains         []string        `json:"blockedDomains"`
	DisabledProxyDomains   []string        `json:"disabledProxyDomains"`
	DisabledDirectDomains  []string        `json:"disabledDirectDomains"`
	DisabledBlockedDomains []string        `json:"disabledBlockedDomains"`
	Profiles               []ServerProfile `json:"profiles"`
}

func DefaultAppConfig() AppConfig {
	return AppConfig{
		ActiveProfileID:        "",
		ConnectionState:        ConnectionDisconnected,
		RoutingMode:            RoutingGlobal,
		RulesProfile:           RulesProfileGlobal,
		DNSMode:                DNSAuto,
		SystemProxyEnabled:     false,
		TUNEnabled:             true,
		LaunchAtStartup:        false,
		ProxyDomains:           []string{},
		DirectDomains:          []string{},
		BlockedDomains:         []string{},
		DisabledProxyDomains:   []string{},
		DisabledDirectDomains:  []string{},
		DisabledBlockedDomains: []string{},
		Profiles:               []ServerProfile{},
	}
}

type Store struct {
	mu     sync.RWMutex
	config AppConfig
	path   string
}

func NewMemoryStore(initial AppConfig) *Store {
	return &Store{config: normalizeConfig(initial)}
}

func NewFileStore(initial AppConfig, path string) (*Store, error) {
	store := &Store{
		config: normalizeConfig(initial),
		path:   path,
	}

	if path == "" {
		return store, nil
	}

	loaded, err := loadFromFile(path)
	if err == nil {
		store.config = normalizeConfig(loaded)
		return store, nil
	}

	if !errors.Is(err, os.ErrNotExist) {
		return nil, err
	}

	if err := store.saveLocked(); err != nil {
		return nil, err
	}

	return store, nil
}

func DefaultConfigPath() (string, error) {
	dir, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "troodi-vpn", "config.json"), nil
}

func (s *Store) Get() AppConfig {
	s.mu.RLock()
	defer s.mu.RUnlock()

	return cloneConfig(s.config)
}

func (s *Store) Put(next AppConfig) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.config = normalizeConfig(next)
	_ = s.saveLocked()
}

func (s *Store) saveLocked() error {
	if s.path == "" {
		return nil
	}

	data, err := json.MarshalIndent(s.config, "", "  ")
	if err != nil {
		return err
	}

	if err := os.MkdirAll(filepath.Dir(s.path), 0o755); err != nil {
		return err
	}

	return os.WriteFile(s.path, data, 0o644)
}

func loadFromFile(path string) (AppConfig, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return AppConfig{}, err
	}

	var cfg AppConfig
	if err := json.Unmarshal(data, &cfg); err != nil {
		return AppConfig{}, err
	}

	return cfg, nil
}

func cloneConfig(cfg AppConfig) AppConfig {
	cloned := cfg
	cloned.ProxyDomains = append([]string(nil), cfg.ProxyDomains...)
	cloned.DirectDomains = append([]string(nil), cfg.DirectDomains...)
	cloned.BlockedDomains = append([]string(nil), cfg.BlockedDomains...)
	cloned.DisabledProxyDomains = append([]string(nil), cfg.DisabledProxyDomains...)
	cloned.DisabledDirectDomains = append([]string(nil), cfg.DisabledDirectDomains...)
	cloned.DisabledBlockedDomains = append([]string(nil), cfg.DisabledBlockedDomains...)
	cloned.Profiles = append([]ServerProfile(nil), cfg.Profiles...)
	return cloned
}

func normalizeConfig(cfg AppConfig) AppConfig {
	cfg.ProxyDomains = append([]string(nil), cfg.ProxyDomains...)
	cfg.DirectDomains = append([]string(nil), cfg.DirectDomains...)
	cfg.BlockedDomains = append([]string(nil), cfg.BlockedDomains...)
	cfg.DisabledProxyDomains = append([]string(nil), cfg.DisabledProxyDomains...)
	cfg.DisabledDirectDomains = append([]string(nil), cfg.DisabledDirectDomains...)
	cfg.DisabledBlockedDomains = append([]string(nil), cfg.DisabledBlockedDomains...)
	cfg.Profiles = append([]ServerProfile(nil), cfg.Profiles...)
	if cfg.ProxyDomains == nil {
		cfg.ProxyDomains = []string{}
	}
	if cfg.DirectDomains == nil {
		cfg.DirectDomains = []string{}
	}
	if cfg.BlockedDomains == nil {
		cfg.BlockedDomains = []string{}
	}
	if cfg.DisabledProxyDomains == nil {
		cfg.DisabledProxyDomains = []string{}
	}
	if cfg.DisabledDirectDomains == nil {
		cfg.DisabledDirectDomains = []string{}
	}
	if cfg.DisabledBlockedDomains == nil {
		cfg.DisabledBlockedDomains = []string{}
	}
	if cfg.Profiles == nil {
		cfg.Profiles = []ServerProfile{}
	}

	if cfg.RoutingMode != RoutingGlobal &&
		cfg.RoutingMode != RoutingWhitelist &&
		cfg.RoutingMode != RoutingBlacklist {
		cfg.RoutingMode = RoutingGlobal
	}

	if cfg.RulesProfile != RulesProfileGlobal &&
		cfg.RulesProfile != RulesProfileRussia {
		cfg.RulesProfile = RulesProfileGlobal
	}

	if cfg.DNSMode != DNSAuto &&
		cfg.DNSMode != DNSProxy &&
		cfg.DNSMode != DNSDirect {
		cfg.DNSMode = DNSAuto
	}

	hasActive := false
	for _, profile := range cfg.Profiles {
		if profile.ID == cfg.ActiveProfileID {
			hasActive = true
			break
		}
	}

	if !hasActive {
		if len(cfg.Profiles) > 0 {
			cfg.ActiveProfileID = cfg.Profiles[0].ID
		} else {
			cfg.ActiveProfileID = ""
			cfg.ConnectionState = ConnectionDisconnected
		}
	}

	if cfg.ConnectionState != ConnectionConnected &&
		cfg.ConnectionState != ConnectionDisconnected {
		cfg.ConnectionState = ConnectionDisconnected
	}

	return cfg
}
