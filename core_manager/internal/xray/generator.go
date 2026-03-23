package xray

import "github.com/troodi/xray-desktop/core-manager/internal/config"

type Config map[string]any

var forcedProxyCheckDomains = []string{
	"full:api4.ipify.org",
	"full:api.ipify.org",
	"full:ifconfig.me",
	"full:ipinfo.io",
}

type BuildOptions struct {
	BindInterface string
	BindAddress   string
	TUNInterface  string
	TUNAddress    string
	TUNMTU        int
}

func DefaultBuildOptions() BuildOptions {
	return BuildOptions{
		TUNInterface: "xray0",
		TUNAddress:   "198.18.0.1",
		TUNMTU:       1500,
	}
}

func Build(cfg config.AppConfig) Config {
	return BuildWithOptions(cfg, DefaultBuildOptions())
}

func BuildWithOptions(cfg config.AppConfig, opts BuildOptions) Config {
	rules := make([]map[string]any, 0, len(cfg.ProxyDomains)+len(cfg.DirectDomains)+len(cfg.BlockedDomains)+8)
	activeProfile := findActiveProfile(cfg)

	if cfg.TUNEnabled {
		rules = append(rules, map[string]any{
			"type":        "field",
			"inboundTag":  []string{"tun-in"},
			"port":        53,
			"network":     "tcp,udp",
			"outboundTag": "dns-out",
		})
	}

	if len(cfg.BlockedDomains) > 0 {
		rules = appendDomainRule(rules, cfg.BlockedDomains, "block")
	}

	if cfg.RulesProfile == config.RulesProfileRussia {
		rules = appendRussiaSmartRules(rules, cfg)
	} else {
		if len(cfg.ProxyDomains) > 0 {
			rules = appendDomainRule(rules, cfg.ProxyDomains, "proxy")
		}

		switch cfg.RoutingMode {
		case config.RoutingWhitelist:
			rules = append(rules, map[string]any{
				"type":        "field",
				"port":        "0-65535",
				"outboundTag": "direct",
			})
		case config.RoutingBlacklist:
			rules = appendDomainRule(rules, cfg.DirectDomains, "direct")
			rules = append(rules, map[string]any{
				"type":        "field",
				"port":        "0-65535",
				"outboundTag": "proxy",
			})
		default:
			rules = appendDomainRule(rules, cfg.DirectDomains, "direct")
			rules = append(rules, map[string]any{
				"type":        "field",
				"port":        "0-65535",
				"outboundTag": "proxy",
			})
		}
	}

	return Config{
		"log":      map[string]any{"loglevel": "warning"},
		"dns":      buildDNS(cfg),
		"inbounds": buildInbounds(cfg, opts),
		"outbounds": []map[string]any{
			buildProxyOutbound(activeProfile, opts.BindInterface, opts.BindAddress),
			buildFreedomOutbound("direct", opts.BindInterface, opts.BindAddress, cfg.RulesProfile == config.RulesProfileRussia),
			{"tag": "dns-out", "protocol": "dns"},
			{"tag": "block", "protocol": "blackhole"},
		},
		"routing": map[string]any{
			"domainStrategy": domainStrategy(cfg),
			"rules":          rules,
		},
		"api": map[string]any{
			"tag":      "api",
			"listen":   LocalLoopbackStatsAPI,
			"services": []string{"StatsService"},
		},
		"stats": map[string]any{},
		"policy": map[string]any{
			"system": map[string]any{
				"statsInboundUplink":    true,
				"statsInboundDownlink":  true,
				"statsOutboundUplink":   true,
				"statsOutboundDownlink": true,
			},
		},
	}
}

func buildDNS(cfg config.AppConfig) map[string]any {
	if cfg.RulesProfile == config.RulesProfileRussia {
		servers := make([]any, 0, 8)

		if len(cfg.ProxyDomains) > 0 {
			servers = append(servers, dnsServer("1.1.1.1", cfg.ProxyDomains, nil, true))
		}
		if len(cfg.DirectDomains) > 0 {
			servers = append(servers, dnsServer("tcp+local://77.88.8.8", cfg.DirectDomains, []string{"geoip:private", "geoip:ru"}, true))
		}

		servers = append(servers,
			dnsServer("1.1.1.1", []string{"geosite:ru-blocked"}, nil, true),
			dnsServer("localhost", []string{"geosite:private"}, []string{"geoip:private"}, true),
			dnsServer("tcp+local://77.88.8.8", []string{"geosite:ru-available-only-inside"}, []string{"geoip:ru"}, true),
			dnsServer("tcp+local://77.88.8.8", []string{"regexp:(^|\\.).*\\.ru$", "regexp:(^|\\.).*\\.xn--p1ai$"}, []string{"geoip:ru"}, true),
			"localhost",
			"1.1.1.1",
			"8.8.8.8",
		)

		return map[string]any{
			"servers":       servers,
			"queryStrategy": "UseIPv4",
		}
	}

	dnsServers := []string{"1.1.1.1", "8.8.8.8"}
	if cfg.DNSMode == config.DNSDirect {
		dnsServers = []string{"localhost"}
	}

	dnsConfig := map[string]any{"servers": dnsServers}
	if cfg.TUNEnabled {
		dnsConfig["queryStrategy"] = "UseIPv4"
	}
	return dnsConfig
}

func dnsServer(address string, domains []string, expectIPs []string, disableFallback bool) map[string]any {
	server := map[string]any{
		"address":      address,
		"skipFallback": true,
	}
	if disableFallback {
		server["disableFallbackIfMatch"] = true
	}
	if len(domains) > 0 {
		server["domains"] = domains
	}
	if len(expectIPs) > 0 {
		server["expectIPs"] = expectIPs
	}
	return server
}

func appendRussiaSmartRules(rules []map[string]any, cfg config.AppConfig) []map[string]any {
	// Keep local/private destinations outside the tunnel even when TUN or
	// system proxy is enabled, so LAN traffic does not loop through Xray.
	rules = appendIPRule(rules, []string{"geoip:private"}, "direct")

	// Ensure runtime IP-check endpoints always go via proxy in Russia profile.
	rules = appendDomainRule(rules, forcedProxyCheckDomains, "proxy")

	if len(cfg.ProxyDomains) > 0 {
		rules = appendDomainRule(rules, cfg.ProxyDomains, "proxy")
	}

	// Smart Russia routing order:
	// 1. Resources blocked in Russia -> proxy
	// 2. Resources available only from inside Russia -> direct
	// 3. Other Russian traffic -> direct
	// 4. Everything else -> proxy
	rules = appendDomainRule(rules, []string{"geosite:ru-blocked"}, "proxy")
	rules = appendIPRule(rules, []string{"geoip:ru-blocked"}, "proxy")

	if len(cfg.DirectDomains) > 0 {
		rules = appendDomainRule(rules, cfg.DirectDomains, "direct")
	}

	rules = appendDomainRule(rules, []string{"geosite:ru-available-only-inside"}, "direct")
	rules = appendDomainRule(rules, []string{"regexp:(^|\\.).*\\.ru$", "regexp:(^|\\.).*\\.xn--p1ai$"}, "direct")
	rules = appendIPRule(rules, []string{"ext:geoip-ls.dat:ru"}, "direct")

	return append(rules, map[string]any{
		"type":        "field",
		"port":        "0-65535",
		"outboundTag": "proxy",
	})
}

func appendDomainRule(rules []map[string]any, domains []string, outboundTag string) []map[string]any {
	if len(domains) == 0 {
		return rules
	}
	return append(rules, map[string]any{
		"type":        "field",
		"domain":      domains,
		"outboundTag": outboundTag,
	})
}

func appendIPRule(rules []map[string]any, ips []string, outboundTag string) []map[string]any {
	if len(ips) == 0 {
		return rules
	}
	return append(rules, map[string]any{
		"type":        "field",
		"ip":          ips,
		"outboundTag": outboundTag,
	})
}

func domainStrategy(cfg config.AppConfig) string {
	if cfg.RulesProfile == config.RulesProfileRussia {
		return "IPIfNonMatch"
	}
	return "AsIs"
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

func buildFreedomOutbound(tag, bindInterface, bindAddress string, useIPv4Resolver bool) map[string]any {
	outbound := map[string]any{
		"tag":      tag,
		"protocol": "freedom",
	}

	if bindAddress != "" {
		outbound["sendThrough"] = bindAddress
	}

	if useIPv4Resolver {
		outbound["settings"] = map[string]any{
			"domainStrategy": "UseIPv4",
		}
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

func buildProxyOutbound(profile config.ServerProfile, bindInterface, bindAddress string) map[string]any {
	if profile.Protocol == "" || profile.Address == "" || profile.Port <= 0 {
		return buildFreedomOutbound("proxy", bindInterface, bindAddress, false)
	}

	outbound := map[string]any{
		"tag":      "proxy",
		"protocol": profile.Protocol,
	}
	if bindAddress != "" {
		outbound["sendThrough"] = bindAddress
	}

	if settings := buildOutboundSettings(profile); settings != nil {
		outbound["settings"] = settings
	}
	if streamSettings := buildStreamSettings(profile, bindInterface); streamSettings != nil {
		outbound["streamSettings"] = streamSettings
	}

	return outbound
}

func buildOutboundSettings(profile config.ServerProfile) map[string]any {
	switch profile.Protocol {
	case "vless":
		user := map[string]any{
			"id":         profile.UserID,
			"encryption": "none",
		}
		if profile.Flow != "" {
			user["flow"] = profile.Flow
		}
		return map[string]any{
			"vnext": []map[string]any{
				{
					"address": profile.Address,
					"port":    profile.Port,
					"users":   []map[string]any{user},
				},
			},
		}
	case "vmess":
		user := map[string]any{
			"id":       profile.UserID,
			"security": "auto",
		}
		return map[string]any{
			"vnext": []map[string]any{
				{
					"address": profile.Address,
					"port":    profile.Port,
					"users":   []map[string]any{user},
				},
			},
		}
	case "trojan":
		server := map[string]any{
			"address":  profile.Address,
			"port":     profile.Port,
			"password": profile.Password,
		}
		if profile.Flow != "" {
			server["flow"] = profile.Flow
		}
		return map[string]any{
			"servers": []map[string]any{server},
		}
	default:
		return nil
	}
}

func buildStreamSettings(profile config.ServerProfile, bindInterface string) map[string]any {
	network := profile.Transport
	if network == "" {
		network = "tcp"
	}

	security := profile.Security
	if security == "" {
		security = "none"
	}

	streamSettings := map[string]any{
		"network":  network,
		"security": security,
	}

	if bindInterface != "" {
		streamSettings["sockopt"] = map[string]any{
			"interface": bindInterface,
		}
	}

	switch network {
	case "ws":
		ws := map[string]any{}
		if profile.Path != "" {
			ws["path"] = profile.Path
		}
		headers := map[string]any{}
		if profile.Host != "" {
			headers["Host"] = profile.Host
		}
		if len(headers) > 0 {
			ws["headers"] = headers
		}
		if len(ws) > 0 {
			streamSettings["wsSettings"] = ws
		}
	case "grpc":
		grpc := map[string]any{}
		if profile.Path != "" {
			grpc["serviceName"] = profile.Path
		}
		if profile.Host != "" {
			grpc["authority"] = profile.Host
		}
		if len(grpc) > 0 {
			streamSettings["grpcSettings"] = grpc
		}
	case "httpupgrade":
		httpUpgrade := map[string]any{}
		if profile.Host != "" {
			httpUpgrade["host"] = profile.Host
		}
		if profile.Path != "" {
			httpUpgrade["path"] = profile.Path
		}
		if len(httpUpgrade) > 0 {
			streamSettings["httpupgradeSettings"] = httpUpgrade
		}
	}

	switch security {
	case "tls":
		tlsSettings := map[string]any{}
		if profile.SNI != "" {
			tlsSettings["serverName"] = profile.SNI
		}
		if profile.Fingerprint != "" {
			tlsSettings["fingerprint"] = profile.Fingerprint
		}
		if profile.ALPN != "" {
			tlsSettings["alpn"] = splitAndTrim(profile.ALPN)
		}
		if len(tlsSettings) > 0 {
			streamSettings["tlsSettings"] = tlsSettings
		}
	case "reality":
		realitySettings := map[string]any{}
		if profile.SNI != "" {
			realitySettings["serverName"] = profile.SNI
		}
		if profile.Fingerprint != "" {
			realitySettings["fingerprint"] = profile.Fingerprint
		}
		if profile.RealityPublicKey != "" {
			realitySettings["publicKey"] = profile.RealityPublicKey
		}
		if profile.RealityShortID != "" {
			realitySettings["shortId"] = profile.RealityShortID
		}
		if profile.SpiderX != "" {
			realitySettings["spiderX"] = profile.SpiderX
		}
		if realitySettings["fingerprint"] == nil {
			realitySettings["fingerprint"] = "chrome"
		}
		streamSettings["realitySettings"] = realitySettings
	}

	return streamSettings
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

func buildInbounds(cfg config.AppConfig, opts BuildOptions) []map[string]any {
	inbounds := []map[string]any{
		{
			"tag":      "mixed-in",
			"port":     config.DefaultMixedInboundPort,
			"listen":   "127.0.0.1",
			"protocol": "mixed",
			"settings": map[string]any{
				"auth": "noauth",
				"udp":  true,
			},
			"sniffing": map[string]any{
				"enabled":      true,
				"routeOnly":    false,
				"destOverride": []string{"http", "tls", "quic"},
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
			"sniffing": map[string]any{
				"enabled":      true,
				"routeOnly":    false,
				"destOverride": []string{"http", "tls", "quic"},
			},
		})
	}

	return inbounds
}
