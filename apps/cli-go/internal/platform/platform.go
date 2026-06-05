package platform

import (
	"os"
	"os/exec"
	"os/user"
	"runtime"
	"strings"
)

type Info struct {
	OS         string `json:"os"`
	Arch       string `json:"arch"`
	User       string `json:"user"`
	IsElevated bool   `json:"isElevated"`
}

func Current() Info {
	name := "unknown"
	if u, err := user.Current(); err == nil && u.Username != "" {
		name = u.Username
	}
	return Info{OS: runtime.GOOS, Arch: runtime.GOARCH, User: name, IsElevated: IsElevated()}
}

func IsElevated() bool {
	if runtime.GOOS != "windows" {
		return os.Geteuid() == 0
	}
	cmd := exec.Command(
		"powershell",
		"-NoProfile",
		"-Command",
		"([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)",
	)
	out, err := cmd.Output()
	if err != nil {
		return false
	}
	return strings.EqualFold(strings.TrimSpace(string(out)), "true")
}
