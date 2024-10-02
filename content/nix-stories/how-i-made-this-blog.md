---
title: "How I Made This Blog"
description: "A detailed look at the process of creating my personal blog using Nix and custom static site generation"
date: 2024-03-14
lastmod: 2024-03-14
draft: false
toc: true
tags:
  - "nix"
  - "static site generator"
  - "blog"
  - "devops"
author: "Scott Scoble"
---

# How I Made This Blog

As a DevOps professional, I'm always looking for efficient and reproducible ways to manage projects. When it came to creating my personal blog, I decided to leverage the power of Nix to build a custom static site that's easy to maintain and deploy. In this post, I'll walk you through the process of how I set up this blog.

## Why Nix?

Before diving into the technical details, let's briefly discuss why I chose Nix for this project:

1. **Reproducibility**: Nix provides a declarative and reproducible build system, which aligns perfectly with my DevOps background. It ensures that my blog's build environment is consistent across different machines.

2. **Customization**: By using Nix, I could create a tailored static site generation process that fits my specific needs, without relying on existing static site generators.

3. **Learning Opportunity**: Building a blog from scratch with Nix allowed me to deepen my understanding of the Nix ecosystem and explore its capabilities in a practical project.

## Setting Up the Project

### The Nix Flake

The heart of this project is the `flake.nix` file, which defines the build environment and dependencies. Here's a look at the key parts of my flake:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, utils }: utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      
      // ... rest of the flake configuration ...
    }
  );
}
```

This section sets up the inputs for our flake, including the Nixpkgs repository and some utilities.

### Building the Blog

To generate the blog content, I created custom scripts using Nix. Here's how I convert Markdown to HTML:

```nix
mdToHtml = pkgs.writeScriptBin "mdToHtml" ''
  #!${pkgs.stdenv.shell}
  ${pkgs.pandoc}/bin/pandoc -f markdown -t html "$1" -o "$2"
'';
```

This script uses Pandoc to convert Markdown files to HTML.

## Generating Blog Pages and Content

I created two main functions to generate the blog:

1. `generateBlogPages`: This function processes Markdown files in the `pages` directory:

```nix
generateBlogPages = pkgs.writeScriptBin "generateBlogPages" ''
  #!${pkgs.stdenv.shell}
  mkdir -p $out
  for file in ${./pages}/*.md; do
    filename=$(basename "$file" .md)
    ${mdToHtml}/bin/mdToHtml "$file" "$out/$filename.html"
  done
'';
```

2. `generateBlogContent`: This function handles the main blog content:

```nix
generateBlogContent = pkgs.writeScriptBin "generateBlogContent" ''
  #!${pkgs.stdenv.shell}
  content_dir="${./content}"
  for file in $(find $content_dir -name '*.md'); do
    rel_path=''${file#$content_dir/}
    dir_path=$(dirname "$rel_path")
    filename=$(basename "$file" .md)
    mkdir -p "$out/$dir_path"
    ${mdToHtml}/bin/mdToHtml "$file" "$out/$dir_path/$filename.html"
  done
'';
```

These functions allow me to maintain a clear separation between static pages and blog content while using a consistent conversion process.

## Continuous Integration and Deployment

To automate the build and deployment process, I set up a GitHub Actions workflow:

```yaml
name: Build and Deploy Site

on:
  push:
    branches:
      - main

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: cachix/install-nix-action@v27
        with:
          nix_path: nixpkgs=channel:nixos-unstable

      - run: nix build .#blog

      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./result
```

This workflow builds the blog using Nix and deploys it to GitHub Pages whenever changes are pushed to the main branch.

## Conclusion

By leveraging Nix, I've created a blog that's not only easy to maintain but also ensures a consistent build environment. The custom static site generation process gives me full control over how my content is processed and presented. The use of GitHub Actions for CI/CD streamlines the deployment process, allowing me to focus on writing content rather than worrying about the technical details of publishing.

In future posts, I'll dive deeper into specific aspects of this setup, including customizing the HTML output, optimizing the Nix build, and more advanced CI/CD techniques.

Feel free to check out the full source code on my [GitHub repository](https://github.com/wscoble/scoble.me.blog) to see how all these pieces fit together.