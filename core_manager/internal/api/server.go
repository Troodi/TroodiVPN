package api

import (
	"encoding/json"
	"errors"
	"net/http"
	"os"
	"time"

	"github.com/troodi/xray-desktop/core-manager/internal/config"
	"github.com/troodi/xray-desktop/core-manager/internal/platform"
	xruntime "github.com/troodi/xray-desktop/core-manager/internal/runtime"
	"github.com/troodi/xray-desktop/core-manager/internal/xray"
)

type Server struct {
	store   *config.Store
	runtime *xruntime.Manager
}

func NewServer(store *config.Store, runtime *xruntime.Manager) *Server {
	return &Server{store: store, runtime: runtime}
}

func (s *Server) Routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/v1/state", s.handleGetState)
	mux.HandleFunc("PUT /api/v1/state", s.handlePutState)
	mux.HandleFunc("POST /api/v1/connect", s.handleConnect)
	mux.HandleFunc("POST /api/v1/disconnect", s.handleDisconnect)
	mux.HandleFunc("POST /api/v1/shutdown", s.handleShutdown)
	mux.HandleFunc("POST /api/v1/routing-assets/warm", s.handleWarmRoutingAssets)
	mux.HandleFunc("GET /api/v1/xray-config", s.handleGetXrayConfig)
	mux.HandleFunc("GET /api/v1/logs", s.handleGetLogs)
	mux.HandleFunc("GET /api/v1/admin-status", s.handleGetAdminStatus)
	mux.HandleFunc("POST /api/v1/request-admin", s.handleRequestAdmin)
	return withCORS(mux)
}

func (s *Server) handleGetState(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, s.snapshot())
}

func (s *Server) handlePutState(w http.ResponseWriter, r *http.Request) {
	var next config.AppConfig
	if err := json.NewDecoder(r.Body).Decode(&next); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if next.ConnectionState == config.ConnectionConnected {
		if err := s.runtime.Restart(next); err != nil {
			next.ConnectionState = config.ConnectionDisconnected
			s.store.Put(next)
			if errors.Is(err, xruntime.ErrRoutingAssetsPending) {
				writeJSON(w, http.StatusServiceUnavailable, s.snapshot())
				return
			}
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
	} else if err := s.runtime.Stop(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	s.store.Put(next)
	if next.RulesProfile == config.RulesProfileRussia {
		go s.runtime.BeginRussiaRoutingAssetsWarmup()
	}
	writeJSON(w, http.StatusOK, s.snapshot())
}

func (s *Server) handleWarmRoutingAssets(w http.ResponseWriter, _ *http.Request) {
	s.runtime.BeginRussiaRoutingAssetsWarmup()
	writeJSON(w, http.StatusOK, s.snapshot())
}

func (s *Server) handleConnect(w http.ResponseWriter, _ *http.Request) {
	cfg := s.store.Get()
	if err := s.runtime.Start(cfg); err != nil {
		if errors.Is(err, xruntime.ErrRoutingAssetsPending) {
			writeJSON(w, http.StatusServiceUnavailable, s.snapshot())
			return
		}
		cfg.ConnectionState = config.ConnectionDisconnected
		s.store.Put(cfg)
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	cfg.ConnectionState = config.ConnectionConnected
	s.store.Put(cfg)
	writeJSON(w, http.StatusOK, s.snapshot())
}

func (s *Server) handleDisconnect(w http.ResponseWriter, _ *http.Request) {
	cfg := s.store.Get()
	if err := s.runtime.Stop(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	cfg.ConnectionState = config.ConnectionDisconnected
	s.store.Put(cfg)
	writeJSON(w, http.StatusOK, s.snapshot())
}

func (s *Server) handleShutdown(w http.ResponseWriter, _ *http.Request) {
	cfg := s.store.Get()
	if err := s.runtime.Stop(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	cfg.ConnectionState = config.ConnectionDisconnected
	s.store.Put(cfg)
	writeJSON(w, http.StatusOK, map[string]any{
		"ok": true,
	})
}

func (s *Server) handleGetXrayConfig(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, xray.Build(s.store.Get()))
}

func (s *Server) handleGetLogs(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"logs": s.runtime.Status().Logs,
	})
}

func (s *Server) handleGetAdminStatus(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"elevated": platform.IsElevated(),
	})
}

func (s *Server) handleRequestAdmin(w http.ResponseWriter, r *http.Request) {
	type adminRequest struct {
		Password string `json:"password"`
	}

	if platform.IsElevated() {
		writeJSON(w, http.StatusOK, map[string]any{
			"elevated":  true,
			"requested": false,
		})
		return
	}

	var payload adminRequest
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil && err.Error() != "EOF" {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if payload.Password != "" {
		if err := platform.SetElevationSecret(payload.Password); err != nil {
			http.Error(w, err.Error(), http.StatusUnauthorized)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{
			"elevated":  true,
			"requested": false,
		})
		return
	}

	executablePath, err := os.Executable()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	workingDirectory, err := os.Getwd()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if err := platform.RequestElevation(executablePath, workingDirectory); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"elevated":  false,
		"requested": true,
	})

	go func() {
		time.Sleep(800 * time.Millisecond)
		os.Exit(0)
	}()
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		w.Header().Set("Access-Control-Allow-Methods", "GET, PUT, POST, OPTIONS")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (s *Server) snapshot() StateResponse {
	cfg := s.store.Get()
	runtimeStatus := s.runtime.Status()
	// When profile is Global, hide routine Russia-asset clutter. The client may
	// still be prefetching rules (profile not saved as Russia until download
	// completes), so we must not strip downloading/error/progress or on-disk
	// timestamps — otherwise the modal never sees progress or completion.
	if cfg.RulesProfile != config.RulesProfileRussia {
		st := runtimeStatus.RoutingAssetsStatus
		switch {
		case st == "downloading" || st == "error":
			// Keep full runtime payload (per-file progress, errors).
		case runtimeStatus.RussiaRoutingAssetsUpdatedAt != "":
			// Files exist on disk; keep updatedAt so prefetch can finish and the
			// Rules UI can show cache age. Drop per-file rows to save payload.
			runtimeStatus.RoutingAssetsStatus = "idle"
			runtimeStatus.RoutingAssetsError = ""
			runtimeStatus.RoutingAssetsFiles = nil
		default:
			runtimeStatus.RussiaRoutingAssetsUpdatedAt = ""
			runtimeStatus.RoutingAssetsStatus = "idle"
			runtimeStatus.RoutingAssetsError = ""
			runtimeStatus.RoutingAssetsFiles = nil
		}
	}
	if !runtimeStatus.Running && cfg.ConnectionState == config.ConnectionConnected {
		cfg.ConnectionState = config.ConnectionDisconnected
		s.store.Put(cfg)
	}

	return StateResponse{
		Config:  cfg,
		Runtime: runtimeStatus,
	}
}
