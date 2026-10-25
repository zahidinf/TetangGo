package realtime

import (
	"log"
	"sync"
	"time"

	"github.com/gofiber/websocket/v2"
)

const (
	// Time allowed to write a message to the peer.
	writeWait = 10 * time.Second

	// Time allowed to read the next pong message from the peer.
	pongWait = 60 * time.Second

	// Send pings to peer with this period. Must be less than pongWait.
	pingPeriod = (pongWait * 9) / 10

	// Maximum message size allowed from peer (small since security client is read-only alarm receiver).
	maxMessageSize = 1024

	// Channel buffer size for outgoing messages.
	sendBufferSize = 64
)

// WSConnection defines the socket operations required by Client.
// Both *websocket.Conn and test mocks satisfy this interface.
type WSConnection interface {
	WriteMessage(messageType int, data []byte) error
	ReadMessage() (messageType int, p []byte, err error)
	SetWriteDeadline(t time.Time) error
	SetReadDeadline(t time.Time) error
	SetReadLimit(limit int64)
	SetPongHandler(h func(string) error)
	Close() error
}

type Client struct {
	hub             *Hub
	conn            WSConnection
	userID          int64
	deviceID        string
	connID          string
	neighborhoodIDs map[int64]struct{}
	sendChan        chan []byte
	closeOnce       sync.Once
	closed          chan struct{}
}

func NewClient(hub *Hub, conn WSConnection, userID int64, deviceID, connID string, neighborhoodIDs []int64) *Client {
	nMap := make(map[int64]struct{}, len(neighborhoodIDs))
	for _, nid := range neighborhoodIDs {
		nMap[nid] = struct{}{}
	}

	return &Client{
		hub:             hub,
		conn:            conn,
		userID:          userID,
		deviceID:        deviceID,
		connID:          connID,
		neighborhoodIDs: nMap,
		sendChan:        make(chan []byte, sendBufferSize),
		closed:          make(chan struct{}),
	}
}

func (c *Client) UserID() int64 {
	return c.userID
}

func (c *Client) DeviceID() string {
	return c.deviceID
}

func (c *Client) ConnID() string {
	return c.connID
}

func (c *Client) HasNeighborhood(neighborhoodID int64) bool {
	_, ok := c.neighborhoodIDs[neighborhoodID]
	return ok
}

func (c *Client) Close() {
	c.closeOnce.Do(func() {
		close(c.closed)
		if c.conn != nil {
			_ = c.conn.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.CloseNormalClosure, "connection closed"))
			_ = c.conn.Close()
		}
	})
}

// ReadPump handles incoming socket messages, enforcing heartbeats and dropping unauthorized client payload.
func (c *Client) ReadPump() {
	defer func() {
		c.hub.Unregister(c)
		c.Close()
	}()

	c.conn.SetReadLimit(maxMessageSize)
	_ = c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		_ = c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, _, err := c.conn.ReadMessage()
		if err != nil {
			break
		}
		// Security client is read-only alarm receiver. Any sent event payloads are rejected / ignored to prevent spoofing.
	}
}

// WritePump pushes queued messages to the socket and sends periodic ping frames.
func (c *Client) WritePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.hub.Unregister(c)
		c.Close()
	}()

	for {
		select {
		case <-c.closed:
			return
		case message, ok := <-c.sendChan:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				// Channel closed by hub
				_ = c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			if err := c.conn.WriteMessage(websocket.TextMessage, message); err != nil {
				log.Printf("[Realtime] Write failed for client %s: %v", c.connID, err)
				return
			}
		case <-ticker.C:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
