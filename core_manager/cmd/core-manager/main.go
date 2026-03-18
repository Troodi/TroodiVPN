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
		if err := runtime.WarmRoutingAssets(); err != nil {
			log.Printf("routing assets warmup failed: %v", err)
		}
	}()
	handler := api.NewServer(store, runtime)

	server := &http.Server{
		Addr:              "127.0.0.1:8080",
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
		if err := server.Shutdown(ctx); err != nil {
			log.Printf("http shutdown failed: %v", err)
		}
	}()

	log.Printf("core-manager listening on http://%s", server.Addr)

	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatal(err)
	}
}
