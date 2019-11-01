package main

import (
	"bufio"
	"bytes"
	"flag"
	"fmt"
	"github.com/blang/semver"
	"io"
	"io/ioutil"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

func main() {
	buildDir := flag.String("dir", "", "build directory to write release notes to")
	flag.Parse()

	err := execute(*buildDir)
	if err != nil {
		fmt.Printf("could not create release notes: %s\n", err)
		os.Exit(1)
	}
}

var (
	documentRegex = regexp.MustCompile("(?ms)(.*?)\n(##[^#].*)")
	sectionRegex  = regexp.MustCompile(`^##[^#]*v(.*?)$`)
)

type section struct {
	version semver.Version
	lines   []string
}

func execute(buildDir string) error {
	if buildDir == "" {
		return fmt.Errorf("please provide a --dir")
	}

	if info, err := os.Stat(buildDir); err != nil || !info.IsDir() {
		return fmt.Errorf("the provided '%s' is not a directory", buildDir)
	}

	releaseNotes, err := ioutil.ReadFile("../docs/release-notes.md")
	if err != nil {
		return err
	}

	documentMatches := documentRegex.FindSubmatch(releaseNotes)
	if len(documentMatches) == 0 {
		return fmt.Errorf("could not find header, regex did not match")
	}

	header := documentMatches[1]
	versionsMatched := documentMatches[2]
	sections := []section{}
	minorVersions := map[string]bool{}

	reader := bufio.NewReader(bytes.NewBuffer(versionsMatched))
	for {
		line, _, err := reader.ReadLine()
		if err == io.EOF {
			break
		}

		if err != nil {
			return fmt.Errorf("could not read lines from release notes: %s", err)
		}

		matches := sectionRegex.FindSubmatch(line)
		if len(matches) > 0 {
			version := string(matches[1])

			semverVersion, err := semver.Make(version)
			if err != nil {
				return fmt.Errorf("could not create semver for %s: %s", version, err)
			}
			s := section{
				version: semverVersion,
				lines:   []string{string(line)},
			}
			sections = append(sections, s)

			minorVersion := strings.Join(strings.Split(version, ".")[0:2], ".")
			minorVersions[minorVersion] = true
		} else {
			s := sections[len(sections)-1]
			s.lines = append(s.lines, string(line))
			sections[len(sections)-1] = s
		}
	}

	sort.Slice(sections, func(i, j int) bool {
		return sections[j].version.LT(sections[i].version)
	})

	for minorVersion, _ := range minorVersions {
		fmt.Printf("creating release notes for %s\n", minorVersion)
		notesFile, err := os.Create(filepath.Join(buildDir, fmt.Sprintf("%s.md", minorVersion)))
		if err != nil {
			return fmt.Errorf("could not create file for %s: %s", minorVersion, err)
		}

		semverMinorVersion, err := semver.Make(fmt.Sprintf("%s.999", minorVersion))
		if err != nil {
			return fmt.Errorf("could not create semver for %s: %s", minorVersion, err)
		}

		_, err = notesFile.Write(header)
		if err != nil {
			return fmt.Errorf("could write header: %s", err)
		}

		_, _ = notesFile.WriteString("\n")

		for _, section := range sections {
			compared := semverMinorVersion.Compare(section.version)

			if compared >= 0 {
				for _, line := range section.lines {
					_, _ = notesFile.WriteString(line)
					_, _ = notesFile.WriteString("\n")
				}
			}
		}

		err = notesFile.Close()
		if err != nil {
			return err
		}
	}

	return nil
}
