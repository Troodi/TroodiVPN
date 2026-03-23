package runtime

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"sync/atomic"
	"time"

	"github.com/troodi/xray-desktop/core-manager/internal/xray"
	statscmd "github.com/xtls/xray-core/app/stats/command"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

var statsDiagDumped atomic.Bool

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
	statsDiagDumped.Store(false)
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

func sumXrayStats(ctx context.Context, client statscmd.StatsServiceClient, names []string) (int64, bool) {
	var total int64
	any := false
	for _, name := range names {
		v, ok := getXrayStat(ctx, client, name)
		if ok {
			any = true
			total += v
		}
	}
	return total, any
}

// dumpAllXrayStats logs every stat name+value via QueryStats (once per xray session).
func (m *Manager) dumpAllXrayStats(ctx context.Context, client statscmd.StatsServiceClient) {
	if statsDiagDumped.Load() {
		return
	}
	statsDiagDumped.Store(true)

	resp, err := client.QueryStats(ctx, &statscmd.QueryStatsRequest{Pattern: ""})
	if err != nil {
		m.appendLog(fmt.Sprintf("[stats-diag] QueryStats error: %v", err))
		return
	}

	stats := resp.GetStat()
	if len(stats) == 0 {
		m.appendLog("[stats-diag] QueryStats returned 0 counters — stats module may not be active")
		return
	}

	names := make([]string, 0, len(stats))
	values := map[string]int64{}
	for _, s := range stats {
		names = append(names, s.Name)
		values[s.Name] = s.Value
	}
	sort.Strings(names)

	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("[stats-diag] %d counters available:\n", len(names)))
	for _, n := range names {
		sb.WriteString(fmt.Sprintf("  %s = %d\n", n, values[n]))
	}
	m.appendLog(sb.String())
}

// measureXrayInboundBps queries Xray StatsService for traffic counters.
//
// Download (IN / Traffic received):
//
//	Primary:  inbound>>>TAG>>>traffic>>>downlink   (bytes Xray → user)
//	Fallback: outbound proxy+direct downlink sum   (bytes remote → Xray)
//
// Upload (OUT / Traffic sent):
//
//	Primary:  inbound>>>TAG>>>traffic>>>uplink      (bytes user → Xray)
//	Fallback: outbound proxy+direct uplink sum      (bytes Xray → remote)
//
// TUN mode in Xray often does NOT populate inbound uplink, so the outbound
// fallback is essential for upload to show a non-zero value.
func (m *Manager) measureXrayInboundBps(ctx context.Context, mode string) (downloadBps, uploadBps uint64, ok bool) {
	tag := trafficInboundTag(mode)

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

	m.dumpAllXrayStats(ctx2, client)

	// --- collect all candidate counters ---

	inDown, okInDown := getXrayStat(ctx2, client, fmt.Sprintf("inbound>>>%s>>>traffic>>>downlink", tag))
	inUp, okInUp := getXrayStat(ctx2, client, fmt.Sprintf("inbound>>>%s>>>traffic>>>uplink", tag))

	outUpSum, okOutUp := sumXrayStats(ctx2, client, []string{
		"outbound>>>proxy>>>traffic>>>uplink",
		"outbound>>>direct>>>traffic>>>uplink",
	})
	outDownSum, okOutDown := sumXrayStats(ctx2, client, []string{
		"outbound>>>proxy>>>traffic>>>downlink",
		"outbound>>>direct>>>traffic>>>downlink",
	})

	// --- pick best source for each direction ---
	// TUN mode in Xray does NOT populate inbound counters (both uplink and
	// downlink stay 0). Outbound counters (proxy+direct) are the reliable
	// source in all modes. Use inbound only when it has actual data.

	var downTotal int64
	if okInDown && inDown > 0 {
		downTotal = inDown
	} else if okOutDown {
		downTotal = outDownSum
	}

	var upTotal int64
	if okInUp && inUp > 0 {
		upTotal = inUp
	} else if okOutUp {
		upTotal = outUpSum
	}

	if downTotal <= 0 && upTotal <= 0 {
		return 0, 0, false
	}

	now := time.Now()

	m.mu.Lock()
	defer m.mu.Unlock()

	if m.xrayBaselineTag != tag || m.xrayBaselineAt.IsZero() {
		m.xrayBaselineTag = tag
		m.xrayBaselineInDown = uint64(downTotal)
		m.xrayBaselineUpSum = uint64(upTotal)
		m.xrayBaselineAt = now
		return 0, 0, true
	}

	if uint64(downTotal) < m.xrayBaselineInDown || uint64(upTotal) < m.xrayBaselineUpSum {
		m.xrayBaselineInDown = uint64(downTotal)
		m.xrayBaselineUpSum = uint64(upTotal)
		m.xrayBaselineAt = now
		return 0, 0, true
	}

	elapsed := now.Sub(m.xrayBaselineAt).Seconds()
	if elapsed <= 0 {
		return 0, 0, true
	}

	dd := uint64(downTotal) - m.xrayBaselineInDown
	du := uint64(upTotal) - m.xrayBaselineUpSum

	downloadBps = uint64(float64(dd) / elapsed)
	uploadBps = uint64(float64(du) / elapsed)

	m.xrayBaselineInDown = uint64(downTotal)
	m.xrayBaselineUpSum = uint64(upTotal)
	m.xrayBaselineAt = now
	return downloadBps, uploadBps, true
}
