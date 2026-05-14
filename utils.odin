package main

import "core:strings"
import "core:fmt"
import "core:os"

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

get_md_files :: proc(path: string) -> []os.File_Info {
    if !os.exists(path) {
        fmt.eprintfln("Path doesn't exist", path)
        return nil
    }

    files, err := os.read_directory_by_path(path, 0, context.temp_allocator)
    if err != nil {
        fmt.eprintln("Error reading files from path", path, "with error:", err)
        return nil
    }
    return files
}

directory_exists_or_create :: proc(cwd: string, subdir: string) -> string {
    directory := fmt.tprintf("%s%s", cwd, subdir)

    if !os.exists(directory) {
        err := os.mkdir(directory)
        if err != nil {
            fmt.eprintfln("Error creating %q directory:", subdir, err)
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
