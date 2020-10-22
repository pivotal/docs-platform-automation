package main

import (
	"io/ioutil"
	"os"
	"os/exec"
	"regexp"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gbytes"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("Insert cli versions into release notes script", func() {
	var (
		compiledPath string
	)

	BeforeEach(func() {
		var err error
		compiledPath, err = gexec.Build("insert-cli-versions-into-release-notes.go")
		Expect(err).NotTo(HaveOccurred())
	})

	When("improper number of arguments are provided", func() {
		It("gives an error saying a path to the release notes file, version table, and version number are required", func() {
			command := exec.Command(compiledPath, "release-notes.md", "versionTable.md")
			session, err := gexec.Start(command, GinkgoWriter, GinkgoWriter)

			Expect(err).NotTo(HaveOccurred())
			Eventually(session).Should(gexec.Exit(1))
			Expect(session.Err).To(gbytes.Say(regexp.QuoteMeta("You must provide a path to the release notes, path to a version table, and a version number.")))
		})
	})

	When("valid release notes, version table, and versions args are provided", func() {
		var (
			releaseNotesFile *os.File
			releaseNotesMD   string
			versionTableFile *os.File
			versionTableMD   string
			versionArg       string
		)

		BeforeEach(func() {
			var err error
			releaseNotesMD = `# Example Release Notes

## v1.3.0
Released Today

### New Features

- has a feature!

### Bug Fixes
etc

## v1.2.3
Released in the Past

??? "CLI Versions"

    | tool | version |   |   |   |
    |------|---------|---|---|---|
    | om   | v1.0.0  |   |   |   |
    |      |         |   |   |   |
    |      |         |   |   |   |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-1.2.3" target="_blank">Download</a>

### Bug Fixes
etc  unrelated version test 999.99.9

## v1.1.4
Released in History Times

We had om at version 0.57 back then man.

### Security Fixes
etc
`
			releaseNotesFile, err = ioutil.TempFile("", "release-notes-*.md")
			Expect(err).NotTo(HaveOccurred())
			err = ioutil.WriteFile(releaseNotesFile.Name(), []byte(releaseNotesMD), os.FileMode(0644))
			Expect(err).NotTo(HaveOccurred())

			versionTableMD = `??? "CLI Versions"

    | tool | version |   |   |   |
    |------|---------|---|---|---|
    | om   | v2.0.0  |   |   |   |
    |      |         |   |   |   |
    |      |         |   |   |   |

`
			versionTableFile, err = ioutil.TempFile("", "cli-versions-*.md")
			err = ioutil.WriteFile(versionTableFile.Name(), []byte(versionTableMD), os.FileMode(0644))
			Expect(err).NotTo(HaveOccurred())

			versionArg = "1.3.0"

		})

		It("updates the specified version entry with the table, adds image receipt link, and exits 0", func() {
			command := exec.Command(compiledPath, releaseNotesFile.Name(), versionTableFile.Name(), versionArg)

			expectedReleaseNotesMD := `# Example Release Notes

## v1.3.0
Released Today

??? "CLI Versions"

    | tool | version |   |   |   |
    |------|---------|---|---|---|
    | om   | v2.0.0  |   |   |   |
    |      |         |   |   |   |
    |      |         |   |   |   |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-1.3.0" target="_blank">Download</a>

### New Features

- has a feature!

### Bug Fixes
etc

## v1.2.3
Released in the Past

??? "CLI Versions"

    | tool | version |   |   |   |
    |------|---------|---|---|---|
    | om   | v1.0.0  |   |   |   |
    |      |         |   |   |   |
    |      |         |   |   |   |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-1.2.3" target="_blank">Download</a>

### Bug Fixes
etc  unrelated version test 999.99.9

## v1.1.4
Released in History Times

We had om at version 0.57 back then man.

### Security Fixes
etc
`
			session, err := gexec.Start(command, GinkgoWriter, GinkgoWriter)
			Expect(err).NotTo(HaveOccurred())

			Eventually(session).Should(gexec.Exit(0))

			contents, err := ioutil.ReadFile(releaseNotesFile.Name())
			Expect(err).NotTo(HaveOccurred())

			Expect(string(contents)).To(BeEquivalentTo(expectedReleaseNotesMD))
		})

		When("Version passed is not present in release notes", func() {
			It("gives an error saying that version is not there", func() {
				versionArg = "999.99.9"
				command := exec.Command(compiledPath, releaseNotesFile.Name(), versionTableFile.Name(), versionArg)

				session, err := gexec.Start(command, GinkgoWriter, GinkgoWriter)


				Expect(err).NotTo(HaveOccurred())
				Eventually(session).Should(gexec.Exit(1))
				Expect(session.Err).To(gbytes.Say(regexp.QuoteMeta("the requested version is not present in the release notes")))
			})
		})

		When("Version passed already has a table", func() {
			It("gives an error saying that version has a table already", func() {
				versionArg = "1.2.3"
				command := exec.Command(compiledPath, releaseNotesFile.Name(), versionTableFile.Name(), versionArg)

				session, err := gexec.Start(command, GinkgoWriter, GinkgoWriter)


				Expect(err).NotTo(HaveOccurred())
				Eventually(session).Should(gexec.Exit(1))
				Expect(session.Err).To(gbytes.Say(regexp.QuoteMeta("the requested version already has a table in the release notes. Remove table or try a different version")))
			})
		})
	})

})
