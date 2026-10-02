package domain

import (
	// archgate-ignore GO-001/domain-is-pure
	"os"
)

var _ = os.Getpid
