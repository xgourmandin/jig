package http

import (
	"example.com/svc/internal/adapters/http/internal/render"
	"example.com/svc/internal/app"
	"example.com/svc/internal/domain"
	"example.com/svc/internal/ports"
)

var _ = render.X
var _ app.Place
var _ domain.Order
var _ ports.OrderRepository
