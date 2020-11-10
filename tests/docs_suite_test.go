package docs_test

import (
	"testing"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

func TestDocstest(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Docstest Suite")
}
