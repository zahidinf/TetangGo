package fcm_test

import (
	"context"
	"sync"
	"testing"
	"time"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/infrastructure/fcm"
)

type mockDeviceTokenRepo struct {
	mu           sync.Mutex
	tokens       map[string]*entity.SecurityDeviceToken // device_token -> token
	revokedCalls int
}

func newMockDeviceTokenRepo() *mockDeviceTokenRepo {
	return &mockDeviceTokenRepo{
		tokens: make(map[string]*entity.SecurityDeviceToken),
	}
}

func (m *mockDeviceTokenRepo) UpsertDeviceToken(ctx context.Context, token *entity.SecurityDeviceToken) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.tokens[token.DeviceToken] = token
	token.IsActive = true
	return nil
}

func (m *mockDeviceTokenRepo) RevokeDeviceToken(ctx context.Context, userID int64, deviceID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, t := range m.tokens {
		if t.UserID == userID && t.DeviceID == deviceID {
			t.IsActive = false
			m.revokedCalls++
		}
	}
	return nil
}

func (m *mockDeviceTokenRepo) DeactivateTokenByValue(ctx context.Context, tokenValue string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if t, exists := m.tokens[tokenValue]; exists {
		t.IsActive = false
		m.revokedCalls++
	}
	return nil
}

func (m *mockDeviceTokenRepo) GetActiveTokensForNeighborhood(ctx context.Context, neighborhoodID int64) ([]entity.SecurityDeviceToken, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var res []entity.SecurityDeviceToken
	for _, t := range m.tokens {
		if t.IsActive {
			res = append(res, *t)
		}
	}
	return res, nil
}

func (m *mockDeviceTokenRepo) GetActiveTokensForUser(ctx context.Context, userID int64) ([]entity.SecurityDeviceToken, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var res []entity.SecurityDeviceToken
	for _, t := range m.tokens {
		if t.UserID == userID && t.IsActive {
			res = append(res, *t)
		}
	}
	return res, nil
}

func TestFCMServiceLifecycleAndTokenHandling(t *testing.T) {
	tokenRepo := newMockDeviceTokenRepo()
	fcmService := fcm.NewFCMService(tokenRepo, "mock", "mock")

	now := time.Now()
	inc := &entity.Incident{
		ID:             55,
		Category:       "KEJAHATAN",
		NeighborhoodID: 101,
		Status:         "ACTIVE",
		ReportedAt:     now,
	}

	t.Run("1. Successfully sends high-priority push with safe minimal payload", func(t *testing.T) {
		tokenRepo.UpsertDeviceToken(context.Background(), &entity.SecurityDeviceToken{
			UserID:      10,
			DeviceID:    "sec-phone-1",
			DeviceToken: "fcm_token_valid_123",
			Platform:    "android",
			IsActive:    true,
		})

		tokens, _ := tokenRepo.GetActiveTokensForNeighborhood(context.Background(), 101)
		err := fcmService.SendIncidentPush(context.Background(), tokens, inc)
		if err != nil {
			t.Fatalf("expected nil error sending push, got %v", err)
		}

		time.Sleep(50 * time.Millisecond)
		records := fcmService.GetSentRecords()
		if len(records) != 1 {
			t.Fatalf("expected 1 sent record, got %d", len(records))
		}
		if records[0].Priority != "HIGH" {
			t.Errorf("expected HIGH priority, got %s", records[0].Priority)
		}
		if records[0].DataPayload["incident_id"] != "55" {
			t.Errorf("expected incident_id 55, got %s", records[0].DataPayload["incident_id"])
		}
		if records[0].DataPayload["category"] != "KEJAHATAN" {
			t.Errorf("expected category KEJAHATAN, got %s", records[0].DataPayload["category"])
		}
	})

	t.Run("2. Handles invalid token and deactivates it in database", func(t *testing.T) {
		fcmService.ClearSentRecords()

		invalidToken := &entity.SecurityDeviceToken{
			UserID:      11,
			DeviceID:    "sec-phone-expired",
			DeviceToken: "invalid_unregistered_token_456",
			Platform:    "android",
			IsActive:    true,
		}
		tokenRepo.UpsertDeviceToken(context.Background(), invalidToken)

		tokens := []entity.SecurityDeviceToken{*invalidToken}
		err := fcmService.SendIncidentPush(context.Background(), tokens, inc)
		if err != nil {
			t.Fatalf("expected nil error at caller level (non-blocking), got %v", err)
		}

		time.Sleep(50 * time.Millisecond)

		// Check that the invalid token was automatically deactivated
		tokenRepo.mu.Lock()
		tVal := tokenRepo.tokens["invalid_unregistered_token_456"]
		tokenRepo.mu.Unlock()

		if tVal == nil || tVal.IsActive {
			t.Errorf("expected invalid token to be deactivated, got %+v", tVal)
		}
	})

	t.Run("3. Push failure does not fail or rollback incident creation", func(t *testing.T) {
		// Even if tokens is empty or nil, no crash or error returned
		err := fcmService.SendIncidentPush(context.Background(), nil, inc)
		if err != nil {
			t.Errorf("expected nil error for nil tokens, got %v", err)
		}
	})
}
