package main

import (
	"fmt"
	"gopkg.in/yaml.v2"
	"io/ioutil"
	"os"
	"path/filepath"
	"text/template"
)

type folder struct {
	Name       string
	Contents   string
	SubFolders []*folder
	SubFiles   []*file
}

type file struct {
	Name     string
	Contents string
}

type readme struct {
	FolderContents string            `yaml:"folder"`
	FileContents   map[string]string `yaml:"files"`
}

func main() {
	folders := map[string]*folder{}

	directory := filepath.Join(os.Getenv("HOME"), "/workspace/telmore/environments")
	//directory := "/Users/pivotal/workspace/docs-platform-automation/src/structure"
	err := filepath.Walk(directory, func(path string, info os.FileInfo, err error) error {
		if info.IsDir() {
			f, ok := folders[path]
			if !ok {
				f = &folder{
					Name: filepath.Base(path),
				}
			}
			folders[path] = f
		} else {
			f, ok := folders[filepath.Dir(path)]
			if ok {
				if filepath.Base(path) == "meta.yml" {
					contents, err := ioutil.ReadFile(path)
					if err != nil {
						panic(fmt.Sprintf("file failed to be read (%s): %s", path, err))
					}

					var readmeContents readme
					err = yaml.UnmarshalStrict(contents, &readmeContents)
					if err != nil {
						panic(fmt.Sprintf("file failed to be unmarshaled (%s): %s", path, err))
					}

					if readmeContents.FolderContents != "" {
						f.Contents = readmeContents.FolderContents
					}

					if len(readmeContents.FileContents) != 0 {
						for fileName, fileContent := range readmeContents.FileContents {
							var found bool
							for ind, file := range f.SubFiles {
								if file.Name == fileName {
									found = true
									file.Contents = fileContent
								}

								f.SubFiles[ind] = file
							}

							if !found {
								f.SubFiles = append(f.SubFiles, &file{
									Name:     fileName,
									Contents: fileContent,
								})
							}
						}
					}
				} else {
					var found bool
					for _, file := range f.SubFiles {
						if file.Name == filepath.Base(path) {
							found = true
						}
					}

					if !found {
						f.SubFiles = append(f.SubFiles, &file{Name: filepath.Base(path)})
					}
				}
				folders[filepath.Dir(path)] = f
			}
		}
		return nil
	})

	if err != nil {
		panic(err)
	}

	for path, f := range folders {
		parentKey := filepath.Dir(path)
		parentFolder, ok := folders[parentKey]
		if ok {
			parentFolder.SubFolders = append(parentFolder.SubFolders, f)
			folders[parentKey] = parentFolder
		}
	}

	root := folders[directory]

	templateStr, err := ioutil.ReadFile("template.gohtml")
	if err != nil {
		panic(fmt.Sprintf("template file failed to be read: %s", err))
	}

	index := 0
	tmpl, err := template.New("test").Funcs(template.FuncMap{
		"inc": func() int {
			index++
			return index
		},
	}).Parse(string(templateStr))
	if err != nil {
		panic(fmt.Sprintf("template failed to be parsed: %s", err))
	}

	err = tmpl.Execute(os.Stdout, root)
	if err != nil {
		panic(fmt.Sprintf("template failed to be executed: %s", err))
	}
}
