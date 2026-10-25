package fcm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
)

// FCMService handles dispatching push notifications via Firebase Cloud Messaging v1 / HTTP protocol.
// Fallback logic safely gracefully degrades if credentials are not configured.
type FCMService struct {
	tokenRepo repository.SecurityDeviceTokenRepository
	client    *http.Client
	projectID string
	apiKey    string // For legacy / mock testing
	mu        sync.RWMutex
	sentLogs  []FCMSentRecord // For test inspection
}

type FCMSentRecord struct {
	DeviceToken string
	IncidentID  int64
	Priority    string
	DataPayload map[string]string
	SentAt      time.Time
}

func NewFCMService(tokenRepo repository.SecurityDeviceTokenRepository, projectID, apiKey string) *FCMService {
	return &FCMService{
		tokenRepo: tokenRepo,
		client: &http.Client{
			Timeout: 5 * time.Second,
		},
		projectID: projectID,
		apiKey:    apiKey,
	}
}

// GetSentRecords returns records of push sent (useful for tests)
func (s *FCMService) GetSentRecords() []FCMSentRecord {
	s.mu.RLock()
	defer s.mu.RUnlock()
	res := make([]FCMSentRecord, len(s.sentLogs))
	copy(res, s.sentLogs)
	return res
}

func (s *FCMService) ClearSentRecords() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.sentLogs = nil
}

// SendIncidentPush sends high-priority FCM data payload to designated security devices.
// Information included is safe & minimal: incident_id, category, neighborhood_id, status.
// Full sensitive details must be fetched through authenticated API.
func (s *FCMService) SendIncidentPush(ctx context.Context, tokens []entity.SecurityDeviceToken, inc *entity.Incident) error {
	if len(tokens) == 0 || inc == nil {
		return nil
	}

	// Payload with HIGH priority for emergency alerting
	// Data payload ensures background handling wakes the device
	dataPayload := map[string]string{
		"type":            "EMERGENCY_INCIDENT",
		"incident_id":     fmt.Sprintf("%d", inc.ID),
		"category":        inc.Category,
		"neighborhood_id": fmt.Sprintf("%d", inc.NeighborhoodID),
		"status":          inc.Status,
		"reported_at":     inc.ReportedAt.Format(time.RFC3339),
		"priority":        "HIGH",
	}

	var wg sync.WaitGroup

	for _, dt := range tokens {
		token := dt
		wg.Add(1)

		go func() {
			defer wg.Done()
			s.dispatchSinglePushWithRetry(context.Background(), token, inc.ID, dataPayload, 2)
		}()
	}

	wg.Wait()
	return nil
}

func (s *FCMService) dispatchSinglePushWithRetry(ctx context.Context, token entity.SecurityDeviceToken, incID int64, data map[string]string, maxRetries int) {
	for attempt := 0; attempt <= maxRetries; attempt++ {
		err := s.sendPushHTTP(ctx, token.DeviceToken, incID, data)
		if err == nil {
			s.mu.Lock()
			s.sentLogs = append(s.sentLogs, FCMSentRecord{
				DeviceToken: token.DeviceToken,
				IncidentID:  incID,
				Priority:    "HIGH",
				DataPayload: data,
				SentAt:      time.Now(),
			})
			s.mu.Unlock()
			return
		}

		// Check if token is invalid or unregistered
		if isTokenInvalidError(err) {
			log.Printf("[FCM] Device token %s is invalid/unregistered. Deactivating token from database.", token.DeviceToken)
			if s.tokenRepo != nil {
				_ = s.tokenRepo.DeactivateTokenByValue(ctx, token.DeviceToken)
			}
			return
		}

		// Retry with backoff if network or server error
		if attempt < maxRetries {
			time.Sleep(time.Duration(100*(attempt+1)) * time.Millisecond)
		} else {
			log.Printf("[FCM] Push notification failed after %d retries for device %s: %v", maxRetries, token.DeviceID, err)
		}
	}
}

func (s *FCMService) sendPushHTTP(ctx context.Context, deviceToken string, incID int64, data map[string]string) error {
	// If mock/test mode or FCM_PROJECT_ID not set or set to mock
	if s.projectID == "" || s.projectID == "mock" || s.apiKey == "mock" {
		// Mock dispatch check for test suite
		if strings.HasPrefix(deviceToken, "invalid_") {
			return fmt.Errorf("UNREGISTERED: device token is no longer registered")
		}
		// Successfully sent in mock/dev mode
		return nil
	}

	// Real FCM HTTP v1 / Send endpoint payload structure
	// https://firebase.google.com/docs/cloud-messaging/send-message
	payload := map[string]interface{}{
		"message": map[string]interface{}{
			"token": deviceToken,
			"data":  data,
			"android": map[string]interface{}{
				"priority": "HIGH",
				"notification": map[string]interface{}{
					"channel_id": "tetanggo_emergency_alarms",
					"sound":      "emergency_siren",
					"priority":   "HIGH",
				},
			},
			"apns": map[string]interface{}{
				"headers": map[string]interface{}{
					"apns-priority": "10",
				},
				"payload": map[string]interface{}{
					"aps": map[string]interface{}{
						"sound":             "emergency_siren.caf",
						"content-available": 1,
					},
				},
			},
		},
	}

	bodyBytes, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	// Note: In real production, Google OAuth2 token is retrieved using google-api-go-client/oauth2
	fcmEndpoint := fmt.Sprintf("https://fcm.googleapis.com/v1/projects/%s/messages:send", s.projectID)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, fcmEndpoint, bytes.NewBuffer(bodyBytes))
	if err != nil {
		return err
	}

	req.Header.Set("Content-Type", "application/json")
	if s.apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+s.apiKey)
	}

	resp, err := s.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		return nil
	}

	if resp.StatusCode == http.StatusNotFound || resp.StatusCode == http.StatusBadRequest {
		return fmt.Errorf("UNREGISTERED: status %d", resp.StatusCode)
	}

	return fmt.Errorf("fcm server returned status %d", resp.StatusCode)
}

func isTokenInvalidError(err error) bool {
	if err == nil {
		return false
	}
	msg := strings.ToUpper(err.Error())
	return strings.Contains(msg, "UNREGISTERED") ||
		strings.Contains(msg, "INVALID_REGISTRATION") ||
		strings.Contains(msg, "INVALID_ARGUMENT") ||
		strings.Contains(msg, "NOT_FOUND")
}

// LoadFCMConfigFromEnv loads configuration without committing credentials
func LoadFCMConfigFromEnv() (string, string) {
	projectID := os.Getenv("FIREBASE_PROJECT_ID")
	apiKey := os.Getenv("FIREBASE_SERVER_KEY") // or Google SA token
	if projectID == "" {
		projectID = "mock"
	}
	return projectID, apiKey
}
