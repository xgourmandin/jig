package store

import "errors"

var (
	ErrMissing = errors.New("missing")
	counter    int
)
