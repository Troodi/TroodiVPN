package singbox

import (
	"net"
	"strings"

	"github.com/troodi/xray-desktop/core-manager/internal/config"
)

type Config map[string]any

func Build(cfg config.AppConfig) Config {
	activeProfile := findActiveProfile(cfg)

	return Config{
		"log": map[string]any{
			"level":     "warn",
			"timestamp": true,
		},
		"dns":       buildDNS(cfg),
		"inbounds":  buildInbounds(),
		"outbounds": buildOutbounds(activeProfile),
		"route":     buildRoute(cfg),
	}
}

func buildInbounds() []map[string]any {
	return []map[string]any{
		{
			"type":           "tun",
			"tag":            "tun-in",
			"interface_name": "troodi-tun",
			"address": []string{
				"172.18.0.1/30",
				"fdfe:dcba:9876::1/126",
			},
			"mtu":          1500,
			"auto_route":   true,
			"strict_route": true,
			"stack":        "system",
			"sniff":        true,
		},
	}
}

func buildOutbounds(profile config.ServerProfile) []map[string]any {
	return []map[string]any{
		buildProxyOutbound(profile),
		{
			"type": "direct",
			"tag":  "direct",
		},
		{
			"type": "block",
			"tag":  "block",
		},
	}
}

func buildDNS(cfg config.AppConfig) map[string]any {
	servers := []map[string]any{
		{
			"type":   "tcp",
			"tag":    "remote",
			"server": "1.1.1.1",
			"detour": "proxy",
		},
		{
			"type":   "tcp",
			"tag":    "remote-fallback",
			"server": "8.8.8.8",
			"detour": "proxy",
		},
		{
			"type":      "local",
			"tag":       "local",
			"prefer_go": true,
		},
		{
			"type":   "tcp",
			"tag":    "local-ru",
			"server": "77.88.8.8",
		},
		{
			"type":   "tcp",
			"tag":    "local-ru-fallback",
			"server": "77.88.8.1",
		},
	}

	rules := make([]map[string]any, 0, 8)

	if len(cfg.ProxyDomains) > 0 {
		rules = append(rules, map[string]any{
			"domain": append([]string(nil), cfg.ProxyDomains...),
			"server": "remote",
		})
	}

	if len(cfg.DirectDomains) > 0 {
		rules = append(rules, ruleForItems(cfg.DirectDomains, map[string]any{
			"server": "local",
		}))
	}

	if cfg.RulesProfile == config.RulesProfileRussia {
		rules = append(rules, map[string]any{
			"domain_suffix": []string{".ru", ".xn--p1ai"},
			"server":        "local-ru",
		})
	}

	final := "remote"
	switch cfg.DNSMode {
	case config.DNSDirect:
		final = "local"
	case config.DNSProxy:
		final = "remote"
	default:
		if cfg.RulesProfile == config.RulesProfileRussia {
			final = "remote"
		}
	}

	return map[string]any{
		"servers":           servers,
		"rules":             rules,
		"final":             final,
		"strategy":          "prefer_ipv4",
		"independent_cache": true,
	}
}

func buildRoute(cfg config.AppConfig) map[string]any {
	rules := []map[string]any{
		{"action": "sniff"},
		{
			"type": "logical",
			"mode": "or",
			"rules": []map[string]any{
				{"protocol": []string{"dns"}},
				{"port": []int{53}},
			},
			"action": "hijack-dns",
		},
		{
			"network": []string{"udp"},
			"port":    []int{135, 137, 138, 139, 5353},
			"action":  "reject",
		},
		{
			"ip_cidr": []string{"224.0.0.0/3", "ff00::/8"},
			"action":  "reject",
		},
		{
			"ip_is_private": true,
			"action":        "route",
			"outbound":      "direct",
		},
	}

	if len(cfg.BlockedDomains) > 0 {
		rules = append(rules, ruleForItems(cfg.BlockedDomains, map[string]any{
			"action":   "route",
			"outbound": "block",
		}))
	}

	if cfg.RulesProfile == config.RulesProfileRussia {
		if len(cfg.ProxyDomains) > 0 {
			rules = append(rules, ruleForItems(cfg.ProxyDomains, map[string]any{
				"action":   "route",
				"outbound": "proxy",
			}))
		}
		if len(cfg.DirectDomains) > 0 {
			rules = append(rules, ruleForItems(cfg.DirectDomains, map[string]any{
				"action":   "route",
				"outbound": "direct",
			}))
		}
		rules = append(rules, map[string]any{
			"domain_suffix": []string{".ru", ".xn--p1ai"},
			"action":        "route",
			"outbound":      "direct",
		})

		return map[string]any{
			"rules":                   rules,
			"final":                   "proxy",
			"auto_detect_interface":   true,
			"default_domain_resolver": "remote",
		}
	}

	if len(cfg.ProxyDomains) > 0 {
		rules = append(rules, ruleForItems(cfg.ProxyDomains, map[string]any{
			"action":   "route",
			"outbound": "proxy",
		}))
	}

	switch cfg.RoutingMode {
	case config.RoutingWhitelist:
		if len(cfg.DirectDomains) > 0 {
			rules = append(rules, ruleForItems(cfg.DirectDomains, map[string]any{
				"action":   "route",
				"outbound": "direct",
			}))
		}
		return map[string]any{
			"rules":                   rules,
			"final":                   "direct",
			"auto_detect_interface":   true,
			"default_domain_resolver": defaultDomainResolver(cfg),
		}
	case config.RoutingBlacklist:
		if len(cfg.DirectDomains) > 0 {
			rules = append(rules, ruleForItems(cfg.DirectDomains, map[string]any{
				"action":   "route",
				"outbound": "direct",
			}))
		}
		return map[string]any{
			"rules":                   rules,
			"final":                   "proxy",
			"auto_detect_interface":   true,
			"default_domain_resolver": defaultDomainResolver(cfg),
		}
	default:
		if len(cfg.DirectDomains) > 0 {
			rules = append(rules, ruleForItems(cfg.DirectDomains, map[string]any{
				"action":   "route",
				"outbound": "direct",
			}))
		}
		return map[string]any{
			"rules":                   rules,
			"final":                   "proxy",
			"auto_detect_interface":   true,
			"default_domain_resolver": defaultDomainResolver(cfg),
		}
	}
}

func defaultDomainResolver(cfg config.AppConfig) string {
	if cfg.DNSMode == config.DNSDirect {
		return "local"
	}
	return "remote"
}

func ruleForItems(items []string, extra map[string]any) map[string]any {
	rule := map[string]any{}
	domains := make([]string, 0, len(items))
	domainSuffixes := make([]string, 0, len(items))
	ipCIDRs := make([]string, 0, len(items))

	for _, item := range items {
		normalized := strings.TrimSpace(strings.ToLower(item))
		if normalized == "" {
			continue
		}
		switch {
		case strings.HasPrefix(normalized, "*."):
			domainSuffixes = append(domainSuffixes, "."+strings.TrimPrefix(normalized, "*."))
		case strings.Contains(normalized, "/"):
			ipCIDRs = append(ipCIDRs, normalized)
		case net.ParseIP(normalized) != nil:
			ipCIDRs = append(ipCIDRs, normalized)
		default:
			domains = append(domains, normalized)
		}
	}

	if len(domains) > 0 {
		rule["domain"] = domains
	}
	if len(domainSuffixes) > 0 {
		rule["domain_suffix"] = domainSuffixes
	}
	if len(ipCIDRs) > 0 {
		rule["ip_cidr"] = ipCIDRs
	}

	for key, value := range extra {
		rule[key] = value
	}
	return rule
}

func buildProxyOutbound(profile config.ServerProfile) map[string]any {
	if profile.Protocol == "" || profile.Address == "" || profile.Port <= 0 {
		return map[string]any{
			"type": "direct",
			"tag":  "proxy",
		}
	}

	outbound := map[string]any{
		"type":            profile.Protocol,
		"tag":             "proxy",
		"server":          profile.Address,
		"server_port":     profile.Port,
		"domain_resolver": "local",
	}

	switch profile.Protocol {
	case "vless":
		outbound["uuid"] = profile.UserID
		if profile.Flow != "" {
			outbound["flow"] = profile.Flow
		}
		outbound["packet_encoding"] = "xudp"
	case "vmess":
		outbound["uuid"] = profile.UserID
		outbound["security"] = "auto"
		outbound["alter_id"] = 0
		outbound["packet_encoding"] = "xudp"
	case "trojan":
		outbound["password"] = profile.Password
	default:
		return map[string]any{
			"type": "direct",
			"tag":  "proxy",
		}
	}

	if tlsOptions := buildTLS(profile); tlsOptions != nil {
		outbound["tls"] = tlsOptions
	}
	if transport := buildTransport(profile); transport != nil {
		outbound["transport"] = transport
	}

	return outbound
}

func buildTLS(profile config.ServerProfile) map[string]any {
	security := strings.ToLower(strings.TrimSpace(profile.Security))
	if profile.Protocol == "trojan" && security == "" {
		security = "tls"
	}
	if security == "" || security == "none" {
		return nil
	}

	tlsOptions := map[string]any{
		"enabled": true,
	}
	if profile.SNI != "" {
		tlsOptions["server_name"] = profile.SNI
	}
	if profile.ALPN != "" {
		tlsOptions["alpn"] = splitAndTrim(profile.ALPN)
	}
	if profile.Fingerprint != "" {
		tlsOptions["utls"] = map[string]any{
			"enabled":     true,
			"fingerprint": profile.Fingerprint,
		}
	}

	if security == "reality" {
		if tlsOptions["utls"] == nil {
			tlsOptions["utls"] = map[string]any{
				"enabled":     true,
				"fingerprint": "chrome",
			}
		}
		tlsOptions["reality"] = map[string]any{
			"enabled":    true,
			"public_key": profile.RealityPublicKey,
			"short_id":   profile.RealityShortID,
		}
	}

	return tlsOptions
}

func buildTransport(profile config.ServerProfile) map[string]any {
	switch strings.ToLower(strings.TrimSpace(profile.Transport)) {
	case "", "tcp":
		return nil
	case "ws":
		transport := map[string]any{
			"type": "ws",
		}
		if profile.Path != "" {
			transport["path"] = profile.Path
		}
		headers := map[string]any{}
		if profile.Host != "" {
			headers["Host"] = profile.Host
		}
		if len(headers) > 0 {
			transport["headers"] = headers
		}
		return transport
	case "grpc":
		transport := map[string]any{
			"type": "grpc",
		}
		if profile.Path != "" {
			transport["service_name"] = profile.Path
		}
		return transport
	case "httpupgrade":
		transport := map[string]any{
			"type": "httpupgrade",
		}
		if profile.Host != "" {
			transport["host"] = profile.Host
		}
		if profile.Path != "" {
			transport["path"] = profile.Path
		}
		return transport
	case "http":
		transport := map[string]any{
			"type": "http",
		}
		if profile.Host != "" {
			transport["host"] = []string{profile.Host}
		}
		if profile.Path != "" {
			transport["path"] = profile.Path
		}
		return transport
	default:
		return nil
	}
}

func findActiveProfile(cfg config.AppConfig) config.ServerProfile {
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

func splitAndTrim(value string) []string {
	items := make([]string, 0, 2)
	current := ""
	for _, ch := range value {
		if ch == ',' {
			if current != "" {
				items = append(items, current)
				current = ""
			}
			continue
		}
		if ch != ' ' && ch != '\t' {
			current += string(ch)
		}
	}
	if current != "" {
		items = append(items, current)
	}
	return items
}
