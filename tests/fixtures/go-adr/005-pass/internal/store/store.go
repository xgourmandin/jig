package store

import (
	_ "embed"
	"errors"
	"regexp"
)

var ErrMissing = errors.New("missing")
var errClosed = errors.New("closed")
var _ Getter = (*Store)(nil)

var (
	idRe = regexp.MustCompile(`^[a-z]+$`)
	_    = idRe
)

//go:embed schema.sql
var schema string

type Getter interface{ Get(k string) string }
type Store struct{ m map[string]string }

func New() *Store { return &Store{m: map[string]string{}} }

// panic(x) in a comment and "panic(x)" in a string are fine; so is a method called panicky(.
func (s *Store) Get(k string) string { _ = errClosed; return "panic(" + s.m[k] }
