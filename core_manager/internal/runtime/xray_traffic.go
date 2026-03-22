package runtime

import (
	"context"
	"fmt"
	"time"

	"github.com/troodi/xray-desktop/core-manager/internal/xray"
	statscmd "github.com/xtls/xray-core/app/stats/command"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

// Xray outbound tags from internal/xray/generator.go — split routing sends
// traffic through either "proxy" or "direct"; upload must sum both or "out" stays 0.
var xrayOutboundUplinkStats = []string{
	"outbound>>>proxy>>>traffic>>>uplink",
	"outbound>>>direct>>>traffic>>>uplink",
}

func trafficInboundTag(mode string) string {
	if mode == "tun" {
		return "tun-in"
	}
	return "mixed-in"
}

func (m *Manager) clearXrayTrafficBaseline() {
	m.xrayBaselineInDown = 0
	m.xrayBaselineUpSum = 0
	m.xrayBaselineAt = time.Time{}
	m.xrayBaselineTag = ""
}

func getXrayStat(
	ctx context.Context,
	client statscmd.StatsServiceClient,
	name string,
) (int64, bool) {
	resp, err := client.GetStats(ctx, &statscmd.GetStatsRequest{Name: name})
	if err != nil {
		return 0, false
	}
	st := resp.GetStat()
	if st == nil {
		return 0, false
	}
	return st.Value, true
}

// measureXrayInboundBps uses Xray StatsService:
//   - user download ≈ inbound downlink (bytes to the local SOCKS/TUN client)
//   - user upload  ≈ sum of outbound uplink on proxy + direct (split tunnel), else inbound uplink
func (m *Manager) measureXrayInboundBps(ctx context.Context, mode string) (downloadBps, uploadBps uint64, ok bool) {
	tag := trafficInboundTag(mode)
	inDownName := fmt.Sprintf("inbound>>>%s>>>traffic>>>downlink", tag)
	inUpName := fmt.Sprintf("inbound>>>%s>>>traffic>>>uplink", tag)

	conn, err := grpc.NewClient(
		xray.LocalLoopbackStatsAPI,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		return 0, 0, false
	}
	defer conn.Close()

	ctx2, cancel := context.WithTimeout(ctx, 800*time.Millisecond)
	defer cancel()

	client := statscmd.NewStatsServiceClient(conn)

	downBytes, okDown := getXrayStat(ctx2, client, inDownName)
	if !okDown {
		return 0, 0, false
	}

	var outSum int64
	outHits := 0
	for _, name := range xrayOutboundUplinkStats {
		v, ok := getXrayStat(ctx2, client, name)
		if ok {
			outHits++
			outSum += v
		}
	}
	inUp, inUpOk := getXrayStat(ctx2, client, inUpName)
	upSum := outSum
	if outHits == 0 && inUpOk {
		upSum = inUp
	} else if inUpOk && inUp > upSum {
		// Split-tunnel uses direct+proxy; on some paths inbound uplink is the only non-zero counter.
		upSum = inUp
	}

	now := time.Now()

	m.mu.Lock()
	defer m.mu.Unlock()

	if m.xrayBaselineTag != tag {
		m.xrayBaselineTag = tag
		m.xrayBaselineInDown = uint64(downBytes)
		m.xrayBaselineUpSum = uint64(upSum)
		m.xrayBaselineAt = now
		return 0, 0, true
	}

	if m.xrayBaselineAt.IsZero() {
		m.xrayBaselineInDown = uint64(downBytes)
		m.xrayBaselineUpSum = uint64(upSum)
		m.xrayBaselineAt = now
		return 0, 0, true
	}

	if uint64(downBytes) < m.xrayBaselineInDown || uint64(upSum) < m.xrayBaselineUpSum {
		m.xrayBaselineInDown = uint64(downBytes)
		m.xrayBaselineUpSum = uint64(upSum)
		m.xrayBaselineAt = now
		return 0, 0, true
	}

	elapsed := now.Sub(m.xrayBaselineAt).Seconds()
	if elapsed <= 0 {
		return 0, 0, true
	}

	dd := uint64(downBytes) - m.xrayBaselineInDown
	du := uint64(upSum) - m.xrayBaselineUpSum
	downloadBps = uint64(float64(dd) / elapsed)
	uploadBps = uint64(float64(du) / elapsed)

	m.xrayBaselineInDown = uint64(downBytes)
	m.xrayBaselineUpSum = uint64(upSum)
	m.xrayBaselineAt = now
	return downloadBps, uploadBps, true
}
