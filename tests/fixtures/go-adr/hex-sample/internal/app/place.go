package app

import (
	"context"

	"example.com/svc/internal/domain"
	"example.com/svc/internal/ports"
)

type Place struct{ r ports.OrderRepository }

func (p Place) Do(ctx context.Context, o domain.Order) error { return p.r.Save(ctx, o) }
