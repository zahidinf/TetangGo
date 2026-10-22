package announcement

import (
	"context"
	"fmt"
	"strings"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
)

type AnnouncementUseCase struct {
	announcementRepo repository.AnnouncementRepository
}

func NewAnnouncementUseCase(announcementRepo repository.AnnouncementRepository) *AnnouncementUseCase {
	return &AnnouncementUseCase{
		announcementRepo: announcementRepo,
	}
}

func (uc *AnnouncementUseCase) GetAll(ctx context.Context, category, search string) ([]entity.Announcement, error) {
	return uc.announcementRepo.GetAll(ctx, category, search)
}

func (uc *AnnouncementUseCase) GetByID(ctx context.Context, id int64) (*entity.Announcement, error) {
	return uc.announcementRepo.GetByID(ctx, id)
}

func (uc *AnnouncementUseCase) Create(ctx context.Context, a *entity.Announcement) error {
	a.Title = strings.TrimSpace(a.Title)
	a.Content = strings.TrimSpace(a.Content)

	if a.Title == "" {
		return fmt.Errorf("judul pengumuman wajib diisi")
	}
	if a.Content == "" {
		return fmt.Errorf("isi pengumuman wajib diisi")
	}
	if a.Category == "" {
		a.Category = "biasa"
	}
	if a.Category != "biasa" && a.Category != "penting" && a.Category != "darurat" {
		return fmt.Errorf("kategori pengumuman tidak valid")
	}

	return uc.announcementRepo.Create(ctx, a)
}

func (uc *AnnouncementUseCase) Update(ctx context.Context, a *entity.Announcement) error {
	a.Title = strings.TrimSpace(a.Title)
	a.Content = strings.TrimSpace(a.Content)

	if a.Title == "" {
		return fmt.Errorf("judul pengumuman wajib diisi")
	}
	if a.Content == "" {
		return fmt.Errorf("isi pengumuman wajib diisi")
	}
	if a.Category != "" && a.Category != "biasa" && a.Category != "penting" && a.Category != "darurat" {
		return fmt.Errorf("kategori pengumuman tidak valid")
	}

	return uc.announcementRepo.Update(ctx, a)
}

func (uc *AnnouncementUseCase) Delete(ctx context.Context, id int64) error {
	return uc.announcementRepo.Delete(ctx, id)
}
