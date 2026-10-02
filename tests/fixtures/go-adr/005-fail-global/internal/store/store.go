package store

var cache = map[string]string{}

func Get(k string) string { return cache[k] }
