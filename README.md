# Minimal Static Site Generator

A small, fast, and personal static site generator written in **Odin**.

Built because I wanted something smaller and simpler than **Hugo**, and something I fully understand and control. And also because I wanted to write some Odin.

## Features

- Markdown → clean HTML using [Tufte CSS](https://edwardtufte.github.io/tufte-css/)
- Clean homepage with sorted post list
- JSON frontmatter support (`title`, `date`, `author`, `type`)
- Distinguishes between **posts** and **static pages**
- Static asset copying (`static/` → `public/static/`)
- Automatic slug generation (`My Cool Post.md` → `my-cool-post.html`)
- Clean builds (removes old files)

## Installation
### 1. Compile the binary (recommended)
```bash
# Clone the repo
git clone https://github.com/UberChili/static-site-generator.git
cd static-site-generator

# Compile with optimizations (fastest binary)
odin build . -o:speed
```
This will produce an executable called static-site-generator (or ssg if you rename it).

### 2. Install system-wide (optional)
```bash
# Make it executable and install to /usr/local/bin
chmod +x static-site-generator
sudo cp static-site-generator /usr/local/bin/ssg
```
Now you can run ssg from anywhere. **But ssg will still expect the directories mentioned in the following section**.

## Usage
For now, you add the content yourself manually. The static site generator expects your project to have a **content**, **templates**, and a **static** directories, something like the following:
```bash
.
├── content/           # ← Your writing goes here
│   ├── posts/
│   └── pages/
├── templates/         # ← Edit these to change appearance
│   ├── base.html
│   └── index.html
├── static/            # ← CSS, fonts, images
│   ├── css/
│   └── images/
└── public/            # ← Generated site (never commit this)
```

**Note:** I left a basic **base.html** and **index.html**, as well as my custom.css with the slight modifications I made to Tufte CSS, as I use them currently, as a starting point for you. 

Be sure to modify them to your liking or replace them completely! 

This is how it knows the current directory is a website. Then you can just do:
```bash
ssg
```

This will:
- Clean the public directory
- Process all **.md** files in the **content/** directory
- Generate **HTML files** + homepage (**index.html**)
- Copy static assets

## Adding content
- Place and edit your posts in **content/posts/**
- Static pages go in **content/pages/**
- Use frontmatter with "type": "post" or omit for pages

Example frontmatter:
```json
{
    "title": "My First Post",
    "author": "Andrés",
    "date": "2026-05-17",
    "type": "post"
}
```

## Limitations
- Very minimal templating (simple string replacement)
- No built-in syntax highlighting
- No watch mode
- No RSS feed
- No advanced features (tags, pagination, etc.)

This is intentionally small. It does exactly what I need (for now), and nothing more.

## Future ideas
- Simple CLI (**ssg new post "title", ssg serve,** etc.)
- Excerpts on homepage
- Watch mode for live reloading
- RSS support

## Why I did this
I wanted to learn Odin while solving a real problem. And even better: solving a real problem for myself. Hugo is amazing, powerful and fast, and it is what I was using until I wrote this, but felt like overkill for a personal site like mine. This project taught me a lot about file handling, memory management, keeping things simple, and more importantly... to build my own tools.
