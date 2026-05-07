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

Before doing this, I used another function to check if path was an existing, valid directory. Simple enough.

At this point I was only getting a list of the **markdown** files in the **posts** directory and printing their filenames or filepaths, I was not really doing anything interesting with them. For now, I decided to only parse them to simple html and print them to output. This can be done with the following function:
```odin
parse_to_html :: proc(data: []byte) {
    root := cm.parse_document(raw_data(data), len(data), cm.DEFAULT_OPTIONS)
    defer cm.node_free(root)

    html := cm.render_html(root, cm.DEFAULT_OPTIONS)
    defer cm.free(html)

    fmt.println(html)
}
```
We are receiving the file as a slice of bytes and using **Commonmark** (included in **Odin**) to parse to HTML. Later on, I'll modify this function to do something useful with the resulting HTML, instead of just printing to stdout.

# Conclusion of first part
And that is it for today. It might seem to be a very minimal amount of work but, to be fair with myself, it is the first time I've written Odin and the first time in a while that I've been actually programming. And I think it is the first time I've documented my progress through developing something. So I'll take a break here and continue tomorrow, trying to take small, accountable steps.

# Part 2: Writing output

In part 1, we left off just writing HTML to stdout. It is time to, at the very least, write to simple output HTML files. For this, my initial approach was to modify the *parse_to_html* function as follows:

```odin
parse_to_html :: proc(data: []byte) -> cstring {
    root := cm.parse_document(raw_data(data), len(data), cm.DEFAULT_OPTIONS)
    defer cm.node_free(root)

    html := cm.render_html(root, cm.DEFAULT_OPTIONS)
    // defer cm.free(html)

    return html
}
``` 

And then use it in another function: