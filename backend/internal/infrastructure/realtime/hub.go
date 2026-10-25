package realtime

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"tetanggo-backend/internal/domain/entity"
)

type Hub struct {
	mu                sync.RWMutex
	clients           map[string]*Client // connID -> Client
	userDeviceClients map[string]*Client // "userID:deviceID" -> Client

	registerChan   chan *Client
	unregisterChan chan *Client
	broadcastChan  chan entity.IncidentRealtimeEvent
	shutdownChan   chan struct{}
	doneChan       chan struct{}
	shutdownOnce   sync.Once
}

func NewHub() *Hub {
	return &Hub{
		clients:           make(map[string]*Client),
		userDeviceClients: make(map[string]*Client),
		registerChan:      make(chan *Client, 64),
		unregisterChan:    make(chan *Client, 64),
		broadcastChan:     make(chan entity.IncidentRealtimeEvent, 128),
		shutdownChan:      make(chan struct{}),
		doneChan:          make(chan struct{}),
	}
}

func (h *Hub) Run() {
	defer close(h.doneChan)

	for {
		select {
		case <-h.shutdownChan:
			h.mu.Lock()
			for _, client := range h.clients {
				client.Close()
			}
			h.clients = make(map[string]*Client)
			h.userDeviceClients = make(map[string]*Client)
			h.mu.Unlock()
			return

		case client := <-h.registerChan:
			h.mu.Lock()
			userDevKey := fmt.Sprintf("%d:%s", client.userID, client.deviceID)

			// Clean up any stale connection from the same device (safe reconnect)
			if oldClient, exists := h.userDeviceClients[userDevKey]; exists {
				delete(h.clients, oldClient.connID)
				go oldClient.Close()
			}

			h.clients[client.connID] = client
			h.userDeviceClients[userDevKey] = client
			h.mu.Unlock()

		case client := <-h.unregisterChan:
			h.mu.Lock()
			if existing, ok := h.clients[client.connID]; ok && existing == client {
				delete(h.clients, client.connID)
				userDevKey := fmt.Sprintf("%d:%s", client.userID, client.deviceID)
				if current, found := h.userDeviceClients[userDevKey]; found && current == client {
					delete(h.userDeviceClients, userDevKey)
				}
			}
			h.mu.Unlock()

		case event := <-h.broadcastChan:
			payload, err := json.Marshal(event)
			if err != nil {
				log.Printf("[Realtime] Failed to marshal incident event: %v", err)
				continue
			}

			h.mu.Lock()
			var slowClients []*Client

			for _, client := range h.clients {
				// Strict neighborhood scoping: only dispatch to security assigned to this neighborhood
				if !client.HasNeighborhood(event.NeighborhoodID) {
					continue
				}

				// Non-blocking send protects fast clients from slow consumers
				select {
				case client.sendChan <- payload:
				default:
					slowClients = append(slowClients, client)
				}
			}

			// Clean up slow consumers
			for _, client := range slowClients {
				delete(h.clients, client.connID)
				userDevKey := fmt.Sprintf("%d:%s", client.userID, client.deviceID)
				if current, found := h.userDeviceClients[userDevKey]; found && current == client {
					delete(h.userDeviceClients, userDevKey)
				}
				go client.Close()
				log.Printf("[Realtime] Evicted slow consumer client %s (userID=%d, deviceID=%s)", client.connID, client.userID, client.deviceID)
			}
			h.mu.Unlock()
		}
	}
}

func (h *Hub) Register(c *Client) {
	select {
	case <-h.shutdownChan:
		c.Close()
	case h.registerChan <- c:
	}
}

func (h *Hub) Unregister(c *Client) {
	select {
	case <-h.shutdownChan:
	case h.unregisterChan <- c:
	}
}

func (h *Hub) Broadcast(event entity.IncidentRealtimeEvent) {
	select {
	case <-h.shutdownChan:
	case h.broadcastChan <- event:
	}
}

func (h *Hub) ClientCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}

func (h *Hub) ActiveClientsInNeighborhood(neighborhoodID int64) int {
	h.mu.RLock()
	defer h.mu.RUnlock()

	count := 0
	for _, client := range h.clients {
		if client.HasNeighborhood(neighborhoodID) {
			count++
		}
	}
	return count
}

func (h *Hub) Shutdown(ctx context.Context) error {
	var err error
	h.shutdownOnce.Do(func() {
		close(h.shutdownChan)
		select {
		case <-h.doneChan:
		case <-ctx.Done():
			err = ctx.Err()
		}
	})
	return err
}
