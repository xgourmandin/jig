package store

import (
	"fmt"
	"os"
)

func Load(id string, err error) error {
	if id == "" {
		return fmt.Errorf("empty id")
	}
	if err != nil {
		return fmt.Errorf("load %s: %w", id, err)
	}
	return fmt.Errorf("load %s: %s", id, "error text with \"err\" in a string")
}

func Clean(p string) {
	_ = os.Remove(p) // best effort, temp file
	// the file may be gone already
	_ = os.Remove(p + ".lock")
}
