package domain

import (
	"context"
	"errors"
	"time"
)

// Do not import "net/http" or "database/sql" here.
var ErrEmpty = errors.New("import \"database/sql\" is a string")

type Order struct{ At time.Time }

func (o Order) Check(ctx context.Context) error { return ctx.Err() }
