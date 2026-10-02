package postgres

import "context"

type client interface {
	Exec(ctx context.Context, q string) error
}

type Repo struct{ c client }

// type Fake interface {
const doc = "type Public interface {"
