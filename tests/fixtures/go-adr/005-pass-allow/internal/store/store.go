package store

// archgate-ignore GO-005/no-global-mutable-state metrics registry is process-wide by design
var registry = map[string]int{}

func Must(err error) {
	if err != nil {
		// archgate-ignore GO-005/no-panic programmer error during start-up wiring
		panic(err)
	}
}
