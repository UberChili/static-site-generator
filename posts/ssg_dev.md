---
{
    "title": "Building a static site generator",
    "author": "Andres",
    "date": "2026-05-06",
}
---

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

Finally, we get some nice, although very simple and raw, **HTML** output which we can see on the browser (by using an http server like Python's built in one). It's not much at all, but it's pretty nice to see the actual expected output so far.

## Conclusion of Part 2
I moved the steps of *parse_to_html* into this function so we can work with and free the allocated data more easily when going out of scope. The procedure is starting to become somewhat big but I believe it is still pretty straightforward at this point. Next is maybe splitting code into different source files and likely start working with frontmatters.

# Part 3: Frontmatters

## Splitting things up a little
First of all I thought that the main Odin file was getting a tiny bit too big to handle, and that kind of stuff sometimes annoys me too much. So I decided to split the file into multiple source files, separated by at least some minimal manner of organization. The following procedures: *read_file*, *get_md_files*, *posts_directory_exists*, and *public_directory_exists_or_create*, to **utils.odin**, in which I will continue to work, and our chunky *handle_file* procedure to **processor.odin**, which seems clean, as I plan to put everything related to the parsing and dealing with the actual Markdown files in there. So the source files are now:

- main.odin
- processor.odin, and
- utils.odin

## Working with frontmatters or "archetypes"
This was a little tricky. I couldn't help but assisting myself with Ginger Bill's [video](https://www.youtube.com/watch?v=YvnTsiIFXeI&t=485s) because I was stuck for a while there. And I have to insist that I'm trying my absolute hardest to not copy his code. But at the end I assisted myself by using the way he parsed the frontmatter, also, like he suggested, I decided to not use YAML:

> If you have a choice to use YAML, don't use it is my recommendation. Never use it! In fact, it's not a recommendation, it's a moral obligation! Don't use YAML, it's dreadful

A first version of the **parse_frontmatter** procedure, along with the **Frontmatter** struct, which will likely be modified, looks like the following:

```odin
Frontmatter :: struct {
    title: string,
    author: string,
    date: string,
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

```

and the example json might look like:
```json
{
    "title": "Building a static site generator",
    "author": "Andres",
    "date": "2026-05-06",
}
```
Of course, this goes between a pair of three dashes whose serve to delimit a frontmatter.

As you can see, for now it is... minimal? And maybe somewhat dumb code. I'm only catching a post title, an author and a date. Chances are we will need to work more on this as the project grows. But so far it's working. So, time to move on to some basic templating.

## A basic template

We'll use the following basic template, for now:
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>{{title}}</title>
    <meta name="author" content="{{author}}">
</head>
<body>
    <header>
        <h1>{{title}}</h1>
        <p>By {{author}} • {{date}}</p>
    </header>

    <main>
        {{content}}
    </main>

    <footer>
        <p>My Static Site Generator • Built with Odin</p>
    </footer>
</body>
</html>
```

Simple enough, let's try to pluck the corrent values in those placeholders. We can do that by adding the following lines to our **handle_file** procedure:
```odin
// loading the html template and replace
html_template := string(read_file("templates/base.html"))
// Title
html_template, _ = strings.replace_all(html_template, "{{title}}", frontmatter.title, context.temp_allocator)
// Author
html_template, _ = strings.replace_all(html_template, "{{author}}", frontmatter.author, context.temp_allocator)
// Date
html_template, _ = strings.replace_all(html_template, "{{date}}", frontmatter.date, context.temp_allocator)

html := cm.render_html(root, cm.DEFAULT_OPTIONS)
defer cm.free(html)

// Replacing template contents
html_template, _ = strings.replace_all(html_template, "{{content}}", string(html), context.temp_allocator)
```
Of course, that includes again the html rendering. I decided to keep it in the same place so I wouldn't get lost when reading this.

Hmm, that code looks a little ugly and disorganized. Maybe we can do something like:

```odin
// Rendering html
html := cm.render_html(root, cm.DEFAULT_OPTIONS)
defer cm.free(html)

// Replacing template contents
template := string(read_file("templates/base.html"))
final_html := apply_template(template, frontmatter, string(html))

// Writing html contents to file
... [snip]...

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
```

We have abstracted out a nice **apply_template** proc. This could be done more elegantly but for "moving-on" purposes we'll leave it like this. And, at least the big **handle_file** proc is trying to stay somewhat small or at least not grow indiscriminately!

This results in a nice, although still very raw, html output. We're getting there!

## Conclusion of Part 3
We split our program into different files for better organization and readability and we have implemented a basic frontmatter parsing, using JSON for now. We also got working the functionality to replace placeholders in a basic template. Later on, we might need to expand this to be able to work with different frontmatter values, ss well as different templates. I suppose this functionality will come in time as the CLI needs to handle stuff like different themes, for example. Although for my uses, there's a good chance that I'll just set a default theme/colorscheme, which is what I'll always use for my blog/website.
