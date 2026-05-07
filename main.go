package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
)

func main() {
	fmt.Println("Hello there")

	filename := "example.md"
	fmt.Println("Reading file", filename)

	for _, line := range ReadFile(filename) {
		fmt.Print(line)
	}
}

func ReadFile(filepath string) []string {
	if filepath == "" {
		log.Fatal("Filename can't be empty")
	}

	file, err := os.Open(filepath)
	if err != nil {
		log.Fatal("Could not open file", filepath, err)
	}
	defer file.Close()

	result := []string{}

	scanner := bufio.NewScanner(file)

	for scanner.Scan() {
		result = append(result, scanner.Text())
	}

	if err := scanner.Err(); err != nil {
		log.Fatal(err)
	}
	return result
}
