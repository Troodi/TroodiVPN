package singbox

import (
	"testing"

	"github.com/troodi/xray-desktop/core-manager/internal/config"
)

func TestBuildWindowsTunConfig(t *testing.T) {
	cfg := config.AppConfig{
		TUNEnabled:      true,
		RoutingMode:     config.RoutingBlacklist,
		RulesProfile:    config.RulesProfileGlobal,
		ProxyDomains:    []string{"github.com"},
		DirectDomains:   []string{"bank.ru", "*.gosuslugi.ru", "1.1.1.1"},
		BlockedDomains:  []string{"ads.example.com"},
		ActiveProfileID: "main",
		Profiles: []config.ServerProfile{
			{
				ID:               "main",
				Protocol:         "vless",
				Address:          "example.com",
				Port:             443,
				UserID:           "00000000-0000-0000-0000-000000000000",
				Security:         "reality",
				SNI:              "github.com",
				Fingerprint:      "chrome",
				RealityPublicKey: "test_public_key",
				RealityShortID:   "12345678",
			},
		},
	}

	payload := Build(cfg)

	inbounds := payload["inbounds"].([]map[string]any)
	if len(inbounds) != 1 || inbounds[0]["type"] != "tun" {
		t.Fatalf("expected tun inbound, got %#v", inbounds)
	}

	route := payload["route"].(map[string]any)
	if got := route["final"]; got != "proxy" {
		t.Fatalf("expected proxy final outbound, got %v", got)
	}

	outbounds := payload["outbounds"].([]map[string]any)
	if len(outbounds) < 3 || outbounds[0]["type"] != "vless" {
		t.Fatalf("expected proxy outbound to be vless, got %#v", outbounds)
	}
}

func TestBuildRussiaSmartAddsRuDirectRouting(t *testing.T) {
	cfg := config.AppConfig{
		TUNEnabled:      true,
		RulesProfile:    config.RulesProfileRussia,
		ActiveProfileID: "main",
		Profiles: []config.ServerProfile{
			{
				ID:       "main",
				Protocol: "trojan",
				Address:  "example.com",
				Port:     443,
				Password: "secret",
			},
		},
	}

	payload := Build(cfg)
	route := payload["route"].(map[string]any)
	rules := route["rules"].([]map[string]any)

	foundRuDirect := false
	for _, rule := range rules {
		if suffixes, ok := rule["domain_suffix"].([]string); ok && len(suffixes) == 2 {
			if suffixes[0] == ".ru" && rule["outbound"] == "direct" {
				foundRuDirect = true
				break
			}
		}
	}

	if !foundRuDirect {
		t.Fatal("expected Russia smart config to route .ru domains directly")
	}
}
