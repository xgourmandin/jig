package store

import "os"

func Clean(p string) {
	_ = os.Remove(p)
}
