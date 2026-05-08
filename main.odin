package main

import "core:os"
import "core:fmt"


main :: proc() {
    cwd, err := os.get_working_directory(context.temp_allocator)
    if err != nil {
        fmt.eprintln("Error with current working directory:", err)
        os.exit(1)
    }
    defer delete(cwd, context.temp_allocator)

    // Ensure posts directory exists
    posts_dir, exists := posts_directory_exists(cwd)
    if !exists {
        os.exit(1)
    }

    // Ensure public directory exists, or create
    public := public_directory_exists_or_create(cwd)
    if public == "" {
        os.exit(1)
    }

    // Getting files from posts directory
    files := get_md_files(posts_dir)
    if files == nil {
        os.exit(1)
    }
    defer delete(files, context.temp_allocator)

    // Write simple HTML files to public directory
    for file in files {
        handle_file(file, public)
    }
}
