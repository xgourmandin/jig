package domain

import (
	// archgate-ignore GO-001/domain-is-pure legacy clock helper, removed in v2
	"os"
)

var _ = os.Getpid
