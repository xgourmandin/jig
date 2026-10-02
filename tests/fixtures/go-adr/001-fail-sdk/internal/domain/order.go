package domain

import (
	"context"
	gormdb "gorm.io/gorm"
)

type Order struct{ db *gormdb.DB; ctx context.Context }
