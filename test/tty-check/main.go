//go:build linux || darwin

// tty-check replicates the exact TTY gate devbox uses before installing Nix
// (internal/nix/install.go: isatty.IsTerminal(os.Stdout.Fd())), plus the
// blocking fmt.Scanln() call that follows when the gate is open.
//
// It lets us verify locally that a given invocation strategy prevents the
// process from hanging without needing a real devbox binary or Nix install.
//
// Observed behaviour
// ------------------
//   go run . | cat        stdout→pipe → stdoutIsTerminal()=false → no prompt
//   go run . </dev/null   stdin→EOF  → stdoutIsTerminal() may be true, but
//                          fmt.Scanln() returns immediately; subprocess stdin
//                          is also /dev/null so no child can block either
//
// The second invocation is the approach used in devbox-on-create.sh because
// it additionally ensures that the nix-installer subprocess (which devbox
// spawns with cmd.Stdin = os.Stdin) also receives /dev/null and cannot block
// waiting for interactive input.
package main

import (
	"fmt"
	"os"

	"golang.org/x/term"
)

// stdoutIsTerminal replicates devbox's isatty.IsTerminal(os.Stdout.Fd()).
// Uses golang.org/x/term so that non-terminal character devices such as
// /dev/null are not misreported as interactive terminals.
func stdoutIsTerminal() bool {
	return term.IsTerminal(int(os.Stdout.Fd()))
}

func main() {
	if stdoutIsTerminal() {
		// Replicates the exact code path from devbox internal/nix/install.go:
		//   fmt.Println("Press enter to continue or ctrl-c to exit.")
		//   fmt.Scanln()
		fmt.Fprintln(os.Stderr, "[tty-check] stdout is a TTY → devbox would print prompt and call fmt.Scanln()")
		fmt.Scanln() //nolint:errcheck – reads from os.Stdin; EOF returns immediately
		fmt.Fprintln(os.Stderr, "[tty-check] Scanln returned (stdin was EOF or user pressed Enter)")
	} else {
		fmt.Fprintln(os.Stderr, "[tty-check] stdout is NOT a TTY → devbox skips the prompt entirely")
	}
	fmt.Fprintln(os.Stderr, "[tty-check] exit 0 — install would continue")
}
