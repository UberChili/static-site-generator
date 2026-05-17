# Minimal Static Site Generator

A small, fast, and personal static site generator written in **Odin**.

Built because I got tired of Hugo's complexity and wanted something I fully understand and control. And also because I wanted to write some Odin.

## Features

- Markdown → clean HTML using [Tufte CSS](https://edwardtufte.github.io/tufte-css/)
- Clean homepage with sorted post list
- JSON frontmatter support (`title`, `date`, `author`, `type`)
- Distinguishes between **posts** and **static pages**
- Static asset copying (`static/` → `public/static/`)
- Automatic slug generation (`My Cool Post.md` → `my-cool-post.html`)
- Clean builds (removes old files)

## Project Structure

```bash
content/
├── posts/
│   └── my-first-post.md
└── pages/
    └── about.md

templates/
├── base.html
└── index.html

static/
├── css/
└── images/

public/          # ← generated output (add to .gitignore)
```

## Usage
1. Build
```bash
odin build .
```

2. Run
```bash
./ssg
```

This will:
- Clean the public directory
- Process all **.md** files in the **content/** directory
- Generate HTML files + homepage (index.html)
- Copy static assets

3. Add content
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
- No built-in syntax highlighting (yet)
- No watch mode
- No RSS feed
- Basic error handling
- No advanced features (tags, pagination, etc.)

This is intentionally small. It does exactly what I need (for now), and nothing more.

## Future ideas
- Simple CLI (**ssg new post "title", ssg serve,** etc.)
- Excerpts on homepage
- Watch mode for live reloading
- RSS support

## Why I did this
I wanted to learn Odin while solving a real problem. Hugo is amazing, powerful and fast, but felt like overkill for a personal site like mine. This project taught me a lot about file handling, memory management, keeping things simple, and more importantly... to build my own tools.
