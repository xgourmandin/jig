package main

var version = "dev"

func init() { _ = version }

func main() {
	if version == "" {
		panic("no version")
	}
}
