//go:build !windows

package runtime

import "syscall"

func hiddenProcessAttributes() *syscall.SysProcAttr {
	return nil
}

func (m *Manager) measureProcessIO() (uint64, uint64) {
	return 0, 0
}
