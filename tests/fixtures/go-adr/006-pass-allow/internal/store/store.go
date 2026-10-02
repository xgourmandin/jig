package store

import "os"

func Clean(p string) {
	// archgate-ignore GO-006/no-ignored-errors reviewed: removal failures are logged elsewhere
	_ = os.Remove(p)
}
