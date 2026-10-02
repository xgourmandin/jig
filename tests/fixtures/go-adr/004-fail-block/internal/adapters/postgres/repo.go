package postgres

type (
	Repo struct{}
	Store interface{ Get() }
)
