package ports

import "database/sql"

type Rows interface{ Scan(ctx context.Context) *sql.Rows }
