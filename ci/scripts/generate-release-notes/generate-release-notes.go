package main

import (
	"bufio"
	"bytes"
	"fmt"
	"github.com/blang/semver"
	"github.com/jessevdk/go-flags"
	"io"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

type command struct {
	DocsRepoDir    string   `long:"docs-dir" required:"true" description:"the path to the docs git repo"`
	PatchNotesPath []string `long:"patch-notes-path" description:"the path to the patch release notes. Will append all notes provided, in order."`
	PatchVersions  []string `long:"patch-versions" description:"a list patch versions to be released with their notes being --patch-notes-path"`
}

func main() {
	cmd := &command{}
	_, err := flags.Parse(cmd)
	if err != nil {
		log.Fatalf("could not create release notes: %s\n", err)
	}

	err = cmd.execute()
	if err != nil {
		log.Fatalf("could not create release notes: %s\n", err)
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

func (c *command) execute() error {
	releaseNotes, err := getReleaseNotes(c.DocsRepoDir)
	if err != nil {
		return fmt.Errorf("could not open relase notes: %s", err)
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
				fmt.Printf("could not create semver for %s: %s", version, err)
				continue
			}
			s := section{
				version: semverVersion,
				lines:   []string{string(line)},
			}
			sections = append(sections, s)

			minorVersion := strings.Join(strings.Split(version, ".")[0:2], ".")
			minorVersions[minorVersion] = true
		} else {
			sections = appendLineToLastSection(line, sections)
		}
	}

	if len(c.PatchNotesPath) > 0 {
		for _, versionNumber := range c.PatchVersions {
			version, err := semver.Parse(versionNumber)
			if err != nil {
				return fmt.Errorf("could not parse semver: %s", err)
			}

			for _, section := range sections {
				if section.version.Equals(version) {
					return fmt.Errorf("the version v%s already exists, cannot generate release notes", version)
				}
			}

			lines, err := c.createReleaseNoteLines(version)
			if err != nil {
				return err
			}

			sections = append(sections, section{
				version: version,
				lines:   lines,
			})
		}
	}

	sort.Slice(sections, func(i, j int) bool {
		return sections[j].version.LT(sections[i].version)
	})

	err, _ = runCommand(
		c.DocsRepoDir,
		"git", "checkout", "develop",
	)
	if err != nil {
		return fmt.Errorf("could not check develop: %s", err)
	}

	err = checkoutBranchForReleaseNotes(c.DocsRepoDir, "develop")
	if err != nil {
		return fmt.Errorf("could not checkout branch: %s", err)
	}

	err = generateReleaseNotes(c.DocsRepoDir, "10000.0", header, sections)
	if err != nil {
		return fmt.Errorf("could not generate release notes for %s: %s", "develop", err)
	}

	err = pushReleaseNotes(c.DocsRepoDir, "develop")
	if err != nil {
		return fmt.Errorf("could not push release notes for %s: %s", "develop", err)
	}

	for minorVersion, _ := range minorVersions {
		err = checkoutBranchForReleaseNotes(c.DocsRepoDir, fmt.Sprintf("v%s", minorVersion))
		if err != nil {
			return fmt.Errorf("could not checkout branch: %s", err)
		}

		err = generateReleaseNotes(c.DocsRepoDir, minorVersion, header, sections)
		if err != nil {
			return fmt.Errorf("could not generate release notes for %s: %s", minorVersion, err)
		}

		err = pushReleaseNotes(c.DocsRepoDir, minorVersion)
		if err != nil {
			return fmt.Errorf("could not push release notes for %s: %s", minorVersion, err)
		}
	}

	err, _ = runCommand(
		c.DocsRepoDir,
		"git", "checkout", "develop",
	)

	return err
}

func (c *command) createReleaseNoteLines(version semver.Version) ([]string, error) {
	releaseTimeLine := time.Now().Format("January 2, 2006")
	lines := []string{
		fmt.Sprintf(
			"## v%s\n%s\n",
			version.String(),
			releaseTimeLine,
		),
	}
	for _, patchNotesPath := range c.PatchNotesPath {
		rawContents, err := ioutil.ReadFile(patchNotesPath)
		contents := strings.TrimSuffix(string(rawContents), "\n")
		if err != nil {
			return nil, fmt.Errorf("could not read patch notes path: %s, %w", patchNotesPath, err)
		}
		lines = append(lines, strings.Split(contents, "\n")...)
	}
	
	lines = append(lines, "")
	return lines, nil
}

func appendLineToLastSection(line []byte, sections []section) []section {
	s := sections[len(sections)-1]
	s.lines = append(s.lines, string(line))
	sections[len(sections)-1] = s
	return sections
}

func runCommand(dir, cmd string, args ...string) (error, string) {
	ourStdout := &bytes.Buffer{}
	fmt.Printf("command: git %s\n", strings.Join(args, " "))

	command := exec.Command(cmd, args...)
	command.Dir = dir
	command.Stderr = os.Stderr
	command.Stdout = io.MultiWriter(os.Stdout, ourStdout)
	return command.Run(), ourStdout.String()
}

func getReleaseNotes(docsRepoDir string) ([]byte, error) {
	docsRepoDir, err := filepath.Abs(docsRepoDir)
	if err != nil {
		return []byte{}, err
	}

	if docsRepoDir == "" {
		return []byte{}, fmt.Errorf("please provide a --dir")
	}

	if info, err := os.Stat(docsRepoDir); err != nil || !info.IsDir() {
		return []byte{}, fmt.Errorf("the provided '%s' is not a directory", docsRepoDir)
	}

	releaseNotes, err := ioutil.ReadFile(filepath.Join(docsRepoDir, "docs", "release-notes.md"))
	if err != nil {
		return []byte{}, err
	}

	return releaseNotes, nil
}

func checkoutBranchForReleaseNotes(docsRepoDir, branchName string) error {
	err, _ := runCommand(
		docsRepoDir,
		"git", "checkout", branchName,
	)
	if err != nil {
		return fmt.Errorf("could not checkout %s: %s", branchName, err)
	}

	err, _ = runCommand(
		docsRepoDir,
		"git", "clean", "-ffd", "external", "||", "true",
	)
	if err != nil {
		return fmt.Errorf("could not remove external folder:  %s\n", err)
	}

	err, _ = runCommand(
		docsRepoDir,
		"git", "pull", "origin", branchName, "-r",
	)
	if err != nil {
		return fmt.Errorf("could not pull commits for %s: %s", branchName, err)
	}

	return nil
}

func generateReleaseNotes(docsRepoDir, minorVersion string, header []byte, sections []section) error {
	fmt.Printf("creating release notes for %s\n", minorVersion)
	releaseNotesFile, err := os.Create(filepath.Join(docsRepoDir, "docs", "release-notes.md"))
	if err != nil {
		return fmt.Errorf("could not create file for %s: %s", minorVersion, err)
	}

	semverMinorVersion, err := semver.Make(fmt.Sprintf("%s.999", minorVersion))
	if err != nil {
		return fmt.Errorf("could not create semver for %s: %s", minorVersion, err)
	}

	_, err = releaseNotesFile.Write(header)
	if err != nil {
		return fmt.Errorf("could write header: %s", err)
	}

	_, _ = releaseNotesFile.WriteString("\n")

	for _, section := range sections {
		compared := semverMinorVersion.Compare(section.version)

		if compared >= 0 {
			for _, line := range section.lines {
				_, _ = releaseNotesFile.WriteString(line)
				_, _ = releaseNotesFile.WriteString("\n")
			}
		}
	}

	err = releaseNotesFile.Close()
	if err != nil {
		return fmt.Errorf("could not close release note file: %s", err)
	}

	return nil
}

func pushReleaseNotes(docsRepoDir, minorVersion string) error {
	err, ourStdout := runCommand(
		docsRepoDir,
		"git", "status", "--porcelain",
	)
	if err != nil {
		return fmt.Errorf("could not checkout cleanly: %s", err)
	}

	if ourStdout != "" {
		err, _ := runCommand(
			docsRepoDir,
			"git", "commit", "-am", fmt.Sprintf("generated release notes %s", minorVersion),
		)
		if err != nil {
			return fmt.Errorf("could not commit %s: %s", minorVersion, err)
		}

		err, _ = runCommand(
			docsRepoDir,
			"git", "push",
		)

		if err != nil {
			return fmt.Errorf("could not push commit %s: %s", minorVersion, err)
		}
	}
	return nil
}
