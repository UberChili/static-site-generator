---
{
    "title": "Building a static site generator",
    "author": "Andres",
    "date": "2026-05-06",
    "type": "post",
}
---

<!-- # Building a Static Site Generator -->

# The Idea
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

# Part 4: Adding some CSS

## Cleaning up some redundant procedures
First, I noticed our **main.odin** file was a little ugly and also noticed a pattern: I was creating multiple unneeded procedures that did the same thing. So I factured that out into a single procedure and cleaned **main** a little. The new procedure looks like:
```odin
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
```

And main, so far, looks like:
```odin
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
```

Now, I deleted the rest of the redundant procedures and **utils.odin** is now "ligher", so to speak.

## A new directory we need
Now, we need an actual *static* directory. This directory is normally where stuff like fonts, images, and **CSS** styles are stored. So far what we need is something like shown in the margin note.

static/

└── css/

   └── et-book/

   └── style.css


We also need to update our base html template. We will add the following line:
```html
<link rel="stylesheet" href="static/css/tufte.css">
```

Notice we will be using the cool [Tufte CSS](https://edwardtufte.github.io/tufte-css/).
(Another inspiration from following Ginger Bill. Thanks, man).
It is funny because I don't think I even use margin notes much, if at all! But that's alright, I still really like how it looks like, so that's that. 

<label for="mn-demo" class="margin-toggle">&#8853;</label>
<input type="checkbox" id="mn-demo" class="margin-toggle"/>
<span class="marginnote">
    Oh hey, here's a margin note!
</span>

[Tufte CSS](https://edwardtufte.github.io/tufte-css/) is Open Source, so we grab it and copy the **et-book** directory (which contains the fonts) and the **style.css** file into our *static* directory.

I will also be making some small modifications to our base template file, nothing worth mentioning here, for now.

This produces a very classy, readable and elegant book-style that looks just great for my style, which, hopefully you can already see as you read this article!

## Some configuration
It seems to work out of the box! Except we need to add some configurations to better suit my style. Let's check it out. First of all, we needed to change some elements of the base template. Which ended up being something almost completely different. So I'll just show it here again:
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>{{title}}</title>
    <meta name="author" content="{{author}}">

    <link rel="stylesheet" href="static/tufte.css">
    <link rel="stylesheet" href="static/css/custom.css">   <!-- your tweaks -->
</head>
<body>
    <article>
        <header>
            <h1>{{title}}</h1>
            <!-- <p class="subtitle">By {{author}} • {{date}}</p> -->
            <p class="subtitle">{{date}}</p>
        </header>

        <main>
            {{content}}
        </main>

        <footer>
            <p>Stay Medieval ❤️‍🔥</p>
        </footer>
    </article>
</body>
</html>
```

This is following Tufte's convention with a little aid by Grok (I'm not very fluent in HTML).

Key changes:
- Wrapped everything in **article** (Tufte's main container)
- Removed the **main** wrapper
- Added a **.subtitle** class for the author/date line

I also added a custom css file to fine tune some things, also using Grok because fuck CSS:
```CSS
body {
    max-width: 72em;           
    margin-left: auto;
    margin-right: auto;
    padding: 0 1.5em;
}

article {
    padding: 0;
}

.byline {
    margin-top: 0.2em;
    color: inherit;            /* keep existing colors */
    opacity: 0.8;
}

/* Optional: fine-tune margin notes if they still feel off */
.marginnote, .sidenote {
    margin-right: -35%;
    width: 30%;
}
```

Except this didn't fully work. Every time I tried something new, something else was missing or janky. I ended up, with even further assistance of all Grok, ChatGPT and Claude, with a **custom.css** that looked considerably different than the one shown above. I'll omit showing it fully again as I think it would not be that interesting for the purposes of this post/devblog. The important thing to keep in mind here is, I used a custom.css to fine tune some elements in how the theme looks.

Done. And I'm starting to feel very happy with the results!

## Conclusion of part 4
That was ANNOYING. Of course I'm not a front-end developer.
Seriously now, all this messing with Tufte's (and my custom) CSS held me back more or less an entire day. I think I am happy with how the site looks currently so I'll just try to move on and focus on what's left for the project, like for example, getting an actual index page.

# Part 5: Index Page
An index page's purpose is to give us a quick glance into the posts of our website and some basic information about ourselves. So it should include the site's name, maybe the author's name, and a series of posts, ranging from around five to ten, or more, depending on the author.

## Getting a list of posts and sorting them
For this, we need to get a list of our posts such that we can display them at the front page. Preferably, sorted.

Sorting the posts is somewhat trivial. We need to use a struct to keep track of very basic information of each post, like their name and url. Currently I decided to use something like the following:

```odin
Post :: struct {
    title: string,
    date: string,
    url: string,
}
```

Along with a couple new procedures:
```odin
slugify :: proc(original: string) -> string {
    lowered, _ := strings.to_lower(original, context.temp_allocator)
    no_spaces, _ := strings.replace_all(lowered, " ", "-", context.temp_allocator)
    no_underscores, _ := strings.replace_all(no_spaces, "_", "-", context.temp_allocator)
    return no_underscores
}

build_post_list :: proc(posts: []Post) -> string {
    b := strings.builder_make(context.temp_allocator)

    for post in posts {
        fmt.sbprintf(&b, `<li><a href="%s">%s</a> <span class="byline">%s</span></li>`, 
             post.url, post.title, post.date)
    }

    return strings.to_string(b)
}
```

And a few additions in main:
```odin
    // Sorting Posts
    slice.sort_by(posts_arr[:], proc(a, b: Post) -> bool {
        return a.date > b.date
    })
    // Building post list
    post_list := build_post_list(posts_arr[:])
    // Loading, handling and copying index page
    handle_index(post_list)
```

As we can see, we use **slugify** to get better named filenames.
In main, we use a little trick, using the **sort_by** Odin procedure to sort our slice of posts. Which we also got from **handle_file**. A small addition was needed in this procedure, which I will omit for brevity, but it is important to mention that that procedure's signature changed to the following:

```odin
handle_file :: proc(filename: os.File_Info, directory: string, array: ^[dynamic]Post) {}
```

This is because we now need to append to our dynamic array of **Post** objects that stores our posts.

## Writing the list to a nice index page
Then, we use **handle_index**, which does some of the job that **handle_file** does, except we only need to grab an HTML template, replace some of its contents, and write it out to the public directory. As we're not dealing with Markdown whatsoever, we can omit a lot of work, so creating a new procedure seemed like a cleaner approach:
```odin
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
```

Along with our new base template for index.html:
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>{{Title}}</title>
    <link rel="stylesheet" href="static/tufte.css">
    <link rel="stylesheet" href="static/css/custom.css">
</head>
<body>
    <article>
        <h1>Heading</h1>

        <h2>Articles</h2>
        
        <ul>
            {{post_list}}
        </ul>

        <footer>
            Something
        </footer>
    </article>
</body>
</html>
```

It is very similar to our base template, simple and minimalistic. The magic is just done, like in the parsing of the other templates, when we replace the **{{post_list}}** placeholder with our list of posts.
a **string builder** is very useful for this. And indeed we use it in a new process called **build_post_list** as is shown next:
```odin
build_post_list :: proc(posts: []Post) -> string {
    b := strings.builder_make(context.temp_allocator)

    for post in posts {
        fmt.sbprintf(&b, `<li><a href="%s">%s</a> <span class="byline">%s</span></li>`, 
             post.url, post.title, post.date)
    }

    return strings.to_string(b)
}
```

We pretty much iterate over our slice of posts, get the info we need, and insert all the information into their respective placeholders and then return all of it as a single string.

By this point, after reading a number of these procedures, there's a chance you might have noticed something:

I'm being somewhat sloppy with the error handling.

I have to admit this is lazy work. But in my defense, I can say that this is first and foremost a personal project and for personal use. I am still trying to use at least some forms of error handling and trying to be careful here and there, but there's a number of places where I'm taking shortcuts. Again, this project is mainly for my personal use so we can just move on. If this ever becomes more serious, we can always work on improving all around it.

## Conclusion of Part 5 and current state of the project
This part was quite fun and I was somewhat excited to get to it. Forming an array/slice of our posts and sorting them in order to display them in a nice, clean list in our index was a nice learning experience as it combines or reinforces many elements we've been dealing with through this project: Parsing our Markdown files to HTML, rendering the HTML and replacing some values while applying some logic to it. I think the current state of the project is... almost finished! This version might be 1.0 as, for my needs, I can totally see myself starting to use this for my personal website. Of course, there are some missing features here and there, but the results speak for themselves. This is usable.

Still, I'll try to not abandon this project here and polish it at least a little more. I have many ideas about what the following parts will be about. So, let's check out the consecutive parts.

# Part 6: A different organization for files
Currently, we are just reading an arbitrary **"posts"** directory, getting all **.md** files, parsing them, and spitting them as HTML to the **public** directory. Good enough for now. But we could use with a little more organization. All the entries in our site are _content_, but... at the very least, and trying to stay minimal, we can split this content into two _categories_: **posts** and **pages**.

## Posts
This is pretty much what we've been dealing with for the entire project up until this point and the chunk of the content of the site.
We can think of a _post_ as a synonim of an _article_ or a _blog entry_. An update, something the author wants to share to the world.

Again, we've been dealing with posts correctly until now. We have a working frontmatter and all. We loop through the **posts** directory and parse all **.md** files. Simple. Those content files (the _posts_) are what will be shown in the **index** page in all their glory. No significant changes here.

## Pages
I think o a page, as something less creative and expressive, but more as more "static" content. Something that holds important information and can easily be seen. Think about a **resume** page or an **about** page. (Both of which, yeah, I plan to use and currently use in my current personal website).

So, in order to support pages, I thought first, like I mentioned at the start of this part, to at least split the directory structure; simply into a **content** directory, inside which, we now have two subdirectories: **posts** and **pages**. This requires some modifications to the **get_md_files** procedure, since before we were getting a list of a directory's contents by using Odin's builtin procedure **os.read_directory_by_path()**, which returns a **[]os.File_Info**, which works well enough. But now we need something a little more robust, as we're dealing with subdirectories.

This is better solved by using **walkers** as shown in the modified **get_md_files** procedure:
```odin
get_md_files :: proc(path: string, files_da: ^[dynamic]os.File_Info) {
    if !os.exists(path) {
        fmt.eprintfln("Path doesn't exist:", path)
        return 
    }

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
```

We now pass a pointer to a dynamic array in which we will store our posts. We pass a pointer of the dynamic array, instead of having the procedure return a dynamic array, because this way it is easier to clean up the memory from the caller, in this case, **main**:
```odin
    // Getting files from content directory
    files := [dynamic]os.File_Info{}
    defer delete(files)
    get_md_files(content, &files)
```

Now, we need to "filter out" the content that _should not_ be included in the index. Stuff like a **resume** page or an **about** page. This can easily be solved by adding a new field to our frontmatters:
```odin
Frontmatter :: struct {
    title: string,
    author: string,
    date: string,
    type: string
}
```

And, for example, this is how the frontmatter looks for this same post:
```json
{
    "title": "Building a static site generator",
    "author": "Andres",
    "date": "2026-05-06",
    "type": "post",
}
```

Keeping it simple for now.
This could also be solved by checking the subfolder name but I think having it in the frontmatter is more descriptive. I could be wrong but I'll keep it like this for now.

And for this to work, we need to make yet another modification to the **handle_file** procedure. Just a simple check to decide whether to include a given file into the **posts_arr** that we return to use to form the **index** posts list.
```odin
    // Filling Post struct and appending to array, only if current file is a post
    if frontmatter.type == "post" {
        slug := fmt.tprintf("%s.html", only_filename)
        post := Post{
            title = frontmatter.title,
            date = frontmatter.date,
            url = fmt.tprintf("%s.html", only_filename)}
        append(array, post)
    }
```

And done. This cleanly "filters out" all content that is not normal _posts_ to be shown in the index page!

## Conclusion of Part 6
Another fun part to implement. Just a matter of adding a little more information to the frontmatters, directory and subdirectories structure, and some logic. This is shaping up nicely.
