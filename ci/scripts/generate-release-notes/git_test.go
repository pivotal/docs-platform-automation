package main_test

import (
	"fmt"
	. "github.com/onsi/ginkgo"
	"github.com/onsi/gomega/gexec"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

type git struct {
	dir string
}

func newGitRepo() (*git, error) {
	dir, err := ioutil.TempDir("", "")
	if err != nil {
		return nil, err
	}

	repo := &git{dir: dir}
	return repo, nil
}

func initGitRepo() (*git, error) {
	repo, err := newGitRepo()
	if err != nil {
		return nil, err
	}

	err = repo.run("init", "--initial-branch", "develop")
	if err != nil {
		return nil, err
	}

	err = repo.run("commit", "--allow-empty", "-m", "init")
	if err != nil {
		return nil, err
	}

	return repo, nil
}

func (g *git) write(filename string, contents string) error {
	fullPath := filepath.Join(g.dir, filename)

	docsDir := filepath.Dir(fullPath)
	err := os.MkdirAll(docsDir, os.ModePerm)
	if err != nil {
		return err
	}

	return ioutil.WriteFile(fullPath, []byte(contents), os.ModePerm)
}

func (g *git) run(args ...string) error {
	command := exec.Command("git", args...)
	command.Dir = g.dir
	session, err := gexec.Start(command, GinkgoWriter, GinkgoWriter)
	if err != nil {
		return err
	}
	session.Wait()
	errCode := session.ExitCode()
	if errCode == 0 {
		return nil
	}

	return fmt.Errorf("could not command 'git %s' with exit code %d", strings.Join(args, " "), errCode)
}

func (g *git) createBranches(names ...string) error {
	for _, name := range names {
		err := g.run("checkout", "-b", name)
		if err != nil {
			return err
		}
		err = g.run("commit", "--allow-empty", "-m", "init")
		if err != nil {
			return err
		}
	}

	return g.run("checkout", "develop")
}

func (g *git) readFileFrom(branch string, filename string) (string, error) {
	err := g.run("checkout", branch)
	if err != nil {
		return "", err
	}

	contents, err := ioutil.ReadFile(filepath.Join(g.dir, filename))
	if err != nil {
		return "", err
	}

	return string(contents), nil
}
