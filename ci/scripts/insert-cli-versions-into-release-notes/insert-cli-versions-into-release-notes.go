package main

import (
	"bytes"
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"os"
)

func main() {

	if len(os.Args) <= 3 {
		log.Fatal("You must provide a path to the release notes, path to a version table, and a version number.")
	}

	releaseNotesFile := os.Args[1]
	versionTableFile := os.Args[2]
	version := os.Args[3]

	releaseNotes, err := ioutil.ReadFile(releaseNotesFile)
	if err != nil {
		log.Fatalf("Could not read release notes file: %s", err)
	}

	versionSeparator := []byte("## v" + version)
	separatorForTableInsertion := []byte("###")

	err = checkVersionExists(releaseNotes, versionSeparator)
	if err != nil {
		log.Fatalf("could not check versions exists: %s", err)
	}

	versionTable, err := ioutil.ReadFile(versionTableFile)
	if err != nil {
		log.Fatalf("Could not read version table file: %s", err)
	}


	notesSplitOnVersionSeparator := bytes.Split(releaseNotes, versionSeparator)

	targetVersionSectionBisected := bytes.SplitN(notesSplitOnVersionSeparator[1], separatorForTableInsertion, 2)

	err = checkVersionTableExists(targetVersionSectionBisected[0])
	if err!= nil {
		log.Fatalf("could not check versions table: %s", err)
	}

	injectVersionTableAndImage(targetVersionSectionBisected, versionTable, version)

	addBackTargetVersionHeaderSeparator(notesSplitOnVersionSeparator, targetVersionSectionBisected)

	newContents := addBackVersionSeparator(notesSplitOnVersionSeparator, versionSeparator)

	err = ioutil.WriteFile(os.Args[1], []byte(newContents), os.FileMode(0644))
	if err != nil {
		log.Fatalf("Could not write table to release notes: %s", err)
	}

	os.Exit(0)
}

func checkVersionExists(releaseNotes, versionSeparator []byte) error {
	if bytes.Contains(releaseNotes, versionSeparator) {
		return nil
	}
	return errors.New("the requested version is not present in the release notes")
}

func checkVersionTableExists(headerSection []byte) error {
	if bytes.Contains(headerSection, []byte("|--")) {
	 	return errors.New("the requested version already has a table in the release notes. Remove table or try a different version")
	}
	return nil
}

func injectVersionTableAndImage(targetVersionSectionBisected [][]byte, versionTable []byte, version string) {
	imageReceipt := fmt.Sprintf("    The full Docker image-receipt: <a href=\"https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-%s\" target=\"_blank\">Download</a>\n\n", version)
	targetVersionSectionBisected[0] = []byte(string(targetVersionSectionBisected[0]) + string(versionTable) + imageReceipt)
}

func addBackTargetVersionHeaderSeparator(notesSplitOnVersionSeparator, targetVersionSectionBisected [][]byte) {
	notesSplitOnVersionSeparator[1] = bytes.Join(targetVersionSectionBisected, []byte("###"))
}

func addBackVersionSeparator(notesSplitOnVersionSeparator [][]byte, versionSeparator []byte) []byte{
	return bytes.Join(notesSplitOnVersionSeparator, versionSeparator)
}
