package calc

import (
	"errors"
	"testing"
)

func TestAdd(t *testing.T) {
	if got := Add(2, 3); got != 5 {
		t.Fatalf("Add(2, 3) = %d, want 5", got)
	}
}

func TestDiv(t *testing.T) {
	if got, err := Div(6, 3); err != nil || got != 2 {
		t.Fatalf("Div(6, 3) = %d, %v, want 2, nil", got, err)
	}
	if _, err := Div(1, 0); !errors.Is(err, ErrDivByZero) {
		t.Fatalf("Div(1, 0) error = %v, want ErrDivByZero", err)
	}
}
