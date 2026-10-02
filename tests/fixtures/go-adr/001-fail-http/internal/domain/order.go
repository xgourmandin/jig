package domain

import (
	"fmt"
	"net/http"
)

func Status() string { return fmt.Sprint(http.StatusOK) }
