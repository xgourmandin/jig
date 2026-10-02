package ports

import "context"

type Repository interface {
	Save(ctx context.Context) error
}
