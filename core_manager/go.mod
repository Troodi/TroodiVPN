module github.com/troodi/xray-desktop/core-manager

go 1.26

require (
	github.com/miekg/dns v1.1.72
	github.com/xtls/xray-core v0.0.0
	golang.org/x/net v0.52.0
	golang.org/x/sys v0.42.0
	google.golang.org/grpc v1.79.2
)

require (
	github.com/pires/go-proxyproto v0.11.0 // indirect
	github.com/sagernet/sing v0.5.1 // indirect
	golang.org/x/mod v0.33.0 // indirect
	golang.org/x/sync v0.20.0 // indirect
	golang.org/x/text v0.35.0 // indirect
	golang.org/x/tools v0.42.0 // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20251202230838-ff82c1b0f217 // indirect
	google.golang.org/protobuf v1.36.11 // indirect
)

replace github.com/xtls/xray-core => ../xray_runtime/xray-core
