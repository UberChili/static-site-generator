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

get_md_files :: proc(path: string, files_da: ^[dynamic]os.File_Info) {
    if !os.exists(path) {
        fmt.eprintfln("Path doesn't exist:", path)
        return 
    }

    /* files, err := os.read_directory_by_path(path, 0, context.temp_allocator) */
    /* if err != nil { */
    /*     fmt.eprintln("Error reading files from path", path, "with error:", err) */
    /*     return nil */
    /* } */
    /* return files */

    // Need to change this to us some form of walk
    // Because we now have subdirectories in the main "content" directory
    w := os.walker_create(path)
    defer os.walker_destroy(&w)

    for info in os.walker_walk(&w) {
        if info.type == .Regular && strings.ends_with(info.name, ".md"){
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
