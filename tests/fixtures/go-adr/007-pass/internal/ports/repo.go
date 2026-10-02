package ports

import (
	"context"
	"fmt"
)

type Repository interface {
	fmt.Stringer
	Save(ctx context.Context, id string) error
	Find(
		ctx context.Context,
		id string,
	) (string, error)
	Close(_ context.Context) error
	Drop(context.Context) error
}
