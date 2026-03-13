package api

import (
	"encoding/json"
	"net/http"

	"github.com/troodi/xray-desktop/core-manager/internal/config"
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
	mux.HandleFunc("GET /api/v1/xray-config", s.handleGetXrayConfig)
	mux.HandleFunc("GET /api/v1/logs", s.handleGetLogs)
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
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
	} else if err := s.runtime.Stop(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	s.store.Put(next)
	writeJSON(w, http.StatusOK, s.snapshot())
}

func (s *Server) handleConnect(w http.ResponseWriter, _ *http.Request) {
	cfg := s.store.Get()
	if err := s.runtime.Start(cfg); err != nil {
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

func (s *Server) handleGetXrayConfig(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, xray.Build(s.store.Get()))
}

func (s *Server) handleGetLogs(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"logs": s.runtime.Status().Logs,
	})
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
	if !runtimeStatus.Running && cfg.ConnectionState == config.ConnectionConnected {
		cfg.ConnectionState = config.ConnectionDisconnected
		s.store.Put(cfg)
	}

	return StateResponse{
		Config:  cfg,
		Runtime: runtimeStatus,
	}
}
