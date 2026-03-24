//go:build !windows

package runtime

import (
	"os"
	"syscall"
)

func hiddenProcessAttributes() *syscall.SysProcAttr {
	return &syscall.SysProcAttr{Setpgid: true}
}

// gracefulStop sends SIGTERM so sudo can forward it to the child xray process,
// giving xray a chance to release the TUN interface before exiting.
func gracefulStop(proc *os.Process) error {
	return proc.Signal(syscall.SIGTERM)
}

func (m *Manager) measureProcessIO() (uint64, uint64) {
	return 0, 0
}
