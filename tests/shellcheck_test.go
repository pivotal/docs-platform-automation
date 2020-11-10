package docs_test

import (
	"os/exec"
	"path/filepath"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("With each task", func() {
	It("should have bash that passed `shellcheck`", func() {
		tasks, err := filepath.Glob("../tasks/*.sh")
		Expect(err).ToNot(HaveOccurred())
		Expect(len(tasks)).To(BeNumerically(">", 0))

		for _, filename := range tasks {
			command := exec.Command("shellcheck", "-s", "bash", "-x", "-a", filename)
			command.Dir, err = filepath.Abs("../tasks")
			Expect(err).ToNot(HaveOccurred())
			session, err := gexec.Start(command, GinkgoWriter, GinkgoWriter)
			Expect(err).ToNot(HaveOccurred())
			Eventually(session, 5).Should(gexec.Exit(0))
		}
	})
})
