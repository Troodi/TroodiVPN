package xray

import "github.com/troodi/xray-desktop/core-manager/internal/config"

type Config map[string]any

type BuildOptions struct {
	BindInterface string
	TUNInterface  string
	TUNMTU        int
}

func DefaultBuildOptions() BuildOptions {
	return BuildOptions{
		TUNInterface: "xray0",
		TUNMTU:       1500,
	}
}

func Build(cfg config.AppConfig) Config {
	return BuildWithOptions(cfg, DefaultBuildOptions())
}

func BuildWithOptions(cfg config.AppConfig, opts BuildOptions) Config {
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
		"log":      map[string]any{"loglevel": "warning"},
		"dns":      map[string]any{"servers": dnsServers},
		"inbounds": buildInbounds(cfg, opts),
		"outbounds": []map[string]any{
			buildFreedomOutbound("proxy", opts.BindInterface),
			buildFreedomOutbound("direct", opts.BindInterface),
			{"tag": "block", "protocol": "blackhole"},
		},
		"routing": map[string]any{
			"domainStrategy": "AsIs",
			"rules":          rules,
		},
	}
}

func buildFreedomOutbound(tag, bindInterface string) map[string]any {
	outbound := map[string]any{
		"tag":      tag,
		"protocol": "freedom",
	}

	if bindInterface != "" {
		outbound["streamSettings"] = map[string]any{
			"sockopt": map[string]any{
				"interface": bindInterface,
			},
		}
	}

	return outbound
}

func buildInbounds(cfg config.AppConfig, opts BuildOptions) []map[string]any {
	inbounds := []map[string]any{
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
	}

	if cfg.TUNEnabled {
		inbounds = append(inbounds, map[string]any{
			"tag":      "tun-in",
			"port":     0,
			"protocol": "tun",
			"settings": map[string]any{
				"name": opts.TUNInterface,
				"MTU":  opts.TUNMTU,
			},
		})
	}

	return inbounds
}
