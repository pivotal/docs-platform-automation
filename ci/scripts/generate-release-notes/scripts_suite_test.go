package main_test

import (
	"github.com/onsi/gomega/gexec"
	"testing"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

func TestScripts(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Generate Release Notes Suite")
}

var _ = AfterSuite(func(){
	gexec.CleanupBuildArtifacts()
})
