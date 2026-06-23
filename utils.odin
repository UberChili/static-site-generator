package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

// reads a file as bytes
read_file :: proc(filename: string) -> []byte {
	if filename == "" {
		fmt.eprintln("Filename can't be empty. Ignoring")
		return nil
	}

	data, err := os.read_entire_file(filename, context.temp_allocator)
	if err != nil {
		fmt.eprintln("Could not open file", filename, "Ignoring because:", err)
		return nil
	}
	return data
}

// Gets all files from a directory, most commonly "content"
get_md_files :: proc(path: string, files_da: ^[dynamic]os.File_Info) {
	if !os.exists(path) {
		fmt.eprintfln("Path to look for content doesn't exist:", path)
		return
	}

	// Need to change this to us some form of walk
	// Because we now have subdirectories in the main "content" directory
	w := os.walker_create(path)
	defer os.walker_destroy(&w)

	for info in os.walker_walk(&w) {
		if info.type == .Regular && strings.ends_with(info.name, ".md") {
			// Clone the fileinfo so it survives after walker is destroyed
			cloned, err := os.file_info_clone(info, context.temp_allocator)
			if err != nil {
				fmt.eprintfln("Error cloning file %#v", info)
				return
			}
			append(files_da, cloned)
		}
	}
}

directory_exists_or_create :: proc(cwd: string, subdir: string) -> string {
	directory, err := filepath.join({cwd, subdir})
	if err != nil {
		fmt.eprintfln("Error joining path: %s, %s", cwd, subdir)
		fmt.eprintln("No directory created")
		return ""
	}

	if !os.exists(directory) {
		mkdir_err := os.mkdir(directory)
		if mkdir_err != nil {
			fmt.eprintfln("Error creating %q directory: %s", directory, err)
			return ""
		}
	}
	return directory
}

slugify :: proc(original: string) -> string {
	lowered, _ := strings.to_lower(original, context.temp_allocator)
	no_spaces, _ := strings.replace_all(lowered, " ", "-", context.temp_allocator)
	no_underscores, _ := strings.replace_all(no_spaces, "_", "-", context.temp_allocator)
	return no_underscores
}
