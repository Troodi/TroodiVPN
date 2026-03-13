package main

import (
	"log"
	"net/http"
	"time"

	"github.com/troodi/xray-desktop/core-manager/internal/api"
	"github.com/troodi/xray-desktop/core-manager/internal/config"
	xruntime "github.com/troodi/xray-desktop/core-manager/internal/runtime"
)

func main() {
	store := config.NewMemoryStore(config.DefaultAppConfig())
	runtime := xruntime.NewManager(xruntime.DefaultBinaryPath())
	handler := api.NewServer(store, runtime)

	server := &http.Server{
		Addr:              "127.0.0.1:8080",
		Handler:           handler.Routes(),
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Printf("core-manager listening on http://%s", server.Addr)

	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatal(err)
	}
}
