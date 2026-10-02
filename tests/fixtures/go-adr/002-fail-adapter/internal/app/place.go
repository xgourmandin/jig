package app

import (
	"example.com/svc/internal/adapters/postgres"
	"example.com/svc/internal/domain"
)

type Place struct{ r *postgres.Repo; o domain.Order }
