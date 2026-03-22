package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/troodi/xray-desktop/core-manager/internal/api"
	"github.com/troodi/xray-desktop/core-manager/internal/config"
	xruntime "github.com/troodi/xray-desktop/core-manager/internal/runtime"
)

func main() {
	store := config.NewMemoryStore(config.DefaultAppConfig())
	if configPath, err := config.DefaultConfigPath(); err == nil {
		if fileStore, err := config.NewFileStore(config.DefaultAppConfig(), configPath); err == nil {
			store = fileStore
			log.Printf("config persistence enabled: %s", configPath)
		} else {
			log.Printf("config persistence disabled (%v), using in-memory store", err)
		}
	} else {
		log.Printf("config path not resolved (%v), using in-memory store", err)
	}
	runtime := xruntime.NewManager(xruntime.DefaultBinaryPath())
	go func() {
		cfg := store.Get()
		if cfg.RulesProfile == config.RulesProfileRussia {
			runtime.BeginRussiaRoutingAssetsWarmup()
		}
	}()

	var httpServer *http.Server
	handler := api.NewServer(store, runtime, func() {
		go func() {
			ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
			defer cancel()
			if httpServer != nil {
				if err := httpServer.Shutdown(ctx); err != nil {
					log.Printf("http shutdown after API request failed: %v", err)
				}
			}
		}()
	})

	httpServer = &http.Server{
		// Avoid clashing with common dev servers / proxy auto-config on 8080.
		Addr:              "127.0.0.1:29452",
		Handler:           handler.Routes(),
		ReadHeaderTimeout: 5 * time.Second,
	}

	signalCtx, stopSignals := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stopSignals()

	go func() {
		<-signalCtx.Done()
		log.Printf("shutdown signal received, stopping runtime")
		if err := runtime.Stop(); err != nil {
			log.Printf("runtime stop on shutdown failed: %v", err)
		}
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		if err := httpServer.Shutdown(ctx); err != nil {
			log.Printf("http shutdown failed: %v", err)
		}
	}()

	log.Printf("core-manager listening on http://%s", httpServer.Addr)

	if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatal(err)
	}
}
