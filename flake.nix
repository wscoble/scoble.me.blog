{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, utils }: utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      
      # Function to convert Markdown to HTML
      mdToHtml = pkgs.writeScriptBin "mdToHtml" ''
        #!${pkgs.stdenv.shell}
        head_content=$(cat ${./partials/head.html})
        foot_content=$(cat ${./partials/foot.html})
        title=$(sed -n 's/^title: "\(.*\)"/\1/p' "$1" | head -n 1)
        description=$(sed -n 's/^description: "\(.*\)"/\1/p' "$1" | head -n 1)
        content=$(${pkgs.pandoc}/bin/pandoc -f markdown -t html "$1")
        echo "$head_content" | sed "s/{{title}}/$title/g; s/{{description}}/$description/g" > "$2"
        echo "$content" >> "$2"
        echo "$foot_content" >> "$2"
      '';

      # Function to generate the blog pages (excluding index)
      generateBlogPages = pkgs.writeScriptBin "generateBlogPages" ''
        #!${pkgs.stdenv.shell}
        mkdir -p $out
        
        for file in ${./pages}/*.md; do
          filename=$(basename "$file" .md)
          if [ "$filename" != "index" ]; then
            ${mdToHtml}/bin/mdToHtml "$file" "$out/$filename.html"
          fi
        done
      '';

      # Function to generate the blog content
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

      # Function to generate and process the index page
      generateIndexPage = pkgs.writeScriptBin "generateIndexPage" ''
        #!${pkgs.stdenv.shell}
        set -e  # Exit on error
        set -x  # Enable debugging output
        content_dir="${./content}"
        index_md="${./pages/index.md}"
        index_html="$out/index.html"
        
        echo "Content directory: $content_dir"
        echo "Files in content directory:"
        ls -R "$content_dir"
        
        # Generate recent posts list
        recent_posts="<ul>"
        while read file; do
          echo "Processing file: $file"
          title=$(sed -n 's/^title: "\(.*\)"/\1/p' "$file" | head -n 1)
          date=$(sed -n 's/^date: \(.*\)/\1/p' "$file" | head -n 1)
          description=$(sed -n 's/^description: "\(.*\)"/\1/p' "$file" | head -n 1)
          rel_path=''${file#$content_dir/}
          link_path=$(echo "$rel_path" | sed 's/\.md$/.html/')
          echo "Title: $title"
          echo "Date: $date"
          echo "Description: $description"
          echo "Link path: $link_path"
          recent_posts="$recent_posts<li><h3><a href=\"/$link_path\">$title</a></h3><p>$date</p><p>$description</p></li>"
        done < <(find "$content_dir" -name '*.md' -print0 | xargs -0 grep -H '^date: ' | sort -r -k2 | head -n 5 | cut -d: -f1)
        recent_posts="$recent_posts</ul>"
        
        echo "Recent posts HTML:"
        echo "$recent_posts"
        
        # Inject recent posts into index.md
        sed "s|{{LATEST_POSTS}}|$recent_posts|g" "$index_md" > index_with_posts.md
        
        echo "Content of index_with_posts.md:"
        cat index_with_posts.md
        
        # Convert to HTML
        ${mdToHtml}/bin/mdToHtml index_with_posts.md "$index_html"
        
        echo "Content of final index.html:"
        cat "$index_html"
        
        # Clean up
        rm index_with_posts.md
      '';

      blog = pkgs.stdenv.mkDerivation {
        name = "scott-scoble-blog";
        src = ./.;
        buildInputs = [ ];
        buildPhase = ''
          mkdir -p $out/assets
          cp -r ${./assets}/* $out/assets/
          ${generateBlogPages}/bin/generateBlogPages
          ${generateBlogContent}/bin/generateBlogContent
          ${generateIndexPage}/bin/generateIndexPage
        '';
      };

      serve = pkgs.writeScriptBin "serve" ''
        #!${pkgs.stdenv.shell}
        ${pkgs.caddy}/bin/caddy file-server --listen :8000 --root $1
      '';

    in
    {
      packages.blog = blog;

      devShell = pkgs.mkShell {
        buildInputs = with pkgs; [
          
        ] ++ [
          serve
        ];
      };
    }
  );
}
