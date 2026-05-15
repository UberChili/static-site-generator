package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"

import cm "vendor:commonmark"

Frontmatter :: struct {
    title: string,
    author: string,
    date: string,
    type: string
}

Post :: struct {
    title: string,
    date: string,
    url: string,
}

// Parses the frontmatter/archetype
parse_frontmatter :: proc(filename: os.File_Info, data: []byte) -> (Frontmatter, string) {
    text := string(data)

    if !strings.starts_with(text, "---") {
        fmt.eprintln("Found no valid frontmatter in file. Or another error")
        return Frontmatter{}, ""
    }
    text = text[3:] 
    frontmatter_end_text := "---\n"

    frontmatter_end := strings.index(text, frontmatter_end_text)
    if frontmatter_end < 0 {
        frontmatter_end_text = "---\r\n" 
        frontmatter_end = strings.index(text,  frontmatter_end_text)
    }
    if frontmatter_end < 0 {
        fmt.eprintln("Missing pair of --- for frontmatter for %q", filename.fullpath)
    }

    closing_end := frontmatter_end + len(frontmatter_end_text) // skip the "---\n" or the "---\r\n"
    body := strings.trim_space(text[closing_end:])

    fm_text := strings.trim_space(text[:frontmatter_end])
    frontmatter: Frontmatter
    unm_err := json.unmarshal_string(fm_text, &frontmatter, .JSON5, context.temp_allocator)
    if unm_err != nil {
        fmt.eprintln("Error when unmarshaling frontmatter for %q", filename.fullpath)
        return Frontmatter{}, ""
    }
    return frontmatter, strings.trim_space(body)
}

// Reads a file, parses to html and writes to disk
handle_file :: proc(filename: os.File_Info, directory: string, array: ^[dynamic]Post) {
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

    only_filename := slugify(strings.trim_suffix(md_filename[len(md_filename) - 1], ".md"))

    new_file := fmt.tprintf("%s%s.html", directory, only_filename)

    // Getting frontmatter and data without frontmatter
    frontmatter, data_without_frontmatter := parse_frontmatter(filename, read_file(filename.fullpath))

    // Filling Post struct and appending to array, only if current file is a post
    if frontmatter.type == "post" {
        slug := fmt.tprintf("%s.html", only_filename)
        post := Post{
            title = frontmatter.title,
            date = frontmatter.date,
            url = fmt.tprintf("%s.html", only_filename)}
        append(array, post)
    }

    // Reading file and parsing markdown
    fmt.printfln("[Parsing] %s into %s", filename.fullpath, new_file)
    // data := read_file(filename.fullpath)
    /* options := cm.DEFAULT_OPTIONS | {cm.Options.Unsafe} */
    root := cm.parse_document(
        raw_data(data_without_frontmatter),
        len(data_without_frontmatter),
        cm.DEFAULT_OPTIONS)
    defer cm.node_free(root)

    // Rendering html
    /* html := cm.render_html(root, cm.DEFAULT_OPTIONS) */
    html := cm.render_html(root, {cm.Options.Unsafe})
    defer cm.free(html)

    // Replacing template contents
    template := string(read_file("templates/base.html"))
    final_html := apply_template(template, frontmatter, string(html))

    // Writing html contents to file
    fmt.printfln("[Writing] %s into public/", new_file)
    write_err := os.write_entire_file_from_string(new_file, string(final_html))
    if write_err != nil {
        fmt.eprintln("Error when writing to file:", filename.fullpath)
        return
    }
}

apply_template :: proc(template: string, frontmatter: Frontmatter, body: string) -> string {
    // Title
    html, _ := strings.replace_all(template, "{{title}}", frontmatter.title, context.temp_allocator)
    // Author
    html, _ = strings.replace_all(html, "{{author}}", frontmatter.author, context.temp_allocator)
    // Date
    html, _ = strings.replace_all(html, "{{date}}", frontmatter.date, context.temp_allocator)

    // Final
    html, _ = strings.replace_all(html, "{{content}}", body, context.temp_allocator)

    return html
}

handle_index :: proc(posts: string) {
    template := string(read_file("templates/index.html"))

    html, _ := strings.replace_all(template, "{{post_list}}", posts, context.temp_allocator)

    fmt.printfln("[Writing] %s into public/", "index.html")

    write_err := os.write_entire_file_from_string("public/index.html", html)
    if write_err != nil {
        fmt.eprintln("Error when writing to file:", "index.html")
        return
    }
}

build_post_list :: proc(posts: []Post) -> string {
    b := strings.builder_make(context.temp_allocator)

    for post in posts {
        fmt.sbprintf(&b, `<li><a href="%s">%s</a> <span class="byline">%s</span></li>`, 
             post.url, post.title, post.date)
    }

    return strings.to_string(b)
}
