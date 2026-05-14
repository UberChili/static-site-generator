package main

import "core:slice"
import "core:os"
import "core:fmt"


main :: proc() {
    cwd, err := os.get_working_directory(context.temp_allocator)
    if err != nil {
        fmt.eprintln("Error with current working directory:", err)
        os.exit(1)
    }
    defer delete(cwd, context.temp_allocator)

    // Posts dynamic array
    posts_arr := [dynamic]Post{}
    defer delete(posts_arr)

    // Ensure required directories exist, or create
    posts := directory_exists_or_create(cwd, "/posts/")
    public := directory_exists_or_create(cwd, "/public/")
    public_static := directory_exists_or_create(cwd, "/public/static")
    static := directory_exists_or_create(cwd, "/static/")
    if public == "" || posts == "" || static == ""{
        os.exit(1)
    }

    // Copy static into public
    copy_err := os.copy_directory_all(public_static, static)
    if copy_err != nil {
        fmt.println("Error copying %q to %q", static, public)
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
        handle_file(file, public, &posts_arr)
    }

    // Sorting Posts
    slice.sort_by(posts_arr[:], proc(a, b: Post) -> bool {
        return a.date > b.date
    })
    // Building post list
    post_list := build_post_list(posts_arr[:])
    // Loading index template
    handle_index(post_list)

}
