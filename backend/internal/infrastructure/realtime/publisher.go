package realtime

import (
	"context"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
)

type RealtimeEventPublisher struct {
	hub *Hub
}

func NewRealtimeEventPublisher(hub *Hub) repository.IncidentEventPublisher {
	return &RealtimeEventPublisher{hub: hub}
}

func (p *RealtimeEventPublisher) PublishIncidentEvent(ctx context.Context, event entity.IncidentRealtimeEvent) error {
	if p.hub != nil {
		p.hub.Broadcast(event)
	}
	return nil
}
