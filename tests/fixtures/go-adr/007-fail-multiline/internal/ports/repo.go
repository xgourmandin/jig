package ports

type Repository interface {
	List(
		id string,
	) error
}
