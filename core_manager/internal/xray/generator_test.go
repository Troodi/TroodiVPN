package xray

import (
	"testing"

	"github.com/troodi/xray-desktop/core-manager/internal/config"
)

func TestRussiaSmartRoutingUsesExpectedOrder(t *testing.T) {
	cfg := config.AppConfig{
		RoutingMode:    config.RoutingWhitelist,
		RulesProfile:   config.RulesProfileRussia,
		ProxyDomains:   []string{"openai.com"},
		DirectDomains:  []string{"bank.ru"},
		BlockedDomains: []string{"ads.example.com"},
	}

	built := Build(cfg)
	routing, ok := built["routing"].(map[string]any)
	if !ok {
		t.Fatalf("routing section missing")
	}

	if got := routing["domainStrategy"]; got != "IPIfNonMatch" {
		t.Fatalf("domainStrategy = %v, want IPIfNonMatch", got)
	}

	rules, ok := routing["rules"].([]map[string]any)
	if !ok {
		t.Fatalf("rules type = %T, want []map[string]any", routing["rules"])
	}

	if len(rules) < 8 {
		t.Fatalf("rules length = %d, want at least 8", len(rules))
	}

	assertRule := func(index int, key string, want []string, outbound string) {
		t.Helper()
		rule := rules[index]
		if got := rule["outboundTag"]; got != outbound {
			t.Fatalf("rule[%d] outboundTag = %v, want %s", index, got, outbound)
		}
		values, ok := rule[key].([]string)
		if !ok {
			t.Fatalf("rule[%d] %s type = %T, want []string", index, key, rule[key])
		}
		if len(values) != len(want) {
			t.Fatalf("rule[%d] %s len = %d, want %d (%v)", index, key, len(values), len(want), values)
		}
		for i := range want {
			if values[i] != want[i] {
				t.Fatalf("rule[%d] %s[%d] = %q, want %q", index, key, i, values[i], want[i])
			}
		}
	}

	assertRule(0, "domain", []string{"ads.example.com"}, "block")
	assertRule(1, "ip", []string{"geoip:private"}, "direct")
	assertRule(2, "domain", []string{"openai.com"}, "proxy")
	assertRule(3, "domain", []string{"geosite:ru-blocked"}, "proxy")
	assertRule(4, "ip", []string{"geoip:ru-blocked"}, "proxy")
	assertRule(5, "domain", []string{"bank.ru"}, "direct")
	assertRule(6, "domain", []string{"geosite:ru-available-only-inside"}, "direct")
	assertRule(7, "domain", []string{"regexp:(^|\\.).*\\.ru$", "regexp:(^|\\.).*\\.xn--p1ai$"}, "direct")
	assertRule(8, "ip", []string{"ext:geoip-ls.dat:ru"}, "direct")

	if got := rules[9]["outboundTag"]; got != "proxy" {
		t.Fatalf("fallback outboundTag = %v, want proxy", got)
	}
}
