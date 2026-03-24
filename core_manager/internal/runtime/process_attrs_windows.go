//go:build windows

package runtime

import (
	"errors"
	"os"
	"syscall"
	"time"
	"unsafe"

	"golang.org/x/sys/windows"
)

var (
	kernel32ProcessIO        = windows.NewLazySystemDLL("kernel32.dll")
	procGetProcessIoCounters = kernel32ProcessIO.NewProc("GetProcessIoCounters")
)

func getProcessIoCounters(handle windows.Handle, counters *windows.IO_COUNTERS) error {
	r1, _, e1 := procGetProcessIoCounters.Call(
		uintptr(handle),
		uintptr(unsafe.Pointer(counters)),
	)
	if r1 != 0 {
		return nil
	}
	if e1 != windows.ERROR_SUCCESS && e1 != nil {
		return e1
	}
	return errors.New("GetProcessIoCounters failed")
}

func hiddenProcessAttributes() *syscall.SysProcAttr {
	return &syscall.SysProcAttr{
		HideWindow:    true,
		CreationFlags: windows.CREATE_NO_WINDOW,
	}
}

func gracefulStop(proc *os.Process) error {
	return proc.Kill()
}

func (m *Manager) measureProcessIO() (uint64, uint64) {
	m.mu.Lock()
	cmd := m.cmd
	lastReadBytes := m.lastReadBytes
	lastWriteBytes := m.lastWriteBytes
	lastMetricsAt := m.lastMetricsAt
	m.mu.Unlock()

	if cmd == nil || cmd.Process == nil {
		return 0, 0
	}

	handle, err := windows.OpenProcess(
		windows.PROCESS_QUERY_LIMITED_INFORMATION,
		false,
		uint32(cmd.Process.Pid),
	)
	if err != nil {
		return 0, 0
	}
	defer windows.CloseHandle(handle)

	var counters windows.IO_COUNTERS
	if err := getProcessIoCounters(handle, &counters); err != nil {
		return 0, 0
	}

	now := time.Now()
	if lastMetricsAt.IsZero() {
		m.mu.Lock()
		m.lastReadBytes = counters.ReadTransferCount
		m.lastWriteBytes = counters.WriteTransferCount
		m.lastMetricsAt = now
		m.mu.Unlock()
		return 0, 0
	}

	elapsed := now.Sub(lastMetricsAt)
	if elapsed <= 0 {
		return 0, 0
	}

	seconds := elapsed.Seconds()
	downloadBps := uint64(
		float64(counters.ReadTransferCount-lastReadBytes) / seconds,
	)
	uploadBps := uint64(
		float64(counters.WriteTransferCount-lastWriteBytes) / seconds,
	)

	m.mu.Lock()
	m.lastReadBytes = counters.ReadTransferCount
	m.lastWriteBytes = counters.WriteTransferCount
	m.lastMetricsAt = now
	m.mu.Unlock()

	return downloadBps, uploadBps
}
