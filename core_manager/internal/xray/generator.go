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
	activeProfile := findActiveProfile(cfg)

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
			buildProxyOutbound(activeProfile, opts.BindInterface),
			buildFreedomOutbound("direct", opts.BindInterface),
			{"tag": "block", "protocol": "blackhole"},
		},
		"routing": map[string]any{
			"domainStrategy": "AsIs",
			"rules":          rules,
		},
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

func buildProxyOutbound(profile config.ServerProfile, bindInterface string) map[string]any {
	if profile.Protocol == "" || profile.Address == "" || profile.Port <= 0 {
		return buildFreedomOutbound("proxy", bindInterface)
	}

	outbound := map[string]any{
		"tag":      "proxy",
		"protocol": profile.Protocol,
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
