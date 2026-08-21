package main

import (
	"os"

	"github.com/alecthomas/kong"
)

func main() {
	ctx := kong.Parse(&CLI,
		kong.Name("tms"),
		kong.Description("Tmux Session Manager"),
		kong.UsageOnError(),
		kong.ConfigureHelp(kong.HelpOptions{
			Compact: true,
		}),
	)

	err := ctx.Run()
	if err != nil {
		os.Exit(1)
	}
}
