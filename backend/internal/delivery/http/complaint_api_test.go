package http_test

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	nethttp "net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	delivery "tetanggo-backend/internal/delivery/http"
	"tetanggo-backend/internal/delivery/http/handler"
	"tetanggo-backend/internal/delivery/http/middleware"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/usecase/auth"
	"tetanggo-backend/internal/usecase/complaint"
)

// Mock Repositories for Complaint HTTP test
type httpComplaintMockRepo struct {
	complaints   map[int64]*entity.Complaint
	byTicket     map[string]*entity.Complaint
	assignments  map[int64][]entity.ComplaintAssignment
	nextID       int64
	nextAssignID int64
}

func newHTTPComplaintMockRepo() *httpComplaintMockRepo {
	return &httpComplaintMockRepo{
		complaints:   make(map[int64]*entity.Complaint),
		byTicket:     make(map[string]*entity.Complaint),
		assignments:  make(map[int64][]entity.ComplaintAssignment),
		nextID:       1,
		nextAssignID: 1,
	}
}

func (m *httpComplaintMockRepo) Create(ctx context.Context, c *entity.Complaint) error {
	c.ID = m.nextID
	m.nextID++
	c.CreatedAt = time.Now()
	c.UpdatedAt = time.Now()
	cp := *c
	m.complaints[c.ID] = &cp
	m.byTicket[c.TicketNumber] = &cp
	return nil
}

func (m *httpComplaintMockRepo) GetByID(ctx context.Context, id int64) (*entity.Complaint, error) {
	if c, ok := m.complaints[id]; ok {
		cp := *c
		return &cp, nil
	}
	return nil, nil
}

func (m *httpComplaintMockRepo) GetByTicketNumber(ctx context.Context, ticket string) (*entity.Complaint, error) {
	if c, ok := m.byTicket[ticket]; ok {
		cp := *c
		return &cp, nil
	}
	return nil, nil
}

func (m *httpComplaintMockRepo) GetByPhotoFilename(ctx context.Context, filename string) (*entity.Complaint, error) {
	for _, c := range m.complaints {
		if c.PhotoURL != nil && strings.Contains(*c.PhotoURL, filename) {
			cp := *c
			return &cp, nil
		}
	}
	return nil, nil
}

func (m *httpComplaintMockRepo) ListByUser(ctx context.Context, userID int64, limit, offset int) ([]entity.Complaint, int, error) {
	var userComps []entity.Complaint
	for _, c := range m.complaints {
		if c.UserID == userID {
			userComps = append(userComps, *c)
		}
	}
	total := len(userComps)
	if offset >= total {
		return []entity.Complaint{}, total, nil
	}
	end := offset + limit
	if end > total {
		end = total
	}
	return userComps[offset:end], total, nil
}

func (m *httpComplaintMockRepo) ListAdmin(ctx context.Context, filter entity.AdminComplaintFilter) ([]entity.Complaint, int, error) {
	var list []entity.Complaint
	for _, c := range m.complaints {
		if filter.Status != "" && string(c.Status) != filter.Status {
			continue
		}
		if filter.Category != "" && string(c.Category) != filter.Category {
			continue
		}
		if filter.Officer != "" && (c.AssignedOfficer == nil || !strings.Contains(*c.AssignedOfficer, filter.Officer)) {
			continue
		}
		if filter.Search != "" && !strings.Contains(c.Title, filter.Search) && !strings.Contains(c.Description, filter.Search) && !strings.Contains(c.TicketNumber, filter.Search) {
			continue
		}
		list = append(list, *c)
	}
	total := len(list)
	if filter.Limit <= 0 {
		filter.Limit = 10
	}
	offset := (filter.Page - 1) * filter.Limit
	if offset < 0 {
		offset = 0
	}
	if offset >= total {
		return []entity.Complaint{}, total, nil
	}
	end := offset + filter.Limit
	if end > total {
		end = total
	}
	return list[offset:end], total, nil
}

func (m *httpComplaintMockRepo) GetKanban(ctx context.Context, filter entity.AdminComplaintFilter) (*entity.KanbanComplaintsResult, error) {
	res := &entity.KanbanComplaintsResult{
		Menunggu: make([]entity.Complaint, 0),
		Diproses: make([]entity.Complaint, 0),
		Selesai:  make([]entity.Complaint, 0),
		Counts: map[string]int{
			"Menunggu": 0,
			"Diproses": 0,
			"Selesai":  0,
			"Ditolak":  0,
		},
	}
	for _, c := range m.complaints {
		res.Counts[string(c.Status)]++
		switch c.Status {
		case entity.ComplaintStatusMenunggu:
			res.Menunggu = append(res.Menunggu, *c)
		case entity.ComplaintStatusDiproses:
			res.Diproses = append(res.Diproses, *c)
		case entity.ComplaintStatusSelesai:
			res.Selesai = append(res.Selesai, *c)
		}
	}
	return res, nil
}

func (m *httpComplaintMockRepo) AssignOfficer(ctx context.Context, assignment *entity.ComplaintAssignment, newStatus *string) error {
	assignment.ID = m.nextAssignID
	m.nextAssignID++
	assignment.CreatedAt = time.Now()
	m.assignments[assignment.ComplaintID] = append([]entity.ComplaintAssignment{*assignment}, m.assignments[assignment.ComplaintID]...)

	if c, ok := m.complaints[assignment.ComplaintID]; ok {
		c.AssignedOfficer = &assignment.OfficerName
		c.AssignedOfficerID = assignment.OfficerUserID
		c.AssignedAt = &assignment.AssignedAt
		if newStatus != nil && *newStatus != "" {
			c.Status = entity.ComplaintStatus(*newStatus)
		}
	}
	return nil
}

func (m *httpComplaintMockRepo) UpdateStatus(ctx context.Context, id int64, status entity.ComplaintStatus) error {
	if c, ok := m.complaints[id]; ok {
		c.Status = status
		c.UpdatedAt = time.Now()
		return nil
	}
	return errors.New("complaint not found")
}

func (m *httpComplaintMockRepo) GetAssignmentsByComplaintID(ctx context.Context, complaintID int64) ([]entity.ComplaintAssignment, error) {
	return m.assignments[complaintID], nil
}

func TestComplaintAPI_E2E(t *testing.T) {
	houseID := int64(10)
	uRepo := &httpMockUserRepo{
		users: map[int64]*entity.User{
			1: {
				ID:      1,
				Name:    "Warga Boni",
				Status:  string(entity.UserStatusActive),
				HouseID: &houseID,
				House:   &entity.House{ID: 10, Block: "B1", HouseNumber: "01"},
			},
			2: {
				ID:      2,
				Name:    "Warga Martha",
				Status:  string(entity.UserStatusActive),
				HouseID: &houseID,
				House:   &entity.House{ID: 10, Block: "B1", HouseNumber: "02"},
			},
			3: {
				ID:      3,
				Name:    "Satpam Joni",
				Status:  string(entity.UserStatusActive),
				HouseID: nil,
			},
			4: {
				ID:     4,
				Name:   "Admin Pengelola",
				Status: string(entity.UserStatusActive),
			},
			5: {
				ID:     5,
				Name:   "Ketua Lingkungan",
				Status: string(entity.UserStatusActive),
			},
		},
	}
	cRepo := newHTTPComplaintMockRepo()
	hRepo := &httpMockHouseRepo{}
	cUC := complaint.NewComplaintUseCase(cRepo, uRepo, hRepo)

	tokenService := auth.NewTokenService("test_secret_key_1234567890123456", 60, 7)
	authMiddleware := middleware.NewAuthMiddleware(tokenService, uRepo)

	appHandler := handler.NewAppHandler(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
	appHandler.SetComplaintUseCase(cUC)

	app := delivery.SetupRouter(appHandler, authMiddleware)

	// Tokens
	tokenUser1, _, err := tokenService.GenerateTokenPair(1, "boni@tetanggo.id", "RESIDENT")
	if err != nil {
		t.Fatal(err)
	}
	tokenUser2, _, err := tokenService.GenerateTokenPair(2, "martha@tetanggo.id", "RESIDENT")
	if err != nil {
		t.Fatal(err)
	}
	tokenSecurity, _, err := tokenService.GenerateTokenPair(3, "security@tetanggo.id", "SECURITY")
	if err != nil {
		t.Fatal(err)
	}
	tokenAdmin, _, err := tokenService.GenerateTokenPair(4, "admin@tetanggo.id", "ADMIN")
	if err != nil {
		t.Fatal(err)
	}
	tokenChairperson, _, err := tokenService.GenerateTokenPair(5, "ketua@tetanggo.id", "CHAIRPERSON")
	if err != nil {
		t.Fatal(err)
	}

	// 1. Satpam without house tries to create complaint -> 403 Forbidden
	{
		body := &bytes.Buffer{}
		writer := multipart.NewWriter(body)
		_ = writer.WriteField("title", "Lampu Jalan Mati")
		_ = writer.WriteField("description", "Tiang 4 mati total")
		_ = writer.WriteField("category", "Lampu Jalan")
		_ = writer.Close()

		req := httptest.NewRequest("POST", "/api/v1/complaints", body)
		req.Header.Set("Authorization", "Bearer "+tokenSecurity)
		req.Header.Set("Content-Type", writer.FormDataContentType())

		resp, err := app.Test(req)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != nethttp.StatusForbidden {
			t.Errorf("expected Satpam without house to get 403, got %d", resp.StatusCode)
		}
	}

	// 2. User 1 creates complaint with valid image
	var complaint1ID int64
	var photoURLUser1 string
	{
		body := &bytes.Buffer{}
		writer := multipart.NewWriter(body)
		_ = writer.WriteField("title", "Lampu Jalan Mati di Blok B1")
		_ = writer.WriteField("description", "Lampu jalan depan rumah B1/01 padam sejak kemarin malam")
		_ = writer.WriteField("category", "Lampu Jalan")

		// Create mock JPEG file
		part, _ := writer.CreateFormFile("photo", "lampu.jpg")
		// Valid JPEG magic header 0xFF, 0xD8, 0xFF
		_, _ = part.Write([]byte{0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01})
		_ = writer.Close()

		req := httptest.NewRequest("POST", "/api/v1/complaints", body)
		req.Header.Set("Authorization", "Bearer "+tokenUser1)
		req.Header.Set("Content-Type", writer.FormDataContentType())

		resp, err := app.Test(req)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != nethttp.StatusCreated {
			respBody, _ := io.ReadAll(resp.Body)
			t.Fatalf("expected 201 Created, got %d: %s", resp.StatusCode, string(respBody))
		}

		var res struct {
			Success bool `json:"success"`
			Data    struct {
				ID           int64  `json:"id"`
				TicketNumber string `json:"ticket_number"`
				Category     string `json:"category"`
				Status       string `json:"status"`
				PhotoURL     string `json:"photo_url"`
			} `json:"data"`
		}
		_ = json.NewDecoder(resp.Body).Decode(&res)
		if !res.Success || res.Data.ID == 0 {
			t.Fatalf("expected success with valid ID, got %+v", res)
		}
		if !strings.HasPrefix(res.Data.TicketNumber, "TKT-") {
			t.Errorf("expected ticket format TKT-, got %s", res.Data.TicketNumber)
		}
		if res.Data.Status != "Menunggu" {
			t.Errorf("expected status Menunggu, got %s", res.Data.Status)
		}
		if !strings.HasPrefix(res.Data.PhotoURL, "/api/v1/complaints/photo/") {
			t.Errorf("expected protected photo URL, got %s", res.Data.PhotoURL)
		}
		complaint1ID = res.Data.ID
		photoURLUser1 = res.Data.PhotoURL
	}

	// 3. Invalid category rejection -> 400 Bad Request
	{
		body := &bytes.Buffer{}
		writer := multipart.NewWriter(body)
		_ = writer.WriteField("title", "Kebisingan Tetangga")
		_ = writer.WriteField("description", "Musik terlalu keras tengah malam")
		_ = writer.WriteField("category", "KategoriPalsu")
		_ = writer.Close()

		req := httptest.NewRequest("POST", "/api/v1/complaints", body)
		req.Header.Set("Authorization", "Bearer "+tokenUser1)
		req.Header.Set("Content-Type", writer.FormDataContentType())

		resp, err := app.Test(req)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != nethttp.StatusBadRequest {
			t.Errorf("expected 400 for invalid category, got %d", resp.StatusCode)
		}
	}

	// 4. Invalid file content (fake image extension with non-image bytes) -> 400 Bad Request
	{
		body := &bytes.Buffer{}
		writer := multipart.NewWriter(body)
		_ = writer.WriteField("title", "Sampah Menumpuk")
		_ = writer.WriteField("description", "Tempat sampah TPS penuh")
		_ = writer.WriteField("category", "Sampah")

		part, _ := writer.CreateFormFile("photo", "fake.jpg")
		_, _ = part.Write([]byte("THIS IS NOT AN IMAGE CONTENT BUT TEXT"))
		_ = writer.Close()

		req := httptest.NewRequest("POST", "/api/v1/complaints", body)
		req.Header.Set("Authorization", "Bearer "+tokenUser1)
		req.Header.Set("Content-Type", writer.FormDataContentType())

		resp, err := app.Test(req)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != nethttp.StatusBadRequest {
			t.Errorf("expected 400 for fake image content, got %d", resp.StatusCode)
		}
	}

	// 5. User 1 gets their complaints list -> 200 OK with 1 item
	{
		req := httptest.NewRequest("GET", "/api/v1/complaints", nil)
		req.Header.Set("Authorization", "Bearer "+tokenUser1)

		resp, err := app.Test(req)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != nethttp.StatusOK {
			t.Errorf("expected 200 OK, got %d", resp.StatusCode)
		}
		var res struct {
			Data []entity.Complaint `json:"data"`
			Meta struct {
				Total int `json:"total"`
			} `json:"meta"`
		}
		_ = json.NewDecoder(resp.Body).Decode(&res)
		if res.Meta.Total != 1 || len(res.Data) != 1 {
			t.Errorf("expected 1 complaint for User 1, got total=%d len=%d", res.Meta.Total, len(res.Data))
		}
	}

	// 6. User 2 gets their complaints list -> 200 OK with 0 items
	{
		req := httptest.NewRequest("GET", "/api/v1/complaints", nil)
		req.Header.Set("Authorization", "Bearer "+tokenUser2)

		resp, err := app.Test(req)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != nethttp.StatusOK {
			t.Errorf("expected 200 OK, got %d", resp.StatusCode)
		}
		var res struct {
			Data []entity.Complaint `json:"data"`
			Meta struct {
				Total int `json:"total"`
			} `json:"meta"`
		}
		_ = json.NewDecoder(resp.Body).Decode(&res)
		if res.Meta.Total != 0 || len(res.Data) != 0 {
			t.Errorf("expected 0 complaints for User 2, got total=%d len=%d", res.Meta.Total, len(res.Data))
		}
	}

	// 7. User 2 tries to access User 1 complaint detail -> 403 Forbidden
	{
		url := fmt.Sprintf("/api/v1/complaints/%d", complaint1ID)
		req := httptest.NewRequest("GET", url, nil)
		req.Header.Set("Authorization", "Bearer "+tokenUser2)

		resp, err := app.Test(req)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != nethttp.StatusForbidden {
			t.Errorf("expected 403 Forbidden when accessing another resident's complaint, got %d", resp.StatusCode)
		}
	}

	// 8. User 1 accesses their own complaint photo -> 200 OK
	{
		req := httptest.NewRequest("GET", photoURLUser1, nil)
		req.Header.Set("Authorization", "Bearer "+tokenUser1)

		resp, err := app.Test(req)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != nethttp.StatusOK {
			t.Errorf("expected 200 OK when owner accesses complaint photo, got %d", resp.StatusCode)
		}
	}

	// 9. User 2 tries to access User 1 complaint photo -> 403 Forbidden
	{
		req := httptest.NewRequest("GET", photoURLUser1, nil)
		req.Header.Set("Authorization", "Bearer "+tokenUser2)

		resp, err := app.Test(req)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != nethttp.StatusForbidden {
			t.Errorf("expected 403 Forbidden when another resident accesses photo, got %d", resp.StatusCode)
		}
	}

	// 10. Anonymous user accesses photo -> 401 Unauthorized
	{
		req := httptest.NewRequest("GET", photoURLUser1, nil)

		resp, err := app.Test(req)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != nethttp.StatusUnauthorized {
			t.Errorf("expected 401 Unauthorized for unauthenticated photo request, got %d", resp.StatusCode)
		}
	}

	// 11. Non-existent photo -> 404 Not Found
	{
		req := httptest.NewRequest("GET", "/api/v1/complaints/photo/non-existent-image.jpg", nil)
		req.Header.Set("Authorization", "Bearer "+tokenUser1)

		resp, err := app.Test(req)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != nethttp.StatusNotFound {
			t.Errorf("expected 404 Not Found for non-existent photo, got %d", resp.StatusCode)
		}
	}

	// 12. Direct static access to /uploads/complaints/ is denied (403 Forbidden)
	{
		req := httptest.NewRequest("GET", "/uploads/complaints/test.jpg", nil)

		resp, err := app.Test(req)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != nethttp.StatusForbidden {
			t.Errorf("expected 403 Forbidden for direct /uploads/complaints access, got %d", resp.StatusCode)
		}
	}

	// 13. Admin lists complaints -> 200 OK
	{
		req := httptest.NewRequest("GET", "/api/v1/admin/complaints", nil)
		req.Header.Set("Authorization", "Bearer "+tokenAdmin)

		resp, err := app.Test(req)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != nethttp.StatusOK {
			t.Errorf("expected 200 OK for admin list complaints, got %d", resp.StatusCode)
		}
	}

	// 14. Warga denied from /api/v1/admin/complaints -> 403 Forbidden
	{
		req := httptest.NewRequest("GET", "/api/v1/admin/complaints", nil)
		req.Header.Set("Authorization", "Bearer "+tokenUser1)

		resp, err := app.Test(req)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != nethttp.StatusForbidden {
			t.Errorf("expected 403 Forbidden when resident accesses admin complaints, got %d", resp.StatusCode)
		}
	}

	// 15. Admin gets Kanban board -> 200 OK
	{
		req := httptest.NewRequest("GET", "/api/v1/admin/complaints/kanban", nil)
		req.Header.Set("Authorization", "Bearer "+tokenAdmin)

		resp, err := app.Test(req)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != nethttp.StatusOK {
			t.Errorf("expected 200 OK for kanban, got %d", resp.StatusCode)
		}
	}

	// 16. Chairperson assigns officer to complaint -> 200 OK
	{
		assignBody := map[string]interface{}{
			"officer_name": "Pak Joko (Teknisi)",
			"notes":        "Tolong cek sekring",
			"status":       "Diproses",
		}
		raw, _ := json.Marshal(assignBody)
		url := fmt.Sprintf("/api/v1/admin/complaints/%d/assign", complaint1ID)
		req := httptest.NewRequest("POST", url, bytes.NewBuffer(raw))
		req.Header.Set("Authorization", "Bearer "+tokenChairperson)
		req.Header.Set("Content-Type", "application/json")

		resp, err := app.Test(req)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != nethttp.StatusOK {
			body, _ := io.ReadAll(resp.Body)
			t.Fatalf("expected 200 OK for assign officer, got %d: %s", resp.StatusCode, string(body))
		}
	}

	// 17. Reassign officer -> 200 OK and preserves history
	{
		assignBody := map[string]interface{}{
			"officer_name": "Pak Budi (Teknisi 2)",
			"notes":        "Penggantian teknisi",
		}
		raw, _ := json.Marshal(assignBody)
		url := fmt.Sprintf("/api/v1/admin/complaints/%d/assign", complaint1ID)
		req := httptest.NewRequest("POST", url, bytes.NewBuffer(raw))
		req.Header.Set("Authorization", "Bearer "+tokenAdmin)
		req.Header.Set("Content-Type", "application/json")

		resp, err := app.Test(req)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != nethttp.StatusOK {
			t.Errorf("expected 200 OK for reassign officer, got %d", resp.StatusCode)
		}
	}

	// 18. Admin updates status to Selesai -> 200 OK
	{
		statusBody := map[string]interface{}{
			"status": "Selesai",
		}
		raw, _ := json.Marshal(statusBody)
		url := fmt.Sprintf("/api/v1/admin/complaints/%d/status", complaint1ID)
		req := httptest.NewRequest("PATCH", url, bytes.NewBuffer(raw))
		req.Header.Set("Authorization", "Bearer "+tokenAdmin)
		req.Header.Set("Content-Type", "application/json")

		resp, err := app.Test(req)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != nethttp.StatusOK {
			t.Errorf("expected 200 OK for update status, got %d", resp.StatusCode)
		}
	}

	// 19. Warga denied from assigning officer -> 403 Forbidden
	{
		assignBody := map[string]interface{}{
			"officer_name": "Pak Ilegal",
		}
		raw, _ := json.Marshal(assignBody)
		url := fmt.Sprintf("/api/v1/admin/complaints/%d/assign", complaint1ID)
		req := httptest.NewRequest("POST", url, bytes.NewBuffer(raw))
		req.Header.Set("Authorization", "Bearer "+tokenUser1)
		req.Header.Set("Content-Type", "application/json")

		resp, err := app.Test(req)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != nethttp.StatusForbidden {
			t.Errorf("expected 403 Forbidden when resident attempts assignment, got %d", resp.StatusCode)
		}
	}

	// 20. Admin gets assignment history -> 200 OK
	{
		url := fmt.Sprintf("/api/v1/admin/complaints/%d/assignments", complaint1ID)
		req := httptest.NewRequest("GET", url, nil)
		req.Header.Set("Authorization", "Bearer "+tokenAdmin)

		resp, err := app.Test(req)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != nethttp.StatusOK {
			t.Errorf("expected 200 OK for assignment history, got %d", resp.StatusCode)
		}
	}
}
