package main

import "core:strings"
import "core:path/filepath"
import "core:os"
import "core:log"
import "core:fmt"

import cm "vendor:commonmark"

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

// Reads a file, parses to html and writes to disk
handle_file :: proc(filename: os.File_Info, directory: string) {
    // Sanity checks
    if !os.exists(filename.fullpath) {
        fmt.eprintfln("File %v does not exist. Ignoring...", filename.fullpath)
        return
    }
    if !strings.ends_with(filename.fullpath, ".md") {
        fmt.eprintfln("File %v is not a markdown file. Ignoring...", filename.fullpath)
        return
    }

    // parsing the name to name the new html file on disk
    md_filename, err := strings.split(filename.fullpath, "/")
    if err != nil {
        fmt.eprintln("Error splitting filename:", filename.fullpath)
        os.exit(1)
    }
    defer delete(md_filename)

    only_filename := strings.trim_suffix(md_filename[len(md_filename) - 1], ".md")

    new_file := fmt.tprintf("%s%s.html", directory, only_filename)

    // Reading file and parsing markdown
    fmt.printfln("[Parsing] %s into %s", filename.fullpath, new_file)
    data := read_file(filename.fullpath)
    root := cm.parse_document(raw_data(data), len(data), cm.DEFAULT_OPTIONS)
    defer cm.node_free(root)

    html := cm.render_html(root, cm.DEFAULT_OPTIONS)
    defer cm.free(html)

    // Writing html contents to file
    fmt.printfln("[Writing] %s into public/", new_file)
    write_err := os.write_entire_file_from_string(new_file, string(html))
    if write_err != nil {
        fmt.eprintln("Error when writing to file:", filename.fullpath)
        return
    }
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
