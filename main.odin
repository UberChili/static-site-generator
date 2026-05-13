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

    // Ensure required directories exist, or create
    posts := directory_exists_or_create(cwd, "/posts/")
    public := directory_exists_or_create(cwd, "/public/")
    static := directory_exists_or_create(cwd, "/static/")
    if public == "" || posts == "" || static == ""{
        os.exit(1)
    }

    // Getting files from posts directory
    files := get_md_files(posts)
    if files == nil {
        os.exit(1)
    }
    defer delete(files, context.temp_allocator)

    // Write simple HTML files to public directory
    for file in files {
        handle_file(file, public)
    }
}
