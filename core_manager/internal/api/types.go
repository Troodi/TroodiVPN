package api

import (
	"github.com/troodi/xray-desktop/core-manager/internal/config"
	xruntime "github.com/troodi/xray-desktop/core-manager/internal/runtime"
)

type StateResponse struct {
	Config  config.AppConfig `json:"config"`
	Runtime xruntime.Status  `json:"runtime"`
}
