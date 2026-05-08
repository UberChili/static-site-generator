package main

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

posts_directory_exists :: proc(cwd: string) -> (string, bool) {
    posts_dir := fmt.tprintf("%s%s", cwd, "/posts/")

    if !os.exists(posts_dir) || !os.is_directory(posts_dir) {
        fmt.eprintln("Not a directory or doesn't exist:", posts_dir)
        return "", false
    }

    return posts_dir, true
}

public_directory_exists_or_create :: proc(cwd: string) -> string {
    public_dir:= fmt.tprintf("%s%s", cwd, "/public/")

    if !os.exists(public_dir) {
        err := os.mkdir(public_dir)
        if err != nil {
            fmt.eprintln("Error creating public directory:", err)
            return ""
        }
        return public_dir
    } 
    fmt.eprintln("public directory found!")
    return public_dir
}