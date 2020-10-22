package main_test

import (
	"fmt"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gbytes"
	"github.com/onsi/gomega/gexec"
	"io/ioutil"
	"os"
	"os/exec"
	"time"
)

var _ = Describe("GenerateReleaseNotes", func() {
	var (
		compiledPath string
		repo         *git
		upstreamRepo *git
	)

	BeforeEach(func() {
		var err error
		compiledPath, err = gexec.Build("generate-release-notes.go")
		Expect(err).NotTo(HaveOccurred())

		repo, err = initGitRepo()
		Expect(err).NotTo(HaveOccurred())

		upstreamRepo, err = newGitRepo()
		Expect(err).NotTo(HaveOccurred())

		err = repo.run("remote", "add", "origin", upstreamRepo.dir)
		Expect(err).NotTo(HaveOccurred())

		err = repo.write("docs/release-notes.md", stableReleaseNotes)
		Expect(err).NotTo(HaveOccurred())

		err = repo.run("add", "-A")
		Expect(err).NotTo(HaveOccurred())

		err = repo.run("commit", "-m", "init")
		Expect(err).NotTo(HaveOccurred())

		err = repo.createBranches("v1.0", "v2.0")
		Expect(err).NotTo(HaveOccurred())

		upstreamRepo.run("clone", "--bare", repo.dir, upstreamRepo.dir)
	})

	When("generating release notes for previous versions", func() {
		It("create the release notes from `develop`", func() {
			command := exec.Command(compiledPath, "--docs-dir", repo.dir)
			session, err := gexec.Start(command, GinkgoWriter, GinkgoWriter)
			Expect(err).NotTo(HaveOccurred())
			Eventually(session).Should(gexec.Exit(0))

			By("keeping all the release notes on develop")
			notes, err := repo.readFileFrom("develop", "docs/release-notes.md")
			Expect(err).NotTo(HaveOccurred())
			Expect(notes).To(Equal(stableReleaseNotes))

			By("having only v1.0 release notes on the v1.0 branch")
			notes, err = repo.readFileFrom("v1.0", "docs/release-notes.md")
			Expect(err).NotTo(HaveOccurred())
			Expect(notes).To(ContainSubstring("Header!!!"))
			Expect(notes).To(ContainSubstring("## v1.0.0"))
			Expect(notes).To(ContainSubstring("- Feature message 1."))
			Expect(notes).ToNot(ContainSubstring("## v2.0.0"))
			Expect(notes).ToNot(ContainSubstring("- Fixes message 1."))

			By("having v2.0 an v1.0 release notes on the v2.0 branch")
			notes, err = repo.readFileFrom("v2.0", "docs/release-notes.md")
			Expect(err).NotTo(HaveOccurred())
			Expect(notes).To(ContainSubstring("Header!!!"))
			Expect(notes).To(ContainSubstring("## v1.0.0"))
			Expect(notes).To(ContainSubstring("- Feature message 1."))
			Expect(notes).To(ContainSubstring("## v2.0.0"))
			Expect(notes).To(ContainSubstring("- Fixes message 1."))
		})
	})

	When("automatically adding release notes", func() {
		When("the release notes have been previously generated", func() {
			It("errors with a helpful message", func() {
				err := repo.write("docs/release-notes.md", stableReleaseNotes + "\n\n## v1.0.1")
				Expect(err).NotTo(HaveOccurred())

				err = repo.run("add", "-A")
				Expect(err).NotTo(HaveOccurred())

				err = repo.run("commit", "-m", "init")
				Expect(err).NotTo(HaveOccurred())

				patchNotesFile, err := ioutil.TempFile("", "")
				Expect(err).NotTo(HaveOccurred())

				err = ioutil.WriteFile(patchNotesFile.Name(), []byte(patchNotes), os.ModePerm)
				Expect(err).NotTo(HaveOccurred())

				command := exec.Command(compiledPath,
					"--docs-dir", repo.dir,
					"--patch-notes-path", patchNotesFile.Name(),
					"--patch-versions", "1.0.1",
				)
				session, err := gexec.Start(command, GinkgoWriter, GinkgoWriter)
				Expect(err).NotTo(HaveOccurred())
				Eventually(session).Should(gexec.Exit(1))
				Expect(session.Err).To(gbytes.Say("the version v1.0.1 already exists, cannot generate release notes"))
			})
		})

		It("adds the notes in the correct place based on semver", func() {
			patchNotesFile, err := ioutil.TempFile("", "")
			Expect(err).NotTo(HaveOccurred())
			additionalPatchNotesFile, err := ioutil.TempFile("", "")
			Expect(err).NotTo(HaveOccurred())

			err = ioutil.WriteFile(patchNotesFile.Name(), []byte(patchNotes), os.ModePerm)
			Expect(err).NotTo(HaveOccurred())
			err = ioutil.WriteFile(additionalPatchNotesFile.Name(), []byte(additionalPatchNotes), os.ModePerm)
			Expect(err).NotTo(HaveOccurred())

			command := exec.Command(compiledPath,
				"--docs-dir", repo.dir,
				"--patch-notes-path", patchNotesFile.Name(),
				"--patch-notes-path", additionalPatchNotesFile.Name(),
				"--patch-versions", "1.0.1",
				"--patch-versions", "2.0.1",
			)
			session, err := gexec.Start(command, GinkgoWriter, GinkgoWriter)
			Expect(err).NotTo(HaveOccurred())
			Eventually(session).Should(gexec.Exit(0))

			By("keeping all the release notes on develop")
			notes, err := repo.readFileFrom("develop", "docs/release-notes.md")
			Expect(err).NotTo(HaveOccurred())
			Expect(notes).To(ContainSubstring(expectedReleaseNotesWithPatches))

			By("having only v1.0 release notes on the v1.0 branch")
			notes, err = repo.readFileFrom("v1.0", "docs/release-notes.md")
			Expect(err).NotTo(HaveOccurred())
			Expect(notes).To(ContainSubstring("Header!!!"))
			Expect(notes).To(ContainSubstring("## v1.0.0"))
			Expect(notes).To(ContainSubstring("- Feature message 1."))
			Expect(notes).ToNot(ContainSubstring("## v2.0.0"))
			Expect(notes).ToNot(ContainSubstring("- Fixes message 1."))
			Expect(notes).To(ContainSubstring("## v1.0.1"))
			Expect(notes).To(ContainSubstring("- We did it! All fixed!"))
			Expect(notes).To(ContainSubstring("- additonal note, another thing fixed!"))
			Expect(notes).To(ContainSubstring("- We just like to fix all the things"))

			By("having v2.0 an v1.0 release notes on the v2.0 branch")
			notes, err = repo.readFileFrom("v2.0", "docs/release-notes.md")
			Expect(err).NotTo(HaveOccurred())
			Expect(notes).To(ContainSubstring("Header!!!"))
			Expect(notes).To(ContainSubstring("## v1.0.0"))
			Expect(notes).To(ContainSubstring("- Feature message 1."))
			Expect(notes).To(ContainSubstring("## v2.0.0"))
			Expect(notes).To(ContainSubstring("- Fixes message 1."))
			Expect(notes).To(ContainSubstring("## v1.0.1"))
			Expect(notes).To(ContainSubstring("- We did it! All fixed!"))
		})
	})
})

const patchNotes = `### Fixes
- We did it! All fixed!
`

const additionalPatchNotes = `- additonal note, another thing fixed!
- We just like to fix all the things
`

var expectedReleaseNotesWithPatches = fmt.Sprintf(`
Header!!!

## v2.0.1
%s

### Fixes
- We did it! All fixed!
- additonal note, another thing fixed!
- We just like to fix all the things

## v2.0.0

### Fixes
- Fixes message 1.
- Fixes message 2.

## v1.0.1
%s

### Fixes
- We did it! All fixed!
- additonal note, another thing fixed!
- We just like to fix all the things

## v1.0.0

### Features
- Feature message 1.
- Feature message 2.
`, time.Now().Format("January 2, 2006"), time.Now().Format("January 2, 2006"))

const stableReleaseNotes = `
Header!!!

## v2.0.0

### Fixes
- Fixes message 1.
- Fixes message 2.

## v1.0.0

### Features
- Feature message 1.
- Feature message 2.
`
