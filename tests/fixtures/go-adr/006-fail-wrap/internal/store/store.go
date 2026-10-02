package store

import "fmt"

func Load(id string) error {
	err := do(id)
	if err != nil {
		return fmt.Errorf("load %s: %v", id, err)
	}
	return nil
}

func do(string) error { return nil }
