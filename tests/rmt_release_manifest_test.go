package docs_test

import (
	"io/ioutil"
	"path/filepath"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("RMT release manifest template", func() {
	It("derives docs_link from the release version instead of a hardcoded host or version", func() {
		templatePath, err := filepath.Abs("../ci/tasks/templates/pa-release.yml.template")
		Expect(err).ToNot(HaveOccurred())

		contents, err := ioutil.ReadFile(templatePath)
		Expect(err).ToNot(HaveOccurred())

		Expect(string(contents)).To(
			MatchRegexp(`(?m)^docs_link: https://techdocs\.broadcom\.com/us/en/vmware-tanzu/platform/platform-automation-toolkit-for-tanzu/\$\{DOC_VERSION\}/vmware-automation-toolkit/docs-release-notes\.html$`),
			"docs_link must be templated from ${DOC_VERSION}, not a hardcoded host/version (see TNZ-124437)",
		)

		Expect(string(contents)).ToNot(
			ContainSubstring("docs.vmware.com"),
			"docs_link must not point at the retired docs.vmware.com host (see TNZ-124437)",
		)
	})
})

var _ = Describe("Pivnet-release metadata generators", func() {
	for _, taskFile := range []string{
		"../ci/tasks/pivnet-release/generate-platform-automation-metadata-bump.yml",
		"../ci/tasks/pivnet-release/generate-platform-automation-metadata-v5.1.yml",
	} {
		taskFile := taskFile
		It("derives release_notes_url from the release version in "+taskFile, func() {
			path, err := filepath.Abs(taskFile)
			Expect(err).ToNot(HaveOccurred())

			contents, err := ioutil.ReadFile(path)
			Expect(err).ToNot(HaveOccurred())

			Expect(string(contents)).To(
				MatchRegexp(`release_notes_url: "https://techdocs\.broadcom\.com/us/en/vmware-tanzu/platform/platform-automation-toolkit-for-tanzu/\$\{TECHDOCS_VERSION\}/vmware-automation-toolkit/docs-release-notes\.html"`),
				"release_notes_url must be templated from ${TECHDOCS_VERSION}, not a hardcoded host/version (see TNZ-124437)",
			)

			Expect(string(contents)).ToNot(
				ContainSubstring("docs.pivotal.io"),
				"release_notes_url must not point at the retired docs.pivotal.io host (see TNZ-124437)",
			)
		})
	}
})
