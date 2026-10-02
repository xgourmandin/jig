package server

// archgate-ignore GO-008/composition-root-in-cmd temporary until wiring moves to cmd/worker
import "example.com/svc/internal/adapters/postgres"

var _ = postgres.X
