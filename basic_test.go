package tests

import (
	"testing"
)

func TestBasic(t *testing.T) {
	t.Log("Basic test running")
	if 1+1 != 2 {
		t.Fatal("Math is broken")
	}
	t.Log("Basic test passed")
}
