package ports

import (
	"context"

	"example.com/svc/internal/domain"
)

type OrderRepository interface {
	Save(ctx context.Context, o domain.Order) error
}
