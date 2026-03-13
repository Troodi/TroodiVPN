package config

import "sync"

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

type ProfileHealth string

const (
	ProfileHealthy ProfileHealth = "healthy"
	ProfileTesting ProfileHealth = "testing"
	ProfileOffline ProfileHealth = "offline"
)

type ServerProfile struct {
	ID        string        `json:"id"`
	Name      string        `json:"name"`
	LatencyMS int           `json:"latencyMs"`
	Health    ProfileHealth `json:"health"`
	Protocol  string        `json:"protocol"`
}

type AppConfig struct {
	ActiveProfileID    string          `json:"activeProfileId"`
	ConnectionState    ConnectionState `json:"connectionState"`
	RoutingMode        RoutingMode     `json:"routingMode"`
	DNSMode            DNSMode         `json:"dnsMode"`
	SystemProxyEnabled bool            `json:"systemProxyEnabled"`
	TUNEnabled         bool            `json:"tunEnabled"`
	LaunchAtStartup    bool            `json:"launchAtStartup"`
	ProxyDomains       []string        `json:"proxyDomains"`
	DirectDomains      []string        `json:"directDomains"`
	BlockedDomains     []string        `json:"blockedDomains"`
	Profiles           []ServerProfile `json:"profiles"`
}

func DefaultAppConfig() AppConfig {
	return AppConfig{
		ActiveProfileID:    "main-reality",
		ConnectionState:    ConnectionConnected,
		RoutingMode:        RoutingBlacklist,
		DNSMode:            DNSAuto,
		SystemProxyEnabled: true,
		TUNEnabled:         false,
		LaunchAtStartup:    true,
		ProxyDomains:       []string{"openai.com", "chatgpt.com", "github.com"},
		DirectDomains:      []string{"bank.ru", "gosuslugi.ru", "youtube.com"},
		BlockedDomains:     []string{"doubleclick.net", "ads.example.com"},
		Profiles: []ServerProfile{
			{ID: "main-reality", Name: "Main Reality", LatencyMS: 48, Health: ProfileHealthy, Protocol: "vless-reality"},
			{ID: "backup-nl", Name: "Backup Netherlands", LatencyMS: 63, Health: ProfileHealthy, Protocol: "trojan"},
			{ID: "usa-streaming", Name: "USA Streaming", LatencyMS: 124, Health: ProfileTesting, Protocol: "vmess"},
		},
	}
}

type Store struct {
	mu     sync.RWMutex
	config AppConfig
}

func NewMemoryStore(initial AppConfig) *Store {
	return &Store{config: initial}
}

func (s *Store) Get() AppConfig {
	s.mu.RLock()
	defer s.mu.RUnlock()

	cfg := s.config
	cfg.ProxyDomains = append([]string(nil), s.config.ProxyDomains...)
	cfg.DirectDomains = append([]string(nil), s.config.DirectDomains...)
	cfg.BlockedDomains = append([]string(nil), s.config.BlockedDomains...)
	cfg.Profiles = append([]ServerProfile(nil), s.config.Profiles...)
	return cfg
}

func (s *Store) Put(next AppConfig) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.config = next
}
