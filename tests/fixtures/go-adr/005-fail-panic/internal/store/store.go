package store

func Get(k string) string {
	if k == "" {
		panic("empty key")
	}
	return k
}
