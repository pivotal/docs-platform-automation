package docs_test

import (
	"io/ioutil"
	"path"
	"path/filepath"
	"strings"

	"fmt"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("Documentation coverage", func() {
	Context("Tasks doc", func() {
		It("Mentions every task we distribute", func() {
			tasks := getTaskNames()
			taskDoc := readFile("../docs/tasks.md")

			for _, task := range tasks {
				Expect(taskDoc).To(
					MatchRegexp(fmt.Sprintf("# %s", task)),
					fmt.Sprintf("task reference should have %s\n", task),
				)

				Expect(taskDoc).To(
					MatchRegexp(fmt.Sprintf(`=== "Task"\n\s+---excerpt--- "tasks/%s"`, task)),
					fmt.Sprintf("task reference should have %s task tab\n", task),
				)

				Expect(taskDoc).To(
					MatchRegexp(fmt.Sprintf(`=== "Implementation"\n\s+---excerpt--- "tasks/%s-script"`, task)),
					fmt.Sprintf("task reference should have %s Implementation tab\n", task),
				)

				Expect(taskDoc).To(
					MatchRegexp(fmt.Sprintf(`=== ".*Usage"\n\s+---excerpt--- "(reference|examples)/%s.*usage"`, task)),
					fmt.Sprintf("task reference should have %s Usage tab\n", task),
				)
			}
		})
	})
})

var _ = Describe("Task format", func() {
	It("should have `om vm-lifecycle` and subcommand-name in the same line", func() {
		tasksDir := "../tasks"
		taskFiles, err := ioutil.ReadDir(tasksDir)
		Expect(err).ToNot(HaveOccurred())

		for _, taskFile := range taskFiles {
			if taskFile.IsDir() {
				continue
			}
			taskContents, err := ioutil.ReadFile(filepath.Join(tasksDir, taskFile.Name()))
			Expect(err).ToNot(HaveOccurred())
			Expect(string(taskContents)).ToNot(
				ContainSubstring(`om vm-lifecycle \`),
				"Commands should be on the same line as the binary invocation",
			)
		}
	})
})

func readFile(docName string) (docContents string) {
	docPath, err := filepath.Abs(docName)
	Expect(err).ToNot(HaveOccurred())
	docContentsBytes, err := ioutil.ReadFile(docPath)
	docContents = string(docContentsBytes)
	Expect(err).ToNot(HaveOccurred())
	return docContents
}

func getTaskNames() (tasks []string) {
	taskListRaw, err := filepath.Glob("../tasks/*.yml")
	Expect(err).ToNot(HaveOccurred())
	Expect(len(taskListRaw)).ToNot(BeZero())
	for _, task := range taskListRaw {
		task = strings.TrimSuffix(path.Base(task), filepath.Ext(task))
		tasks = append(tasks, task)
	}
	Expect(tasks).ToNot(BeNil())
	return tasks
}
