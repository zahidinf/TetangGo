package realtime_test

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/infrastructure/realtime"
)

// mockConn simulates a WSConnection with an in-memory queue.
type mockConn struct {
	mu           sync.Mutex
	textMessages [][]byte
	allMessages  [][]byte
	closed       bool
	writeDelay   time.Duration
	blockWrites  bool
	readBlock    chan struct{}
	closeHandler func()
}

func newMockConn() *mockConn {
	return &mockConn{
		textMessages: make([][]byte, 0),
		allMessages:  make([][]byte, 0),
		readBlock:    make(chan struct{}),
	}
}

func (m *mockConn) WriteMessage(messageType int, data []byte) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.closed {
		return fmt.Errorf("connection closed")
	}
	if m.blockWrites {
		time.Sleep(50 * time.Millisecond)
	}
	if m.writeDelay > 0 {
		time.Sleep(m.writeDelay)
	}

	copied := make([]byte, len(data))
	copy(copied, data)
	m.allMessages = append(m.allMessages, copied)
	if messageType == 1 { // websocket.TextMessage
		m.textMessages = append(m.textMessages, copied)
	}
	return nil
}

func (m *mockConn) ReadMessage() (int, []byte, error) {
	<-m.readBlock
	return 0, nil, fmt.Errorf("connection closed")
}

func (m *mockConn) SetWriteDeadline(t time.Time) error { return nil }
func (m *mockConn) SetReadDeadline(t time.Time) error  { return nil }
func (m *mockConn) SetReadLimit(limit int64)           {}
func (m *mockConn) SetPongHandler(h func(string) error) {}

func (m *mockConn) Close() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if !m.closed {
		m.closed = true
		close(m.readBlock)
		if m.closeHandler != nil {
			m.closeHandler()
		}
	}
	return nil
}

func (m *mockConn) GetMessages() [][]byte {
	m.mu.Lock()
	defer m.mu.Unlock()
	res := make([][]byte, len(m.textMessages))
	copy(res, m.textMessages)
	return res
}

func TestHub_NeighborhoodScoping(t *testing.T) {
	hub := realtime.NewHub()
	go hub.Run()
	defer func() { _ = hub.Shutdown(context.Background()) }()

	// Client 1: Security in Neighborhood 1
	conn1 := newMockConn()
	c1 := realtime.NewClient(hub, conn1, 101, "dev1", "conn1", []int64{1})
	hub.Register(c1)
	go c1.WritePump()

	// Client 2: Security in Neighborhood 2 only
	conn2 := newMockConn()
	c2 := realtime.NewClient(hub, conn2, 102, "dev2", "conn2", []int64{2})
	hub.Register(c2)
	go c2.WritePump()

	// Client 3: Security in both Neighborhood 1 and 2
	conn3 := newMockConn()
	c3 := realtime.NewClient(hub, conn3, 103, "dev3", "conn3", []int64{1, 2})
	hub.Register(c3)
	go c3.WritePump()

	time.Sleep(20 * time.Millisecond)

	// Event in Neighborhood 1
	inc1 := &entity.Incident{
		ID:             1,
		Category:       "KEJAHATAN",
		NeighborhoodID: 1,
		Title:          "Pencurian",
		Status:         "ACTIVE",
		ReportedAt:     time.Now(),
	}
	event1 := entity.NewIncidentRealtimeEvent(entity.IncidentEventTypeCreated, inc1, "")
	hub.Broadcast(event1)

	time.Sleep(50 * time.Millisecond)

	// Verification for Event 1
	if len(conn1.GetMessages()) != 1 {
		t.Errorf("Client 1 (Neighborhood 1) expected 1 message, got %d", len(conn1.GetMessages()))
	}
	if len(conn2.GetMessages()) != 0 {
		t.Errorf("Client 2 (Neighborhood 2) LEAK! Expected 0 messages, got %d", len(conn2.GetMessages()))
	}
	if len(conn3.GetMessages()) != 1 {
		t.Errorf("Client 3 (Neighborhood 1&2) expected 1 message, got %d", len(conn3.GetMessages()))
	}

	// Event in Neighborhood 2
	inc2 := &entity.Incident{
		ID:             2,
		Category:       "KEBAKARAN",
		NeighborhoodID: 2,
		Title:          "Kebakaran Sampah",
		Status:         "ACTIVE",
		ReportedAt:     time.Now(),
	}
	event2 := entity.NewIncidentRealtimeEvent(entity.IncidentEventTypeCreated, inc2, "")
	hub.Broadcast(event2)

	time.Sleep(50 * time.Millisecond)

	// Verification for Event 2
	if len(conn1.GetMessages()) != 1 {
		t.Errorf("Client 1 (Neighborhood 1) expected still 1 message, got %d", len(conn1.GetMessages()))
	}
	if len(conn2.GetMessages()) != 1 {
		t.Errorf("Client 2 (Neighborhood 2) expected 1 message for N2, got %d", len(conn2.GetMessages()))
	}
	if len(conn3.GetMessages()) != 2 {
		t.Errorf("Client 3 (Neighborhood 1&2) expected 2 messages total, got %d", len(conn3.GetMessages()))
	}

	// Verify payload contents
	var received entity.IncidentRealtimeEvent
	_ = json.Unmarshal(conn1.GetMessages()[0], &received)
	if received.EventType != entity.IncidentEventTypeCreated || received.Data.IncidentID != 1 {
		t.Errorf("unexpected event payload: %+v", received)
	}
}

func TestHub_SafeReconnectDeduplication(t *testing.T) {
	hub := realtime.NewHub()
	go hub.Run()
	defer func() { _ = hub.Shutdown(context.Background()) }()

	userID := int64(201)
	deviceID := "mobile-samsung-a52"

	// Initial connection
	connOld := newMockConn()
	clientOld := realtime.NewClient(hub, connOld, userID, deviceID, "conn_old", []int64{1})
	hub.Register(clientOld)
	go clientOld.WritePump()

	time.Sleep(20 * time.Millisecond)

	if hub.ClientCount() != 1 {
		t.Fatalf("expected 1 client, got %d", hub.ClientCount())
	}

	// Reconnect with same device ID
	connNew := newMockConn()
	clientNew := realtime.NewClient(hub, connNew, userID, deviceID, "conn_new", []int64{1})
	hub.Register(clientNew)
	go clientNew.WritePump()

	time.Sleep(50 * time.Millisecond)

	// Old connection should be closed/evicted
	if hub.ClientCount() != 1 {
		t.Fatalf("expected client count to remain 1 after reconnect, got %d", hub.ClientCount())
	}

	// Broadcast event
	inc := &entity.Incident{
		ID:             99,
		Category:       "MEDIS",
		NeighborhoodID: 1,
		Status:         "ACTIVE",
		ReportedAt:     time.Now(),
	}
	hub.Broadcast(entity.NewIncidentRealtimeEvent(entity.IncidentEventTypeCreated, inc, ""))

	time.Sleep(50 * time.Millisecond)

	// Verify new connection receives message, old connection does NOT receive duplicate
	if len(connNew.GetMessages()) != 1 {
		t.Errorf("new connection expected 1 message, got %d", len(connNew.GetMessages()))
	}
	if len(connOld.GetMessages()) != 0 {
		t.Errorf("old connection should not receive broadcast after reconnect, got %d", len(connOld.GetMessages()))
	}
}

func TestHub_SlowConsumerProtection(t *testing.T) {
	hub := realtime.NewHub()
	go hub.Run()
	defer func() { _ = hub.Shutdown(context.Background()) }()

	// Normal Fast Client
	fastConn := newMockConn()
	fastClient := realtime.NewClient(hub, fastConn, 301, "fast-dev", "conn-fast", []int64{1})
	hub.Register(fastClient)
	go fastClient.WritePump()

	// Slow / Stalled Client (does not run WritePump, channel fills up to buffer limit)
	slowConn := newMockConn()
	slowClient := realtime.NewClient(hub, slowConn, 302, "slow-dev", "conn-slow", []int64{1})
	hub.Register(slowClient)
	// Notice: slowClient does NOT drain sendChan!

	time.Sleep(20 * time.Millisecond)

	// Send more messages than sendBufferSize (64)
	for i := 1; i <= 80; i++ {
		inc := &entity.Incident{
			ID:             int64(i),
			Category:       "KEJAHATAN",
			NeighborhoodID: 1,
			Status:         "ACTIVE",
			ReportedAt:     time.Now(),
		}
		hub.Broadcast(entity.NewIncidentRealtimeEvent(entity.IncidentEventTypeCreated, inc, ""))
		time.Sleep(500 * time.Microsecond)
	}

	time.Sleep(100 * time.Millisecond)

	// Fast client should have received all messages without blocking
	fastMsgs := fastConn.GetMessages()
	if len(fastMsgs) < 80 {
		t.Errorf("fast client expected 80 messages, got %d", len(fastMsgs))
	}

	// Slow client should be evicted from the hub
	if hub.ClientCount() != 1 {
		t.Errorf("expected slow client to be evicted, remaining clients: %d", hub.ClientCount())
	}
}

func TestHub_MultiClientConcurrencyAndRace(t *testing.T) {
	hub := realtime.NewHub()
	go hub.Run()
	defer func() { _ = hub.Shutdown(context.Background()) }()

	const numClients = 30
	var wg sync.WaitGroup
	var receivedCount int64

	for i := 1; i <= numClients; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			conn := newMockConn()
			client := realtime.NewClient(hub, conn, int64(id), fmt.Sprintf("dev-%d", id), fmt.Sprintf("conn-%d", id), []int64{1})
			hub.Register(client)
			go client.WritePump()

			time.Sleep(10 * time.Millisecond)

			// Randomly disconnect some clients midway
			if id%5 == 0 {
				client.Close()
				hub.Unregister(client)
			}
		}(i)
	}

	wg.Wait()

	// Broadcast 10 events concurrently
	var bcastWg sync.WaitGroup
	for i := 1; i <= 10; i++ {
		bcastWg.Add(1)
		go func(eventID int) {
			defer bcastWg.Done()
			inc := &entity.Incident{
				ID:             int64(eventID),
				Category:       "MEDIS",
				NeighborhoodID: 1,
				Status:         "ACTIVE",
				ReportedAt:     time.Now(),
			}
			hub.Broadcast(entity.NewIncidentRealtimeEvent(entity.IncidentEventTypeCreated, inc, ""))
		}(i)
	}
	bcastWg.Wait()

	time.Sleep(100 * time.Millisecond)

	_ = atomic.LoadInt64(&receivedCount)
	// Test passes cleanly without deadlock or data races under `go test -race`
}

func TestHub_GracefulShutdown(t *testing.T) {
	hub := realtime.NewHub()
	go hub.Run()

	conn := newMockConn()
	client := realtime.NewClient(hub, conn, 501, "dev-shut", "conn-shut", []int64{1})
	hub.Register(client)
	go client.WritePump()

	time.Sleep(20 * time.Millisecond)

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	err := hub.Shutdown(ctx)
	if err != nil {
		t.Fatalf("unexpected shutdown error: %v", err)
	}

	if hub.ClientCount() != 0 {
		t.Errorf("expected 0 clients after shutdown, got %d", hub.ClientCount())
	}
}
