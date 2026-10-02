package store

import "fmt"

func Load(id string, err error) error {
	return fmt.Errorf(
		"load %s: %v",
		id,
		err,
	)
}
