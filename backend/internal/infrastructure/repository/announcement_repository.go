package repository

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"tetanggo-backend/internal/domain/entity"
)

type PostgresAnnouncementRepository struct {
	db *sql.DB
}

func NewPostgresAnnouncementRepository(db *sql.DB) *PostgresAnnouncementRepository {
	return &PostgresAnnouncementRepository{db: db}
}

func (r *PostgresAnnouncementRepository) GetAll(ctx context.Context, category string, search string) ([]entity.Announcement, error) {
	whereClauses := []string{"1=1"}
	args := []interface{}{}
	argIdx := 1

	if category != "" {
		whereClauses = append(whereClauses, fmt.Sprintf("a.category = $%d", argIdx))
		args = append(args, category)
		argIdx++
	}

	if search != "" {
		whereClauses = append(whereClauses, fmt.Sprintf("(a.title ILIKE $%d OR a.content ILIKE $%d)", argIdx, argIdx))
		args = append(args, "%"+search+"%")
		argIdx++
	}

	whereSQL := strings.Join(whereClauses, " AND ")

	query := fmt.Sprintf(`
		SELECT 
			a.id, a.title, a.content, a.category, a.image_url, a.is_pinned, a.author_id,
			COALESCE(u.name, 'Pengurus Cluster') AS author_name,
			a.created_at, a.updated_at
		FROM announcements a
		LEFT JOIN users u ON a.author_id = u.id
		WHERE %s
		ORDER BY a.is_pinned DESC, a.created_at DESC;
	`, whereSQL)

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed querying announcements: %w", err)
	}
	defer rows.Close()

	announcements := make([]entity.Announcement, 0)
	for rows.Next() {
		var a entity.Announcement
		err := rows.Scan(
			&a.ID,
			&a.Title,
			&a.Content,
			&a.Category,
			&a.ImageURL,
			&a.IsPinned,
			&a.AuthorID,
			&a.AuthorName,
			&a.CreatedAt,
			&a.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed scanning announcement: %w", err)
		}
		announcements = append(announcements, a)
	}

	return announcements, nil
}

func (r *PostgresAnnouncementRepository) GetByID(ctx context.Context, id int64) (*entity.Announcement, error) {
	query := `
		SELECT 
			a.id, a.title, a.content, a.category, a.image_url, a.is_pinned, a.author_id,
			COALESCE(u.name, 'Pengurus Cluster') AS author_name,
			a.created_at, a.updated_at
		FROM announcements a
		LEFT JOIN users u ON a.author_id = u.id
		WHERE a.id = $1;
	`
	var a entity.Announcement
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&a.ID,
		&a.Title,
		&a.Content,
		&a.Category,
		&a.ImageURL,
		&a.IsPinned,
		&a.AuthorID,
		&a.AuthorName,
		&a.CreatedAt,
		&a.UpdatedAt,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get announcement by id: %w", err)
	}
	return &a, nil
}

func (r *PostgresAnnouncementRepository) Create(ctx context.Context, a *entity.Announcement) error {
	query := `
		INSERT INTO announcements (title, content, category, image_url, is_pinned, author_id, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
		RETURNING id, created_at, updated_at;
	`
	return r.db.QueryRowContext(
		ctx,
		query,
		a.Title,
		a.Content,
		a.Category,
		a.ImageURL,
		a.IsPinned,
		a.AuthorID,
	).Scan(&a.ID, &a.CreatedAt, &a.UpdatedAt)
}

func (r *PostgresAnnouncementRepository) Update(ctx context.Context, a *entity.Announcement) error {
	query := `
		UPDATE announcements
		SET title = $1, content = $2, category = $3, image_url = COALESCE($4, image_url), is_pinned = $5, updated_at = NOW()
		WHERE id = $6;
	`
	res, err := r.db.ExecContext(ctx, query, a.Title, a.Content, a.Category, a.ImageURL, a.IsPinned, a.ID)
	if err != nil {
		return fmt.Errorf("failed to update announcement: %w", err)
	}
	rowsAff, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if rowsAff == 0 {
		return fmt.Errorf("pengumuman tidak ditemukan")
	}
	return nil
}

func (r *PostgresAnnouncementRepository) Delete(ctx context.Context, id int64) error {
	var imageURL sql.NullString
	checkQuery := `SELECT image_url FROM announcements WHERE id = $1;`
	err := r.db.QueryRowContext(ctx, checkQuery, id).Scan(&imageURL)
	if err != nil {
		if err == sql.ErrNoRows {
			return fmt.Errorf("pengumuman tidak ditemukan")
		}
		return fmt.Errorf("gagal memeriksa pengumuman: %w", err)
	}

	deleteQuery := `DELETE FROM announcements WHERE id = $1;`
	_, err = r.db.ExecContext(ctx, deleteQuery, id)
	if err != nil {
		return fmt.Errorf("gagal menghapus pengumuman: %w", err)
	}

	if imageURL.Valid && imageURL.String != "" {
		relPath := strings.TrimPrefix(imageURL.String, "/")
		_ = os.Remove(filepath.Clean(relPath))
	}

	return nil
}
