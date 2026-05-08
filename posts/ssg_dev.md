# Building a Static Site Generator

## The Idea
I wanted to work on a static site generator for a while now. Up until now, I've been using Go's Hugo, which works great but is pretty damn overkill for my needs. Not to mention that, I kind of feel like learning it has been too hard for me. Also, I've been thinking on some project ideas lately and a static site generator seemed like a decent project for my skill level. First, I tried writing it in Rust but dropped the project shortly after starting. No real reason why, it just kind of happened.

Then, some days ago, I came accross [Ginger Bill's video](https://www.gingerbill.org/) in which he explains how he wrote his own SSG. What a coincidence! When I watched that video, I was already one or two days into learning a little **Odin**. So it seemed like a great project idea. So I started working. 

Let's see if we can make it so that this site is actually built using my own static site generator!

# Part 1: Reading files and simple parsing

## Getting filenames and opening files
I was expecting this to be done in a similar fashion as in Rust, i.e. with something like a PathBuf. But it can be just easily done with regular strings, like, to get the contents of a directory, we can do something like:

```odin
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
``` 

Before doing this, I used another procedure to check if path was an existing, valid directory. Simple enough.

## What do we do with the filenames?
At this point I was only getting a list of the **markdown** files in the **posts** directory and printing their filenames or filepaths, I was not really doing anything interesting with them. For now, I decided to only parse them to simple html and print them to stdout. This can be done with the following procedure:
```odin
parse_to_html :: proc(data: []byte) {
    root := cm.parse_document(raw_data(data), len(data), cm.DEFAULT_OPTIONS)
    defer cm.node_free(root)

    html := cm.render_html(root, cm.DEFAULT_OPTIONS)
    defer cm.free(html)

    fmt.println(html)
}
```
We are receiving the file as a slice of bytes and using **Commonmark** (included in **Odin**) to parse to HTML. Later on, I'll modify this procedure to do something useful with the resulting HTML, instead of just printing to stdout.

## Conclusion of Part 1
And that is it for today. It might seem to be a very minimal amount of work but, to be fair with myself, it is the first time I've written Odin and the first time in a while that I've been actually programming. And I think it is the first time I've documented my progress through developing something. So I'll take a break here and continue tomorrow, trying to take small, accountable steps.

# Part 2: Writing output
In part 1, we left off just writing HTML to stdout. It is time to, at the very least, write to simple output HTML files. For this, my initial approach was to modify the *parse_to_html* procedure as follows:

```odin
parse_to_html :: proc(data: []byte) -> cstring {
    root := cm.parse_document(raw_data(data), len(data), cm.DEFAULT_OPTIONS)
    defer cm.node_free(root)

    html := cm.render_html(root, cm.DEFAULT_OPTIONS)
    // defer cm.free(html)

    return html
}
``` 

And then call it from another procedure, tentatively named *handle_file*, but this quickly seemed to me to be not ideal. So I thought instead to use a single procedure to get the html and to write to disk. Also, notice how the defer line is commented out. This is because we need to return this data to the caller, so another procedure can use it to write that information to disk. Thus, we cannot free the allocated data in the variable **html** before going out of scope. However, if I leave that line commented out, We get a memory leak!

## A single procedure to handle files
The solution for this is to use a single procedure to read the file (although this can still be done by calling *read_file*), then parsing the contents to html, and then printing the html code to disk. The best candidate is to use our already working, although leaky, *handle_file* procedure. The final version, at least for this part, looks like the following:
```odin
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
```
I moved the steps of *parse_to_html* into this function so we can work with and free the allocated data more easily when going out of scope. The procedure is starting to become somewhat big but I believe it is still pretty straightforward at this point.