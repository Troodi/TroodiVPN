package xray

import "github.com/troodi/xray-desktop/core-manager/internal/config"

type Config map[string]any

func Build(cfg config.AppConfig) Config {
	rules := make([]map[string]any, 0, len(cfg.ProxyDomains)+len(cfg.DirectDomains)+len(cfg.BlockedDomains)+2)

	if len(cfg.BlockedDomains) > 0 {
		rules = append(rules, map[string]any{
			"type":        "field",
			"domain":      cfg.BlockedDomains,
			"outboundTag": "block",
		})
	}

	switch cfg.RoutingMode {
	case config.RoutingWhitelist:
		if len(cfg.ProxyDomains) > 0 {
			rules = append(rules, map[string]any{
				"type":        "field",
				"domain":      cfg.ProxyDomains,
				"outboundTag": "proxy",
			})
		}
		rules = append(rules, map[string]any{
			"type":        "field",
			"port":        "0-65535",
			"outboundTag": "direct",
		})
	case config.RoutingBlacklist:
		if len(cfg.DirectDomains) > 0 {
			rules = append(rules, map[string]any{
				"type":        "field",
				"domain":      cfg.DirectDomains,
				"outboundTag": "direct",
			})
		}
		rules = append(rules, map[string]any{
			"type":        "field",
			"port":        "0-65535",
			"outboundTag": "proxy",
		})
	default:
		rules = append(rules, map[string]any{
			"type":        "field",
			"port":        "0-65535",
			"outboundTag": "proxy",
		})
	}

	dnsServers := []string{"1.1.1.1", "8.8.8.8"}
	if cfg.DNSMode == config.DNSDirect {
		dnsServers = []string{"localhost"}
	}

	return Config{
		"log": map[string]any{"loglevel": "warning"},
		"dns": map[string]any{"servers": dnsServers},
		"inbounds": []map[string]any{
			{
				"tag":      "mixed-in",
				"port":     10808,
				"listen":   "127.0.0.1",
				"protocol": "mixed",
				"settings": map[string]any{
					"auth": "noauth",
					"udp":  true,
				},
			},
		},
		"outbounds": []map[string]any{
			{"tag": "proxy", "protocol": "freedom"},
			{"tag": "direct", "protocol": "freedom"},
			{"tag": "block", "protocol": "blackhole"},
		},
		"routing": map[string]any{
			"domainStrategy": "AsIs",
			"rules":          rules,
		},
	}
}
